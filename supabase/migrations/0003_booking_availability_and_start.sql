-- 0003_booking_availability_and_start.sql
--
-- Booking flow, slice 1: the availability layer and the signup RPC. No
-- Stripe and no UI here; this is the real, server-side foundation the
-- booking funnel calls (no_mockups: the funnel is built against these
-- from its first commit).
--
-- What this adds:
--   1. City booking config (slot length, buffer, horizon, timezone).
--   2. bath_availability_windows  - the operator's recurring weekly open
--      windows. Empty until Paul enters his real Villages hours
--      (real_data_only): no slots are offered until then.
--   3. bath_availability_exceptions - per-date closures and one-off extra
--      windows (holidays, a day off, an added Saturday).
--   4. bath_open_slots(city, from, to) - SECURITY DEFINER function that
--      returns only genuinely free slots (windows expanded to the slot
--      grid, minus past, minus already-booked visits). It returns no PII,
--      so anon and authenticated may call it to render the picker without
--      leaking anyone else's bookings.
--   5. bath_start_subscription(...) - SECURITY DEFINER signup RPC that
--      enforces the rule pack atomically: bath-only coat eligibility,
--      three-dog cap, cadence pricing, founders cap + one-year lock,
--      price snapshot, one-bath-at-a-time, and creates the first
--      appointment at the chosen slot.
--
-- NOT in this slice (own slices next): the Stripe SetupIntent edge
-- function (needs the Dog Gone Clean test keys) and the funnel UI. The
-- portal mutation RPCs (pause/resume/cancel/skip/reschedule) are Phase 3.
--
-- Deliberately deferred: the route/drive-time optimizer. Clients picking a
-- real open slot does not need auto-sequencing (elons_algorithm: do not
-- build it until it is real), so availability is a flat per-city slot grid
-- for now. The one-bath-at-a-time guard is a global no-overlap rule on the
-- single operator; revisit when a second operator/route exists.
--
-- OPEN PRICING DECISION for Paul (flagged, not invented): for a multi-dog
-- visit with mixed coat tiers, base_price is taken as the HIGHER tier among
-- the dogs and each additional dog applies the city decrement. This never
-- undercharges. If Paul wants a different combination rule (e.g. first dog
-- as entered), it changes only the base-tier selection below.

-- ── 1. City booking config ────────────────────────────────────────────
ALTER TABLE public.cities
  ADD COLUMN IF NOT EXISTS hb_slot_minutes        integer,
  ADD COLUMN IF NOT EXISTS hb_buffer_minutes      integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS hb_booking_horizon_days integer NOT NULL DEFAULT 28,
  ADD COLUMN IF NOT EXISTS hb_timezone            text    NOT NULL DEFAULT 'America/New_York';

ALTER TABLE public.cities
  ADD CONSTRAINT cities_hb_slot_minutes_chk
    CHECK (hb_slot_minutes IS NULL OR hb_slot_minutes > 0),
  ADD CONSTRAINT cities_hb_buffer_minutes_chk
    CHECK (hb_buffer_minutes >= 0),
  ADD CONSTRAINT cities_hb_horizon_chk
    CHECK (hb_booking_horizon_days > 0);

-- hb_slot_minutes intentionally left NULL on The Villages until Paul
-- gives the real per-visit duration. bath_open_slots raises until it is
-- set, so the picker shows nothing rather than a guessed grid.


-- ── 2. bath_availability_windows ──────────────────────────────────────
-- weekday uses Postgres DOW: 0 = Sunday .. 6 = Saturday. Times are local
-- to the city's hb_timezone.
CREATE TABLE public.bath_availability_windows (
  id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  city_id     uuid        NOT NULL REFERENCES public.cities(id) ON DELETE CASCADE,
  weekday     smallint    NOT NULL CHECK (weekday BETWEEN 0 AND 6),
  start_time  time        NOT NULL,
  end_time    time        NOT NULL,
  active      boolean     NOT NULL DEFAULT true,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now(),
  CHECK (end_time > start_time)
);
CREATE INDEX bath_availability_windows_city_idx
  ON public.bath_availability_windows(city_id, weekday) WHERE active = true;

ALTER TABLE public.bath_availability_windows ENABLE ROW LEVEL SECURITY;
-- No anon/authenticated policy: operator/service-role writes only. Slots
-- reach the public exclusively through bath_open_slots (SECURITY DEFINER).


