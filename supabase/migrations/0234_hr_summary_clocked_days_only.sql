-- 0234_hr_summary_clocked_days_only.sql
-- HR floor honesty fix. The per-workday average was diluted two ways during the
-- cutover: (1) visits that came over without a start/stop clock reading still made
-- their date count as a full "work day" worth ~0 hours, and (2) a stray visit dated
-- a year in the future added an empty work day. Both dragged avg_hours_per_workday
-- far below the real number.
--
-- Fix: never count a future-dated row, and base the per-workday math only on days
-- that were actually clocked (at least one visit with recorded minutes). Days with
-- no recorded time are a measurement gap, not a zero-hour workday, so they no longer
-- pull the average down. We never invent the missing minutes (real data only); the
-- figure converges on the true workload as visits get clocked start-to-finish.
create or replace function public.admin_hr_summary(p_window_days integer default 30)
returns jsonb language plpgsql security definer set search_path = public, pg_temp
as $$
declare
  v_visits int; v_minutes bigint; v_revenue bigint;
  v_workdays int; v_clocked_visits int; v_busiest jsonb;
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;

  -- Headline totals over the window. A completed visit can never be in the future,
  -- so a future-dated row is bad data and is excluded everywhere.
  select count(*), coalesce(sum(actual_minutes),0), coalesce(sum(amount_collected_cents),0)
    into v_visits, v_minutes, v_revenue
    from public.visits
   where visited_at >= now() - make_interval(days => p_window_days)
     and visited_at <= now();

  -- Per-workday math: only days with at least one clocked visit count as work days,
  -- and only the visits on those days feed the per-day visit count.
  with clocked_days as (
    select visited_at::date as d
      from public.visits
     where visited_at >= now() - make_interval(days => p_window_days)
       and visited_at <= now()
       and actual_minutes > 0
     group by 1
  )
  select count(*),
         coalesce((
           select count(*) from public.visits v
            where v.visited_at::date in (select d from clocked_days)
              and v.visited_at >= now() - make_interval(days => p_window_days)
              and v.visited_at <= now()
         ),0)
    into v_workdays, v_clocked_visits
    from clocked_days;

  select jsonb_build_object('date', to_char(d,'Mon DD'), 'hours', round(mins/60.0,1), 'visits', n)
    into v_busiest from (
      select visited_at::date d, sum(actual_minutes) mins, count(*) n from public.visits
       where visited_at >= now() - make_interval(days => p_window_days)
         and visited_at <= now()
         and actual_minutes > 0
       group by 1 order by mins desc nulls last limit 1) b;

  return jsonb_build_object(
    'window_days', p_window_days, 'visits', v_visits,
    'hours', round(v_minutes/60.0,1), 'work_days', v_workdays,
    'avg_hours_per_workday', case when v_workdays>0 then round((v_minutes/60.0)/v_workdays,1) end,
    'avg_visits_per_workday', case when v_workdays>0 then round(v_clocked_visits::numeric/v_workdays,1) end,
    'revenue', v_revenue, 'busiest_day', v_busiest);
end;
$$;
revoke all on function public.admin_hr_summary(integer) from public;
grant execute on function public.admin_hr_summary(integer) to authenticated;
