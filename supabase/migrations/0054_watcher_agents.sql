-- 0054_watcher_agents.sql
-- Three deterministic watcher agents (no LLM): retention catches standing
-- clients slipping past their cadence; pricing flags clients below the business
-- revenue-per-hour rate; bookkeeper flags uncategorized and duplicate expenses.
-- Each writes briefings into the feed (recommend, never act) on its own cron.

insert into public.agents (agent_key, label, department, description, schedule_cron, is_active) values
  ('retention', 'Retention watcher', 'growth',   'Flags standing clients overdue against their own cadence (early churn signal).', '0 12 * * *', false),
  ('pricing',   'Pricing watcher',   'finance',  'Flags clients whose revenue per hour sits below the business rate.', '0 13 * * 1', false),
  ('bookkeeper','Bookkeeper',        'finance',  'Flags uncategorized and duplicate expenses to keep the ledger clean.', '0 14 * * *', false),
  ('chief_of_staff','Weekly review', 'reports',  'A weekly cross-department business review.', '0 13 * * 1', false)
on conflict (agent_key) do nothing;

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
        and (evidence->>'client_id')::uuid = r.id and status in ('new','read') and created_at > now() - interval '20 days') then
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
        and (evidence->>'client_id')::uuid = r.id and status in ('new','read') and created_at > now() - interval '30 days') then
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

create or replace function public._bookkeeper_scan()
returns integer language plpgsql security definer set search_path = public, pg_temp
as $$
declare v_created int := 0; v_uncat int; v_dupes int;
begin
  select count(*) into v_uncat from public.expenses where is_business and category='other' and txn_date >= current_date - 60;
  select count(*) into v_dupes from (
    select 1 from public.expenses where is_business and txn_date >= current_date - 60
     group by lower(description), amount_cents having count(*) > 1) d;
  if v_uncat > 0 and not exists (select 1 from public.briefings where agent_key='bookkeeper'
        and evidence->>'kind'='uncategorized' and status in ('new','read') and created_at > now() - interval '7 days') then
    insert into public.briefings (agent_key, department, severity, title, body, evidence)
    values ('bookkeeper','finance','signal','Expenses need a category',
      format('%s expense(s) in the last 60 days are still uncategorized. Tagging them keeps the by-category view and the net honest.', v_uncat),
      jsonb_build_object('kind','uncategorized','count',v_uncat));
    v_created := v_created + 1;
  end if;
  if v_dupes > 0 and not exists (select 1 from public.briefings where agent_key='bookkeeper'
        and evidence->>'kind'='duplicates' and status in ('new','read') and created_at > now() - interval '7 days') then
    insert into public.briefings (agent_key, department, severity, title, body, evidence)
    values ('bookkeeper','finance','signal','Possible duplicate charges',
      format('%s merchant+amount group(s) repeat within the last 60 days. Worth a glance to confirm they are real, not a double charge.', v_dupes),
      jsonb_build_object('kind','duplicates','count',v_dupes));
    v_created := v_created + 1;
  end if;
  if v_created > 0 then update public.agents set is_active=true, updated_at=now() where agent_key='bookkeeper'; end if;
  return v_created;
end;
$$;

select cron.schedule('retention-daily',  '0 12 * * *', 'select public._retention_scan();')
  where not exists (select 1 from cron.job where jobname='retention-daily');
select cron.schedule('pricing-weekly',   '0 13 * * 1', 'select public._pricing_scan();')
  where not exists (select 1 from cron.job where jobname='pricing-weekly');
select cron.schedule('bookkeeper-daily', '0 14 * * *', 'select public._bookkeeper_scan();')
  where not exists (select 1 from cron.job where jobname='bookkeeper-daily');
