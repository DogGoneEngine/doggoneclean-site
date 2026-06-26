-- 0256_operator_horizon_reaches_cadence.sql
--
-- 0255 fixed the suggester's window math, but exposed the deeper wall: every
-- city carries hb_booking_horizon_days = 60, and bath_open_slots refuses to
-- generate any open time past that horizon. Koerner's cadence is 98 days, so her
-- next visit is due in October, ~112 days out, with zero generated availability
-- to land on. The window pointed at the right month; the month was empty.
--
-- The 60-day horizon is the PUBLIC guardrail: how far ahead a cold visitor or a
-- client can self-book. That stays. What must change is that the OPERATOR booking
-- a standing client's next regular visit has to reach that client's real cadence,
-- even when it is past the public horizon. So the horizon becomes overridable,
-- and only the operator doors pass the override:
--
--   * bath_open_slots gains an optional p_horizon_days. Default null keeps the
--     city's 60-day horizon, so the public /book funnel and the client portal are
--     completely unchanged.
--   * The shared suggester core gains p_extend_horizon. The operator door
--     (admin_suggest_slots) passes true and reaches exactly as far as the client's
--     due date needs; the client door (bath_suggest_slots) passes false and stays
--     inside the 60-day policy, falling back to the soonest open times if a
--     client's own cadence date sits beyond what they may self-book.
--   * admin_open_slots (the operator's "More options" specific-day flow) passes
--     the override too, so forcing a specific October day works as well.
--
-- Net: the operator can book any standing client at their true cadence; the
-- public-facing booking distance is untouched. Whether clients should be allowed
-- to self-book further than 60 days is a separate business call, left to Paul.

-- ── bath_open_slots: optional horizon override (default = city policy) ──
drop function if exists public.bath_open_slots(uuid, timestamptz, timestamptz, integer);

create function public.bath_open_slots(
  p_city_id uuid,
  p_from timestamp with time zone,
  p_to timestamp with time zone,
  p_duration_minutes integer default null,
  p_horizon_days integer default null)
 returns table(slot_start timestamp with time zone, slot_end timestamp with time zone)
 language plpgsql
 stable security definer
 set search_path to ''
as $function$
declare
  v_city_slot integer;
  v_horizon   integer;
  v_tz        text;
  v_anchor    date;
  v_from      timestamptz;
  v_to        timestamptz;
  v_len       interval;
  v_grid      interval := interval '15 minutes';
begin
  select hb_slot_minutes, hb_booking_horizon_days, hb_timezone, hb_week_parity_anchor
    into v_city_slot, v_horizon, v_tz, v_anchor
    from public.cities where id = p_city_id;
  if not found or v_tz is null then
    raise exception 'city % is not configured for scheduling', p_city_id;
  end if;

  if p_duration_minutes is not null then
    v_len := make_interval(mins => p_duration_minutes);
  elsif v_city_slot is not null then
    v_len := make_interval(mins => v_city_slot);
  else
    return;
  end if;

  -- An explicit p_horizon_days extends (or sets) the booking horizon. Null keeps
  -- the city's public policy. Only the operator-side callers pass it.
  v_from := greatest(p_from, now());
  v_to   := least(p_to, now() + make_interval(days => coalesce(p_horizon_days, v_horizon)));
  if v_from >= v_to then
    return;
  end if;

  return query
  with days as (
    select d::date as day
    from generate_series(v_from at time zone v_tz, v_to at time zone v_tz, interval '1 day') as d
  ),
  recurring as (
    select days.day, w.start_time, w.end_time
    from days
    join public.bath_availability_windows w
      on w.city_id = p_city_id
     and w.active = true
     and w.weekday = extract(dow from days.day)::int
    where not exists (
      select 1 from public.bath_availability_exceptions x
      where x.city_id = p_city_id and x.exception_date = days.day and x.is_closed = true
    )
    and (v_anchor is null
         or mod(mod((days.day - v_anchor) / 7, 2) + 2, 2) = 0)
  ),
  extra as (
    select days.day, x.start_time, x.end_time
    from days
    join public.bath_availability_exceptions x
      on x.city_id = p_city_id
     and x.exception_date = days.day
     and x.is_closed = false
  ),
  windows as (
    select * from recurring
    union all
    select * from extra
  ),
  candidates as (
    select s as slot_start, s + v_len as slot_end
    from windows,
    lateral generate_series(
      (windows.day + windows.start_time) at time zone v_tz,
      ((windows.day + windows.end_time)  at time zone v_tz) - v_len,
      v_grid
    ) as s
  )
  select c.slot_start, c.slot_end
  from candidates c
  where c.slot_start >= v_from
    and c.slot_start <  v_to
    and not exists (
      select 1 from public.bath_appointments a
      where a.status not in ('cancelled', 'skipped', 'no_show')
        and a.scheduled_start < c.slot_end
        and coalesce(a.scheduled_end, a.scheduled_start + v_len) > c.slot_start
    )
  order by c.slot_start;
end;
$function$;

revoke all on function public.bath_open_slots(uuid, timestamptz, timestamptz, integer, integer) from public;
grant execute on function public.bath_open_slots(uuid, timestamptz, timestamptz, integer, integer) to anon, authenticated, service_role;

-- ── Shared engine: reach the cadence on the operator side, stay in policy on the client side ──
drop function if exists public._suggest_slots_core(uuid, uuid[], date, int, boolean);

create function public._suggest_slots_core(
  p_client_id uuid,
  p_dog_ids uuid[] default null,
  p_target_date date default null,
  p_target_span int default null,
  p_include_stops boolean default true,
  p_extend_horizon boolean default false)
 returns jsonb
 language plpgsql
 security definer
 set search_path to ''
as $function$
declare
  ctx record;
  w record;
  v_tz text;
  v_horizon int;
  v_hard text;
  v_nd text[];
  v_last date;
  v_cad int;
  v_due date;
  v_next timestamptz;
  v_next_status text;
  v_from date;
  v_to date;
  v_pass_horizon int;
  d date;
  v_slots jsonb;
  v_stops jsonb;
  v_days jsonb := '[]'::jsonb;
  v_count int := 0;
  v_override boolean := p_target_date is not null;
  v_sel int; v_total int; v_min int; v_dur int;
begin
  select * into ctx from public._client_booking_context(p_client_id);

  select count(*)::int into v_total from public.dogs dd
   where dd.client_id = p_client_id
     and coalesce(dd.roster_status, 'regular') not in ('former','deceased','moved');
  select count(*)::int into v_sel from public.dogs dd
   where p_dog_ids is not null and dd.id = any(p_dog_ids) and dd.client_id = p_client_id
     and coalesce(dd.roster_status, 'regular') not in ('former','deceased','moved');
  select coalesce(hb_min_stop_minutes, 30) into v_min from public.cities where id = ctx.o_city;
  v_dur := public._clean_minutes_for_dog_selection(ctx.o_dur, nullif(v_sel, 0), v_total, v_min);

  select hb_timezone, coalesce(hb_booking_horizon_days, 60) into v_tz, v_horizon
    from public.cities where id = ctx.o_city;
  select availability_hard, availability_not_days into v_hard, v_nd
    from public.clients where id = p_client_id;
  select * into w from public._capacity_window(v_hard, v_nd);

  select max(x) into v_last from (
    select max(visited_at at time zone v_tz)::date as x
      from public.visits where client_id = p_client_id
       and visited_at <= now()
    union all
    select max(a.scheduled_start at time zone v_tz)::date
      from public.bath_appointments a
      join public.bath_subscribers s on s.id = a.subscriber_id
     where s.client_id = p_client_id
       and a.scheduled_start <= now()
       and a.status not in ('cancelled', 'no_show', 'skipped')
  ) t;

  select a.scheduled_start, a.status into v_next, v_next_status
    from public.bath_appointments a
    join public.bath_subscribers s on s.id = a.subscriber_id
   where s.client_id = p_client_id
     and a.scheduled_start > now()
     and a.status not in ('cancelled', 'no_show', 'skipped')
   order by a.scheduled_start
   limit 1;

  v_cad := coalesce(
    (select b.cadence_days from public.bath_subscriptions b
      where b.subscriber_id = ctx.o_sub and b.status = 'active' and b.is_recurring
      order by b.created_at desc limit 1),
    (select c.cadence_days from public.clients c where c.id = p_client_id));

  if v_cad is not null and v_last is not null then
    v_due := v_last + v_cad;
  else
    v_due := null;
  end if;

  if v_override then
    v_from := greatest(current_date + 1, p_target_date);
    v_to := greatest(v_from, p_target_date + greatest(coalesce(p_target_span, 1), 1) - 1);
  elsif v_due is not null and v_due > current_date then
    v_from := greatest(current_date + 1, v_due - 7);
    v_to := v_due + 14;
  else
    v_from := current_date + 1;
    v_to := current_date + 21;
  end if;

  -- The client door stays inside the public booking horizon. If a client's own
  -- cadence date sits past what they may self-book, fall back to the soonest open
  -- times rather than show an empty result. The operator door extends to reach.
  if not p_extend_horizon then
    v_to := least(v_to, current_date + v_horizon);
    if v_from > v_to then
      v_from := current_date + 1;
      v_to := least(current_date + 21, current_date + v_horizon);
    end if;
    v_pass_horizon := null;
  else
    v_pass_horizon := greatest((v_to - current_date) + 1, 1);
  end if;

  d := v_from;
  while d <= v_to and v_count < 8 loop
    if extract(dow from d)::int = any(w.o_dows) then
      select coalesce(jsonb_agg(q.s_start order by q.s_start), '[]'::jsonb) into v_slots
      from (
        select s_start, rn, cnt
          from (
            select s.slot_start as s_start,
                   row_number() over (order by s.slot_start) as rn,
                   count(*) over () as cnt
              from public.bath_open_slots(ctx.o_city,
                     (d::timestamp at time zone v_tz),
                     ((d + 1)::timestamp at time zone v_tz),
                     v_dur,
                     v_pass_horizon) s
             where (s.slot_start at time zone v_tz)::time >= w.o_start
               and (s.slot_start at time zone v_tz)::time <= w.o_end_start
          ) z
         where rn = cnt
            or (rn - 1) % greatest(1, ceil((cnt - 1)::numeric / 6)::int) = 0
      ) q;
      if jsonb_array_length(v_slots) > 0 then
        if p_include_stops then
          select coalesce(jsonb_agg(jsonb_build_object(
                   'start', a.scheduled_start, 'minutes', a.duration_minutes, 'client', c2.name,
                   'tentative', a.status = 'tentative')
                   order by a.scheduled_start), '[]'::jsonb)
            into v_stops
            from public.bath_appointments a
            left join public.bath_subscribers s2 on s2.id = a.subscriber_id
            left join public.clients c2 on c2.id = s2.client_id
           where (a.scheduled_start at time zone v_tz)::date = d
             and a.status not in ('cancelled', 'no_show', 'skipped');
        else
          v_stops := '[]'::jsonb;
        end if;
        v_days := v_days || jsonb_build_object(
          'date', d,
          'offset_days', case when v_due is null then null else d - v_due end,
          'slots', v_slots,
          'day_stops', v_stops);
        v_count := v_count + 1;
      end if;
    end if;
    d := d + 1;
  end loop;

  if not v_override and v_due is not null then
    select coalesce(jsonb_agg(e order by abs((e->>'offset_days')::int), (e->>'date')), '[]'::jsonb)
      into v_days from jsonb_array_elements(v_days) e;
  end if;

  return jsonb_build_object(
    'due_date', v_due,
    'cadence_days', v_cad,
    'last_visit', v_last,
    'next_booked', v_next,
    'next_booked_status', v_next_status,
    'next_booked_offset_days', case when v_next is not null and v_due is not null
      then (v_next at time zone v_tz)::date - v_due else null end,
    'duration_minutes', v_dur,
    'target_date', p_target_date,
    'window_note', nullif(coalesce(v_hard, ''), ''),
    'not_days', to_jsonb(coalesce(v_nd, '{}'::text[])),
    'days', v_days);
end;
$function$;

revoke all on function public._suggest_slots_core(uuid, uuid[], date, int, boolean, boolean) from public, anon, authenticated;

create or replace function public.admin_suggest_slots(p_client_id uuid, p_dog_ids uuid[] default null)
 returns jsonb
 language plpgsql
 security definer
 set search_path to ''
as $function$
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  return public._suggest_slots_core(p_client_id, p_dog_ids, null, null, true, true);
end;
$function$;

create or replace function public.bath_suggest_slots(
  p_target_date date default null,
  p_target_span int default null,
  p_dog_ids uuid[] default null)
 returns jsonb
 language plpgsql
 security definer
 set search_path to ''
as $function$
declare v_client uuid;
begin
  select client_id into v_client
    from public.bath_subscribers
   where auth_user_id = auth.uid()
   limit 1;
  if v_client is null then raise exception 'no_subscriber'; end if;
  return public._suggest_slots_core(v_client, p_dog_ids, p_target_date, p_target_span, false, false);
end;
$function$;

-- Operator manual specific-day flow: reach past the public horizon too.
create or replace function public.admin_open_slots(p_client_id uuid, p_from date, p_days integer default 1, p_dog_ids uuid[] default null)
 returns jsonb
 language plpgsql
 security definer
 set search_path to ''
as $function$
declare ctx record; v_sel int; v_total int; v_min int; v_dur int; v_horizon int;
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  select * into ctx from public._client_booking_context(p_client_id);
  select count(*)::int into v_total from public.dogs d
   where d.client_id = p_client_id
     and coalesce(d.roster_status, 'regular') not in ('former','deceased','moved');
  select count(*)::int into v_sel from public.dogs d
   where p_dog_ids is not null and d.id = any(p_dog_ids) and d.client_id = p_client_id
     and coalesce(d.roster_status, 'regular') not in ('former','deceased','moved');
  select coalesce(hb_min_stop_minutes, 30) into v_min from public.cities where id = ctx.o_city;
  v_dur := public._clean_minutes_for_dog_selection(ctx.o_dur, nullif(v_sel, 0), v_total, v_min);
  v_horizon := greatest((p_from + greatest(p_days, 1)) - current_date + 1, 1);
  return jsonb_build_object(
    'duration_minutes', v_dur,
    'slots', coalesce((
      select jsonb_agg(jsonb_build_object('start', s.slot_start, 'end', s.slot_end) order by s.slot_start)
        from public.bath_open_slots(
          ctx.o_city,
          greatest(p_from::timestamptz, now()),
          (p_from + greatest(p_days, 1))::timestamptz,
          v_dur,
          v_horizon) s
    ), '[]'::jsonb));
end;
$function$;
