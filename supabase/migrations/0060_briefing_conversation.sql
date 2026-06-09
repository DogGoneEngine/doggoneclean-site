-- 0060_briefing_conversation.sql
-- Two-way briefings. Paul can reply to an action item, the agent acknowledges,
-- and "this is intentional" records his reason and makes the agent stand down on
-- that exact subject for good (e.g. an intentionally low price for a fixed-income
-- client). The agents stop throwing the same thing back.

-- allow the 'resolved' status that admin_resolve_briefing sets
alter table public.briefings drop constraint if exists briefings_status_check;
alter table public.briefings add constraint briefings_status_check
  check (status = any (array['new','read','approved','dismissed','acted','resolved']));

alter table public.briefings add column if not exists disposition text;

create table if not exists public.briefing_notes (
  id uuid primary key default gen_random_uuid(),
  briefing_id uuid not null references public.briefings(id) on delete cascade,
  author text not null check (author = any (array['paul','agent'])),
  body text not null,
  created_at timestamptz not null default now()
);
alter table public.briefing_notes enable row level security;

create or replace function public.admin_list_briefings(p_department text default null, p_status text default null)
returns jsonb language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', b.id, 'agent_key', b.agent_key, 'department', b.department,
      'severity', b.severity, 'title', b.title, 'body', b.body,
      'evidence', b.evidence, 'recommended_action', b.recommended_action,
      'status', b.status, 'disposition', b.disposition, 'created_at', b.created_at,
      'notes', (select coalesce(jsonb_agg(jsonb_build_object('author',n.author,'body',n.body,'created_at',n.created_at) order by n.created_at),'[]'::jsonb)
                 from public.briefing_notes n where n.briefing_id=b.id)
    ) order by b.created_at desc)
    from public.briefings b
    where (p_department is null or b.department = p_department)
      and (p_status is null or b.status = p_status)
  ), '[]'::jsonb);
end;
$$;
revoke all on function public.admin_list_briefings(text, text) from public;
grant execute on function public.admin_list_briefings(text, text) to authenticated;

create or replace function public.admin_add_briefing_note(p_briefing_id uuid, p_body text)
returns void language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  if coalesce(trim(p_body),'')='' then raise exception 'empty note'; end if;
  insert into public.briefing_notes (briefing_id, author, body) values (p_briefing_id, 'paul', p_body);
  update public.briefings set status='read' where id=p_briefing_id and status='new';
end;
$$;
revoke all on function public.admin_add_briefing_note(uuid, text) from public;
grant execute on function public.admin_add_briefing_note(uuid, text) to authenticated;

create or replace function public.admin_resolve_briefing(p_briefing_id uuid, p_disposition text, p_note text default null)
returns void language plpgsql security definer set search_path = public, pg_temp
as $$
declare v_ack text;
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  if p_disposition not in ('intentional','dismissed','done') then raise exception 'bad disposition'; end if;
  if coalesce(trim(p_note),'') <> '' then
    insert into public.briefing_notes (briefing_id, author, body) values (p_briefing_id, 'paul', p_note);
  end if;
  update public.briefings set disposition=p_disposition, status='resolved' where id=p_briefing_id;
  v_ack := case p_disposition
    when 'intentional' then 'Understood. I will leave this one alone and stop flagging it. Tell me if that changes.'
    when 'done' then 'Got it, marked done.'
    else 'Cleared.' end;
  insert into public.briefing_notes (briefing_id, author, body) values (p_briefing_id, 'agent', v_ack);
end;
$$;
revoke all on function public.admin_resolve_briefing(uuid, text, text) from public;
grant execute on function public.admin_resolve_briefing(uuid, text, text) to authenticated;

