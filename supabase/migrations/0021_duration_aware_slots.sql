-- 0021_duration_aware_slots.sql
-- Make the slot engine reserve each client's real block time instead of a
-- single fixed city slot (legacy_folds_into_v2). bath_open_slots gains an
-- optional p_duration_minutes: the appointment length to fit. When omitted it
-- falls back to the city's bath slot, so the bath funnel's existing 3-arg call
-- keeps working unchanged. Start times move to a 15-minute grid so a long groom
-- and a short nail visit both find real openings.
--
-- Because block lengths now vary per client, a unique-on-start index no longer
-- prevents double-booking (a 9:00 x 60min and a 9:15 x 30min overlap without
-- sharing a start). Replace it with a real no-overlap exclusion constraint over
-- the live appointment time ranges.

CREATE EXTENSION IF NOT EXISTS btree_gist;

-- Defensive: every live appointment needs an end for the range guard. All insert
-- paths set scheduled_end; this only catches any pre-existing null.
UPDATE public.bath_appointments
   SET scheduled_end = scheduled_start + interval '60 minutes'
 WHERE scheduled_end IS NULL
   AND status NOT IN ('cancelled', 'skipped', 'no_show');

DROP INDEX IF EXISTS public.bath_appointments_one_at_a_time;

ALTER TABLE public.bath_appointments
  ADD CONSTRAINT bath_appointments_no_overlap
  EXCLUDE USING gist (tstzrange(scheduled_start, scheduled_end, '[)') WITH &&)
  WHERE (status NOT IN ('cancelled', 'skipped', 'no_show'));

-- Replace the fixed-slot function with the duration-aware one. Drop the old
-- 3-arg signature first; the new 4-arg form with a default covers the old call.
DROP FUNCTION IF EXISTS public.bath_open_slots(uuid, timestamptz, timestamptz);

CREATE OR REPLACE FUNCTION public.bath_open_slots(
  p_city_id          uuid,
  p_from             timestamptz,
  p_to               timestamptz,
  p_duration_minutes integer DEFAULT NULL
)
RETURNS TABLE (slot_start timestamptz, slot_end timestamptz)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_city_slot integer;
  v_horizon   integer;
  v_tz        text;
  v_from      timestamptz;
  v_to        timestamptz;
  v_len       interval;
  v_grid      interval := interval '15 minutes';  -- start-time granularity
BEGIN
  SELECT hb_slot_minutes, hb_booking_horizon_days, hb_timezone
    INTO v_city_slot, v_horizon, v_tz
    FROM public.cities WHERE id = p_city_id AND hb_active = true;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'city % is not an active Hurricane Bath city', p_city_id;
  END IF;

  -- Appointment length: the requested per-client duration, else the city's
  -- default bath slot. If neither is set, offer nothing rather than guess.
  IF p_duration_minutes IS NOT NULL THEN
    v_len := make_interval(mins => p_duration_minutes);
  ELSIF v_city_slot IS NOT NULL THEN
    v_len := make_interval(mins => v_city_slot);
  ELSE
    RETURN;
  END IF;

  v_from := greatest(p_from, now());
  v_to   := least(p_to, now() + make_interval(days => v_horizon));
  IF v_from >= v_to THEN
    RETURN;
  END IF;

  RETURN QUERY
  WITH days AS (
    SELECT d::date AS day
    FROM generate_series(v_from AT TIME ZONE v_tz, v_to AT TIME ZONE v_tz, interval '1 day') AS d
  ),
  recurring AS (
    SELECT days.day, w.start_time, w.end_time
    FROM days
    JOIN public.bath_availability_windows w
      ON w.city_id = p_city_id
     AND w.active = true
     AND w.weekday = EXTRACT(DOW FROM days.day)::int
    WHERE NOT EXISTS (
      SELECT 1 FROM public.bath_availability_exceptions x
      WHERE x.city_id = p_city_id AND x.exception_date = days.day AND x.is_closed = true
    )
  ),
  extra AS (
    SELECT days.day, x.start_time, x.end_time
    FROM days
    JOIN public.bath_availability_exceptions x
      ON x.city_id = p_city_id
     AND x.exception_date = days.day
     AND x.is_closed = false
  ),
  windows AS (
    SELECT * FROM recurring
    UNION ALL
    SELECT * FROM extra
  ),
  -- Every 15-minute start where a full v_len block fits inside the window.
  candidates AS (
    SELECT s AS slot_start, s + v_len AS slot_end
    FROM windows,
    LATERAL generate_series(
      (windows.day + windows.start_time) AT TIME ZONE v_tz,
      ((windows.day + windows.end_time)  AT TIME ZONE v_tz) - v_len,
      v_grid
    ) AS s
  )
  SELECT c.slot_start, c.slot_end
  FROM candidates c
  WHERE c.slot_start >= v_from
    AND c.slot_start <  v_to
    AND NOT EXISTS (
      SELECT 1 FROM public.bath_appointments a
      WHERE a.status NOT IN ('cancelled', 'skipped', 'no_show')
        AND a.scheduled_start < c.slot_end
        AND COALESCE(a.scheduled_end, a.scheduled_start + v_len) > c.slot_start
    )
  ORDER BY c.slot_start;
END;
$$;

REVOKE ALL ON FUNCTION public.bath_open_slots(uuid, timestamptz, timestamptz, integer) FROM public;
GRANT EXECUTE ON FUNCTION public.bath_open_slots(uuid, timestamptz, timestamptz, integer)
  TO anon, authenticated;
