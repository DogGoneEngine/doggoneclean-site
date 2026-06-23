-- 0237_prospectus_two_client_kinds.sql
--
-- The prospectus contradicted itself: it reported "standing clients" off the
-- legacy clients.status column and "active recurring plans" off a raw count of
-- bath_subscriptions, two unrelated lists that drifted apart (a test plan, a
-- non-recurring plan, and a recurring client filed under a different status all
-- landed in the plan count but not the client count, so plans > clients).
--
-- Fix: there are exactly two kinds of client, recurring and on-demand, and that
-- truth already lives in the clean clients.client_type column (migration 0216).
-- Count the roster by client_type, restrict every number to the real current
-- book via clients.exclude_from_everything = false (which already marks banned,
-- deceased, moved-away, inactive, merged, and test records), and exclude test
-- subscribers from all visit-based money math. The words "standing", "one-off",
-- and "repeat client" are retired from the buyer-facing surface.

create or replace function public._business_value()
 returns jsonb
 language plpgsql
 security definer
 set search_path to ''
as $function$
declare
  v_ttm bigint; v_prev bigint; v_recurring bigint; v_expenses bigint;
  v_growth numeric; v_rs numeric; v_bump numeric;
  v_method text; v_low_mult numeric; v_high_mult numeric;
  v_base bigint;
begin
  -- trailing-12-month revenue, real book only (no test subscribers, no excluded clients)
  select coalesce(sum(v.amount_collected_cents), 0) into v_ttm
    from public.visits v
    left join public.clients c on c.id = v.client_id
    left join public.bath_subscribers s on s.id = v.subscriber_id
   where v.visited_at > now() - interval '365 days' and v.visited_at <= now()
     and coalesce(c.exclude_from_everything, false) = false
     and coalesce(s.is_test, false) = false;

  -- the prior 12 months on the same basis, for the growth read
  select coalesce(sum(v.amount_collected_cents), 0) into v_prev
    from public.visits v
    left join public.clients c on c.id = v.client_id
    left join public.bath_subscribers s on s.id = v.subscriber_id
   where v.visited_at > now() - interval '730 days' and v.visited_at <= now() - interval '365 days'
     and coalesce(c.exclude_from_everything, false) = false
     and coalesce(s.is_test, false) = false;

  -- recurring share uses the clean client_type column, the same definition the
  -- rest of the app uses, not a cadence_days proxy
  select coalesce(sum(v.amount_collected_cents), 0) into v_recurring
    from public.visits v
    join public.clients c on c.id = v.client_id
    left join public.bath_subscribers s on s.id = v.subscriber_id
   where v.visited_at > now() - interval '365 days' and v.visited_at <= now()
     and coalesce(c.exclude_from_everything, false) = false
     and coalesce(s.is_test, false) = false
     and c.client_type = 'recurring';

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
$function$;

create or replace function public.admin_prospectus()
 returns jsonb
 language plpgsql
 security definer
 set search_path to ''
as $function$
declare v jsonb;
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;

  v := public.admin_business_value();

  return jsonb_build_object(
    'value', v,
    'generated_at', now(),
    'book', (
      with realvisits as (
        select v2.client_id, v2.visited_at
          from public.visits v2
          left join public.clients c on c.id = v2.client_id
          left join public.bath_subscribers s on s.id = v2.subscriber_id
         where coalesce(c.exclude_from_everything, false) = false
           and coalesce(s.is_test, false) = false
      ),
      tenure as (
        select client_id, min(visited_at) as first_v, max(visited_at) as last_v
          from realvisits where client_id is not null
         group by client_id having count(*) >= 3
      )
      select jsonb_build_object(
        'total_visits', (select count(*) from realvisits),
        'first_visit', (select min(visited_at)::date from realvisits),
        'recurring_clients', (select count(*) from public.clients
           where client_type = 'recurring' and coalesce(exclude_from_everything, false) = false),
        'on_demand_clients', (select count(*) from public.clients
           where client_type = 'on_demand' and coalesce(exclude_from_everything, false) = false),
        'avg_tenure_years', (select round((avg(extract(epoch from (last_v - first_v)) / 31557600.0))::numeric, 1) from tenure),
        'max_tenure_years', (select round((max(extract(epoch from (last_v - first_v)) / 31557600.0))::numeric, 1) from tenure)
      )
    ),
    'money', (
      with rv as (
        select v2.amount_collected_cents, v2.actual_minutes, v2.tip_cents
          from public.visits v2
          left join public.clients c on c.id = v2.client_id
          left join public.bath_subscribers s on s.id = v2.subscriber_id
         where v2.visited_at > now() - interval '365 days' and v2.visited_at <= now()
           and coalesce(c.exclude_from_everything, false) = false
           and coalesce(s.is_test, false) = false
      )
      select jsonb_build_object(
        'median_visit_cents', (
          select round(percentile_cont(0.5) within group (order by amount_collected_cents))::bigint
            from rv where amount_collected_cents > 0),
        'earned_per_hour_cents', (
          select round(sum(amount_collected_cents)::numeric / nullif(sum(actual_minutes), 0) * 60)::bigint
            from rv where coalesce(actual_minutes, 0) > 0 and coalesce(amount_collected_cents, 0) > 0),
        'avg_on_site_min', (
          select round(avg(actual_minutes))::int from rv where coalesce(actual_minutes, 0) > 0),
        'tips_ttm_cents', (
          select coalesce(sum(tip_cents), 0) from rv)
      )
    ),
    'machine', (
      select jsonb_build_object(
        'active_agents', (select count(*) from public.agents where is_active),
        'briefings_on_record', (select count(*) from public.briefings),
        'riker_parses', (select count(*) from public.riker_log),
        'wisdom_entries', (select count(*) from public.wisdom),
        'client_records', (select count(*) from public.clients where coalesce(exclude_from_everything, false) = false),
        'dog_records', (select count(*) from public.dogs),
        'tracked_visits', (
          select count(*) from public.visits v2
            left join public.clients c on c.id = v2.client_id
            left join public.bath_subscribers s on s.id = v2.subscriber_id
           where v2.arrived_at is not null
             and coalesce(c.exclude_from_everything, false) = false
             and coalesce(s.is_test, false) = false),
        'notifications_sent', (select count(*) from public.notification_log where status = 'sent')
      )
    ),
    'agents_list', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'label', label, 'department', department, 'description', description) order by label), '[]'::jsonb)
      from public.agents where is_active
    ),
    'fleet', (
      select jsonb_build_object(
        'equipment_items', (select count(*) from public.equipment where active),
        'generators', (select count(*) from public.equipment where active and kind = 'generator'),
        'hour_tracked', (select count(*) from public.equipment where active and track_hours),
        'maintenance_tasks', (select count(*) from public.maintenance_tasks where active),
        'equipment_names', (select coalesce(jsonb_agg(name order by name), '[]'::jsonb) from public.equipment where active)
      )
    )
  );
end;
$function$;
