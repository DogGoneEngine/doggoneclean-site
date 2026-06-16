-- 0197_operators_and_rigs.sql
-- Operators and rigs: accommodate more than one person running the book (a pilot
-- in command plus an optional helper) and more than one vehicle, and carry both
-- onto the Time is Money backup so the rate-per-hour math can tell who and which
-- vehicle earned it.
--
-- Today there are two operators (Paul, role owner; Jake, role operator) and one
-- rig. Paul and Jake either run the rig as a team or take it on alternating days.
-- The rig is modeled now but stays INVISIBLE and AUTOMATIC: while exactly one rig
-- is active a trigger assigns it and nobody ever picks it; the moment a second
-- active rig exists, new rows are left unassigned so a rig must be chosen, which
-- is when the picker turns on. Adding Rig 2 later is a data change, not a rebuild.
--
-- See operators_and_rigs, single_rig_auto_assigned, and
-- time_is_money_carries_operator_and_rig in CLEAN_ORACLE.md.

-- 1. Rigs. One row per vehicle. The display name is editable so "Rig 1" can be
--    renamed (a truck name, a plate) later without a migration.
create table if not exists public.rigs (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  is_active boolean not null default true,
  sort integer not null default 0,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.rigs enable row level security;
comment on table public.rigs is
  'Vehicles ("rigs"). One active rig today (Rig 1); auto-assigned and invisible until a second exists. See single_rig_auto_assigned.';

-- Seed the one rig that exists today, only if the table is empty.
insert into public.rigs (name, sort)
select 'Rig 1', 0
where not exists (select 1 from public.rigs);

-- 2. Rig on appointments and visits; pilot in command + helper on visits.
--    A visit's pilot in command is who ran it (the person of record for the
--    rate math); the helper is the second person on a team day (Paul training
--    Jake on one rig). The appointment already carries operator_admin_id.
alter table public.bath_appointments
  add column if not exists rig_id uuid references public.rigs(id);
alter table public.visits
  add column if not exists rig_id uuid references public.rigs(id),
  add column if not exists operator_admin_id uuid references public.admins(id),
  add column if not exists helper_admin_id uuid references public.admins(id);

-- 3. Backfill everything that predates rigs to the single Rig 1. Pre-cutover work
--    was Paul, solo, in one rig; that is the honest default, not invented data.
update public.bath_appointments
   set rig_id = (select id from public.rigs order by sort, created_at limit 1)
 where rig_id is null;
update public.visits
   set rig_id = (select id from public.rigs order by sort, created_at limit 1)
 where rig_id is null;

-- Pilot in command on each past visit: the appointment's operator if there is one,
-- else whoever logged it, else the owner (Paul). Resolved once into the column so
-- the ledger reads it directly.
update public.visits v
   set operator_admin_id = coalesce(
        (select a.operator_admin_id from public.bath_appointments a where a.id = v.appointment_id),
        v.completed_by,
        (select id from public.admins where role = 'owner' and is_active order by created_at limit 1))
 where v.operator_admin_id is null;

-- 4. Invisible auto-assign. While exactly one rig is active, fill it in on insert;
--    with two or more active rigs, leave rig_id null so a rig must be chosen.
create or replace function public._default_rig_id()
returns uuid language plpgsql stable set search_path = public, pg_temp as $$
declare v_n int; v_id uuid;
begin
  select count(*) into v_n from public.rigs where is_active;
  if v_n = 1 then
    select id into v_id from public.rigs where is_active limit 1;
    return v_id;
  end if;
  return null;
end;
$$;

create or replace function public._set_default_rig()
returns trigger language plpgsql set search_path = public, pg_temp as $$
begin
  if new.rig_id is null then
    new.rig_id := public._default_rig_id();
  end if;
  return new;
end;
$$;

drop trigger if exists trg_default_rig on public.bath_appointments;
create trigger trg_default_rig before insert on public.bath_appointments
  for each row execute function public._set_default_rig();

drop trigger if exists trg_default_rig on public.visits;
create trigger trg_default_rig before insert on public.visits
  for each row execute function public._set_default_rig();

