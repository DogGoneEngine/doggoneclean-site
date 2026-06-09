-- 0069_hr_workload.sql
-- HR floor: for a solo operator, the honest content is the workload, computed
-- from real visit data and tied to the prime directive (earn more, grind less).
-- Scales to a team roster when Paul hires.
create or replace function public.admin_hr_summary(p_window_days integer default 30)
returns jsonb language plpgsql security definer set search_path = public, pg_temp
as $$
declare v_visits int; v_minutes bigint; v_workdays int; v_revenue bigint; v_busiest jsonb;
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  select count(*), coalesce(sum(actual_minutes),0), count(distinct visited_at::date), coalesce(sum(amount_collected_cents),0)
    into v_visits, v_minutes, v_workdays, v_revenue
    from public.visits where visited_at >= now() - make_interval(days => p_window_days);
  select jsonb_build_object('date', to_char(d,'Mon DD'), 'hours', round(mins/60.0,1), 'visits', n)
    into v_busiest from (
      select visited_at::date d, sum(actual_minutes) mins, count(*) n from public.visits
       where visited_at >= now() - make_interval(days => p_window_days)
       group by 1 order by mins desc nulls last limit 1) b;
  return jsonb_build_object(
    'window_days', p_window_days, 'visits', v_visits,
    'hours', round(v_minutes/60.0,1), 'work_days', v_workdays,
    'avg_hours_per_workday', case when v_workdays>0 then round((v_minutes/60.0)/v_workdays,1) end,
    'avg_visits_per_workday', case when v_workdays>0 then round(v_visits::numeric/v_workdays,1) end,
    'revenue', v_revenue, 'busiest_day', v_busiest);
end;
$$;
revoke all on function public.admin_hr_summary(integer) from public;
grant execute on function public.admin_hr_summary(integer) to authenticated;
