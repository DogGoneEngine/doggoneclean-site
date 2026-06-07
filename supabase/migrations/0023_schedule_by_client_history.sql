-- 0023_schedule_by_client_history.sql
-- Implement schedule_by_client_history for Clean: an appointment is sized by the
-- exact client's historical on-site time when known, otherwise the cold-start
-- guess (coat-tier bath default), floored by the minimum stop block. Also fixes
-- booking, which broke when hb_slot_minutes moved to per-tier minutes (the old
-- RPCs keyed off hb_slot_minutes, now null).

-- Effective appointment duration for a subscriber: their linked legacy client's
-- historical block (clients.visit_minutes) if any, else the coat-tier bath
-- default for their dogs, floored by the city minimum stop block.
create or replace function public.clean_effective_duration_minutes(p_subscriber_id uuid)
returns integer
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_city       public.cities%rowtype;
  v_client     uuid;
  v_hist       integer;
  v_default    integer;
  v_min        integer;
  v_has_double boolean;
begin
  select c.* into v_city
    from public.cities c
    join public.bath_subscribers s on s.city_id = c.id
   where s.id = p_subscriber_id;
  if not found then
    return null;
  end if;

  select client_id into v_client from public.bath_subscribers where id = p_subscriber_id;
  if v_client is not null then
    select visit_minutes into v_hist from public.clients where id = v_client;
  end if;

  select bool_or(coat_tier = 'doublecoat') into v_has_double
    from public.bath_dogs where subscriber_id = p_subscriber_id and active;

  v_default := case when coalesce(v_has_double, false)
                    then v_city.hb_doublecoat_minutes
                    else v_city.hb_smoothcoat_minutes end;
  v_min := coalesce(v_city.hb_min_stop_minutes, 30);
  return greatest(v_min, coalesce(v_hist, v_default, v_min));
end;
$$;

revoke all on function public.clean_effective_duration_minutes(uuid) from public;
grant execute on function public.clean_effective_duration_minutes(uuid) to anon, authenticated;

-- Reschedule: a known client re-books, so size the slot by their effective
-- duration (history when present) instead of the fixed city slot.
create or replace function public.bath_reschedule_appointment(p_appointment_id uuid, p_new_start timestamptz)
returns jsonb
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $function$
declare
  v_appt    record;
  v_city_id uuid;
  v_dur     integer;
  v_slot_ok boolean;
begin
  select a.*, b.city_id as subscriber_city_id
    into v_appt
  from public.bath_appointments a
  join public.bath_subscribers b on b.id = a.subscriber_id
  where a.id = p_appointment_id
    and b.auth_user_id = auth.uid();

  if v_appt.id is null then
    return jsonb_build_object('ok', false, 'error', 'not_found');
  end if;

  if v_appt.status not in ('requested', 'confirmed') then
    return jsonb_build_object('ok', false, 'error', 'not_reschedulable');
  end if;

  if v_appt.scheduled_start <= now() + interval '24 hours' then
    return jsonb_build_object('ok', false, 'error', 'too_late');
  end if;

  v_city_id := v_appt.subscriber_city_id;
  v_dur := public.clean_effective_duration_minutes(v_appt.subscriber_id);
  if v_dur is null then
    return jsonb_build_object('ok', false, 'error', 'slot_unavailable');
  end if;

  select exists (
    select 1
    from public.bath_open_slots(v_city_id, p_new_start, p_new_start + interval '1 second', v_dur)
    where slot_start = p_new_start
  ) into v_slot_ok;

  if not v_slot_ok then
    return jsonb_build_object('ok', false, 'error', 'slot_unavailable');
  end if;

  update public.bath_appointments
     set original_scheduled_start = coalesce(original_scheduled_start, scheduled_start),
         scheduled_start = p_new_start,
         scheduled_end   = p_new_start + make_interval(mins => v_dur),
         duration_minutes = v_dur,
         updated_at = now()
   where id = v_appt.id;

  return jsonb_build_object('ok', true, 'status', v_appt.status, 'new_start', p_new_start);
end;
$function$;

-- Signup: a brand-new client has no history, so the first appointment uses the
-- cold-start guess (coat-tier bath default, floored). Sizes the slot by that
-- duration and stamps the appointment's service_type, payment_method, and
-- duration_minutes.
create or replace function public.bath_start_subscription(p_city_slug text, p_first_name text, p_last_name text, p_email text, p_phone_e164 text, p_address_line_1 text, p_address_city text, p_address_state text, p_address_zip text, p_service_lat numeric, p_service_lng numeric, p_gate_code text, p_sms_opt_in boolean, p_dogs jsonb, p_cadence text, p_slot_start timestamptz, p_stripe_payment_method_id text DEFAULT NULL::text)
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
    v_tier := d->>'coat_tier';
    IF v_tier IS NULL OR v_tier NOT IN ('smoothcoat', 'doublecoat') THEN
      RAISE EXCEPTION 'dog "%" is not bath-eligible (coat_tier=%)',
        COALESCE(d->>'name', '?'), COALESCE(v_tier, 'null');
    END IF;
    IF v_tier = 'doublecoat' THEN
      v_has_double := true;
    END IF;
  END LOOP;

  -- Cold-start guess: coat-tier bath default for a new client, floored.
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
