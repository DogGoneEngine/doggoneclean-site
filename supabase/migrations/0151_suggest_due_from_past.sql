-- 0151: suggestion-engine correction, caught in live verification minutes
-- after 0150. The due date was computed off max(visit, appointment) INCLUDING
-- future appointments, so Michelle and Ginger (groomed today, but carrying
-- July 24 evening bookings the calendar sync imported from Paul's Google
-- Calendar) showed a phantom "last visit" six weeks ahead and a due date
-- past the window, yielding zero suggestions. Now: the cadence anchors on
-- the last PAST visit only, and any already-booked future appointment is
-- returned as next_booked with its own offset from due, so the panel can say
-- "already booked Jul 24, 16 days past their 28-day rhythm" instead of
-- silently absorbing it.

create or replace function public.admin_suggest_slots(p_client_id uuid)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $$
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
  v_from date;
  v_to date;
  d date;
  v_slots jsonb;
  v_stops jsonb;
  v_days jsonb := '[]'::jsonb;
  v_count int := 0;
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;

  select * into ctx from public._client_booking_context(p_client_id);
  select hb_timezone into v_tz from public.cities where id = ctx.o_city;
  select availability_hard, availability_not_days into v_hard, v_nd
    from public.clients where id = p_client_id;
  select * into w from public._capacity_window(v_hard, v_nd);

  -- The rhythm anchors on what has HAPPENED, never on future bookings.
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

  -- Already booked ahead? Surface it; do not absorb it.
  select min(a.scheduled_start) into v_next
    from public.bath_appointments a
    join public.bath_subscribers s on s.id = a.subscriber_id
   where s.client_id = p_client_id
     and a.scheduled_start > now()
     and a.status not in ('cancelled', 'no_show', 'skipped');

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
      select coalesce(jsonb_agg(t.s order by t.s), '[]'::jsonb) into v_slots from (
        select s.slot_start as s
          from public.bath_open_slots(ctx.o_city,
                 (d::timestamp at time zone v_tz),
                 ((d + 1)::timestamp at time zone v_tz),
                 ctx.o_dur) s
         where (s.slot_start at time zone v_tz)::time >= w.o_start
           and (s.slot_start at time zone v_tz)::time <= w.o_end_start
         limit 6
      ) t;
      if jsonb_array_length(v_slots) > 0 then
        select coalesce(jsonb_agg(jsonb_build_object(
                 'start', a.scheduled_start, 'minutes', a.duration_minutes, 'client', c2.name)
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
    'next_booked_offset_days', case when v_next is not null and v_due is not null
      then (v_next at time zone v_tz)::date - v_due else null end,
    'duration_minutes', ctx.o_dur,
    'window_note', nullif(coalesce(v_hard, ''), ''),
    'not_days', to_jsonb(coalesce(v_nd, '{}'::text[])),
    'days', v_days);
end;
$$;
revoke all on function public.admin_suggest_slots(uuid) from public, anon;
grant execute on function public.admin_suggest_slots(uuid) to authenticated, service_role;