-- ── 3. bath_availability_exceptions ───────────────────────────────────
-- is_closed = true  -> the whole date is closed (start/end ignored).
-- is_closed = false -> an extra open window on that date (start/end set).
CREATE TABLE public.bath_availability_exceptions (
  id              uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  city_id         uuid        NOT NULL REFERENCES public.cities(id) ON DELETE CASCADE,
  exception_date  date        NOT NULL,
  is_closed       boolean     NOT NULL DEFAULT true,
  start_time      time,
  end_time        time,
  note            text,
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now(),
  CHECK (is_closed OR (start_time IS NOT NULL AND end_time IS NOT NULL AND end_time > start_time))
);
CREATE INDEX bath_availability_exceptions_city_date_idx
  ON public.bath_availability_exceptions(city_id, exception_date);

ALTER TABLE public.bath_availability_exceptions ENABLE ROW LEVEL SECURITY;
-- Operator/service-role writes only; read via bath_open_slots.


-- ── 4. One-bath-at-a-time guard ───────────────────────────────────────
-- Bookings always land on a slot-grid start from bath_open_slots, so a
-- unique start time among live appointments enforces no double-booking
-- for the single operator. (Multi-operator: replace with a per-route
-- overlap exclusion constraint.)
CREATE UNIQUE INDEX bath_appointments_one_at_a_time
  ON public.bath_appointments(scheduled_start)
  WHERE status NOT IN ('cancelled', 'skipped', 'no_show');


-- ── 5. updated_at triggers for the new tables ─────────────────────────
CREATE TRIGGER bath_availability_windows_set_updated_at
  BEFORE UPDATE ON public.bath_availability_windows
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
CREATE TRIGGER bath_availability_exceptions_set_updated_at
  BEFORE UPDATE ON public.bath_availability_exceptions
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


-- ── 6. bath_open_slots(city_id, from, to) ─────────────────────────────
-- Returns free slot starts/ends for a city within [from, to], clamped to
-- [now(), now() + horizon]. SECURITY DEFINER so it can read the operator
-- availability tables and all appointments; it returns only timestamps,
-- never any subscriber data.
CREATE OR REPLACE FUNCTION public.bath_open_slots(
  p_city_id uuid,
  p_from    timestamptz,
  p_to      timestamptz
)
RETURNS TABLE (slot_start timestamptz, slot_end timestamptz)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_slot_min   integer;
  v_buffer_min integer;
  v_horizon    integer;
  v_tz         text;
  v_from       timestamptz;
  v_to         timestamptz;
  v_step       interval;
  v_len        interval;
