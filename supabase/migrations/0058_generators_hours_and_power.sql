-- 0058_generators_hours_and_power.sql
-- Generators tracked by ENGINE HOURS (not dates), each appliance tagged with its
-- power draw and which generator feeds it, and a load-vs-capacity headroom calc
-- so Paul knows what is free before adding equipment. Maintenance becomes
-- hours-based service tasks (from the Predator 5000 manual). The watcher also
-- reminds Paul to read the hours off the panel when they go stale.

alter table public.equipment
  add column if not exists kind text not null default 'equipment'
    check (kind = any (array['generator','appliance','equipment'])),
  add column if not exists track_hours boolean not null default false,
  add column if not exists current_hours numeric,
  add column if not exists hours_updated_at timestamptz,
  add column if not exists rated_watts integer,
  add column if not exists side text,
  add column if not exists powered_by uuid references public.equipment(id) on delete set null,
  add column if not exists watts integer;

create table if not exists public.maintenance_tasks (
  id uuid primary key default gen_random_uuid(),
  equipment_id uuid not null references public.equipment(id) on delete cascade,
  task text not null,
  interval_hours integer check (interval_hours is null or interval_hours > 0),
  interval_days integer check (interval_days is null or interval_days > 0),
  last_done_hours numeric,
  last_done_date date,
  notes text,
  active boolean not null default true,
  created_at timestamptz not null default now()
);
alter table public.maintenance_tasks enable row level security;

update public.equipment set name='Infrastructure generator', kind='generator', track_hours=true,
  rated_watts=3900, side='passenger',
  notes='Predator 5000 (3900W continuous). Powers the air conditioner, main vacuum, clippers, and lights. Read engine hours off the panel.'
  where name='Generator A';
update public.equipment set name='Bathing generator', kind='generator', track_hours=true,
  rated_watts=3900, side=null,
  notes='Predator 5000 (3900W continuous). Powers the high-velocity dryer, water pumps, and dehumidifier. Confirm which physical side. Read engine hours off the panel.'
  where name='Generator B';

update public.equipment set kind='appliance', powered_by=(select id from public.equipment where name='Bathing generator')
  where name in ('High-velocity dryer','Dual submersible bath pumps');
update public.equipment set kind='appliance', powered_by=(select id from public.equipment where name='Infrastructure generator')
  where name in ('Clippers and blades');
update public.equipment set kind='appliance' where name='Rotary tool';
update public.equipment set kind='equipment'
  where name in ('Freshwater + recirculating water system','Trailer (climate-controlled)','Tow vehicle');

insert into public.equipment (name, category, kind, powered_by, notes)
select v.name, 'other', 'appliance', g.id, v.note
from (values
  ('Air conditioner','Infrastructure generator','Climate for the dog.'),
  ('Main vacuum','Infrastructure generator',null),
  ('Lights','Infrastructure generator',null),
  ('Dehumidifier','Bathing generator','Pulls moisture during drying.')
) as v(name, gen, note)
join public.equipment g on g.name = v.gen
where not exists (select 1 from public.equipment e where e.name = v.name);

insert into public.maintenance_tasks (equipment_id, task, interval_hours, notes)
select g.id, t.task, t.hrs, t.note
from public.equipment g
cross join (values
  ('Oil change (10W-30)', 100, 'First change at 30 hours, then every 100 hours or 6 months.'),
  ('Clean/inspect air filter', 50, 'Clean foam element; replace when dirty or saturated.'),
  ('Inspect spark plug', 300, 'Gap 0.028-0.031 in; replace around 300 hours.')
) as t(task, hrs, note)
where g.kind='generator'
  and not exists (select 1 from public.maintenance_tasks m where m.equipment_id=g.id and m.task=t.task);

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
    into v_items from public.equipment where kind='equipment';
  select count(*) filter (where active and kind='equipment' and last_service_date is not null and interval_days is not null
            and (last_service_date + interval_days) between current_date and current_date + 14),
         count(*) filter (where active and kind='equipment' and last_service_date is not null and interval_days is not null
            and (last_service_date + interval_days) < current_date)
    into v_due, v_over from public.equipment;
  return jsonb_build_object('items', v_items, 'due_soon', v_due, 'overdue', v_over);
end;
$$;
revoke all on function public.admin_list_equipment() from public;
grant execute on function public.admin_list_equipment() to authenticated;

create or replace function public.admin_update_equipment_hours(p_id uuid, p_hours numeric)
returns void language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  update public.equipment set current_hours = p_hours, hours_updated_at = now(), updated_at = now()
   where id = p_id and kind='generator';
  if not found then raise exception 'generator not found'; end if;
end;
$$;
revoke all on function public.admin_update_equipment_hours(uuid, numeric) from public;
grant execute on function public.admin_update_equipment_hours(uuid, numeric) to authenticated;

create or replace function public.admin_set_power(p_id uuid, p_watts integer default null, p_rated_watts integer default null)
returns void language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  update public.equipment set watts = coalesce(p_watts, watts), rated_watts = coalesce(p_rated_watts, rated_watts), updated_at = now()
   where id = p_id;
  if not found then raise exception 'equipment not found'; end if;
