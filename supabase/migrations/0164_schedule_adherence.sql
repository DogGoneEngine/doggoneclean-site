-- 0164: Schedule adherence becomes a first-class metric
-- (schedule_adherence_is_a_main_metric). Paul plans the day on the calendar
-- and the Time is Money sheet records what actually happened; the gap
-- between the two is the metric he tracks like cycle time. Going forward
-- the app already captures both halves on its own: bath_appointments holds
-- scheduled_start (the plan) and the tracker stamps visits.arrived_at and
-- departed_at (the reality). This RPC derives the adherence picture from
-- those rows so it needs no new capture and survives any redesign.
--
-- delta_min is signed: positive = arrived late, negative = early.
-- stop_order is the visit's position in its local (Eastern) day, because
-- the interesting failure mode is slippage that accumulates stop by stop.
--
-- Applied to dgc-prod 2026-06-12.

create or replace function public.admin_schedule_adherence(p_days int default 90)
returns jsonb language plpgsql security definer set search_path to ''
as $$
declare result jsonb;
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;

  with base as (
    select vi.id,
           vi.arrived_at,
           vi.departed_at,
           a.scheduled_start,
           coalesce(c.name, nullif(btrim(coalesce(s.first_name, '') || ' ' || coalesce(s.last_name, '')), '')) as client_name,
           (vi.arrived_at at time zone 'America/New_York')::date as day_local,
           round(extract(epoch from (vi.arrived_at - a.scheduled_start)) / 60.0)::int as delta_min
      from public.visits vi
      join public.bath_appointments a on a.id = vi.appointment_id
      left join public.clients c on c.id = vi.client_id
      left join public.bath_subscribers s on s.id = vi.subscriber_id
     where vi.arrived_at is not null
       and a.scheduled_start is not null
       and vi.arrived_at >= now() - make_interval(days => p_days)
  ), ordered as (
    select b.*, row_number() over (partition by b.day_local order by b.scheduled_start) as stop_order
      from base b
  )
  select jsonb_build_object(
    'days', p_days,
    'n', (select count(*) from ordered),
    'mean_delta_min', (select round(avg(delta_min))::int from ordered),
    'median_delta_min', (select round(percentile_cont(0.5) within group (order by delta_min))::int from ordered),
    'p90_delta_min', (select round(percentile_cont(0.9) within group (order by delta_min))::int from ordered),
    'on_time_5_pct', (select round(100.0 * count(*) filter (where delta_min <= 5) / nullif(count(*), 0))::int from ordered),
    'on_time_15_pct', (select round(100.0 * count(*) filter (where delta_min <= 15) / nullif(count(*), 0))::int from ordered),
    'late_30_pct', (select round(100.0 * count(*) filter (where delta_min > 30) / nullif(count(*), 0))::int from ordered),
    'early_15_pct', (select round(100.0 * count(*) filter (where delta_min < -15) / nullif(count(*), 0))::int from ordered),
    'drift_by_stop', (
      select coalesce(jsonb_agg(d order by d->>'stop'), '[]'::jsonb) from (
        select jsonb_build_object(
          'stop', case when least(stop_order, 4) = 4 then '4+' else least(stop_order, 4)::text end,
          'n', count(*),
          'mean_delta_min', round(avg(delta_min))::int
        ) as d
        from ordered
        group by least(stop_order, 4)
      ) drift
    ),
    'recent', (
      select coalesce(jsonb_agg(r), '[]'::jsonb) from (
        select jsonb_build_object(
          'day', day_local,
          'client', client_name,
          'scheduled_start', scheduled_start,
          'arrived_at', arrived_at,
          'delta_min', delta_min,
          'stop_order', stop_order
        ) as r
        from ordered
        order by arrived_at desc
        limit 30
      ) recents
    )
  ) into result;

  return result;
end;
$$;
revoke all on function public.admin_schedule_adherence(int) from public, anon;
grant execute on function public.admin_schedule_adherence(int) to authenticated, service_role;