BEGIN
  SELECT hb_slot_minutes, hb_buffer_minutes, hb_booking_horizon_days, hb_timezone
    INTO v_slot_min, v_buffer_min, v_horizon, v_tz
    FROM public.cities WHERE id = p_city_id AND hb_active = true;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'city % is not an active Hurricane Bath city', p_city_id;
  END IF;
  IF v_slot_min IS NULL THEN
    -- No real visit duration set yet: offer nothing rather than guess.
    RETURN;
  END IF;

  v_len  := make_interval(mins => v_slot_min);
  v_step := make_interval(mins => v_slot_min + v_buffer_min);
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
  -- Recurring weekly windows for each day, dropping fully-closed dates.
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
  -- Per-date extra open windows from exceptions.
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
  -- Expand each window into grid slots in the city's local timezone.
  candidates AS (
    SELECT s AS slot_start, s + v_len AS slot_end
    FROM windows,
    LATERAL generate_series(
      (windows.day + windows.start_time) AT TIME ZONE v_tz,
      ((windows.day + windows.end_time)  AT TIME ZONE v_tz) - v_len,
      v_step
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

REVOKE ALL ON FUNCTION public.bath_open_slots(uuid, timestamptz, timestamptz) FROM public;
GRANT EXECUTE ON FUNCTION public.bath_open_slots(uuid, timestamptz, timestamptz)
  TO anon, authenticated;


-- ── 7. bath_start_subscription(...) ───────────────────────────────────
-- The signup. Runs as the signed-in user (auth.uid() is the gate),
-- enforces the rule pack, and writes subscriber + dogs + subscription +
-- first appointment atomically. Returns the created ids and the snapshot
-- price. p_stripe_payment_method_id may be NULL only on the pre-launch
-- test path (a future check can require it once Stripe is wired).
CREATE OR REPLACE FUNCTION public.bath_start_subscription(
  p_city_slug               text,
  p_first_name              text,
  p_last_name               text,
  p_email                   text,
  p_phone_e164              text,
  p_address_line_1          text,
  p_address_city            text,
  p_address_state           text,
  p_address_zip             text,
  p_service_lat             numeric,
  p_service_lng             numeric,
  p_dogs                    jsonb,
  p_cadence                 text,
  p_slot_start              timestamptz,
  p_stripe_payment_method_id text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_uid          uuid := auth.uid();
  v_city         public.cities%ROWTYPE;
  v_dog_count    int;
  v_base_tier    text;
  v_is_founders  boolean := false;
  v_founders_cnt int;
  v_base_cents   int;
  v_decrement    int;
  v_amount       int;
  v_subscriber   uuid;
  v_subscription uuid;
  v_appointment  uuid;
  v_locked_until date := NULL;
  v_slot_end     timestamptz;
  d              jsonb;
  v_tier         text;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'authentication required to start a subscription';
  END IF;

  SELECT * INTO v_city FROM public.cities
   WHERE slug = p_city_slug AND hb_active = true;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Hurricane Bath is not open in "%"', p_city_slug;
  END IF;

  IF p_cadence NOT IN ('4wk', '2wk', 'oneoff') THEN
    RAISE EXCEPTION 'invalid cadence: %', p_cadence;
  END IF;

  -- Dogs: 1..3 (three_dog_cap), every dog bath-eligible (bath_only_no_mats).
  v_dog_count := COALESCE(jsonb_array_length(p_dogs), 0);
  IF v_dog_count < 1 OR v_dog_count > 3 THEN
    RAISE EXCEPTION 'a visit covers one to three dogs (got %)', v_dog_count;
  END IF;

  v_base_tier := NULL;
  FOR d IN SELECT * FROM jsonb_array_elements(p_dogs)
  LOOP
    v_tier := d->>'coat_tier';
    IF v_tier IS NULL OR v_tier NOT IN ('smoothcoat', 'doublecoat') THEN
      RAISE EXCEPTION 'dog "%" is not bath-eligible (coat_tier=%)',
        COALESCE(d->>'name', '?'), COALESCE(v_tier, 'null');
    END IF;
    -- Base tier = the more expensive coat among the dogs (doublecoat > smoothcoat).
    IF v_tier = 'doublecoat' THEN
      v_base_tier := 'doublecoat';
    ELSIF v_base_tier IS NULL THEN
      v_base_tier := 'smoothcoat';
    END IF;
  END LOOP;

  -- Founders: available while the city's founders cohort is below cap.
  IF p_cadence <> 'oneoff' THEN
    SELECT count(*) INTO v_founders_cnt
      FROM public.bath_subscriptions s
      JOIN public.bath_subscribers sub ON sub.id = s.subscriber_id
     WHERE s.city_id = v_city.id
       AND s.is_founders = true
       AND s.status IN ('active', 'paused');
    IF v_founders_cnt < v_city.hb_founders_cap THEN
      v_is_founders := true;
      v_locked_until := (current_date + interval '1 year')::date;
    END IF;
  END IF;

  -- Price snapshot in cents from the city row.
  IF p_cadence = 'oneoff' THEN
    v_base_cents := CASE v_base_tier
      WHEN 'doublecoat' THEN v_city.hb_doublecoat_single_cents
      ELSE v_city.hb_smoothcoat_single_cents END;
  ELSIF v_is_founders THEN
    v_base_cents := CASE v_base_tier
      WHEN 'doublecoat' THEN v_city.hb_founders_doublecoat_cents
      ELSE v_city.hb_founders_smoothcoat_cents END;
  ELSE
    v_base_cents := CASE v_base_tier
      WHEN 'doublecoat' THEN v_city.hb_doublecoat_recurring_cents
      ELSE v_city.hb_smoothcoat_recurring_cents END;
  END IF;
  IF v_base_cents IS NULL THEN
    RAISE EXCEPTION 'city "%" is missing the price for tier % / cadence %',
      p_city_slug, v_base_tier, p_cadence;
  END IF;

  v_decrement := v_city.hb_addon_decrement_cents;
  v_amount := greatest(0, v_base_cents - v_decrement * (v_dog_count - 1));

  -- Slot must be a currently-open slot for this city.
  SELECT slot_end INTO v_slot_end
    FROM public.bath_open_slots(v_city.id, p_slot_start - interval '1 second', p_slot_start + interval '1 second')
   WHERE slot_start = p_slot_start
   LIMIT 1;
  IF v_slot_end IS NULL THEN
    RAISE EXCEPTION 'selected time is no longer available';
  END IF;

  -- Upsert the subscriber (one row per auth identity).
  INSERT INTO public.bath_subscribers (
    auth_user_id, first_name, last_name, email, phone_e164,
    address_line_1, address_city, address_state, address_zip,
    service_lat, service_lng, city_id, last_profile_confirmed_at
  ) VALUES (
    v_uid, p_first_name, p_last_name, p_email, p_phone_e164,
    p_address_line_1, p_address_city, p_address_state, p_address_zip,
    p_service_lat, p_service_lng, v_city.id, now()
  )
  ON CONFLICT (auth_user_id) DO UPDATE SET
    first_name = EXCLUDED.first_name,
    last_name  = EXCLUDED.last_name,
    email      = EXCLUDED.email,
    phone_e164 = EXCLUDED.phone_e164,
    address_line_1 = EXCLUDED.address_line_1,
    address_city   = EXCLUDED.address_city,
    address_state  = EXCLUDED.address_state,
    address_zip    = EXCLUDED.address_zip,
    service_lat    = EXCLUDED.service_lat,
    service_lng    = EXCLUDED.service_lng,
    city_id        = EXCLUDED.city_id,
    last_profile_confirmed_at = now()
  RETURNING id INTO v_subscriber;

  -- One active/paused subscription per subscriber (matches the partial
  -- unique index; caught here for a friendly message).
  IF EXISTS (
    SELECT 1 FROM public.bath_subscriptions
     WHERE subscriber_id = v_subscriber AND status IN ('active', 'paused')
  ) THEN
    RAISE EXCEPTION 'this account already has an active subscription';
  END IF;

  -- Replace this signup's dogs with the submitted set.
  DELETE FROM public.bath_dogs WHERE subscriber_id = v_subscriber;
  INSERT INTO public.bath_dogs (subscriber_id, name, breed, coat_tier)
  SELECT v_subscriber, e->>'name', e->>'breed', e->>'coat_tier'
  FROM jsonb_array_elements(p_dogs) AS e;

  INSERT INTO public.bath_subscriptions (
    subscriber_id, city_id, cadence, base_price_cents,
    additional_dog_decrement_cents, is_founders, founders_locked_until,
    stripe_payment_method_id, status
  ) VALUES (
    v_subscriber, v_city.id, p_cadence, v_base_cents,
    v_decrement, v_is_founders, v_locked_until,
    p_stripe_payment_method_id, 'active'
  )
  RETURNING id INTO v_subscription;

  INSERT INTO public.bath_appointments (
    subscriber_id, subscription_id, scheduled_start, scheduled_end,
    dog_count, amount_cents, status, payment_status, original_scheduled_start
  ) VALUES (
    v_subscriber, v_subscription, p_slot_start, v_slot_end,
    v_dog_count, v_amount, 'requested', 'pending', p_slot_start
  )
  RETURNING id INTO v_appointment;

  RETURN jsonb_build_object(
    'subscriber_id',   v_subscriber,
    'subscription_id', v_subscription,
    'appointment_id',  v_appointment,
    'is_founders',     v_is_founders,
    'base_price_cents', v_base_cents,
    'amount_cents',    v_amount,
    'scheduled_start', p_slot_start
  );
END;
$$;

REVOKE ALL ON FUNCTION public.bath_start_subscription(
  text, text, text, text, text, text, text, text, text,
  numeric, numeric, jsonb, text, timestamptz, text) FROM public;
GRANT EXECUTE ON FUNCTION public.bath_start_subscription(
  text, text, text, text, text, text, text, text, text,
  numeric, numeric, jsonb, text, timestamptz, text) TO authenticated;
