-- 0112_visit_clocks_and_time_is_money_export.sql
-- Capture the three time_is_money clocks (Inbound/depart, Arrival, Departure/finish)
-- plus a separate Charged amount on each visit logged in the app, and an export that
-- emits new app-entered visits in the exact time_is_money column order so Paul can
-- copy the block and paste it onto the end of his original sheet, aligned. Paul keeps
-- maintaining the original book in parallel until he trusts the app-built version
-- (deliberate duplication; the app never touches his sheet). The clocks are stamped
-- one-tap (current time) in the visit form. See visit_history_migration +
-- time_is_money_is_source_of_truth.

alter table public.visits
  add column if not exists inbound_at  timestamptz,
  add column if not exists arrived_at  timestamptz,
  add column if not exists departed_at timestamptz,
  add column if not exists charged_cents integer;

-- Extend admin_log_visit with the four new fields (appended, all optional). When
-- arrive + depart are both stamped and minutes are not given, derive minutes from them.
drop function if exists public.admin_log_visit(uuid, uuid, uuid, timestamptz, text, uuid[], text, text, text[], integer, integer, integer, text, text, jsonb);
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
  p_source text default 'manual',
  p_dog_scores jsonb default null,
  p_inbound_at timestamptz default null,
  p_arrived_at timestamptz default null,
  p_departed_at timestamptz default null,
  p_charged_cents integer default null
) returns uuid
language plpgsql security definer set search_path = public, pg_temp
as $$
declare v_id uuid; v_admin uuid; v_minutes integer;
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  if p_client_id is null and p_subscriber_id is null then
    raise exception 'a visit needs a client or a subscriber';
  end if;
  select id into v_admin from public.admins where auth_user_id = auth.uid();
  v_minutes := p_actual_minutes;
  if v_minutes is null and p_arrived_at is not null and p_departed_at is not null then
    v_minutes := round(extract(epoch from (p_departed_at - p_arrived_at)) / 60.0);
  end if;
  insert into public.visits (
    client_id, subscriber_id, appointment_id, visited_at, service_type,
    dog_ids, work_done, visit_notes, condition_flags, actual_minutes,
    amount_collected_cents, tip_cents, payment_method, source, completed_by,
    inbound_at, arrived_at, departed_at, charged_cents
  ) values (
    p_client_id, p_subscriber_id, p_appointment_id, coalesce(p_visited_at, now()), p_service_type,
    coalesce(p_dog_ids, '{}'), p_work_done, p_visit_notes, coalesce(p_condition_flags, '{}'), v_minutes,
    p_amount_collected_cents, p_tip_cents, p_payment_method, coalesce(p_source, 'manual'), v_admin,
    p_inbound_at, p_arrived_at, p_departed_at, p_charged_cents
  ) returning id into v_id;
  perform public._apply_visit_dog_scores(v_id, p_dog_scores);
  return v_id;
end;
$$;
revoke all on function public.admin_log_visit(uuid, uuid, uuid, timestamptz, text, uuid[], text, text, text[], integer, integer, integer, text, text, jsonb, timestamptz, timestamptz, timestamptz, integer) from public;
grant execute on function public.admin_log_visit(uuid, uuid, uuid, timestamptz, text, uuid[], text, text, text[], integer, integer, integer, text, text, jsonb, timestamptz, timestamptz, timestamptz, integer) to authenticated;

-- Export new app-entered visits in time_is_money column order, ready to paste onto
-- the end of the original sheet. Only visits that originated in the app
-- (source manual/appointment) are exported; historical imports are not re-emitted.
create or replace function public.admin_export_time_is_money(p_since date default null)
returns jsonb language plpgsql security definer set search_path = public, pg_temp
as $$
declare result jsonb;
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  -- All dates and times render in America/New_York (Paul's local Eastern), since the
  -- clocks are stored as UTC timestamptz but his sheet is in his local time.
  select coalesce(jsonb_agg(jsonb_build_object(
           'date',      to_char(v.visited_at at time zone 'America/New_York', 'MM/DD/YYYY'),
           'client',    coalesce(c.name, ''),
           'inbound',   coalesce(to_char(v.inbound_at  at time zone 'America/New_York', 'HH12:MI AM'), ''),
           'arrival',   coalesce(to_char(v.arrived_at  at time zone 'America/New_York', 'HH12:MI AM'), ''),
           'departure', coalesce(to_char(v.departed_at at time zone 'America/New_York', 'HH12:MI AM'), ''),
           'charged',   coalesce(to_char(v.charged_cents / 100.0, 'FM999990.00'), ''),
           'paid',      coalesce(to_char(v.amount_collected_cents / 100.0, 'FM999990.00'), ''),
           'method',    coalesce(v.payment_method, '')
         ) order by v.visited_at), '[]'::jsonb)
    into result
  from public.visits v
  left join public.clients c on c.id = v.client_id
  where v.source in ('manual','appointment')
    and (p_since is null or v.visited_at::date >= p_since);
  return result;
end;
$$;
revoke all on function public.admin_export_time_is_money(date) from public;
grant execute on function public.admin_export_time_is_money(date) to authenticated;
