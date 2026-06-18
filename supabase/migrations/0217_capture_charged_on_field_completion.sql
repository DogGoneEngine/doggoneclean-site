-- 0217: the Time is Money "Charged" column was coming through blank for stops
-- finished in the field (Paul, 2026-06-18).
--
-- Root cause: there are two ways an appointment becomes a completed visit.
--   (a) admin_complete_appointment (the explicit complete form) recorded Charged,
--       but defaulted it to bath_appointments.amount_cents, which is 0 across the
--       whole full-groom book (price lives on dogs.price_cents, per 0200). So it
--       wrote $0, not the real price.
--   (b) admin_stamp_appointment_time (the on-my-way / here / all done clock flow,
--       the way stops are actually finished in the field) created the visit and
--       marked it completed on the departed stamp, but never touched charged_cents
--       at all, so it came through NULL -> blank in the ledger.
-- Colleen Smith's 6/17 row (the bottom of the report) was case (b): clocked and
-- paid, but Charged blank.
--
-- Fix: use clean_appt_price_cents (the one canonical price definition, amount on
-- the row when set else the sum of the dogs on it) as the Charged source in BOTH
-- paths, only when a charge was not given explicitly. Then backfill the completed,
-- post-cutover appointment visits that are currently blank with that same real
-- price, so the live ledger rows stop showing an empty Charged. Paul can still
-- override any single visit's Charged by hand; this only fills the blanks.
--
-- Applied to dgc-prod 2026-06-18.

-- (a) explicit complete form: default Charged to the real price, not amount_cents(=0).
create or replace function public.admin_complete_appointment(
  p_appointment_id uuid,
  p_work_done text default null,
  p_visit_notes text default null,
  p_actual_minutes integer default null,
  p_amount_collected_cents integer default null,
  p_tip_cents integer default null,
  p_payment_method text default null,
  p_condition_flags text[] default null,
  p_dog_ids uuid[] default null,
  p_dog_scores jsonb default null,
  p_charged_cents integer default null
) returns uuid
language plpgsql security definer set search_path = public, pg_temp
as $$
declare v_id uuid; v_admin uuid; v_sub uuid; v_client uuid; v_stype text; v_amt integer; v_price integer;
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  select subscriber_id, service_type, amount_cents into v_sub, v_stype, v_amt
    from public.bath_appointments where id = p_appointment_id;
  if not found then raise exception 'appointment not found'; end if;
  select client_id into v_client from public.bath_subscribers where id = v_sub;
  select id into v_admin from public.admins where auth_user_id = auth.uid();
  -- the real expected price of this appointment (row amount when set, else the dogs on it)
  v_price := public.clean_appt_price_cents(v_amt, coalesce(p_dog_ids, '{}'), v_sub);
  update public.bath_appointments
     set status = 'completed', duration_minutes = coalesce(p_actual_minutes, duration_minutes), updated_at = now()
   where id = p_appointment_id;
  insert into public.visits (
    client_id, subscriber_id, appointment_id, visited_at, service_type,
    dog_ids, work_done, visit_notes, condition_flags, actual_minutes,
    amount_collected_cents, tip_cents, payment_method, source, completed_by, charged_cents
  ) values (
    v_client, v_sub, p_appointment_id, now(), v_stype,
    coalesce(p_dog_ids, '{}'), p_work_done, p_visit_notes, coalesce(p_condition_flags, '{}'), p_actual_minutes,
    coalesce(p_amount_collected_cents, v_amt), p_tip_cents, p_payment_method, 'appointment', v_admin,
    coalesce(p_charged_cents, nullif(v_price, 0))
  ) returning id into v_id;
  perform public._apply_visit_dog_scores(v_id, p_dog_scores);
  return v_id;
end;
$$;
revoke all on function public.admin_complete_appointment(uuid, text, text, integer, integer, integer, text, text[], uuid[], jsonb, integer) from public;
grant execute on function public.admin_complete_appointment(uuid, text, text, integer, integer, integer, text, text[], uuid[], jsonb, integer) to authenticated;

-- (b) field clock flow: when the departed stamp completes the stop, capture Charged
-- from the real price if the visit does not already carry one.
create or replace function public.admin_stamp_appointment_time(
  p_appointment_id uuid,
  p_field text,
  p_at timestamptz
) returns jsonb
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $function$
declare
  v_id uuid;
  a record;
  r record;
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  if p_field not in ('inbound', 'arrived', 'departed') then
    raise exception 'bad field: %', p_field;
  end if;

  select a2.id, a2.subscriber_id, a2.service_type, a2.scheduled_start, a2.amount_cents, s.client_id
    into a
  from public.bath_appointments a2
  left join public.bath_subscribers s on s.id = a2.subscriber_id
  where a2.id = p_appointment_id;
  if not found then raise exception 'appointment not found'; end if;

  select id into v_id from public.visits
   where appointment_id = p_appointment_id order by created_at limit 1;
  if v_id is null then
    insert into public.visits (appointment_id, subscriber_id, client_id, visited_at, service_type, source)
    values (p_appointment_id, a.subscriber_id, a.client_id, a.scheduled_start, a.service_type, 'appointment')
    returning id into v_id;
  end if;

  update public.visits set
    inbound_at  = case when p_field = 'inbound'  then p_at else inbound_at  end,
    arrived_at  = case when p_field = 'arrived'  then p_at else arrived_at  end,
    departed_at = case when p_field = 'departed' then p_at else departed_at end
  where id = v_id;

  update public.visits set actual_minutes =
    case when arrived_at is not null and departed_at is not null
         then greatest(0, round(extract(epoch from (departed_at - arrived_at)) / 60.0)::int)
         else null end
  where id = v_id;

  -- A departed time means the stop is finished, whether tapped or typed in after
  -- the fact; clearing it reopens the stop. Only nudge across that one boundary,
  -- never regressing a stop that is mid-visit.
  if p_field = 'departed' then
    if p_at is not null then
      update public.bath_appointments set status = 'completed', updated_at = now()
       where id = p_appointment_id and status <> 'completed';
      -- capture Charged from the real price, but never overwrite a charge already set.
      update public.visits
         set charged_cents = nullif(public.clean_appt_price_cents(a.amount_cents, dog_ids, a.subscriber_id), 0)
       where id = v_id and charged_cents is null;
    else
      update public.bath_appointments set status = 'returning', updated_at = now()
       where id = p_appointment_id and status = 'completed';
    end if;
  end if;

  select inbound_at, arrived_at, departed_at, actual_minutes
    into r from public.visits where id = v_id;
  return jsonb_build_object(
    'visit_id', v_id,
    'inbound_at', r.inbound_at,
    'arrived_at', r.arrived_at,
    'departed_at', r.departed_at,
    'actual_minutes', r.actual_minutes
  );
end;
$function$;

-- Backfill: the completed, post-cutover appointment visits that the live ledger
-- actually shows with a blank Charged. Fill from the real price; never touch a
-- visit that already has a charge.
update public.visits v
   set charged_cents = nullif(
         public.clean_appt_price_cents(a.amount_cents, v.dog_ids, a.subscriber_id), 0)
  from public.bath_appointments a
 where a.id = v.appointment_id
   and v.charged_cents is null
   and v.arrived_at is not null
   and (v.visited_at at time zone 'America/New_York')::date > date '2026-06-13';
