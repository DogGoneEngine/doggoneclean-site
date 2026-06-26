-- 0255_smart_slots_shared_and_long_cadence_fix.sql
--
-- Two problems, one root cause, plus one new door.
--
-- THE BUG (operator side). admin_suggest_slots framed its search window as
--   v_from := greatest(current_date + 1, v_due - 7);
--   v_to   := least(v_due + 14, current_date + 59);
-- That ceiling of current_date + 59 silently strands any client whose next
-- visit is due more than ~2 months out. Debbie Koerner comes every 98 days, so
-- the day she is freshly visited her next due date sits ~3 months ahead, past
-- the ceiling: v_from lands AFTER v_to, the day loop never runs, and the panel
-- shows "none available" for a client who is wide open. The mirror image breaks
-- too: a client already PAST their cadence has v_due in the past, v_to closes
-- behind today, and the same empty result appears exactly when you most want to
-- get them back in.
--
-- THE FIX. Aim the window at the client's real next-visit timing, whatever it
-- is, and never strand it:
--   * Future due  -> a spread of good times AROUND the due date (v_due-7..+14),
--                    no absolute ceiling, so a 14-week or 26-week cadence is
--                    reached just like a 2-week one.
--   * Due passed  -> the soonest good times forward (tomorrow .. +21 days). No
--                    fresh-cadence-from-today, no lateness framing: just the
--                    earliest options that still fit.
--   * No cadence  -> soonest forward, same as before.
--
-- THE NEW DOOR (client side). The same brains now back the client portal, so a
-- client rescheduling their own visit gets the SAME curated suggestions you do,
-- not a raw wall of every open time. bath_suggest_slots resolves the caller's
-- own client record from their sign-in and never leaks another client's stops
-- (p_include_stops = false). Either side can also aim the engine at a specific
-- day or week (p_target_date + p_target_span) instead of the cadence default.
--
-- One engine (_suggest_slots_core), two doors (admin_suggest_slots for the
-- operator, bath_suggest_slots for the client), so the two surfaces can never
-- drift apart or break separately. The operator's existing "More options"
-- specific-day flow (admin_open_slots) is unchanged.

-- ── The shared engine ──────────────────────────────────────────────────
create or replace function public._suggest_slots_core(
  p_client_id uuid,
  p_dog_ids uuid[] default null,
  p_target_date date default null,
  p_target_span int default null,
  p_include_stops boolean default true)
 returns jsonb
 language plpgsql
 security definer
 set search_path to ''
as $function$
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

  -- v_due stays meaningful for context/labels even when we are not centered on
  -- it (overdue, or an explicit day/week pick).
  if v_cad is not null and v_last is not null then
    v_due := v_last + v_cad;
  else
    v_due := null;
  end if;

  if v_override then
    -- Caller named a day or week: search exactly there, never before tomorrow.
    v_from := greatest(current_date + 1, p_target_date);
    v_to := greatest(v_from, p_target_date + greatest(coalesce(p_target_span, 1), 1) - 1);
  elsif v_due is not null and v_due > current_date then
    -- On a future cadence: a spread of good times around the due date. No
    -- absolute ceiling, so long cadences (98, 182 days) are reached.
    v_from := greatest(current_date + 1, v_due - 7);
    v_to := v_due + 14;
  else
    -- Overdue, due today, or no cadence on file: the soonest good times forward.
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

  -- Cadence default centers on the due date (closest-to-due first). An explicit
  -- day/week pick stays in plain chronological order (what the caller asked to see).
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

-- ── Operator door: unchanged signature, now delegates to the shared engine ──
create or replace function public.admin_suggest_slots(p_client_id uuid, p_dog_ids uuid[] default null)
 returns jsonb
 language plpgsql
 security definer
 set search_path to ''
as $function$
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  return public._suggest_slots_core(p_client_id, p_dog_ids, null, null, true);
end;
$function$;

-- ── Client door: resolves the caller's own client record, no other-client PII ──
-- Defaults to the cadence-aware suggestions; pass p_target_date (+ optional
-- p_target_span: 1 = that day, 7 = that week) to aim at a specific stretch.
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
  return public._suggest_slots_core(v_client, p_dog_ids, p_target_date, p_target_span, false);
end;
$function$;

revoke all on function public._suggest_slots_core(uuid, uuid[], date, int, boolean) from public, anon, authenticated;
revoke all on function public.bath_suggest_slots(date, int, uuid[]) from public, anon;
grant execute on function public.bath_suggest_slots(date, int, uuid[]) to authenticated;
