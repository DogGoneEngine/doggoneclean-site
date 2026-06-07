-- 0017_lift_dog_count_cap.sql
--
-- Lift the hard 3-dog cap on the bath surface. The number 3 was the Villages
-- residency limit borrowed as a convenient default, never a real Dog Gone
-- rule. The bath pivot starts in Ocala, where that limit does not apply, and
-- real clients have more dogs (one with 5, one with 4). A hard wall would
-- wrongly block them. Pricing is already per-dog (each dog at its tier minus
-- the decrement, ranked high to low), so it scales to any count with no
-- change. Visit time and route capacity are the real limits and live in
-- scheduling, not in a count constraint. See three_dog_cap in CLEAN_ORACLE.md.
--
-- This drops the cap in the three durable places: the pack trigger, the
-- appointment CHECK, and the booking RPC guard. The booking form and portal
-- UI are relaxed alongside in the same change set.

-- 1. Remove the household pack cap (trigger + its function).
drop trigger if exists bath_dogs_cap on public.bath_dogs;
drop function if exists public.bath_enforce_dog_cap();

-- 2. Relax the per-appointment count: at least one dog, no hard ceiling.
alter table public.bath_appointments
  drop constraint if exists bath_appointments_dog_count_check;
alter table public.bath_appointments
  add constraint bath_appointments_dog_count_check check (dog_count >= 1);

-- 3. Relax the booking RPC guard (was 1..3). Body is otherwise identical to
--    0009; only the dog-count guard and its message change. search_path = ''
--    is preserved (the function fully-qualifies every reference).
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
  p_gate_code               text,
  p_sms_opt_in              boolean,
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
  v_city            public.cities%ROWTYPE;
  v_dog_count       int;
  v_is_founders     boolean := false;
  v_founders_cnt    int;
  v_base_cents      int;
  v_decrement       int;
  v_amount          int;
  v_null_cnt        int;
  v_subscriber      uuid;
  v_subscription    uuid;
  v_appointment     uuid;
  v_locked_until    date := NULL;
  v_slot_end        timestamptz;
  v_address_verified boolean := false;
  d                 jsonb;
  v_tier            text;
