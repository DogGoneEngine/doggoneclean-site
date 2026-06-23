-- 0238_prospectus_dog_records_live_book.sql
--
-- Consistency follow-up to 0237. The prospectus now counts client_records on
-- the live book (exclude_from_everything = false), but dog_records still counted
-- every dog row including dogs belonging to excluded clients (deceased, moved
-- away, merged, test). That left "85 client records" sitting next to "153 dog
-- records" on two different bases. Count dogs on the same live-book basis so the
-- two numbers describe the same set of clients.

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
        'dog_records', (select count(*) from public.dogs d
           join public.clients c on c.id = d.client_id
          where coalesce(c.exclude_from_everything, false) = false),
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
