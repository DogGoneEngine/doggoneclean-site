-- 0199: two reporting numbers Paul asked for (2026-06-18).
--
-- (1) Started-and-finished-inside-the-block adherence. The On-schedule panel
--     already tracks ARRIVAL versus the plan (admin_schedule_adherence). Paul
--     also wants to know how often a visit both STARTED and FINISHED inside its
--     appointment block. The block end is bath_appointments.scheduled_end (the
--     adaptive block from 0153; 0021 backfilled any nulls and every booking path
--     sets it). Started-in-block = arrived_at on or before scheduled_end;
--     finished-in-block = departed_at on or before scheduled_end. No new tapping:
--     the tracker already stamps arrived_at and departed_at, and the block is on
--     the appointment. Survives a redesign because the teeth are these stamps.
--
-- (2) Weekly money pager (admin_weekly_money). "How much will I make this week,
--     next week, the week after; how much last week, the week before." A week is
--     Monday through the end of Saturday, local Eastern (Sunday is excluded; the
--     book does not run Sundays). Future and current weeks show the booked plan
--     (appointment prices, anything not cancelled/no-show/skipped/pencilled),
--     past weeks show what was actually collected (visit amounts). Pencilled
--     (tentative) money rides along as a separate number so the headline stays
--     honest. Returns a band of weeks so the Finance pager can page with no
--     refetch. Lives in Finance (Paul, 2026-06-18).
--
-- Applied to dgc-prod 2026-06-18.

-- (1) Adherence + block fit. Rebuilt from the 0165 definition, adding scheduled_end
--     to the base rows and four block-fit fields to the result.
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
           a.scheduled_end as block_end,
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
    -- Block fit: of the stops whose appointment carries a block end, how many
    -- started (arrived) and finished (departed) inside it.
    'block_n', (select count(*) from ordered where block_end is not null),
    'started_in_block_pct', (
      select round(100.0 * count(*) filter (where block_end is not null and arrived_at <= block_end)
             / nullif(count(*) filter (where block_end is not null), 0))::int from ordered),
    'finished_n', (select count(*) from ordered where block_end is not null and departed_at is not null),
    'finished_in_block_pct', (
      select round(100.0 * count(*) filter (where block_end is not null and departed_at is not null and departed_at <= block_end)
             / nullif(count(*) filter (where block_end is not null and departed_at is not null), 0))::int from ordered),
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
    ),
    'baseline', (
      select case when count(*) = 0 then null else jsonb_build_object(
        'n', count(*),
        'first_day', min(day),
        'last_day', max(day),
        'mean_delta_min', round(avg(delta_min))::int,
        'median_delta_min', round(percentile_cont(0.5) within group (order by delta_min))::int,
        'on_time_15_pct', round(100.0 * count(*) filter (where delta_min <= 15) / count(*))::int,
        'by_year', (
          select jsonb_agg(y order by y->>'year') from (
            select jsonb_build_object(
              'year', extract(year from day)::int,
              'n', count(*),
              'median_delta_min', round(percentile_cont(0.5) within group (order by delta_min))::int
            ) as y
            from public.schedule_adherence_history
            group by extract(year from day)
          ) years
        )
      ) end
      from public.schedule_adherence_history
    )
  ) into result;

  return result;
end;
$$;
revoke all on function public.admin_schedule_adherence(int) from public, anon;
grant execute on function public.admin_schedule_adherence(int) to authenticated, service_role;

-- (2) Weekly money pager. p_back / p_fwd are how many weeks each way to return,
--     centred on the current Monday-Saturday week (offset 0).
create or replace function public.admin_weekly_money(p_back int default 12, p_fwd int default 12)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $$
declare
  v_today  date := (now() at time zone 'America/New_York')::date;
  v_monday date := date_trunc('week', v_today::timestamp)::date;  -- Monday of the current ISO week
  v_weeks  jsonb;
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;

  select coalesce(jsonb_agg(to_jsonb(w) order by w.wk_offset), '[]'::jsonb) into v_weeks
  from (
    select
      gs as wk_offset,
      (v_monday + gs * 7)::date            as week_start,   -- Monday
      (v_monday + gs * 7 + 5)::date         as week_sat,     -- Saturday
      ((v_monday + gs * 7 + 5) < v_today)   as is_past,
      case when (v_monday + gs * 7 + 5) < v_today then 'collected' else 'booked' end as basis,
      -- Money: past weeks = collected (visits), current/future = booked plan
      -- (appointments not cancelled / no-show / skipped / pencilled).
      case when (v_monday + gs * 7 + 5) < v_today then
        coalesce((select sum(v.amount_collected_cents)
                    from public.visits v
                   where (v.visited_at at time zone 'America/New_York')::date
                         between (v_monday + gs * 7) and (v_monday + gs * 7 + 5)), 0)
      else
        coalesce((select sum(a.amount_cents)
                    from public.bath_appointments a
                   where (a.scheduled_start at time zone 'America/New_York')::date
                         between (v_monday + gs * 7) and (v_monday + gs * 7 + 5)
                     and a.status not in ('cancelled', 'no_show', 'skipped', 'tentative')), 0)
      end as amount_cents,
      -- Stop count behind the number.
      case when (v_monday + gs * 7 + 5) < v_today then
        (select count(*) from public.visits v
          where (v.visited_at at time zone 'America/New_York')::date
                between (v_monday + gs * 7) and (v_monday + gs * 7 + 5))
      else
        (select count(*) from public.bath_appointments a
          where (a.scheduled_start at time zone 'America/New_York')::date
                between (v_monday + gs * 7) and (v_monday + gs * 7 + 5)
            and a.status not in ('cancelled', 'no_show', 'skipped', 'tentative'))
      end as stops,
      -- Pencilled (tentative) money on the books for the week, shown separately.
      coalesce((select sum(a.amount_cents)
                  from public.bath_appointments a
                 where (a.scheduled_start at time zone 'America/New_York')::date
                       between (v_monday + gs * 7) and (v_monday + gs * 7 + 5)
                   and a.status = 'tentative'), 0) as tentative_cents
    from generate_series(-p_back, p_fwd) gs
  ) w;

  return jsonb_build_object(
    'today', v_today,
    'this_monday', v_monday,
    'weeks', v_weeks
  );
end;
$$;
revoke all on function public.admin_weekly_money(int, int) from public, anon;
grant execute on function public.admin_weekly_money(int, int) to authenticated, service_role;