BEGIN
  IF p_phone_e164 IS NULL OR length(trim(p_phone_e164)) = 0 THEN
    RAISE EXCEPTION 'a phone number is required to book';
  END IF;

  SELECT * INTO v_city FROM public.cities
   WHERE slug = p_city_slug AND hb_active = true;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Hurricane Bath is not open in "%"', p_city_slug;
  END IF;

  IF p_service_lat IS NULL OR p_service_lng IS NULL THEN
    RAISE EXCEPTION 'a verified in-area service address is required to book';
  END IF;
  IF NOT public._bath_point_in_area(
      p_service_lng::double precision, p_service_lat::double precision, v_city.polygon) THEN
    RAISE EXCEPTION 'that service address is outside the current Hurricane Bath route';
  END IF;
  v_address_verified := true;

  IF p_cadence NOT IN ('4wk', '2wk', 'oneoff') THEN
    RAISE EXCEPTION 'invalid cadence: %', p_cadence;
  END IF;

  v_dog_count := COALESCE(jsonb_array_length(p_dogs), 0);
  IF v_dog_count < 1 THEN
    RAISE EXCEPTION 'a visit covers at least one dog (got %)', v_dog_count;
  END IF;

  FOR d IN SELECT * FROM jsonb_array_elements(p_dogs)
  LOOP
    v_tier := d->>'coat_tier';
    IF v_tier IS NULL OR v_tier NOT IN ('smoothcoat', 'doublecoat') THEN
      RAISE EXCEPTION 'dog "%" is not bath-eligible (coat_tier=%)',
        COALESCE(d->>'name', '?'), COALESCE(v_tier, 'null');
    END IF;
  END LOOP;

  IF p_cadence <> 'oneoff' THEN
    SELECT count(*) INTO v_founders_cnt
      FROM public.bath_subscriptions s
     WHERE s.city_id = v_city.id
       AND s.is_founders = true
       AND s.status IN ('active', 'paused');
    IF v_founders_cnt < v_city.hb_founders_cap THEN
      v_is_founders := true;
      v_locked_until := (current_date + interval '1 year')::date;
    END IF;
  END IF;

  v_decrement := v_city.hb_addon_decrement_cents;

  WITH dog_prices AS (
    SELECT (CASE
      WHEN p_cadence = 'oneoff' THEN
        CASE e->>'coat_tier' WHEN 'doublecoat' THEN v_city.hb_doublecoat_single_cents
                             ELSE v_city.hb_smoothcoat_single_cents END
      WHEN v_is_founders THEN
        CASE e->>'coat_tier' WHEN 'doublecoat' THEN v_city.hb_founders_doublecoat_cents
                             ELSE v_city.hb_founders_smoothcoat_cents END
      ELSE
        CASE e->>'coat_tier' WHEN 'doublecoat' THEN v_city.hb_doublecoat_recurring_cents
                             ELSE v_city.hb_smoothcoat_recurring_cents END
    END) AS cents
    FROM jsonb_array_elements(p_dogs) AS e
  ),
  ranked AS (
    SELECT cents, (row_number() OVER (ORDER BY cents DESC) - 1) AS idx
    FROM dog_prices
  )
  SELECT max(cents),
         sum(greatest(0, cents - v_decrement * idx)),
         count(*) FILTER (WHERE cents IS NULL)
    INTO v_base_cents, v_amount, v_null_cnt
    FROM ranked;

  IF v_null_cnt > 0 OR v_base_cents IS NULL THEN
    RAISE EXCEPTION 'city "%" is missing a price for one of the coat tiers / cadence %',
      p_city_slug, p_cadence;
  END IF;

  SELECT slot_end INTO v_slot_end
    FROM public.bath_open_slots(v_city.id, p_slot_start - interval '1 second', p_slot_start + interval '1 second')
   WHERE slot_start = p_slot_start
   LIMIT 1;
  IF v_slot_end IS NULL THEN
    RAISE EXCEPTION 'selected time is no longer available';
  END IF;

  SELECT id INTO v_subscriber
    FROM public.bath_subscribers
   WHERE phone_e164 = p_phone_e164
   ORDER BY created_at
   LIMIT 1;

  IF v_subscriber IS NULL THEN
    INSERT INTO public.bath_subscribers (
      first_name, last_name, email, phone_e164,
      address_line_1, address_city, address_state, address_zip,
      service_lat, service_lng, gate_code, city_id, sms_opt_in, address_verified
    ) VALUES (
      p_first_name, p_last_name, p_email, p_phone_e164,
      p_address_line_1, p_address_city, p_address_state, p_address_zip,
      p_service_lat, p_service_lng, p_gate_code, v_city.id, COALESCE(p_sms_opt_in, true), v_address_verified
    )
    RETURNING id INTO v_subscriber;
  ELSE
    UPDATE public.bath_subscribers SET
      first_name = p_first_name,
      last_name  = p_last_name,
      email      = p_email,
      address_line_1 = p_address_line_1,
      address_city   = p_address_city,
      address_state  = p_address_state,
      address_zip    = p_address_zip,
      service_lat    = p_service_lat,
      service_lng    = p_service_lng,
      gate_code      = p_gate_code,
      city_id        = v_city.id,
      sms_opt_in     = COALESCE(p_sms_opt_in, sms_opt_in),
      address_verified = v_address_verified
    WHERE id = v_subscriber;
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.bath_subscriptions
     WHERE subscriber_id = v_subscriber AND status IN ('active', 'paused')
  ) THEN
    RAISE EXCEPTION 'this phone number already has an active subscription';
  END IF;

  DELETE FROM public.bath_dogs WHERE subscriber_id = v_subscriber;
  INSERT INTO public.bath_dogs (subscriber_id, name, breed, coat_tier, birth_date, dob_approximate)
  SELECT v_subscriber, e->>'name', e->>'breed', e->>'coat_tier',
         NULLIF(e->>'birth_date', '')::date,
         COALESCE((e->>'dob_approximate')::boolean, false)
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
    'subscriber_id',    v_subscriber,
    'subscription_id',  v_subscription,
    'appointment_id',   v_appointment,
    'is_founders',      v_is_founders,
    'base_price_cents', v_base_cents,
    'amount_cents',     v_amount,
    'scheduled_start',  p_slot_start,
    'address_verified', v_address_verified
  );
END;
$$;

REVOKE ALL ON FUNCTION public.bath_start_subscription(
  text, text, text, text, text, text, text, text, text,
  numeric, numeric, text, boolean, jsonb, text, timestamptz, text) FROM public;
GRANT EXECUTE ON FUNCTION public.bath_start_subscription(
  text, text, text, text, text, text, text, text, text,
  numeric, numeric, text, boolean, jsonb, text, timestamptz, text) TO anon, authenticated;
