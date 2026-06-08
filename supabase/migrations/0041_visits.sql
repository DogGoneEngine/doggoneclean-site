-- 0041_visits.sql
-- The growing bottom of the contact sheet: a per-visit record that mirrors the
-- visit-history section Paul keeps under each client's semi-permanent header.
--
-- Per Paul's decision, a visit can STAND ALONE: appointment_id is nullable, so
-- imported legacy history (which never had a calendar booking) and pure walk-ups
-- are first-class. When a visit does come from a booking, appointment_id links
-- back to bath_appointments (the unified appointment spine). The semi-permanent
-- header still lives in public.clients + public.dogs; this table is only the
-- evolving ledger that grows one row per appointment as it happens.

create table if not exists public.visits (
  id uuid primary key default gen_random_uuid(),
  client_id uuid references public.clients(id) on delete set null,
  subscriber_id uuid references public.bath_subscribers(id) on delete set null,
  appointment_id uuid references public.bath_appointments(id) on delete set null,
  visited_at timestamptz not null default now(),
  service_type text check (service_type is null or service_type = any (array['full_groom','bath','nails'])),
  dog_ids uuid[] not null default '{}',
  work_done text,
  visit_notes text,
  condition_flags text[] not null default '{}',
  actual_minutes integer check (actual_minutes is null or actual_minutes > 0),
  amount_collected_cents integer check (amount_collected_cents is null or amount_collected_cents >= 0),
  tip_cents integer check (tip_cents is null or tip_cents >= 0),
  payment_method text check (payment_method is null or payment_method = any (array['square_in_person','stripe_card','cash','wallet'])),
  photo_paths text[] not null default '{}',
  source text not null default 'manual',
  external_id text,
  completed_by uuid references public.admins(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint visits_has_subject check (client_id is not null or subscriber_id is not null)
);

create index if not exists visits_client_idx on public.visits (client_id, visited_at desc);
create index if not exists visits_subscriber_idx on public.visits (subscriber_id, visited_at desc);
create index if not exists visits_appointment_idx on public.visits (appointment_id);
-- Idempotent imports: a (source, external_id) pair imports at most once.
create unique index if not exists visits_source_external_uidx
  on public.visits (source, external_id) where external_id is not null;

-- RLS on, no policy: reachable only by the service role and the SECURITY
-- DEFINER admin RPCs below. Matches every other operational table in dgc-prod.
alter table public.visits enable row level security;

-- Clients department: list + full contact sheet -----------------------------

create or replace function public.admin_list_clients()
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', c.id,
      'name', c.name,
      'aka', c.aka,
      'roster_group', c.roster_group,
      'status', c.status,
      'service_type', c.service_type,
      'cadence_days', c.cadence_days,
      'hardness', c.hardness,
      'location_zone', c.location_zone,
      'flags', c.flags,
      'data_gaps', c.data_gaps,
      'dog_count', (select count(*) from public.dogs d where d.client_id = c.id),
      'last_visit_at', (select max(v.visited_at) from public.visits v where v.client_id = c.id)
    ) order by c.name)
    from public.clients c
    where c.exclude_from_everything = false
  ), '[]'::jsonb);
end;
$$;
revoke all on function public.admin_list_clients() from public;
grant execute on function public.admin_list_clients() to authenticated;

create or replace function public.admin_get_client(p_client_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare result jsonb;
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  select jsonb_build_object(
    'client', to_jsonb(c.*),
    'dogs', coalesce((
      select jsonb_agg(to_jsonb(d.*) order by d.name)
        from public.dogs d where d.client_id = c.id), '[]'::jsonb),
    'subscriber', (
      select to_jsonb(s.*) from public.bath_subscribers s
       where s.client_id = c.id limit 1),
    'visits', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', v.id, 'visited_at', v.visited_at, 'service_type', v.service_type,
        'work_done', v.work_done, 'visit_notes', v.visit_notes,
        'actual_minutes', v.actual_minutes,
        'amount_collected_cents', v.amount_collected_cents, 'tip_cents', v.tip_cents,
        'payment_method', v.payment_method, 'condition_flags', v.condition_flags,
        'source', v.source
      ) order by v.visited_at desc)
        from public.visits v where v.client_id = c.id), '[]'::jsonb),
    'upcoming', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', a.id, 'scheduled_start', a.scheduled_start, 'status', a.status,
        'service_type', a.service_type, 'amount_cents', a.amount_cents
      ) order by a.scheduled_start)
        from public.bath_appointments a
        join public.bath_subscribers s2 on s2.id = a.subscriber_id
       where s2.client_id = c.id
         and a.status in ('requested','confirmed')), '[]'::jsonb)
  ) into result
  from public.clients c
  where c.id = p_client_id;
  if result is null then raise exception 'client not found'; end if;
  return result;
