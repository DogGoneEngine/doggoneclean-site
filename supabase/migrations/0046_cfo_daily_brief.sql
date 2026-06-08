-- 0046_cfo_daily_brief.sql
-- The CFO department head's narration layer: a daily edge function (cfo-brief)
-- reads the real books and has Claude write a short briefing in the CFO's
-- voice. These are the service-role data/save RPCs it uses, the cron dispatcher
-- (mirrors notify_appointment's net.http_post + shared-secret pattern), and the
-- daily schedule. The Anthropic key lives as an edge-function secret, not here.

create or replace function public.cfo_brief_data(p_window_days integer default 90)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_visits int; v_priced int; v_timed int; v_revenue bigint; v_minutes bigint; v_clients int;
  v_rph numeric; v_prev_rph numeric; v_ar_count int; v_ar_cents bigint; v_noshow int; v_top jsonb;
begin
  select count(*), count(*) filter (where amount_collected_cents is not null),
         count(*) filter (where actual_minutes is not null),
         coalesce(sum(amount_collected_cents),0), coalesce(sum(actual_minutes),0), count(distinct client_id)
    into v_visits, v_priced, v_timed, v_revenue, v_minutes, v_clients
    from public.visits where visited_at >= now() - make_interval(days => p_window_days);
  if v_minutes>0 and v_revenue>0 then v_rph := round((v_revenue/100.0)/(v_minutes/60.0),2); end if;

  select case when sum(actual_minutes)>0 and sum(amount_collected_cents)>0
              then round((sum(amount_collected_cents)/100.0)/(sum(actual_minutes)/60.0),2) end
    into v_prev_rph
    from public.visits
   where visited_at >= now() - make_interval(days => p_window_days*2)
     and visited_at <  now() - make_interval(days => p_window_days);

  select count(*) into v_noshow from public.bath_appointments
   where status='no_show' and scheduled_start >= now() - make_interval(days => p_window_days);
  select count(*), coalesce(sum(amount_cents),0) into v_ar_count, v_ar_cents
    from public.bath_appointments where payment_status='pending' and scheduled_start < now();

  select coalesce(jsonb_agg(t), '[]'::jsonb) into v_top from (
    select c.name, count(*) as visits, coalesce(sum(v.amount_collected_cents),0) as collected_cents
      from public.visits v join public.clients c on c.id=v.client_id
     where v.visited_at >= now() - make_interval(days => p_window_days)
     group by c.name order by collected_cents desc nulls last limit 5
  ) t;

  return jsonb_build_object(
    'window_days', p_window_days, 'visits', v_visits, 'priced_visits', v_priced,
    'timed_visits', v_timed, 'clients', v_clients, 'revenue_cents', v_revenue, 'minutes', v_minutes,
    'revenue_per_hour', v_rph, 'prev_revenue_per_hour', v_prev_rph,
    'no_shows', v_noshow, 'ar_count', v_ar_count, 'ar_cents', v_ar_cents, 'top_clients', v_top);
end;
$$;
revoke all on function public.cfo_brief_data(integer) from public, authenticated, anon;
grant execute on function public.cfo_brief_data(integer) to service_role;

create or replace function public.cfo_save_briefing(
  p_title text, p_body text, p_severity text default 'info',
  p_evidence jsonb default null, p_model text default 'claude-sonnet-4-6', p_tokens integer default null
) returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare v_run uuid; v_brief uuid;
begin
  insert into public.agent_runs (agent_key, status, finished_at, model, tokens_used, input_summary)
  values ('cfo','ok',now(),p_model,p_tokens, jsonb_build_object('via','edge')) returning id into v_run;
  update public.briefings set status='read' where agent_key='cfo' and status='new';
  insert into public.briefings (agent_key, department, severity, title, body, evidence, run_id)
  values ('cfo','finance', coalesce(p_severity,'info'), p_title, p_body, p_evidence, v_run)
  returning id into v_brief;
  update public.agents set is_active=true, updated_at=now() where agent_key='cfo';
  return v_brief;
end;
$$;
revoke all on function public.cfo_save_briefing(text, text, text, jsonb, text, integer) from public, authenticated, anon;
grant execute on function public.cfo_save_briefing(text, text, text, jsonb, text, integer) to service_role;

-- Shared secret for the cron -> edge-function call (generated; the real value
-- lives only in the database, never in the repo).
insert into public.app_secrets (name, value)
values ('cfo_cron_secret', replace(gen_random_uuid()::text,'-','') || replace(gen_random_uuid()::text,'-',''))
on conflict (name) do nothing;

create or replace function public.cfo_dispatch_briefing()
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare v_secret text; v_base text;
begin
  select value into v_secret from public.app_secrets where name = 'cfo_cron_secret';
  select value into v_base   from public.app_secrets where name = 'edge_base_url';
  if v_secret is null or v_base is null then return; end if;
  perform net.http_post(
    url     => v_base || '/cfo-brief',
    headers => jsonb_build_object('Content-Type','application/json','x-cfo-secret', v_secret),
    body    => jsonb_build_object('window_days', 90),
    timeout_milliseconds => 20000
  );
end;
$$;
revoke all on function public.cfo_dispatch_briefing() from public, authenticated, anon;

-- Daily at 10:00 UTC (6am US Eastern, EDT).
select cron.schedule('cfo-daily-briefing', '0 10 * * *', 'select public.cfo_dispatch_briefing();')
where not exists (select 1 from cron.job where jobname = 'cfo-daily-briefing');
