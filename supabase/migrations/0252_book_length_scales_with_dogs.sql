-- 0252_book_length_scales_with_dogs.sql
--
-- When Paul books a visit and takes a dog off (e.g. Koa is not coming this time),
-- the appointment length must shrink so the slot engine offers the time he wants.
-- Until now the length was one whole-visit block (clean_effective_duration_minutes,
-- the client's typical total time) and the dog checkboxes only changed who was
-- assigned and the price, never the length. The system had no per-dog time at all.
--
-- Decision (Paul, 2026-06-25): each dog is an EQUAL SHARE of the visit. Dropping
-- one of four dogs trims about a quarter off the block; the full roster is
-- unchanged. We can move to a per-dog minutes model later if real timings warrant.
--
-- This puts the rule in the durable layer: the three booking RPCs scale the block
-- by (dogs going / dogs on the roster), floored at the city minimum stop and
-- rounded up to 5 minutes. "Dogs on the roster" = the client's non-archived dogs
-- (regular or occasional), matching the set the booking screen lets Paul pick from.
-- When all dogs go (or no subset is passed) the length is exactly as before.

-- Equal-share scaler. Full minutes when the selection is the whole roster (or
-- unknown); otherwise the proportional share, floored and rounded up to 5.
CREATE OR REPLACE FUNCTION public._clean_minutes_for_dog_selection(
  p_full integer, p_selected integer, p_total integer, p_min integer)
RETURNS integer LANGUAGE sql IMMUTABLE AS $function$
  select case
    when p_full is null then null
    when p_selected is null or p_total is null or p_total <= 0
         or p_selected <= 0 or p_selected >= p_total then p_full
    else greatest(coalesce(p_min, 30),
                  (ceil((p_full::numeric * p_selected / p_total) / 5.0) * 5)::integer)
  end;
$function$;

-- admin_open_slots: now takes the dogs going (p_dog_ids) and sizes the open times
-- to the scaled block. Signature changes, so drop and recreate, then restore grants.
DROP FUNCTION IF EXISTS public.admin_open_slots(uuid, date, integer);
CREATE FUNCTION public.admin_open_slots(p_client_id uuid, p_from date, p_days integer DEFAULT 1, p_dog_ids uuid[] DEFAULT NULL)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare ctx record; v_sel int; v_total int; v_min int; v_dur int;
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
  return jsonb_build_object(
    'duration_minutes', v_dur,
    'slots', coalesce((
      select jsonb_agg(jsonb_build_object('start', s.slot_start, 'end', s.slot_end) order by s.slot_start)
        from public.bath_open_slots(
          ctx.o_city,
          greatest(p_from::timestamptz, now()),
          (p_from + greatest(p_days, 1))::timestamptz,
          v_dur) s
    ), '[]'::jsonb));
end;
$function$;
REVOKE ALL ON FUNCTION public.admin_open_slots(uuid, date, integer, uuid[]) FROM public;
GRANT EXECUTE ON FUNCTION public.admin_open_slots(uuid, date, integer, uuid[]) TO authenticated, service_role;

-- admin_suggest_slots: same, for the suggested day-cards. Signature changes too.
DROP FUNCTION IF EXISTS public.admin_suggest_slots(uuid);
CREATE FUNCTION public.admin_suggest_slots(p_client_id uuid, p_dog_ids uuid[] DEFAULT NULL)
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
      select coalesce(jsonb_agg(t.s order by t.s), '[]'::jsonb) into v_slots from (
        select s.slot_start as s
          from public.bath_open_slots(ctx.o_city,
                 (d::timestamp at time zone v_tz),
                 ((d + 1)::timestamp at time zone v_tz),
                 v_dur) s
         where (s.slot_start at time zone v_tz)::time >= w.o_start
           and (s.slot_start at time zone v_tz)::time <= w.o_end_start
         limit 6
      ) t;
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
REVOKE ALL ON FUNCTION public.admin_suggest_slots(uuid, uuid[]) FROM public;
GRANT EXECUTE ON FUNCTION public.admin_suggest_slots(uuid, uuid[]) TO authenticated, service_role;

-- admin_book_appointment: reserve the scaled block (and check the right window)
-- when a subset of dogs is booked. Same signature, so a plain replace.
CREATE OR REPLACE FUNCTION public.admin_book_appointment(p_client_id uuid, p_start timestamp with time zone, p_override boolean DEFAULT false, p_dog_ids uuid[] DEFAULT NULL::uuid[])
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  ctx record;
  v_open boolean;
  v_id uuid;
  v_end timestamptz;
  v_dogs uuid[];
  v_amount int;
  v_sel int; v_total int; v_min int; v_dur int;
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  if p_start is null or p_start <= now() then
    return jsonb_build_object('ok', false, 'error', 'start_in_past');
  end if;

  if p_dog_ids is not null and array_length(p_dog_ids, 1) > 0 then
    select array_agg(d.id) into v_dogs
      from public.dogs d
     where d.id = any(p_dog_ids) and d.client_id = p_client_id;
    if coalesce(array_length(v_dogs, 1), 0) <> array_length(p_dog_ids, 1) then
      return jsonb_build_object('ok', false, 'error', 'dogs_not_this_client');
    end if;
  end if;

  select * into ctx from public._client_booking_context(p_client_id);

  -- Equal-share length: scale the block by the dogs going / dogs on the roster.
  select count(*)::int into v_total from public.dogs d
   where d.client_id = p_client_id
     and coalesce(d.roster_status, 'regular') not in ('former','deceased','moved');
  select count(*)::int into v_sel from public.dogs d
   where v_dogs is not null and d.id = any(v_dogs) and d.client_id = p_client_id
     and coalesce(d.roster_status, 'regular') not in ('former','deceased','moved');
  select coalesce(hb_min_stop_minutes, 30) into v_min from public.cities where id = ctx.o_city;
  v_dur := public._clean_minutes_for_dog_selection(ctx.o_dur, nullif(v_sel, 0), v_total, v_min);

  v_end := p_start + make_interval(mins => v_dur);

  v_amount := null;
  if v_dogs is not null and array_length(v_dogs, 1) > 0 then
    select nullif(sum(coalesce(d.price_cents, 0)), 0)::int into v_amount
      from public.dogs d where d.id = any(v_dogs);
  end if;
  v_amount := coalesce(v_amount, ctx.o_price, 0);

  select exists (
    select 1 from public.bath_open_slots(ctx.o_city, p_start - interval '1 second', p_start + interval '1 second', v_dur) s
     where s.slot_start = p_start
  ) into v_open;

  if not v_open and not p_override then
    return jsonb_build_object('ok', false, 'error', 'slot_conflict',
      'duration_minutes', v_dur,
      'overlaps', coalesce((
        select jsonb_agg(jsonb_build_object('start', a.scheduled_start, 'client',
            (select c2.name from public.bath_subscribers s2 left join public.clients c2 on c2.id = s2.client_id where s2.id = a.subscriber_id)))
          from public.bath_appointments a
         where a.status not in ('cancelled','skipped','no_show')
           and a.scheduled_start < v_end and coalesce(a.scheduled_end, a.scheduled_start) > p_start
      ), '[]'::jsonb));
  end if;

  begin
    insert into public.bath_appointments (
      subscriber_id, subscription_id, scheduled_start, scheduled_end, duration_minutes,
      status, service_type, amount_cents, dog_count, dog_ids, notes, overridden
    ) values (
      ctx.o_sub, ctx.o_subscription, p_start, v_end, v_dur,
      'confirmed', ctx.o_service, v_amount,
      coalesce(array_length(v_dogs, 1), ctx.o_dogs), v_dogs,
      case when not v_open then 'Booked with operator override' else null end,
      not v_open
    ) returning id into v_id;
  exception when exclusion_violation then
    return jsonb_build_object('ok', false, 'error', 'overlaps_existing');
  end;

  return jsonb_build_object('ok', true, 'appointment_id', v_id,
    'scheduled_start', p_start, 'scheduled_end', v_end,
    'duration_minutes', v_dur, 'amount_cents', v_amount,
    'overridden', not v_open);
end;
$function$;
