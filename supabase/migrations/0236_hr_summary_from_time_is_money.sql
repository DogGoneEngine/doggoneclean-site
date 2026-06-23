-- 0236_hr_summary_from_time_is_money.sql
--
-- Point the HR floor at the Time is Money sheet, the actual source of truth, not
-- a recomputation from the app's visit rows. Paul kept his master sheet running
-- with the real arrival/departure on every stop, including visits the app logged
-- without a clock time. Reading the raw visits table threw those away and read
-- low; the ledger has them all.
--
-- Same union the Reports ledger uses (_time_is_money_ledger): the frozen master
-- history through 2026-06-13, plus live visits after the cutover, in the master's
-- own columns. Hands-on per day = Appointment Duration (arrival to departure).
-- Door-to-door per day = Cycle Time (heading-there to departure). Both are summed
-- per day and averaged over the days that have them. Revenue is the sheet's Paid
-- column. Durations are parsed from the sheet's H:MM:SS text; nothing is invented.
create or replace function public.admin_hr_summary(p_window_days integer default 30)
returns jsonb language plpgsql security definer set search_path = public, pg_temp
as $$
declare
  v_visits int; v_revenue_cents bigint; v_untimed int;
  v_handson_days int; v_handson_hrs numeric;
  v_door_days int; v_door_hrs numeric; v_clocked_visits int;
  v_busiest jsonb;
  v_since date := (now() at time zone 'America/New_York')::date - p_window_days;
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;

  with led as (
    -- Frozen master history through the 2026-06-13 cutover.
    select sort_date as day, client,
      case when duration ~ '^[0-9]+:[0-9]{2}:[0-9]{2}$' then
        split_part(duration,':',1)::numeric*60 + split_part(duration,':',2)::numeric + split_part(duration,':',3)::numeric/60.0 end as dur_min,
      case when cycle_time ~ '^[0-9]+:[0-9]{2}:[0-9]{2}$' then
        split_part(cycle_time,':',1)::numeric*60 + split_part(cycle_time,':',2)::numeric + split_part(cycle_time,':',3)::numeric/60.0 end as cyc_min,
      nullif(regexp_replace(coalesce(paid,''),'[^0-9.]','','g'),'')::numeric as paid_d
    from public.time_is_money_history
    where sort_date >= v_since
    union all
    -- Live visits after the cutover, in the same shape.
    select (v.visited_at at time zone 'America/New_York')::date as day, coalesce(c.name,''),
      case when v.departed_at > v.arrived_at then extract(epoch from (v.departed_at - v.arrived_at))/60.0 end,
      case when v.inbound_at is not null and v.departed_at > v.inbound_at then extract(epoch from (v.departed_at - v.inbound_at))/60.0 end,
      v.amount_collected_cents/100.0
    from public.visits v
    left join public.clients c on c.id = v.client_id
    where v.arrived_at is not null
      and (v.visited_at at time zone 'America/New_York')::date > date '2026-06-13'
      and v.visited_at <= now()
  ),
  per_day as (
    select day,
      sum(dur_min) d_hands, sum(cyc_min) d_door,
      count(*) filter (where dur_min is not null) n_timed,
      count(*) n
    from led group by day
  )
  select
    (select count(*) from led),
    coalesce((select round(sum(paid_d)*100)::bigint from led),0),
    (select count(*) from led where dur_min is null),
    (select count(*) from per_day where d_hands is not null),
    coalesce((select sum(d_hands) from per_day),0)/60.0,
    (select count(*) from per_day where d_door is not null),
    coalesce((select sum(d_door) from per_day),0)/60.0,
    coalesce((select sum(n_timed) from per_day where d_hands is not null),0)
  into v_visits, v_revenue_cents, v_untimed,
       v_handson_days, v_handson_hrs, v_door_days, v_door_hrs, v_clocked_visits;

  select jsonb_build_object('date', to_char(day,'Mon DD'), 'hours', round(d_hands/60.0,1), 'visits', n)
    into v_busiest
    from per_day where d_hands is not null order by d_hands desc limit 1;

  return jsonb_build_object(
    'window_days', p_window_days, 'visits', v_visits,
    'hours', round(v_handson_hrs,1), 'work_days', v_handson_days,
    'avg_hours_per_workday', case when v_handson_days>0 then round(v_handson_hrs/v_handson_days,1) end,
    'avg_hands_on_per_workday', case when v_handson_days>0 then round(v_handson_hrs/v_handson_days,1) end,
    'avg_visits_per_workday', case when v_handson_days>0 then round(v_clocked_visits::numeric/v_handson_days,1) end,
    'door_to_door_days', v_door_days,
    'avg_door_to_door_per_workday', case when v_door_days>0 then round(v_door_hrs/v_door_days,1) end,
    'untimed_visits', v_untimed,
    'revenue', v_revenue_cents, 'busiest_day', v_busiest);
end;
$$;
revoke all on function public.admin_hr_summary(integer) from public;
grant execute on function public.admin_hr_summary(integer) to authenticated;
