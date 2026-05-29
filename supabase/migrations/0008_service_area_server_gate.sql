-- 0008_service_area_server_gate.sql
--
-- Make the service-area check authoritative on the SERVER, not the browser.
--
-- Before this, the only point-in-polygon check lived in the booking island
-- (src/components/portal/maps.js, isInServiceArea), and it only ran when the
-- Google autocomplete returned coordinates. A dead autocomplete box, the
-- manual-entry fallback, or any crafted request could place an out-of-area
-- signup, because bath_start_subscription did no area check at all. The
-- browser widget is a convenience; the gate belongs here.
--
-- What this does:
--   1. _bath_point_in_area(lng, lat, polygon) -- ray-cast point-in-ring over
--      the cities.polygon jsonb, mirroring maps.js exactly (x=lng, y=lat,
--      tolerates [[[lng,lat],...]] or a bare ring).
--   2. bath_subscribers.address_verified -- true only when the server itself
--      confirmed the coordinates fall inside the city polygon.
--   3. bath_start_subscription re-created with the gate:
--        - coordinates present + outside polygon -> REJECT (hard error).
--        - coordinates present + inside           -> address_verified = true.
--        - coordinates absent (manual / dead box) -> address_verified = false,
--          recorded honestly and confirmed before any charge. NEVER silently
--          treated as in-area.
--
-- Auto-verifying a typed manual address (server-side geocode) needs the
-- Geocoding API on Clean's server Maps key, which is a Google-console item on
-- Paul's plate (maps_js_api_only). Until then a manual address is accepted as
-- unverified and confirmed by the operator before the first visit. When the
-- Stripe charge job lands it MUST refuse to charge an appointment whose
-- subscriber address_verified is false (see CLEAN_PARKING_LOT.md).

-- ── 1. point-in-polygon helper (pure, no table access) ─────────────────────
CREATE OR REPLACE FUNCTION public._bath_point_in_area(
  p_lng     double precision,
  p_lat     double precision,
  p_polygon jsonb
)
RETURNS boolean
LANGUAGE plpgsql
IMMUTABLE
SET search_path = ''
AS $$
DECLARE
  ring   jsonb;
  n      int;
  i      int := 0;
  j      int;
  xi     double precision; yi double precision;
  xj     double precision; yj double precision;
  inside boolean := false;
BEGIN
  IF p_polygon IS NULL OR p_lng IS NULL OR p_lat IS NULL THEN
    RETURN false;
  END IF;
  -- [[[lng,lat],...]] (ring wrapped in an array) vs a bare ring [[lng,lat],...].
  IF jsonb_typeof(p_polygon->0) = 'array'
     AND jsonb_typeof(p_polygon->0->0) = 'array' THEN
    ring := p_polygon->0;
  ELSE
    ring := p_polygon;
  END IF;
  n := jsonb_array_length(ring);
  IF n IS NULL OR n < 3 THEN
    RETURN false;
  END IF;
  j := n - 1;
  WHILE i < n LOOP
    xi := (ring->i->>0)::double precision; yi := (ring->i->>1)::double precision;
    xj := (ring->j->>0)::double precision; yj := (ring->j->>1)::double precision;
    IF ((yi > p_lat) <> (yj > p_lat))
       AND (p_lng < ((xj - xi) * (p_lat - yi) / (yj - yi)) + xi) THEN
      inside := NOT inside;
    END IF;
    j := i;
    i := i + 1;
  END LOOP;
  RETURN inside;
END;
$$;

REVOKE ALL ON FUNCTION public._bath_point_in_area(double precision, double precision, jsonb) FROM public;

-- ── 2. address_verified flag ───────────────────────────────────────────────
ALTER TABLE public.bath_subscribers
  ADD COLUMN IF NOT EXISTS address_verified boolean NOT NULL DEFAULT false;

-- ── 3. bath_start_subscription with the server-side service-area gate ──────
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

  -- Service-area gate (authoritative, server-side). The browser autocomplete
  -- is convenience only; this is the line a dead box / manual entry / crafted
  -- request cannot walk past.
  IF p_service_lat IS NOT NULL AND p_service_lng IS NOT NULL THEN
    IF NOT public._bath_point_in_area(
        p_service_lng::double precision, p_service_lat::double precision, v_city.polygon) THEN
      RAISE EXCEPTION 'that service address is outside the current Hurricane Bath route';
    END IF;
    v_address_verified := true;
  ELSE
    -- No coordinates (manual entry / autocomplete unavailable): record the
    -- address but mark it unverified. Confirmed before any charge; never
    -- treated as in-area on trust.
    v_address_verified := false;
  END IF;

  IF p_cadence NOT IN ('4wk', '2wk', 'oneoff') THEN
    RAISE EXCEPTION 'invalid cadence: %', p_cadence;
  END IF;

  v_dog_count := COALESCE(jsonb_array_length(p_dogs), 0);
  IF v_dog_count < 1 OR v_dog_count > 3 THEN
    RAISE EXCEPTION 'a visit covers one to three dogs (got %)', v_dog_count;
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
