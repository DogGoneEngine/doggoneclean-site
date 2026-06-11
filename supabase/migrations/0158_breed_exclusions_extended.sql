-- 0158: Paul's breed-exclusion extension (2026-06-11) gets durable teeth.
-- Three exclusion families, each with its own kind decline: haircut-level
-- coats (doodles, poodles, Shih Tzus, Pomeranians and friends; no-haircut
-- dogs are the whole point), excessive double coats (Husky, Malamute,
-- Samoyed, Chow), and excessively large dogs (Great Dane, Saint Bernard,
-- Newfoundland and friends; the business gets in and out). The funnel's
-- breed list declines these at the pick; this helper is the server-side
-- net under it, shared so the pattern lives in exactly one place. Also:
-- sms_opt_in's insert default flips to false (sms_consent_unchecked;
-- consent is opt-in, the server must not assume yes when the flag is
-- missing).

create or replace function public._breed_excluded(p_breed text)
returns text
language sql
immutable
set search_path to ''
as $$
  select case
    when p_breed ~* '(great\s*dane|saint\s*bernard|st\.?\s*bernard|newfoundland|mastiff|wolfhound|leonberger|anatolian|bernese)'
      then 'size'
    when p_breed ~* '(husky|huskies|malamute|samoyed|chow|keeshond|akita|pyrenees)'
      then 'coat'
    when p_breed ~* '(doodle|poodle|[a-z]+poo\M|shih\s*tzu|yorkie|yorkshire|maltese|bichon|havanese|lhasa|schnauzer|wheaten|west\s*highland|westie|scottish\s*terrier|scottie|cocker|pekingese|old\s*english\s*sheepdog|portuguese\s*water|bouvier|airedale|pomeranian|morkie|shorkie|cavachon|shichon|coton)'
      then 'haircut'
    else null
  end
$$;
revoke all on function public._breed_excluded(text) from public;
grant execute on function public._breed_excluded(text) to anon, authenticated, service_role;

CREATE OR REPLACE FUNCTION public.bath_start_subscription(p_city_slug text, p_first_name text, p_last_name text, p_email text, p_phone_e164 text, p_address_line_1 text, p_address_city text, p_address_state text, p_address_zip text, p_service_lat numeric, p_service_lng numeric, p_gate_code text, p_sms_opt_in boolean, p_dogs jsonb, p_cadence text, p_slot_start timestamp with time zone, p_stripe_payment_method_id text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
  v_excl            text;
  v_has_double      boolean := false;
  v_min_stop        int;
  v_duration        int;
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
    -- excluded_breeds_are_slide_holes + the 2026-06-11 extension: declined
    -- kindly before any row is written, with the reason named.
    v_excl := public._breed_excluded(d->>'breed');
    IF v_excl = 'size' THEN
      RAISE EXCEPTION 'We are honestly not built for % dogs: the gentle giants need more room and time than our get-in-get-out route stops can give. A full-service dog grooming salon is the right home.',
        COALESCE(d->>'breed', 'this breed');
    ELSIF v_excl = 'coat' THEN
      RAISE EXCEPTION 'We are honestly not built for % dogs: that much undercoat needs more hours than a mobile route stop allows. A full-service dog grooming salon is the right home for that coat.',
        COALESCE(d->>'breed', 'this breed');
    ELSIF v_excl = 'haircut' THEN
      RAISE EXCEPTION 'We are honestly not built for % dogs: that coat needs haircut-level coat work, and dogs that do not need haircuts are the whole point of this service. A full-service dog grooming salon is the right home for that coat.',
        COALESCE(d->>'breed', 'this breed');
    END IF;

    v_tier := d->>'coat_tier';
    IF v_tier IS NULL OR v_tier NOT IN ('smoothcoat', 'doublecoat') THEN
      RAISE EXCEPTION 'dog "%" is not bath-eligible (coat_tier=%)',
        COALESCE(d->>'name', '?'), COALESCE(v_tier, 'null');
    END IF;
    IF v_tier = 'doublecoat' THEN
      v_has_double := true;
    END IF;
  END LOOP;

  v_min_stop := COALESCE(v_city.hb_min_stop_minutes, 30);
  v_duration := greatest(v_min_stop, COALESCE(
    CASE WHEN v_has_double THEN v_city.hb_doublecoat_minutes ELSE v_city.hb_smoothcoat_minutes END,
    v_min_stop));

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
    FROM public.bath_open_slots(v_city.id, p_slot_start - interval '1 second', p_slot_start + interval '1 second', v_duration)
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
      p_service_lat, p_service_lng, p_gate_code, v_city.id, COALESCE(p_sms_opt_in, false), v_address_verified
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
    stripe_payment_method_id, status, service_type, payment_method
  ) VALUES (
    v_subscriber, v_city.id, p_cadence, v_base_cents,
    v_decrement, v_is_founders, v_locked_until,
    p_stripe_payment_method_id, 'active', 'bath', 'stripe_card'
  )
  RETURNING id INTO v_subscription;

  INSERT INTO public.bath_appointments (
    subscriber_id, subscription_id, scheduled_start, scheduled_end,
    dog_count, amount_cents, status, payment_status, original_scheduled_start,
    service_type, payment_method, duration_minutes
  ) VALUES (
    v_subscriber, v_subscription, p_slot_start, v_slot_end,
    v_dog_count, v_amount, 'requested', 'pending', p_slot_start,
    'bath', 'stripe_card', v_duration
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
$function$;
