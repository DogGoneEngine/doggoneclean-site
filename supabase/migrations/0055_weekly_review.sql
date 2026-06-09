-- 0055_weekly_review.sql
-- The chief-of-staff weekly review (LLM): one memo a week synthesizing money,
-- retention, pricing, and compliance. Aggregate data RPC + save + cron dispatch;
-- the narration is the weekly-review edge function.

create or replace function public.weekly_review_data()
returns jsonb language plpgsql security definer set search_path = public, pg_temp
as $$
declare
  v_rev30 bigint; v_min30 bigint; v_exp30 bigint; v_rev_prev bigint; v_min_prev bigint;
  v_visits7 int; v_visits30 int; v_ret int; v_pri int; v_due int; v_over int; v_up int;
  v_clients int; v_standing int; v_rph numeric; v_prev_rph numeric;
begin
  select coalesce(sum(amount_collected_cents),0), coalesce(sum(actual_minutes),0)
    into v_rev30, v_min30 from public.visits where visited_at >= now() - interval '30 days';
  select coalesce(sum(amount_collected_cents),0), coalesce(sum(actual_minutes),0)
    into v_rev_prev, v_min_prev from public.visits
   where visited_at >= now() - interval '60 days' and visited_at < now() - interval '30 days';
  select coalesce(sum(amount_cents),0) into v_exp30 from public.expenses
   where is_business and txn_date >= (now() - interval '30 days')::date;
  select count(*) into v_visits7 from public.visits where visited_at >= now() - interval '7 days';
  select count(*) into v_visits30 from public.visits where visited_at >= now() - interval '30 days';
  select count(*) into v_ret from public.briefings where agent_key='retention' and status in ('new','read');
  select count(*) into v_pri from public.briefings where agent_key='pricing' and status in ('new','read');
  select count(*) filter (where active and renewal_date between current_date and current_date+45),
         count(*) filter (where active and renewal_date < current_date)
    into v_due, v_over from public.compliance_items;
  select count(*) into v_up from public.bath_appointments
   where status in ('requested','confirmed') and scheduled_start between now() and now()+interval '7 days';
  select count(*) into v_clients from public.clients where not exclude_from_everything;
  select count(*) into v_standing from public.clients where roster_group='standing';
  if v_min30>0 and v_rev30>0 then v_rph := round((v_rev30/100.0)/(v_min30/60.0),2); end if;
  if v_min_prev>0 and v_rev_prev>0 then v_prev_rph := round((v_rev_prev/100.0)/(v_min_prev/60.0),2); end if;

  return jsonb_build_object(
    'revenue_30d_cents', v_rev30, 'expenses_30d_cents', v_exp30, 'net_30d_cents', v_rev30 - v_exp30,
    'revenue_per_hour_30d', v_rph, 'prev_revenue_per_hour', v_prev_rph,
    'visits_last_7d', v_visits7, 'visits_last_30d', v_visits30,
    'retention_open_alerts', v_ret, 'pricing_open_alerts', v_pri,
    'compliance_due_soon', v_due, 'compliance_overdue', v_over,
    'upcoming_appointments_7d', v_up, 'total_clients', v_clients, 'standing_clients', v_standing);
end;
$$;
revoke all on function public.weekly_review_data() from public, authenticated, anon;
grant execute on function public.weekly_review_data() to service_role;

create or replace function public.weekly_review_save(
  p_title text, p_body text, p_severity text default 'info',
  p_evidence jsonb default null, p_model text default 'claude-sonnet-4-6', p_tokens integer default null
) returns uuid language plpgsql security definer set search_path = public, pg_temp
as $$
declare v_run uuid; v_brief uuid;
begin
  insert into public.agent_runs (agent_key, status, finished_at, model, tokens_used, input_summary)
  values ('chief_of_staff','ok',now(),p_model,p_tokens, jsonb_build_object('via','edge')) returning id into v_run;
  update public.briefings set status='read' where agent_key='chief_of_staff' and status='new';
  insert into public.briefings (agent_key, department, severity, title, body, evidence, run_id)
  values ('chief_of_staff','reports', coalesce(p_severity,'info'), p_title, p_body, p_evidence, v_run)
  returning id into v_brief;
  update public.agents set is_active=true, updated_at=now() where agent_key='chief_of_staff';
  return v_brief;
end;
$$;
revoke all on function public.weekly_review_save(text, text, text, jsonb, text, integer) from public, authenticated, anon;
grant execute on function public.weekly_review_save(text, text, text, jsonb, text, integer) to service_role;

create or replace function public.weekly_review_dispatch()
returns void language plpgsql security definer set search_path = public, pg_temp
as $$
declare v_secret text; v_base text;
begin
  select value into v_secret from public.app_secrets where name='cfo_cron_secret';
  select value into v_base   from public.app_secrets where name='edge_base_url';
  if v_secret is null or v_base is null then return; end if;
  perform net.http_post(
    url => v_base || '/weekly-review',
    headers => jsonb_build_object('Content-Type','application/json','x-cfo-secret', v_secret),
    body => jsonb_build_object('run', true),
    timeout_milliseconds => 20000);
end;
$$;
revoke all on function public.weekly_review_dispatch() from public, authenticated, anon;

select cron.schedule('weekly-review', '0 14 * * 1', 'select public.weekly_review_dispatch();')
  where not exists (select 1 from cron.job where jobname='weekly-review');
