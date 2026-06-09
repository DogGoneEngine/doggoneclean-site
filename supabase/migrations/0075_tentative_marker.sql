-- 0075_tentative_marker.sql
-- Paul marks tentative appointments with a trailing "?" in his Google Calendar
-- title. That "?" is his PRIVATE placeholder so he does not forget a pencilled
-- slot; it is never a client-facing thing. So:
--   1. The "?" character itself never lands in any column. It is translated into
--      an internal status = 'tentative' (add it to the status CHECK).
--   2. _sync_appointments strips the "?" for matching (already) AND records the
--      appointment as 'tentative' instead of 'confirmed' when the title carried
--      one. A tentative appointment is NOT a confirmed appointment.
--   3. tentative is a SOFT booking: it excludes the client from win-back (a "?"
--      client is by definition not forgotten) and counts toward calendar
--      capacity (it is real time Paul is planning around), exactly like a
--      confirmed appointment, but it is operator-only and never client-facing.
-- See tentative_marker_is_private in CLEAN_ORACLE.md.

alter table public.bath_appointments drop constraint if exists bath_appointments_status_check;
alter table public.bath_appointments add constraint bath_appointments_status_check
  check (status = any (array['requested','confirmed','tentative','on_the_way','on_site','in_service','completed','no_show','cancelled','skipped']));

create or replace function public._sync_appointments(p_events jsonb)
returns jsonb language plpgsql security definer set search_path = public, pg_temp
as $$
declare e record; v_name text; v_tentative boolean; v_status text;
        v_client uuid; v_sub uuid; v_appt uuid; v_ins int:=0; v_upd int:=0; v_unmatched jsonb:='[]'::jsonb;
begin
  for e in select * from jsonb_to_recordset(p_events) as x(
      external_id text, starts timestamptz, ends timestamptz, client_name text, client_email text,
      dog_count int, service_type text, amount_cents int, notes text)
  loop
    -- a trailing "?" is Paul's private "tentative / don't forget" marker. Detect
    -- it, then strip it: the "?" never enters the database, only the status does.
    v_tentative := right(btrim(e.client_name), 1) = '?';
    v_status := case when v_tentative then 'tentative' else 'confirmed' end;
    v_name := lower(btrim(rtrim(btrim(e.client_name), '? ')));
    select c.id into v_client from public.clients c
     where not c.exclude_from_everything and (
        lower(btrim(c.name)) = v_name
        or exists (select 1 from public.client_aliases a where a.client_id=c.id and lower(btrim(a.alias))=v_name)
        or (nullif(btrim(e.client_email),'') is not null and lower(c.email)=lower(btrim(e.client_email)))
     )
     order by (lower(btrim(c.name))=v_name) desc
     limit 1;
    if v_client is null then v_unmatched := v_unmatched || to_jsonb(e.client_name); continue; end if;
    select id into v_sub from public.bath_subscribers where client_id=v_client limit 1;
    if v_sub is null then insert into public.bath_subscribers (client_id) values (v_client) returning id into v_sub; end if;
    select id into v_appt from public.bath_appointments where external_id = e.external_id;
    if v_appt is null then
      insert into public.bath_appointments (subscriber_id, scheduled_start, scheduled_end, status, service_type, amount_cents, dog_count, source, external_id, notes)
      values (v_sub, e.starts, e.ends, v_status, coalesce(e.service_type,'full_groom'), coalesce(e.amount_cents,0), coalesce(e.dog_count,1), 'gcal_sync', e.external_id, e.notes);
      v_ins := v_ins + 1;
    else
      -- only the sync owns the tentative/confirmed distinction; never clobber an
      -- appointment that has already moved on (on_the_way..completed/cancelled).
      update public.bath_appointments set subscriber_id=v_sub, scheduled_start=e.starts, scheduled_end=e.ends,
        status = case when status in ('requested','confirmed','tentative') then v_status else status end,
        service_type=coalesce(e.service_type,service_type), amount_cents=coalesce(e.amount_cents,amount_cents),
        dog_count=coalesce(e.dog_count,dog_count,1), source='gcal_sync', notes=coalesce(e.notes,notes), updated_at=now()
       where id=v_appt;
      v_upd := v_upd + 1;
    end if;
  end loop;
  return jsonb_build_object('inserted', v_ins, 'updated', v_upd, 'unmatched', v_unmatched);
end;
$$;
revoke all on function public._sync_appointments(jsonb) from public, anon, authenticated;
grant execute on function public._sync_appointments(jsonb) to service_role;

-- Win-back treats tentative as a soft booking: a client with a pencilled slot is
-- not forgotten, so do not nudge them, and the slot counts toward capacity.
create or replace function public._winback_due_view()
returns table(id uuid, name text, email text, roster_group text, cadence_days int, last_visit date, days_since int)
language sql security definer set search_path = public, pg_temp
as $$
  select c.id, c.name, c.email, c.roster_group, c.cadence_days,
         max(v.visited_at)::date, (current_date - max(v.visited_at)::date)
    from public.clients c join public.visits v on v.client_id = c.id
   where not c.exclude_from_everything
     and not exists (
       select 1 from public.bath_appointments a
       join public.bath_subscribers s on s.id = a.subscriber_id
       where s.client_id = c.id and a.scheduled_start >= now() and a.status in ('requested','confirmed','tentative'))
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
   where status in ('requested','confirmed','tentative') and scheduled_start between now() and now() + interval '14 days';
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

create or replace function public.admin_growth_summary()
returns jsonb language plpgsql security definer set search_path = public, pg_temp
as $$
declare v_cap int; v_upcoming int; v_cand jsonb; v_ret int;
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  v_cap := coalesce((select value::int from public.app_secrets where name='winback_capacity_14d'), 40);
  select count(*) into v_upcoming from public.bath_appointments
   where status in ('requested','confirmed','tentative') and scheduled_start between now() and now() + interval '14 days';
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
