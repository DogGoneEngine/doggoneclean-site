-- 0059_maintenance_filters_and_watts.sql
-- Confirm the Bathing generator side (driver), add filter-cleaning tasks for the
-- appliances that have filters, let Paul mark a task done, and extend the
-- maintenance watcher to (a) remind about filters and (b) ask for missing
-- appliance watt draws as part of its routine.

update public.equipment set side='driver' where name='Bathing generator';

insert into public.maintenance_tasks (equipment_id, task, interval_days, notes)
select e.id, 'Clean filter', v.days, v.note
from (values
  ('High-velocity dryer', 14, 'Hair clogs the intake fast; adjust to your real use.'),
  ('Air conditioner',     30, 'Keeps cooling strong and the compressor happy.'),
  ('Dehumidifier',        30, 'A clogged filter kills drying performance.')
) as v(name, days, note)
join public.equipment e on e.name = v.name
where not exists (select 1 from public.maintenance_tasks m where m.equipment_id=e.id and m.task='Clean filter');

create or replace function public.admin_mark_task_done(p_task_id uuid, p_done_date date default null, p_done_hours numeric default null)
returns void language plpgsql security definer set search_path = public, pg_temp
as $$
declare t record; v_hours numeric;
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  select * into t from public.maintenance_tasks where id = p_task_id;
  if t is null then raise exception 'task not found'; end if;
  if t.interval_hours is not null then
    select current_hours into v_hours from public.equipment where id = t.equipment_id;
    update public.maintenance_tasks set last_done_hours = coalesce(p_done_hours, v_hours), last_done_date = coalesce(p_done_date, current_date)
     where id = p_task_id;
  else
    update public.maintenance_tasks set last_done_date = coalesce(p_done_date, current_date) where id = p_task_id;
  end if;
end;
$$;
revoke all on function public.admin_mark_task_done(uuid, date, numeric) from public;
grant execute on function public.admin_mark_task_done(uuid, date, numeric) to authenticated;

create or replace function public.admin_list_maintenance_tasks()
returns jsonb language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', m.id, 'equipment', e.name, 'kind', e.kind, 'task', m.task,
      'interval_hours', m.interval_hours, 'interval_days', m.interval_days,
      'last_done_hours', m.last_done_hours, 'last_done_date', m.last_done_date,
      'current_hours', e.current_hours,
      'status', case
        when m.interval_hours is not null then
          case when e.current_hours is null then 'enter hours'
               when (e.current_hours - coalesce(m.last_done_hours,0)) >= m.interval_hours then 'due'
               when m.interval_hours - (e.current_hours - coalesce(m.last_done_hours,0)) <= 10 then 'soon'
               else 'ok' end
        else
          case when m.last_done_date is null then 'log last done'
               when (m.last_done_date + m.interval_days) <= current_date then 'due'
               when (m.last_done_date + m.interval_days) <= current_date + 7 then 'soon'
               else 'ok' end end
    ) order by e.name, m.task)
    from public.maintenance_tasks m join public.equipment e on e.id = m.equipment_id
    where m.active and e.active), '[]'::jsonb);
end;
$$;
revoke all on function public.admin_list_maintenance_tasks() from public;
grant execute on function public.admin_list_maintenance_tasks() to authenticated;

-- Watcher v3: date-based gear + generator hours + hours reminder + date-based
-- maintenance tasks (filters) + a routine ask for missing watt draws.
create or replace function public._maintenance_scan()
returns integer language plpgsql security definer set search_path = public, pg_temp
as $$
declare v_created int := 0; r record; g record; t record; v_next date; v_used numeric; v_missing int;
begin
  for r in select * from public.equipment
           where active and kind='equipment' and last_service_date is not null and interval_days is not null
             and (last_service_date + interval_days) <= current_date + 14 loop
    v_next := r.last_service_date + r.interval_days;
    if not exists (select 1 from public.briefings where agent_key='maintenance'
        and (evidence->>'equipment_id')::uuid = r.id and (evidence->>'task') is null and evidence->>'kind' is null
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
        if v_used >= t.interval_hours and not exists (select 1 from public.briefings where agent_key='maintenance'
              and (evidence->>'task_id')::uuid=t.id and status in ('new','read') and created_at > now() - interval '20 days') then
          insert into public.briefings (agent_key, department, severity, title, body, evidence)
          values ('maintenance','operations','alert', t.task||' due: '||g.name,
            format('%s on the %s: %s hours run since last done (interval %s hours, now at %s). %s',
              t.task, g.name, round(v_used), t.interval_hours, round(g.current_hours), coalesce(t.notes,'')),
            jsonb_build_object('equipment_id',g.id,'task_id',t.id,'task',t.task,'hours',g.current_hours));
          v_created := v_created + 1;
        end if;
      end loop;
    end if;
  end loop;

  for t in select m.*, e.name as ename from public.maintenance_tasks m join public.equipment e on e.id=m.equipment_id
           where m.active and e.active and m.interval_days is not null
             and (m.last_done_date is null or (m.last_done_date + m.interval_days) <= current_date + 7) loop
    if not exists (select 1 from public.briefings where agent_key='maintenance'
        and (evidence->>'task_id')::uuid=t.id and status in ('new','read') and created_at > now() - interval '20 days') then
      insert into public.briefings (agent_key, department, severity, title, body, evidence)
      values ('maintenance','operations',
        case when t.last_done_date is not null and (t.last_done_date + t.interval_days) < current_date then 'alert' else 'signal' end,
        t.task||': '||t.ename,
        case when t.last_done_date is null
             then format('Log when you last did "%s" on the %s so I can keep it on a %s-day cycle.', t.task, t.ename, t.interval_days)
             else format('%s on the %s (every %s days, last done %s).', t.task, t.ename, t.interval_days, to_char(t.last_done_date,'Mon DD')) end,
        jsonb_build_object('task_id', t.id, 'equipment', t.ename, 'kind','filter'));
      v_created := v_created + 1;
    end if;
  end loop;

  select count(*) into v_missing from public.equipment where kind='appliance' and active and watts is null;
  if v_missing > 0 and not exists (select 1 from public.briefings where agent_key='maintenance'
      and evidence->>'kind'='watts_prompt' and status in ('new','read') and created_at > now() - interval '30 days') then
    insert into public.briefings (agent_key, department, severity, title, body, evidence)
    values ('maintenance','operations','info','Enter appliance watt draws',
      format('%s appliance(s) have no watt draw recorded. Next time you have the labels handy, enter them so each generator''s load and headroom are accurate.', v_missing),
      jsonb_build_object('kind','watts_prompt','count',v_missing));
    v_created := v_created + 1;
  end if;

  if v_created > 0 then update public.agents set is_active=true, updated_at=now() where agent_key='maintenance'; end if;
  return v_created;
end;
$$;