end;
$$;
revoke all on function public.admin_set_power(uuid, integer, integer) from public;
grant execute on function public.admin_set_power(uuid, integer, integer) to authenticated;

create or replace function public.admin_power_summary()
returns jsonb language plpgsql security definer set search_path = public, pg_temp
as $$
declare v_gens jsonb; v_unassigned jsonb;
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  select coalesce(jsonb_agg(jsonb_build_object(
      'id', g.id, 'name', g.name, 'side', g.side, 'rated_watts', g.rated_watts,
      'current_hours', g.current_hours, 'hours_updated_at', g.hours_updated_at,
      'load_watts', (select coalesce(sum(a.watts),0) from public.equipment a where a.powered_by=g.id),
      'appliances', (select coalesce(jsonb_agg(jsonb_build_object('id',a.id,'name',a.name,'watts',a.watts) order by a.name),'[]'::jsonb)
                      from public.equipment a where a.powered_by=g.id),
      'tasks', (select coalesce(jsonb_agg(jsonb_build_object(
                  'id',m.id,'task',m.task,'interval_hours',m.interval_hours,'last_done_hours',m.last_done_hours,
                  'hours_remaining', case when m.interval_hours is not null and g.current_hours is not null
                                          then m.interval_hours - (g.current_hours - coalesce(m.last_done_hours,0)) end,
                  'notes',m.notes) order by m.task),'[]'::jsonb)
                from public.maintenance_tasks m where m.equipment_id=g.id and m.active)
    ) order by g.name), '[]'::jsonb)
    into v_gens from public.equipment g where g.kind='generator';
  select coalesce(jsonb_agg(jsonb_build_object('id',a.id,'name',a.name,'watts',a.watts) order by a.name),'[]'::jsonb)
    into v_unassigned from public.equipment a where a.kind='appliance' and a.powered_by is null;
  return jsonb_build_object('generators', v_gens, 'unassigned_appliances', v_unassigned);
end;
$$;
revoke all on function public.admin_power_summary() from public;
grant execute on function public.admin_power_summary() to authenticated;

create or replace function public._maintenance_scan()
returns integer language plpgsql security definer set search_path = public, pg_temp
as $$
declare v_created int := 0; r record; g record; t record; v_next date; v_used numeric;
begin
  for r in select * from public.equipment
           where active and kind='equipment' and last_service_date is not null and interval_days is not null
             and (last_service_date + interval_days) <= current_date + 14 loop
    v_next := r.last_service_date + r.interval_days;
    if not exists (select 1 from public.briefings where agent_key='maintenance'
        and (evidence->>'equipment_id')::uuid = r.id and (evidence->>'task') is null
        and status in ('new','read') and created_at > now() - interval '20 days') then
      insert into public.briefings (agent_key, department, severity, title, body, evidence)
      values ('maintenance','operations', case when v_next <= current_date + 7 then 'alert' else 'signal' end,
        case when v_next < current_date then 'Overdue service: '||r.name else 'Service due: '||r.name end,
        format('%s %s service on %s.', r.name, case when v_next<current_date then 'was due for' else 'is due for' end, to_char(v_next,'Mon DD')),
        jsonb_build_object('equipment_id', r.id, 'next_service', v_next));
      v_created := v_created + 1;
    end if;
  end loop;

  for g in select * from public.equipment where active and kind='generator' loop
    if g.track_hours and (g.hours_updated_at is null or g.hours_updated_at < now() - interval '21 days') then
      if not exists (select 1 from public.briefings where agent_key='maintenance'
          and evidence->>'kind'='hours_reminder' and (evidence->>'equipment_id')::uuid=g.id
          and status in ('new','read') and created_at > now() - interval '14 days') then
        insert into public.briefings (agent_key, department, severity, title, body, evidence)
        values ('maintenance','operations','signal','Update hours: '||g.name,
          format('Read the engine hours off the %s panel and enter them, so maintenance stays on schedule.', g.name),
          jsonb_build_object('kind','hours_reminder','equipment_id',g.id));
        v_created := v_created + 1;
      end if;
    end if;
    if g.current_hours is not null then
      for t in select * from public.maintenance_tasks where equipment_id=g.id and active and interval_hours is not null loop
        v_used := g.current_hours - coalesce(t.last_done_hours, 0);
        if v_used >= t.interval_hours then
          if not exists (select 1 from public.briefings where agent_key='maintenance'
              and (evidence->>'task_id')::uuid=t.id and status in ('new','read') and created_at > now() - interval '20 days') then
            insert into public.briefings (agent_key, department, severity, title, body, evidence)
            values ('maintenance','operations','alert', t.task||' due: '||g.name,
              format('%s on the %s: %s hours run since last done (interval %s hours, now at %s). %s',
                t.task, g.name, round(v_used), t.interval_hours, round(g.current_hours), coalesce(t.notes,'')),
              jsonb_build_object('equipment_id',g.id,'task_id',t.id,'task',t.task,'hours',g.current_hours));
            v_created := v_created + 1;
          end if;
        end if;
      end loop;
    end if;
  end loop;

  if v_created > 0 then update public.agents set is_active=true, updated_at=now() where agent_key='maintenance'; end if;
  return v_created;
end;
$$;
