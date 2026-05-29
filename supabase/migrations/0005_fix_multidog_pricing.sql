-- 0005_fix_multidog_pricing.sql
--
-- Fix the multi-dog pricing in bath_start_subscription. The 0003 version
-- collapsed a visit to a single base tier and subtracted the per-dog
-- decrement from it, which undercharged (and ignored each dog's own
-- tier). The correct model, and the one /the-villages advertises ("each
-- additional dog is $20 less than the prior dog"):
--
--   Price every dog at ITS OWN tier price, order the dogs most-expensive
--   first, and take $20 off each additional dog in order. The cheaper
--   dogs absorb the stacking discount, so we never undercharge:
--     total = sum_i( max(0, tier_price_i - decrement * i) )   (i from 0)
--
--   e.g. one doublecoat ($100) + one smoothcoat ($75), recurring:
--     100 + max(0, 75 - 20) = 100 + 55 = $155.
--
-- base_price_cents on the subscription snapshots the top (first) dog's
-- full tier price; amount_cents on the appointment is the visit total.
-- Only the pricing block changed; the rest of 0003 is reproduced as-is so
-- this migration is a complete CREATE OR REPLACE.

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
  v_is_founders  boolean := false;
  v_founders_cnt int;
  v_base_cents   int;
  v_decrement    int;
  v_amount       int;
  v_null_cnt     int;
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

  v_dog_count := COALESCE(jsonb_array_length(p_dogs), 0);
  IF v_dog_count < 1 OR v_dog_count > 3 THEN
    RAISE EXCEPTION 'a visit covers one to three dogs (got %)', v_dog_count;
  END IF;

  -- Every dog must be bath-eligible (bath_only_no_mats).
  FOR d IN SELECT * FROM jsonb_array_elements(p_dogs)
  LOOP
    v_tier := d->>'coat_tier';
    IF v_tier IS NULL OR v_tier NOT IN ('smoothcoat', 'doublecoat') THEN
      RAISE EXCEPTION 'dog "%" is not bath-eligible (coat_tier=%)',
        COALESCE(d->>'name', '?'), COALESCE(v_tier, 'null');
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

  v_decrement := v_city.hb_addon_decrement_cents;

  -- Per-dog pricing: each dog at its own tier price for the chosen
  -- cadence/founders, dogs ordered most-expensive first, $20 off each
  -- additional dog in order. base_cents = top dog's full price;
  -- amount = the visit total.
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

  -- Slot must be a currently-open slot for this city.
  SELECT slot_end INTO v_slot_end
    FROM public.bath_open_slots(v_city.id, p_slot_start - interval '1 second', p_slot_start + interval '1 second')
   WHERE slot_start = p_slot_start
   LIMIT 1;
  IF v_slot_end IS NULL THEN
    RAISE EXCEPTION 'selected time is no longer available';
  END IF;

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

  IF EXISTS (
    SELECT 1 FROM public.bath_subscriptions
     WHERE subscriber_id = v_subscriber AND status IN ('active', 'paused')
  ) THEN
    RAISE EXCEPTION 'this account already has an active subscription';
  END IF;

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
