-- 0200: fix the weekly money number, add the "ran past the block" metric (Paul 2026-06-18).
--
-- (1) Weekly money was summing bath_appointments.amount_cents, which is 0 on the
--     whole legacy/calendar-synced full-groom book (price was never stamped on
--     the appointment row; it lives on each dog as dogs.price_cents). So the
--     pager showed near-zero "random" numbers (only the odd nails appointment
--     carried a price). The real expected price of an appointment is: the row's
--     amount_cents when it was set by the booking flow, else the sum of the
--     prices of the dogs actually on it (the assigned dog_ids, or the client's
--     active dogs when no list is pinned). clean_appt_price_cents centralises
--     that so every forward-looking money view uses one definition.
--
-- (2) Adherence gains finished_after_block_pct: of the stops that have both a
--     block end and a departed stamp, how many WRAPPED AFTER the block ended
--     (the overrun rate Paul watches, the complement of finished-in-block).
--
-- Applied to dgc-prod 2026-06-18.

-- (1) One definition of an appointment's expected price.
create or replace function public.clean_appt_price_cents(p_amount int, p_dog_ids uuid[], p_subscriber uuid)
returns int
language sql
stable
security definer
set search_path to ''
as $$
  select case
    when coalesce(p_amount, 0) > 0 then p_amount
    else coalesce(
      case
        when p_dog_ids is not null and array_length(p_dog_ids, 1) > 0
          then (select sum(d.price_cents)::int from public.dogs d where d.id = any(p_dog_ids))
        else (select sum(d.price_cents)::int
                from public.dogs d
                join public.bath_subscribers s on s.id = p_subscriber
               where d.client_id = s.client_id
                 and coalesce(d.roster_status, 'regular') in ('regular', 'occasional'))
      end, 0)
  end;
$$;
revoke all on function public.clean_appt_price_cents(int, uuid[], uuid) from public, anon;
grant execute on function public.clean_appt_price_cents(int, uuid[], uuid) to authenticated, service_role;

create or replace function public.admin_weekly_money(p_back int default 12, p_fwd int default 12)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $$
declare
  v_today  date := (now() at time zone 'America/New_York')::date;
  v_monday date := date_trunc('week', v_today::timestamp)::date;
  v_weeks  jsonb;
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;

  select coalesce(jsonb_agg(to_jsonb(w) order by w.wk_offset), '[]'::jsonb) into v_weeks
  from (
    select
      gs as wk_offset,
      (v_monday + gs * 7)::date            as week_start,
      (v_monday + gs * 7 + 5)::date         as week_sat,
      ((v_monday + gs * 7 + 5) < v_today)   as is_past,
      case when (v_monday + gs * 7 + 5) < v_today then 'collected' else 'booked' end as basis,
      -- Past weeks: what was actually collected (visits). Current/future: the
      -- booked plan, priced from the dogs on each appointment.
      case when (v_monday + gs * 7 + 5) < v_today then
        coalesce((select sum(v.amount_collected_cents)
                    from public.visits v
                   where (v.visited_at at time zone 'America/New_York')::date
                         between (v_monday + gs * 7) and (v_monday + gs * 7 + 5)), 0)
      else
        coalesce((select sum(public.clean_appt_price_cents(a.amount_cents, a.dog_ids, a.subscriber_id))
                    from public.bath_appointments a
                   where (a.scheduled_start at time zone 'America/New_York')::date
                         between (v_monday + gs * 7) and (v_monday + gs * 7 + 5)
                     and a.status not in ('cancelled', 'no_show', 'skipped', 'tentative')), 0)
      end as amount_cents,
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
      -- Pencilled (tentative) money, priced the same way.
      coalesce((select sum(public.clean_appt_price_cents(a.amount_cents, a.dog_ids, a.subscriber_id))
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

-- (2) Adherence + the overrun number. Rebuilt from 0199, adding finished_after_block_pct.
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
    'block_n', (select count(*) from ordered where block_end is not null),
    'started_in_block_pct', (
      select round(100.0 * count(*) filter (where block_end is not null and arrived_at <= block_end)
             / nullif(count(*) filter (where block_end is not null), 0))::int from ordered),
    'finished_n', (select count(*) from ordered where block_end is not null and departed_at is not null),
    'finished_in_block_pct', (
      select round(100.0 * count(*) filter (where block_end is not null and departed_at is not null and departed_at <= block_end)
             / nullif(count(*) filter (where block_end is not null and departed_at is not null), 0))::int from ordered),
    'finished_after_block_pct', (
      select round(100.0 * count(*) filter (where block_end is not null and departed_at is not null and departed_at > block_end)
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