end;
$$;
revoke all on function public.admin_get_client(uuid) from public;
grant execute on function public.admin_get_client(uuid) to authenticated;

-- Logging a visit: standalone (walk-up / imported) --------------------------

create or replace function public.admin_log_visit(
  p_client_id uuid default null,
  p_subscriber_id uuid default null,
  p_appointment_id uuid default null,
  p_visited_at timestamptz default now(),
  p_service_type text default null,
  p_dog_ids uuid[] default null,
  p_work_done text default null,
  p_visit_notes text default null,
  p_condition_flags text[] default null,
  p_actual_minutes integer default null,
  p_amount_collected_cents integer default null,
  p_tip_cents integer default null,
  p_payment_method text default null,
  p_source text default 'manual'
) returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare v_id uuid; v_admin uuid;
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  if p_client_id is null and p_subscriber_id is null then
    raise exception 'a visit needs a client or a subscriber';
  end if;
  select id into v_admin from public.admins where auth_user_id = auth.uid();
  insert into public.visits (
    client_id, subscriber_id, appointment_id, visited_at, service_type,
    dog_ids, work_done, visit_notes, condition_flags, actual_minutes,
    amount_collected_cents, tip_cents, payment_method, source, completed_by
  ) values (
    p_client_id, p_subscriber_id, p_appointment_id, coalesce(p_visited_at, now()), p_service_type,
    coalesce(p_dog_ids, '{}'), p_work_done, p_visit_notes, coalesce(p_condition_flags, '{}'), p_actual_minutes,
    p_amount_collected_cents, p_tip_cents, p_payment_method, coalesce(p_source, 'manual'), v_admin
  ) returning id into v_id;
  return v_id;
end;
$$;
revoke all on function public.admin_log_visit(uuid, uuid, uuid, timestamptz, text, uuid[], text, text, text[], integer, integer, integer, text, text) from public;
grant execute on function public.admin_log_visit(uuid, uuid, uuid, timestamptz, text, uuid[], text, text, text[], integer, integer, integer, text, text) to authenticated;

-- Completing a booked appointment: flips it to completed and writes the visit.

create or replace function public.admin_complete_appointment(
  p_appointment_id uuid,
  p_work_done text default null,
  p_visit_notes text default null,
  p_actual_minutes integer default null,
  p_amount_collected_cents integer default null,
  p_tip_cents integer default null,
  p_payment_method text default null,
  p_condition_flags text[] default null,
  p_dog_ids uuid[] default null
) returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare v_id uuid; v_admin uuid; v_sub uuid; v_client uuid; v_stype text; v_amt integer;
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  select subscriber_id, service_type, amount_cents
    into v_sub, v_stype, v_amt
    from public.bath_appointments where id = p_appointment_id;
  if not found then raise exception 'appointment not found'; end if;
  select client_id into v_client from public.bath_subscribers where id = v_sub;
  select id into v_admin from public.admins where auth_user_id = auth.uid();
  update public.bath_appointments
     set status = 'completed',
         duration_minutes = coalesce(p_actual_minutes, duration_minutes),
         updated_at = now()
   where id = p_appointment_id;
  insert into public.visits (
    client_id, subscriber_id, appointment_id, visited_at, service_type,
    dog_ids, work_done, visit_notes, condition_flags, actual_minutes,
    amount_collected_cents, tip_cents, payment_method, source, completed_by
  ) values (
    v_client, v_sub, p_appointment_id, now(), v_stype,
    coalesce(p_dog_ids, '{}'), p_work_done, p_visit_notes, coalesce(p_condition_flags, '{}'), p_actual_minutes,
    coalesce(p_amount_collected_cents, v_amt), p_tip_cents, p_payment_method, 'appointment', v_admin
  ) returning id into v_id;
  return v_id;
end;
$$;
revoke all on function public.admin_complete_appointment(uuid, text, text, integer, integer, integer, text, text[], uuid[]) from public;
grant execute on function public.admin_complete_appointment(uuid, text, text, integer, integer, integer, text, text[], uuid[]) to authenticated;
