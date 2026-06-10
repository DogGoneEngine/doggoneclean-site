-- 0143: two truth fixes in the slot engine, found while building the
-- capacity watcher (2026-06-10).
--
-- 1. LEGACY RESCHEDULE WAS BROKEN. bath_open_slots raised an exception for
--    any city with hb_active = false, and all 33 legacy subscribers live in
--    Ocala, which is hb_active = false until the anchor gate launch. So every
--    legacy portal reschedule and skip-then-rebook died with "city is not an
--    active Hurricane Bath city". hb_active means "open to NEW public
--    booking" and is still enforced where that decision lives
--    (bath_start_subscription checks it independently); the slot engine now
--    serves any configured city, because existing clients in a not-yet-
--    launched city still need to move their visits. The only thing this
--    exposes to anon is Ocala's free time grid, which is the same class of
--    information The Villages already publishes.
--
-- 2. THE OCALA EVERY-OTHER-WEEK RULE HAD NO TEETH
--    (ocala_availability_every_other_week): the recurring Tue-Sat windows
--    repeated every week, so a legacy client could reschedule onto a week
--    Paul is in The Villages. cities.hb_week_parity_anchor (a Monday date;
--    null = every week) now carries the alternation: recurring windows only
--    open on weeks an even number of weeks from the anchor. Manual
--    bath_availability_exceptions with is_closed = false BYPASS the parity
--    on purpose: that is exactly how Paul opens an extra day or a brief
--    return trip on an off week, per the same Oracle rule.
--    Ocala's anchor: Monday 2026-06-08 (the rule's own anchor week).

alter table public.cities
  add column if not exists hb_week_parity_anchor date;

comment on column public.cities.hb_week_parity_anchor is
  'When set (a Monday), recurring availability windows open only on weeks an even number of weeks from this date (ocala_availability_every_other_week). Null = every week. Open exceptions bypass it.';

update public.cities set hb_week_parity_anchor = date '2026-06-08' where slug = 'ocala';

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
  v_anchor    date;
  v_from      timestamptz;
  v_to        timestamptz;
  v_len       interval;
  v_grid      interval := interval '15 minutes';  -- start-time granularity
BEGIN
  -- Configured city, active or not: hb_active gates NEW public booking (and
  -- is enforced in bath_start_subscription), not the slot grid itself.
  SELECT hb_slot_minutes, hb_booking_horizon_days, hb_timezone, hb_week_parity_anchor
    INTO v_city_slot, v_horizon, v_tz, v_anchor
    FROM public.cities WHERE id = p_city_id;
  IF NOT FOUND OR v_tz IS NULL THEN
    RAISE EXCEPTION 'city % is not configured for scheduling', p_city_id;
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
    -- Every-other-week cities: recurring windows open only on on-weeks.
    AND (v_anchor IS NULL
         OR mod(mod((days.day - v_anchor) / 7, 2) + 2, 2) = 0)
  ),
  extra AS (
    -- Open exceptions bypass the parity: this is how an off-week return
    -- trip or an extra day is opened by hand.
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
  TO anon, authenticated, service_role;
