-- 0139: Lelo named + per-service durations (the Lisa Prater override).
--
-- 1. Edely Abreu's American Staffordshire Terrier is named LELO (Paul,
--    2026-06-10), closing one of the three name gaps from 0138.
-- 2. schedule_by_client_history says grooms and nails split where a client
--    gets both; until now the engine read one blended clients.visit_minutes,
--    which for Lisa Prater (two full grooms at 45-59 min, nine nails visits
--    at 5-11 min) collapsed to a nails-weighted 11 and would book her grooms
--    laughably short. New per-service override columns
--    (visit_minutes_groom / visit_minutes_nails) sit on top of the blended
--    value: clean_effective_duration_minutes gains a service-aware form that
--    prefers the matching split, falls back to the blended history, then the
--    coat-tier default, floored by the city minimum as always.
--    Lisa's seed values come straight from her Time is Money record: groom 52
--    (median of her two recorded grooms, 45 and 59), nails 11 (her recorded
--    nails-weighted median; the 30-minute floor governs at booking time).
-- Keyed by name so a reseed replays it (client_dispositions_are_migrations).

-- 1. Lelo.
update public.dogs d
   set name = 'Lelo',
       notes = 'Named Lelo (Paul, 2026-06-10). Breed from the Acuity booking form (2025-08-10). Charged $75. No Drive contact sheet exists for this client.'
  from public.clients c
 where d.client_id = c.id
   and c.name = 'Edely Abreu'
   and d.name = 'Am Staff (name unknown)';

update public.clients
   set note = replace(note, 'Dog name still a gap;', 'Dog named Lelo (2026-06-10);')
 where name = 'Edely Abreu'
   and note like '%Dog name still a gap;%';

-- 2. Per-service duration overrides.
alter table public.clients
  add column if not exists visit_minutes_groom integer,
  add column if not exists visit_minutes_nails integer;

comment on column public.clients.visit_minutes_groom is
  'Per-service on-site history override (minutes) for full-groom visits; null means use the blended visit_minutes. schedule_by_client_history.';
comment on column public.clients.visit_minutes_nails is
  'Per-service on-site history override (minutes) for nails visits; null means use the blended visit_minutes. schedule_by_client_history.';

update public.clients
   set visit_minutes_groom = 52,
       visit_minutes_nails = 11
 where name = 'Lisa Prater';

-- Service-aware duration: prefer the per-service history, then the blended
-- history, then the coat-tier default, floored by the city minimum.
create or replace function public.clean_effective_duration_minutes(p_subscriber_id uuid, p_service_type text)
returns integer
language plpgsql
stable security definer
set search_path to ''
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
    select coalesce(
             case p_service_type
               when 'full_groom' then visit_minutes_groom
               when 'nails' then visit_minutes_nails
               else null
             end,
             visit_minutes)
      into v_hist
      from public.clients where id = v_client;
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
revoke all on function public.clean_effective_duration_minutes(uuid, text) from public, anon;
grant execute on function public.clean_effective_duration_minutes(uuid, text) to authenticated, service_role;

-- The 1-arg form stays for existing callers and delegates (blended history).
create or replace function public.clean_effective_duration_minutes(p_subscriber_id uuid)
returns integer
language sql
stable security definer
set search_path to ''
as $$
  select public.clean_effective_duration_minutes(p_subscriber_id, null);
$$;

-- Reschedule now books the appointment's own service type at its real length.
CREATE OR REPLACE FUNCTION public.bath_reschedule_appointment(p_appointment_id uuid, p_new_start timestamp with time zone)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
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
  v_dur := public.clean_effective_duration_minutes(v_appt.subscriber_id, v_appt.service_type);
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
