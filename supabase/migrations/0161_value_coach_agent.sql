-- 0161: the Valuation coach (Paul, 2026-06-11): an agent whose whole job is
-- raising what the business would sell for. Weekly, it reads the same
-- valuation the Finance floor shows plus the levers behind it (recurring
-- share, growth, expense coverage, client concentration, receivables) and
-- cards Today with the two or three highest-leverage moves. Recommend only,
-- never act, like every department head.

-- The valuation core, callable by agents (no admin gate); the admin RPC
-- keeps its gate and now just wraps this.
create or replace function public._business_value()
returns jsonb
language plpgsql
security definer
set search_path to ''
as $$
declare
  v_ttm bigint; v_prev bigint; v_recurring bigint; v_expenses bigint;
  v_growth numeric; v_rs numeric; v_bump numeric;
  v_method text; v_low_mult numeric; v_high_mult numeric;
  v_base bigint;
begin
  select coalesce(sum(amount_collected_cents), 0) into v_ttm
    from public.visits where visited_at > now() - interval '365 days' and visited_at <= now();
  select coalesce(sum(amount_collected_cents), 0) into v_prev
    from public.visits where visited_at > now() - interval '730 days' and visited_at <= now() - interval '365 days';
  select coalesce(sum(v.amount_collected_cents), 0) into v_recurring
    from public.visits v join public.clients c on c.id = v.client_id
   where v.visited_at > now() - interval '365 days' and v.visited_at <= now()
     and c.cadence_days is not null;
  select coalesce(sum(amount_cents), 0) into v_expenses
    from public.expenses where is_business and txn_date > current_date - 365;

  v_growth := case when v_prev > 0 then (v_ttm - v_prev)::numeric / v_prev else null end;
  v_rs := case when v_ttm > 0 then least(1, v_recurring::numeric / v_ttm) else 0 end;
  v_bump := case when coalesce(v_growth, 0) >= 0.10 then 0.05
                 when coalesce(v_growth, 0) <= -0.10 then -0.05 else 0 end;

  if v_expenses >= v_ttm * 0.05 then
    v_method := 'sde';
    v_base := v_ttm - v_expenses;
    v_low_mult := 2.0 + 0.5 * v_rs + v_bump * 2;
    v_high_mult := 2.8 + 0.7 * v_rs + v_bump * 2;
  else
    v_method := 'revenue';
    v_base := v_ttm;
    v_low_mult := 0.50 + 0.20 * v_rs + v_bump;
    v_high_mult := 0.85 + 0.25 * v_rs + v_bump;
  end if;

  return jsonb_build_object(
    'value_low_cents', round(v_base * v_low_mult),
    'value_high_cents', round(v_base * v_high_mult),
    'method', v_method,
    'base_cents', v_base,
    'low_multiple', round(v_low_mult, 2),
    'high_multiple', round(v_high_mult, 2),
    'ttm_revenue_cents', v_ttm,
    'prev_ttm_revenue_cents', v_prev,
    'growth_pct', case when v_growth is null then null else round(v_growth * 100, 1) end,
    'recurring_share_pct', round(v_rs * 100),
    'expenses_ttm_cents', v_expenses);
end;
$$;
revoke all on function public._business_value() from public, anon, authenticated;
grant execute on function public._business_value() to service_role;

create or replace function public.admin_business_value()
returns jsonb
language plpgsql
security definer
set search_path to ''
as $$
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  return public._business_value();
end;
$$;
revoke all on function public.admin_business_value() from public, anon;
grant execute on function public.admin_business_value() to authenticated, service_role;

-- Everything the coach reasons over, one call.
create or replace function public.value_coach_data()
returns jsonb
language plpgsql
security definer
set search_path to ''
as $$
declare v jsonb; v_ttm bigint;
begin
  v := public._business_value();
  v_ttm := coalesce((v->>'ttm_revenue_cents')::bigint, 0);
  return v || jsonb_build_object(
    'top3_concentration_pct', case when v_ttm > 0 then (
      select round(coalesce(sum(c_total), 0)::numeric / v_ttm * 100) from (
        select sum(amount_collected_cents) as c_total
          from public.visits
         where visited_at > now() - interval '365 days' and client_id is not null
         group by client_id order by c_total desc limit 3) t) else null end,
    'active_clients_ttm', (select count(distinct client_id) from public.visits
                            where visited_at > now() - interval '365 days' and client_id is not null),
    'ar_open_count', (select count(*) from public.bath_appointments
                       where status = 'completed' and payment_status = 'pending'),
    'open_capacity_alerts', (select count(*) from public.briefings
                              where agent_key = 'capacity' and status in ('new','read')),
    'open_winback_cards', (select count(*) from public.briefings
                            where agent_key = 'winback' and status in ('new','read')));
end;
$$;
revoke all on function public.value_coach_data() from public, anon, authenticated;
grant execute on function public.value_coach_data() to service_role;

create or replace function public.value_coach_dispatch()
returns void
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $$
declare v_secret text; v_base text;
begin
  select value into v_secret from public.app_secrets where name = 'cfo_cron_secret';
  select value into v_base   from public.app_secrets where name = 'edge_base_url';
  if v_secret is null or v_base is null then return; end if;
  perform net.http_post(
    url     => v_base || '/value-coach',
    headers => jsonb_build_object('Content-Type','application/json','x-cfo-secret', v_secret),
    body    => '{}'::jsonb,
    timeout_milliseconds => 30000
  );
end;
$$;
revoke all on function public.value_coach_dispatch() from public, anon, authenticated;
grant execute on function public.value_coach_dispatch() to service_role;

insert into public.agents (agent_key, label, department, description, schedule_cron, is_active)
values ('value_coach', 'Valuation coach', 'finance',
        'Weekly: reads what the business is worth and the levers behind it, and cards the two or three highest-leverage moves to raise it. Recommends, never acts.',
        '30 14 * * 1', true)
on conflict (agent_key) do nothing;
select cron.schedule('value-coach-weekly', '30 14 * * 1', 'select public.value_coach_dispatch();');