-- 5. Time is Money ledger gains Operator, Helper, and Rig columns. The 12 money
--    and clock columns are unchanged; the three new columns ride at the end.
--    Frozen pre-2026-06-13 history reads as Paul / (no helper) / Rig 1. Live
--    visits resolve the pilot in command (visit operator, else appointment
--    operator, else logger, else owner), the helper, and the rig name.
create or replace function public._time_is_money_ledger()
returns jsonb language plpgsql security definer set search_path = public, pg_temp
as $$
declare result jsonb; v_owner text;
begin
  select btrim(coalesce(first_name,'') || ' ' || coalesce(last_name,'')) into v_owner
    from public.admins where role = 'owner' and is_active order by created_at limit 1;
  v_owner := coalesce(nullif(v_owner, ''), 'Paul Nickerson');

  select coalesce(jsonb_agg(obj order by sort_date, ord, cli), '[]'::jsonb) into result
  from (
    select h.sort_date, 0 as ord, h.client as cli,
      jsonb_build_object(
        'Date', h.d, 'Client', h.client, 'Inbound', h.inbound, 'Arrival', h.arrival,
        'Departure', h.departure, 'Charged', h.charged, 'Paid', h.paid, 'Method', h.method,
        'Appointment Duration', h.duration, 'Cycle Time', h.cycle_time,
        'On Site Rate', h.on_site_rate, 'Cycle Rate', h.cycle_rate,
        'Operator', v_owner, 'Helper', '', 'Rig', 'Rig 1') as obj
    from public.time_is_money_history h
    union all
    select (v.visited_at at time zone 'America/New_York')::date as sort_date, 1 as ord,
           coalesce(c.name,'') as cli,
      jsonb_build_object(
        'Date',      to_char(v.visited_at at time zone 'America/New_York', 'FMMM/FMDD/YYYY'),
        'Client',    coalesce(c.name,''),
        'Inbound',   coalesce(to_char(v.inbound_at  at time zone 'America/New_York', 'FMHH12:MI:SS AM'), ''),
        'Arrival',   coalesce(to_char(v.arrived_at  at time zone 'America/New_York', 'FMHH12:MI:SS AM'), ''),
        'Departure', coalesce(to_char(v.departed_at at time zone 'America/New_York', 'FMHH12:MI:SS AM'), ''),
        'Charged',   case when v.charged_cents is not null then '$' || (v.charged_cents/100)::int else '' end,
        'Paid',      case when v.amount_collected_cents is not null then '$' || (v.amount_collected_cents/100)::int else '' end,
        'Method',    coalesce(v.payment_method, ''),
        'Appointment Duration', case when v.departed_at > v.arrived_at then public._fmt_hms(extract(epoch from (v.departed_at - v.arrived_at))) else '' end,
        'Cycle Time',           case when v.inbound_at is not null and v.departed_at > v.inbound_at then public._fmt_hms(extract(epoch from (v.departed_at - v.inbound_at))) else '' end,
        'On Site Rate', case when v.amount_collected_cents is not null and v.departed_at > v.arrived_at
                             then '$' || round((v.amount_collected_cents/100.0) / (extract(epoch from (v.departed_at - v.arrived_at))/3600.0))::int else '' end,
        'Cycle Rate',   case when v.amount_collected_cents is not null and v.inbound_at is not null and v.departed_at > v.inbound_at
                             then '$' || round((v.amount_collected_cents/100.0) / (extract(epoch from (v.departed_at - v.inbound_at))/3600.0))::int else '' end,
        'Operator', coalesce(nullif(btrim(coalesce(op.first_name,'') || ' ' || coalesce(op.last_name,'')), ''), v_owner),
        'Helper',   coalesce(nullif(btrim(coalesce(hp.first_name,'') || ' ' || coalesce(hp.last_name,'')), ''), ''),
        'Rig',      coalesce(rg.name, 'Rig 1')
      ) as obj
    from public.visits v
    left join public.clients c on c.id = v.client_id
    left join public.admins op on op.id = coalesce(
           v.operator_admin_id,
           (select a.operator_admin_id from public.bath_appointments a where a.id = v.appointment_id),
           v.completed_by)
    left join public.admins hp on hp.id = v.helper_admin_id
    left join public.rigs   rg on rg.id = v.rig_id
    where v.arrived_at is not null
      and (v.visited_at at time zone 'America/New_York')::date > date '2026-06-13'
  ) s;
  return result;
end;
$$;
revoke all on function public._time_is_money_ledger() from public, authenticated, anon;
grant execute on function public._time_is_money_ledger() to service_role;