-- Client agents skip a subject permanently once Paul marks it 'intentional'.
create or replace function public._pricing_scan()
returns integer language plpgsql security definer set search_path = public, pg_temp
as $$
declare v_created int := 0; r record; v_rate numeric; v_floor numeric;
begin
  select case when sum(actual_minutes)>0 and sum(amount_collected_cents)>0
              then (sum(amount_collected_cents)/100.0)/(sum(actual_minutes)/60.0) end
    into v_rate from public.visits
   where visited_at >= now() - interval '180 days' and amount_collected_cents is not null and actual_minutes is not null;
  if v_rate is null then return 0; end if;
  v_floor := v_rate * 0.75;
  for r in
    select c.id, c.name, count(*) n, sum(v.amount_collected_cents) cents, sum(v.actual_minutes) mins
      from public.visits v join public.clients c on c.id = v.client_id
     where v.visited_at >= now() - interval '180 days' and v.amount_collected_cents is not null and v.actual_minutes is not null
       and not c.exclude_from_everything
     group by c.id, c.name
    having count(*) >= 3 and (sum(v.amount_collected_cents)/100.0)/(sum(v.actual_minutes)/60.0) < v_floor
  loop
    if not exists (select 1 from public.briefings where agent_key='pricing'
        and (evidence->>'client_id')::uuid = r.id and status in ('new','read') and created_at > now() - interval '30 days')
       and not exists (select 1 from public.briefings where agent_key='pricing'
        and (evidence->>'client_id')::uuid = r.id and disposition='intentional') then
      insert into public.briefings (agent_key, department, severity, title, body, evidence)
      values ('pricing','finance','signal','Below rate: '||r.name,
        format('%s earns $%s per hour across %s visits, under the $%s business rate. Consider a price review at the next visit to pull it up toward the target.',
          r.name, round((r.cents/100.0)/(r.mins/60.0),2), r.n, round(v_rate,2)),
        jsonb_build_object('client_id', r.id, 'rev_per_hour', round((r.cents/100.0)/(r.mins/60.0),2), 'business_rate', round(v_rate,2), 'visits', r.n));
      v_created := v_created + 1;
    end if;
  end loop;
  if v_created > 0 then update public.agents set is_active=true, updated_at=now() where agent_key='pricing'; end if;
  return v_created;
end;
$$;

create or replace function public._retention_scan()
returns integer language plpgsql security definer set search_path = public, pg_temp
as $$
declare v_created int := 0; r record;
begin
  for r in
    select c.id, c.name, c.cadence_days, max(v.visited_at)::date as last_visit,
           (current_date - max(v.visited_at)::date) as days_since
      from public.clients c join public.visits v on v.client_id = c.id
     where c.roster_group = 'standing' and c.cadence_days is not null and not c.exclude_from_everything
     group by c.id, c.name, c.cadence_days
    having (current_date - max(v.visited_at)::date) > c.cadence_days * 1.5
  loop
    if not exists (select 1 from public.briefings where agent_key='retention'
        and (evidence->>'client_id')::uuid = r.id and status in ('new','read') and created_at > now() - interval '20 days')
       and not exists (select 1 from public.briefings where agent_key='retention'
        and (evidence->>'client_id')::uuid = r.id and disposition='intentional') then
      insert into public.briefings (agent_key, department, severity, title, body, evidence)
      values ('retention','growth',
        case when r.days_since > r.cadence_days * 2 then 'alert' else 'signal' end,
        'Overdue: '||r.name,
        format('%s runs on an every-%s-day rhythm but has not been in for %s days (last visit %s). A standing client slipping past their cadence is an early churn signal; a quick message to rebook is worth it.',
          r.name, r.cadence_days, r.days_since, to_char(r.last_visit,'Mon DD')),
        jsonb_build_object('client_id', r.id, 'cadence_days', r.cadence_days, 'days_since', r.days_since, 'last_visit', r.last_visit));
      v_created := v_created + 1;
    end if;
  end loop;
  if v_created > 0 then update public.agents set is_active=true, updated_at=now() where agent_key='retention'; end if;
  return v_created;
end;
$$;
