-- 0065_winback_growth.sql
-- Win-back agent (Growth floor). Times off the client's own cadence (cadence +
-- ~2 weeks) or ~90 days for a one-off with no cadence; targets the RECENTLY
-- lapsed (winnable), not the long-gone (upper window, default 18 months); only
-- surfaces win-backs when there is calendar room; and when it is time but the
-- calendar is full, surfaces THAT instead. Trickles the most-recently-lapsed a
-- few per run so Today is never flooded. Email-framed; respects 'intentional'.
-- See winback_is_cadence_and_calendar_aware + winback_contact_email_opt_in.

insert into public.agents (agent_key, label, department, description, schedule_cron, is_active) values
  ('winback','Win-back watcher','growth','Surfaces lapsed clients to re-engage by email, timed to their cadence and the calendar.','30 13 * * *', false)
on conflict (agent_key) do nothing;

insert into public.app_secrets (name, value) values ('winback_capacity_14d','40') on conflict (name) do nothing;
insert into public.app_secrets (name, value) values ('winback_max_days','540') on conflict (name) do nothing;

create or replace function public._winback_due_view()
returns table(id uuid, name text, email text, roster_group text, cadence_days int, last_visit date, days_since int)
language sql security definer set search_path = public, pg_temp
as $$
  select c.id, c.name, c.email, c.roster_group, c.cadence_days,
         max(v.visited_at)::date, (current_date - max(v.visited_at)::date)
    from public.clients c join public.visits v on v.client_id = c.id
   where not c.exclude_from_everything
   group by c.id, c.name, c.email, c.roster_group, c.cadence_days
  having (current_date - max(v.visited_at)::date) >= (case when c.cadence_days is not null then c.cadence_days + 14 else 90 end)
     and (current_date - max(v.visited_at)::date) <= coalesce((select value::int from public.app_secrets where name='winback_max_days'), 540);
$$;

create or replace function public._winback_scan()
returns integer language plpgsql security definer set search_path = public, pg_temp
as $$
declare v_created int := 0; v_clients int := 0; v_blocked int := 0; r record; v_cap int; v_upcoming int; v_room boolean;
begin
  v_cap := coalesce((select value::int from public.app_secrets where name='winback_capacity_14d'), 40);
  select count(*) into v_upcoming from public.bath_appointments
   where status in ('requested','confirmed') and scheduled_start between now() and now() + interval '14 days';
  v_room := v_upcoming < v_cap;

  for r in select * from public._winback_due_view() order by days_since asc loop
    if exists (select 1 from public.briefings where agent_key='winback' and (evidence->>'client_id')::uuid=r.id and disposition='intentional')
       or exists (select 1 from public.briefings where agent_key='winback' and (evidence->>'client_id')::uuid=r.id and status in ('new','read') and created_at > now() - interval '21 days')
       or exists (select 1 from public.briefings where agent_key='retention' and (evidence->>'client_id')::uuid=r.id and status in ('new','read')) then
      continue;
    end if;
    if v_room then
      if v_clients >= 6 then exit; end if;
      insert into public.briefings (agent_key, department, severity, title, body, evidence)
      values ('winback','growth','signal','Win back: '||r.name,
        case when r.cadence_days is not null
          then format('%s is on an every-%s-day rhythm and it has been %s days since the last visit. Good time to send the coat-care reminder email%s.', r.name, r.cadence_days, r.days_since, case when r.email is not null then ' to '||r.email else ' (no email on file)' end)
          else format('%s came once and it has been %s days. Good time to invite them back by email%s.', r.name, r.days_since, case when r.email is not null then ' at '||r.email else ' (no email on file)' end) end,
        jsonb_build_object('client_id', r.id, 'email', r.email, 'days_since', r.days_since, 'cadence_days', r.cadence_days));
      v_created := v_created + 1; v_clients := v_clients + 1;
    else
      v_blocked := v_blocked + 1;
    end if;
  end loop;

  if not v_room and v_blocked > 0 then
    if not exists (select 1 from public.briefings where agent_key='winback' and evidence->>'kind'='no_room' and status in ('new','read') and created_at > now() - interval '7 days') then
      insert into public.briefings (agent_key, department, severity, title, body, evidence)
      values ('winback','growth','alert','Win-backs waiting on calendar room',
        format('%s client(s) are due for a win-back, but the calendar is full for the next two weeks (%s booked, capacity %s). Worth making room or adding capacity rather than letting them drift.', v_blocked, v_upcoming, v_cap),
        jsonb_build_object('kind','no_room','due', v_blocked, 'upcoming', v_upcoming, 'capacity', v_cap));
      v_created := v_created + 1;
    end if;
  end if;

  if v_created > 0 then update public.agents set is_active=true, updated_at=now() where agent_key='winback'; end if;
  return v_created;
end;
$$;

create or replace function public.admin_winback_check()
returns jsonb language plpgsql security definer set search_path = public, pg_temp
as $$
declare v int;
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  v := public._winback_scan();
  return jsonb_build_object('alerts_created', v);
end;
$$;
revoke all on function public.admin_winback_check() from public;
grant execute on function public.admin_winback_check() to authenticated;

create or replace function public.admin_growth_summary()
returns jsonb language plpgsql security definer set search_path = public, pg_temp
as $$
declare v_cap int; v_upcoming int; v_cand jsonb; v_ret int;
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  v_cap := coalesce((select value::int from public.app_secrets where name='winback_capacity_14d'), 40);
  select count(*) into v_upcoming from public.bath_appointments
   where status in ('requested','confirmed') and scheduled_start between now() and now() + interval '14 days';
  select coalesce(jsonb_agg(jsonb_build_object(
      'name', d.name, 'email', d.email, 'days_since', d.days_since, 'cadence_days', d.cadence_days,
      'kind', case when d.cadence_days is not null then 'recurring' else 'one-off' end) order by d.days_since asc), '[]'::jsonb)
    into v_cand from public._winback_due_view() d
    where not exists (select 1 from public.briefings where agent_key='winback' and (evidence->>'client_id')::uuid=d.id and disposition='intentional');
  select count(*) into v_ret from public.briefings where agent_key='retention' and status in ('new','read');
  return jsonb_build_object('upcoming_14d', v_upcoming, 'capacity_14d', v_cap, 'has_room', v_upcoming < v_cap,
    'candidates', v_cand, 'retention_open', v_ret);
end;
$$;
revoke all on function public.admin_growth_summary() from public;
grant execute on function public.admin_growth_summary() to authenticated;

select cron.schedule('winback-daily', '30 13 * * *', 'select public._winback_scan();')
  where not exists (select 1 from cron.job where jobname='winback-daily');
