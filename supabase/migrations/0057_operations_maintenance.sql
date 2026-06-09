-- 0057_operations_maintenance.sql
-- Operations / Field floor: the trailer and gear, each with a service interval.
-- A daily maintenance watcher (maintenance-daily cron, or admin_maintenance_check
-- on demand) flags anything overdue within 14 days into the briefings feed
-- before it fails on a route. Deterministic, no LLM.

create table if not exists public.equipment (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  category text not null default 'other'
    check (category = any (array['trailer','tow_vehicle','generator','bath_system','dryer','clippers','rotary','water_system','other'])),
  last_service_date date,
  interval_days integer check (interval_days is null or interval_days > 0),
  provider text,
  notes text,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.equipment enable row level security;

create or replace function public.admin_list_equipment()
returns jsonb language plpgsql security definer set search_path = public, pg_temp
as $$
declare v_items jsonb; v_due int; v_over int;
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  select coalesce(jsonb_agg(jsonb_build_object(
      'id', id, 'name', name, 'category', category, 'last_service_date', last_service_date,
      'interval_days', interval_days,
      'next_service', case when last_service_date is not null and interval_days is not null then last_service_date + interval_days end,
      'days_until', case when last_service_date is not null and interval_days is not null then (last_service_date + interval_days) - current_date end,
      'provider', provider, 'notes', notes, 'active', active
    ) order by (last_service_date is null or interval_days is null),
      case when last_service_date is not null and interval_days is not null then last_service_date + interval_days end, name), '[]'::jsonb)
    into v_items from public.equipment;
  select count(*) filter (where active and last_service_date is not null and interval_days is not null
            and (last_service_date + interval_days) between current_date and current_date + 14),
         count(*) filter (where active and last_service_date is not null and interval_days is not null
            and (last_service_date + interval_days) < current_date)
    into v_due, v_over from public.equipment;
  return jsonb_build_object('items', v_items, 'due_soon', v_due, 'overdue', v_over);
end;
$$;
revoke all on function public.admin_list_equipment() from public;
grant execute on function public.admin_list_equipment() to authenticated;

create or replace function public.admin_upsert_equipment(
  p_id uuid, p_name text, p_category text, p_last_service_date date, p_interval_days integer,
  p_provider text default null, p_notes text default null, p_active boolean default true
) returns uuid language plpgsql security definer set search_path = public, pg_temp
as $$
declare v_id uuid;
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  if coalesce(trim(p_name),'')='' then raise exception 'name required'; end if;
  if p_id is null then
    insert into public.equipment (name, category, last_service_date, interval_days, provider, notes, active)
    values (p_name, coalesce(p_category,'other'), p_last_service_date, p_interval_days, p_provider, p_notes, coalesce(p_active,true))
    returning id into v_id;
  else
    update public.equipment set name=p_name, category=coalesce(p_category,'other'), last_service_date=p_last_service_date,
      interval_days=p_interval_days, provider=p_provider, notes=p_notes, active=coalesce(p_active,true), updated_at=now()
     where id=p_id returning id into v_id;
    if v_id is null then raise exception 'item not found'; end if;
  end if;
  return v_id;
end;
$$;
revoke all on function public.admin_upsert_equipment(uuid, text, text, date, integer, text, text, boolean) from public;
grant execute on function public.admin_upsert_equipment(uuid, text, text, date, integer, text, text, boolean) to authenticated;

create or replace function public.admin_delete_equipment(p_id uuid)
returns void language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  delete from public.equipment where id = p_id;
  if not found then raise exception 'item not found'; end if;
end;
$$;
revoke all on function public.admin_delete_equipment(uuid) from public;
grant execute on function public.admin_delete_equipment(uuid) to authenticated;

create or replace function public._maintenance_scan()
returns integer language plpgsql security definer set search_path = public, pg_temp
as $$
declare v_created int := 0; r record; v_next date;
begin
  for r in select * from public.equipment
           where active and last_service_date is not null and interval_days is not null
             and (last_service_date + interval_days) <= current_date + 14 loop
    v_next := r.last_service_date + r.interval_days;
    if not exists (select 1 from public.briefings where agent_key='maintenance'
        and (evidence->>'equipment_id')::uuid = r.id and status in ('new','read') and created_at > now() - interval '20 days') then
      insert into public.briefings (agent_key, department, severity, title, body, evidence)
      values ('maintenance','operations',
        case when v_next <= current_date + 7 then 'alert' else 'signal' end,
        case when v_next < current_date then 'Overdue service: '||r.name else 'Service due: '||r.name end,
        format('%s (%s) %s service on %s (every %s days, last done %s). Keeping it serviced avoids a breakdown on a route.',
          r.name, r.category, case when v_next < current_date then 'was due for' else 'is due for' end,
          to_char(v_next,'Mon DD'), r.interval_days, to_char(r.last_service_date,'Mon DD')),
        jsonb_build_object('equipment_id', r.id, 'next_service', v_next, 'days', v_next - current_date));
      v_created := v_created + 1;
    end if;
  end loop;
  if v_created > 0 then update public.agents set is_active=true, updated_at=now() where agent_key='maintenance'; end if;
  return v_created;
end;
$$;

create or replace function public.admin_maintenance_check()
returns jsonb language plpgsql security definer set search_path = public, pg_temp
as $$
declare v int;
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  v := public._maintenance_scan();
  return jsonb_build_object('alerts_created', v);
end;
$$;
revoke all on function public.admin_maintenance_check() from public;
grant execute on function public.admin_maintenance_check() to authenticated;

insert into public.agents (agent_key, label, department, description, schedule_cron, is_active) values
  ('maintenance','Maintenance watcher','operations','Flags equipment overdue for service before it fails on a route.','30 11 * * *', false)
on conflict (agent_key) do nothing;

select cron.schedule('maintenance-daily', '30 11 * * *', 'select public._maintenance_scan();')
  where not exists (select 1 from cron.job where jobname='maintenance-daily');

insert into public.equipment (name, category, notes) values
  ('Generator A',                 'generator',    'Two generators run for redundancy. Add the service interval and last service.'),
  ('Generator B',                 'generator',    'Redundant second generator.'),
  ('Dual submersible bath pumps', 'bath_system',  'External 5-gallon recirculating bucket. Rinse intake screen between baths.'),
  ('High-velocity dryer',         'dryer',        null),
  ('Clippers and blades',         'clippers',     '#7 blade and others; blades need periodic sharpening.'),
  ('Rotary tool',                 'rotary',       'Nails-only tool.'),
  ('Freshwater + recirculating water system', 'water_system', 'Freshwater tank separate from the recirculating bucket.'),
  ('Trailer (climate-controlled)','trailer',      'Climate control keeps the tank warm through the day.'),
  ('Tow vehicle',                 'tow_vehicle',  'Oil, tires, brakes.')
on conflict do nothing;
