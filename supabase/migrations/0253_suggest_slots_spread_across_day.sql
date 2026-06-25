-- 0253_suggest_slots_spread_across_day.sql
--
-- The booking suggestions only ever showed the 6 EARLIEST open times of a day.
-- On a wide-open day that is 12:00, 12:15, 12:30, 12:45, 1:00, 1:15 - and because
-- start times sit on a fixed 15-minute clock, those earliest times are identical
-- no matter how long the visit is. So adding or removing a dog changed nothing a
-- person could see: the whole afternoon was hidden, and the one part that DOES
-- move with the dog count (how late the visit can start) was never shown.
--
-- Fix: show a spread of open times ACROSS the whole open window, and ALWAYS
-- include the latest-fitting start. The latest start depends on the visit length,
-- so dropping a dog (shorter visit) pushes it later and the offered set genuinely
-- changes. Tonya open day: 4 dogs offers ...3:30; drop Koa and it offers ...4:30.
-- Everything else in the function is unchanged from 0252.

CREATE OR REPLACE FUNCTION public.admin_suggest_slots(p_client_id uuid, p_dog_ids uuid[] DEFAULT NULL)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  ctx record;
  w record;
  v_tz text;
  v_hard text;
  v_nd text[];
  v_last date;
  v_cad int;
  v_due date;
  v_next timestamptz;
  v_next_status text;
  v_from date;
  v_to date;
  d date;
  v_slots jsonb;
  v_stops jsonb;
  v_days jsonb := '[]'::jsonb;
  v_count int := 0;
  v_sel int; v_total int; v_min int; v_dur int;
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;

  select * into ctx from public._client_booking_context(p_client_id);

  select count(*)::int into v_total from public.dogs dd
   where dd.client_id = p_client_id
     and coalesce(dd.roster_status, 'regular') not in ('former','deceased','moved');
  select count(*)::int into v_sel from public.dogs dd
   where p_dog_ids is not null and dd.id = any(p_dog_ids) and dd.client_id = p_client_id
     and coalesce(dd.roster_status, 'regular') not in ('former','deceased','moved');
  select coalesce(hb_min_stop_minutes, 30) into v_min from public.cities where id = ctx.o_city;
  v_dur := public._clean_minutes_for_dog_selection(ctx.o_dur, nullif(v_sel, 0), v_total, v_min);

  select hb_timezone into v_tz from public.cities where id = ctx.o_city;
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
    v_from := greatest(current_date + 1, v_due - 7);
    v_to := least(v_due + 14, current_date + 59);
  else
    v_due := null;
    v_from := current_date + 1;
    v_to := current_date + 21;
  end if;

  d := v_from;
  while d <= v_to and v_count < 8 loop
    if extract(dow from d)::int = any(w.o_dows) then
      -- A spread of open starts across the whole window, ALWAYS including the
      -- latest-fitting one (rn = cnt). The latest moves with the visit length, so
      -- the offered set changes when a dog is added or removed.
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
                     v_dur) s
             where (s.slot_start at time zone v_tz)::time >= w.o_start
               and (s.slot_start at time zone v_tz)::time <= w.o_end_start
          ) z
         where rn = cnt
            or (rn - 1) % greatest(1, ceil((cnt - 1)::numeric / 6)::int) = 0
      ) q;
      if jsonb_array_length(v_slots) > 0 then
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

  if v_due is not null then
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
    'window_note', nullif(coalesce(v_hard, ''), ''),
    'not_days', to_jsonb(coalesce(v_nd, '{}'::text[])),
    'days', v_days);
end;
$function$;
