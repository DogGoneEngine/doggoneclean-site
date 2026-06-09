-- 0053_settings_and_audit.sql
-- Settings (system status / integrations) and Audit (the append-only record of
-- every AI run and recommendation). Read-only views over existing data; secret
-- names only are ever returned, never values.

create or replace function public.admin_system_status()
returns jsonb language plpgsql security definer set search_path = public, pg_temp
as $$
declare v_secrets jsonb; v_agents jsonb; v_crons jsonb; v_me jsonb; v_counts jsonb;
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  select coalesce(jsonb_agg(name order by name), '[]'::jsonb) into v_secrets from public.app_secrets;
  select coalesce(jsonb_agg(jsonb_build_object(
      'label', label, 'department', department, 'is_active', is_active, 'schedule_cron', schedule_cron,
      'last_run', (select max(started_at) from public.agent_runs r where r.agent_key = a.agent_key)) order by label), '[]'::jsonb)
    into v_agents from public.agents a;
  select coalesce(jsonb_agg(jsonb_build_object('job', jobname, 'schedule', schedule, 'active', active) order by jobname), '[]'::jsonb)
    into v_crons from cron.job;
  select jsonb_build_object('email', email, 'name', first_name) into v_me from public.admins where auth_user_id = auth.uid();
  v_counts := jsonb_build_object(
    'clients', (select count(*) from public.clients),
    'visits', (select count(*) from public.visits),
    'expenses', (select count(*) from public.expenses),
    'recurring_costs', (select count(*) from public.recurring_costs),
    'compliance_items', (select count(*) from public.compliance_items));
  return jsonb_build_object('secrets', v_secrets, 'agents', v_agents, 'crons', v_crons, 'me', v_me, 'counts', v_counts);
end;
$$;
revoke all on function public.admin_system_status() from public;
grant execute on function public.admin_system_status() to authenticated;

create or replace function public.admin_audit_feed(p_limit integer default 60)
returns jsonb language plpgsql security definer set search_path = public, pg_temp
as $$
declare v_runs jsonb; v_briefs jsonb; v_admins jsonb;
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  select coalesce(jsonb_agg(jsonb_build_object(
      'agent_key', agent_key, 'status', status, 'started_at', started_at, 'finished_at', finished_at,
      'model', model, 'tokens', tokens_used) order by started_at desc), '[]'::jsonb)
    into v_runs from (select * from public.agent_runs order by started_at desc limit greatest(1, least(p_limit, 200))) r;
  select coalesce(jsonb_agg(jsonb_build_object(
      'agent_key', agent_key, 'department', department, 'severity', severity, 'title', title,
      'status', status, 'created_at', created_at) order by created_at desc), '[]'::jsonb)
    into v_briefs from (select * from public.briefings order by created_at desc limit greatest(1, least(p_limit, 200))) b;
  select coalesce(jsonb_agg(jsonb_build_object('email', email, 'name', first_name, 'active', is_active) order by email), '[]'::jsonb)
    into v_admins from public.admins;
  return jsonb_build_object('runs', v_runs, 'briefings', v_briefs, 'admins', v_admins);
end;
$$;
revoke all on function public.admin_audit_feed(integer) from public;
grant execute on function public.admin_audit_feed(integer) to authenticated;
