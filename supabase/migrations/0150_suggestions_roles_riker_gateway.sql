-- 0150: field batch four (Paul, 2026-06-10/11).
--
-- 1. SMART BOOKING SUGGESTIONS (admin_suggest_slots). Paul's verdict on the
--    raw date-and-time picker: "completely not usable", because picking a
--    slot requires knowing the cadence target, the client's windows, and
--    what the day already holds. The RPC answers all three at once: due date
--    from their real cadence and last visit, candidate days around it
--    filtered by THEIR constraints (the same _capacity_window parser the
--    Availability watcher uses), each day carrying its offset from due
--    ("-2 days" / "on time") and the stops already booked that day for
--    context. Geography-aware ranking arrives with the String of Pearls
--    route engine; this layer is cadence + constraints + day shape.
-- 2. Booking horizon raised 28 -> 60 days: a 6-week-cadence client's due
--    date sits beyond a 28-day horizon, so suggestions (and the funnel)
--    could never reach it.
-- 3. ORBIT ROLES, the foundation (Paul: more people are coming; Jake tests
--    as the first Hurricane Bath Operator). admins.role ('owner' |
--    'operator'); admin_self adopts a pre-created row by email on first
--    Google sign-in (so onboarding = insert a row with the person's email,
--    they sign in, it binds) and returns the role; operator masking lives
--    SERVER-SIDE where it cannot be styled away: admin_get_client strips
--    contact and money and hands back a click-to-text link instead, and
--    admin_today_appointments strips the money column. Honest limit until
--    Twilio: an sms: link necessarily carries the number inside the href
--    (not displayed, but inspectable); true number-hiding is the Twilio
--    relay, recorded in the rule.
-- 4. Riker becomes the one gateway: a plan may now carry wisdom with no
--    client at all, and apply routes it to the wisdom inbox, so the
--    floating + can send EVERYTHING through Riker and nothing needs a
--    dedicated capture path.

-- 1+2 ─ horizon, then suggestions ─────────────────────────────────────────
update public.cities set hb_booking_horizon_days = 60 where hb_booking_horizon_days < 60;

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

  select max(x) into v_last from (
    select max(visited_at at time zone v_tz)::date as x
      from public.visits where client_id = p_client_id
    union all
    select max(a.scheduled_start at time zone v_tz)::date
      from public.bath_appointments a
      join public.bath_subscribers s on s.id = a.subscriber_id
     where s.client_id = p_client_id
       and a.status not in ('cancelled', 'no_show', 'skipped')
  ) t;

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

  -- Closest to due first; chronological inside a tie.
  if v_due is not null then
    select coalesce(jsonb_agg(e order by abs((e->>'offset_days')::int), (e->>'date')), '[]'::jsonb)
      into v_days from jsonb_array_elements(v_days) e;
  end if;

  return jsonb_build_object(
    'due_date', v_due,
    'cadence_days', v_cad,
    'last_visit', v_last,
    'duration_minutes', ctx.o_dur,
    'window_note', nullif(coalesce(v_hard, ''), ''),
    'not_days', to_jsonb(coalesce(v_nd, '{}'::text[])),
    'days', v_days);
end;
$$;
revoke all on function public.admin_suggest_slots(uuid) from public, anon;
grant execute on function public.admin_suggest_slots(uuid) to authenticated, service_role;

-- 3 ─ roles ───────────────────────────────────────────────────────────────
alter table public.admins
  add column if not exists role text not null default 'owner'
  check (role in ('owner', 'operator'));

create or replace function public._admin_role()
returns text
language sql
stable
security definer
set search_path to 'public', 'pg_temp'
as $$
  select role from public.admins where auth_user_id = auth.uid() and is_active limit 1;
$$;
revoke all on function public._admin_role() from public, anon, authenticated;
grant execute on function public._admin_role() to service_role;

-- Onboarding by email: insert a row with the person's email (no auth id yet);
-- their first Google sign-in adopts it. A row already bound never re-binds.
drop function if exists public.admin_self();
create or replace function public.admin_self()
returns table(id uuid, first_name text, last_name text, email citext, is_active boolean, role text)
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $$
declare v_email text;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  if not exists (select 1 from public.admins a where a.auth_user_id = auth.uid()) then
    select u.email into v_email from auth.users u where u.id = auth.uid();
    if v_email is not null then
      update public.admins a
         set auth_user_id = auth.uid(), updated_at = now()
       where a.auth_user_id is null and a.is_active and a.email = v_email::citext;
    end if;
  end if;
  return query
    select a.id, a.first_name, a.last_name, a.email, a.is_active, a.role
      from public.admins a
     where a.auth_user_id = auth.uid() and a.is_active
     limit 1;
end;
$$;
revoke all on function public.admin_self() from public, anon;
grant execute on function public.admin_self() to authenticated, service_role;

-- Operator masking: money off the Today payload.
CREATE OR REPLACE FUNCTION public.admin_today_appointments()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare result jsonb;
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  result := coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', a.id,
      'client_id', s.client_id,
      'client', c.name,
      'fallback', nullif((select string_agg(bd.name, ', ') from public.bath_dogs bd where bd.subscriber_id = a.subscriber_id), ''),
      'scheduled_start', a.scheduled_start,
      'service_type', a.service_type,
      'status', a.status,
      'amount_cents', a.amount_cents,
      'dog_count', a.dog_count,
      'inbound_at', vt.inbound_at,
      'arrived_at', vt.arrived_at,
      'departed_at', vt.departed_at,
      'followups', coalesce((
        select jsonb_agg(jsonb_build_object('dog', dd.name, 'body', f.body) order by dd.name)
          from public.dog_followups f join public.dogs dd on dd.id = f.dog_id
         where dd.client_id = s.client_id and f.status = 'open'), '[]'::jsonb)
    ) order by a.scheduled_start)
    from public.bath_appointments a
    left join public.bath_subscribers s on s.id = a.subscriber_id
    left join public.clients c on c.id = s.client_id
    left join lateral (
      select inbound_at, arrived_at, departed_at
        from public.visits v
       where v.appointment_id = a.id
       order by v.created_at limit 1
    ) vt on true
    where (a.scheduled_start at time zone 'America/New_York')::date = (now() at time zone 'America/New_York')::date
      and a.status not in ('cancelled','no_show','skipped')
  ), '[]'::jsonb);
  if public._admin_role() = 'operator' then
    result := coalesce((select jsonb_agg(e - 'amount_cents') from jsonb_array_elements(result) e), '[]'::jsonb);
  end if;
  return result;
end;
$function$;
revoke all on function public.admin_today_appointments() from public, anon;
grant execute on function public.admin_today_appointments() to authenticated, service_role;

-- Operator masking on the contact sheet: contact and money stripped
-- server-side, click-to-text link handed back instead of a number.
CREATE OR REPLACE FUNCTION public.admin_get_client(p_client_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare result jsonb;
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  select jsonb_build_object(
    'client', to_jsonb(c.*),
    'dogs', coalesce((select jsonb_agg(to_jsonb(d.*) order by d.name) from public.dogs d where d.client_id = c.id), '[]'::jsonb),
    'subscriber', (select to_jsonb(s.*) from public.bath_subscribers s where s.client_id = c.id limit 1),
    'visits', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', v.id, 'visited_at', v.visited_at, 'service_type', v.service_type,
        'work_done', v.work_done, 'visit_notes', v.visit_notes,
        'actual_minutes', v.actual_minutes,
        'amount_collected_cents', v.amount_collected_cents, 'tip_cents', v.tip_cents,
        'payment_method', v.payment_method, 'condition_flags', v.condition_flags, 'source', v.source,
        'dog_ratings', coalesce((
          select jsonb_agg(jsonb_build_object('dog_id', r.dog_id, 'name', d2.name, 'score', r.score, 'note', r.note) order by d2.name)
            from public.visit_dog_ratings r left join public.dogs d2 on d2.id = r.dog_id
           where r.visit_id = v.id), '[]'::jsonb),
        'photos', coalesce((
          select jsonb_agg(jsonb_build_object('id', p.id, 'kind', p.kind, 'path', p.storage_path, 'client_visible', p.client_visible,
                                              'dog_id', p.dog_id, 'dog_name', d3.name) order by p.created_at)
            from public.visit_photos p left join public.dogs d3 on d3.id = p.dog_id
           where p.visit_id = v.id), '[]'::jsonb)
      ) order by v.visited_at desc)
        from public.visits v where v.client_id = c.id), '[]'::jsonb),
    'upcoming', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', a.id, 'scheduled_start', a.scheduled_start, 'status', a.status,
        'service_type', a.service_type, 'amount_cents', a.amount_cents
      ) order by a.scheduled_start)
        from public.bath_appointments a
        join public.bath_subscribers s2 on s2.id = a.subscriber_id
       where s2.client_id = c.id and a.status in ('requested','confirmed','tentative')), '[]'::jsonb)
  ) into result
  from public.clients c where c.id = p_client_id;
  if result is null then raise exception 'client not found'; end if;

  if public._admin_role() = 'operator' then
    result := result || jsonb_build_object('contact_links',
      case when (result->'client'->>'phone_e164') is not null
           then jsonb_build_object('sms', 'sms:' || (result->'client'->>'phone_e164'))
           else '{}'::jsonb end);
    result := jsonb_set(result, '{client}',
      (result->'client') - 'phone_e164' - 'email' - 'message_thoughts' - 'note');
    if jsonb_typeof(result->'subscriber') = 'object' then
      result := jsonb_set(result, '{subscriber}', (result->'subscriber') - 'phone_e164' - 'email');
    end if;
    result := jsonb_set(result, '{visits}', coalesce((
      select jsonb_agg(v - 'amount_collected_cents' - 'tip_cents' - 'payment_method')
        from jsonb_array_elements(result->'visits') v), '[]'::jsonb));
    result := jsonb_set(result, '{upcoming}', coalesce((
      select jsonb_agg(v - 'amount_cents')
        from jsonb_array_elements(result->'upcoming') v), '[]'::jsonb));
  end if;
  return result;
end;
$function$;
revoke all on function public.admin_get_client(uuid) from public, anon;
grant execute on function public.admin_get_client(uuid) to authenticated, service_role;

-- 4 ─ Riker as the one gateway: wisdom with or without a client ──────────
create or replace function public.admin_riker_apply(p_plan jsonb)
returns jsonb language plpgsql security definer set search_path = public, pg_temp
as $$
declare v_client uuid; v_sub uuid; v_admin uuid; v_visit uuid;
        v_scores int := 0; v_note boolean := false; v_dognotes int := 0; r record;
        v_np jsonb; v_np_id uuid; v_status int := 0; v_wisdom text; v_wisdom_saved boolean := false;
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  v_client := nullif(p_plan->>'client_id','')::uuid;
  v_wisdom := nullif(btrim(coalesce(p_plan->>'wisdom','')),'');
  if v_client is null and v_wisdom is null then raise exception 'riker: no client resolved'; end if;
  if v_client is not null and not exists (select 1 from public.clients where id = v_client) then
    raise exception 'riker: client not found';
  end if;
  select id into v_admin from public.admins where auth_user_id = auth.uid();
  if v_client is not null then
    select id into v_sub from public.bath_subscribers where client_id = v_client limit 1;
  end if;

  if v_client is not null and jsonb_typeof(p_plan->'visit') = 'object' then
    insert into public.visits (
      client_id, subscriber_id, visited_at, service_type, dog_ids,
      work_done, visit_notes, actual_minutes, amount_collected_cents, payment_method, source, completed_by
    ) values (
      v_client, v_sub, now(),
      nullif(p_plan->'visit'->>'service_type',''),
      coalesce((select array_agg((e->>'dog_id')::uuid)
                  from jsonb_array_elements(coalesce(p_plan->'visit'->'dog_scores','[]')) e
                 where exists (select 1 from public.dogs d where d.id = (e->>'dog_id')::uuid and d.client_id = v_client)), '{}'),
      nullif(p_plan->'visit'->>'work_done',''),
      nullif(p_plan->'visit'->>'visit_notes',''),
      nullif(p_plan->'visit'->>'actual_minutes','')::int,
      nullif(p_plan->'visit'->>'amount_cents','')::int,
      nullif(p_plan->'visit'->>'payment_method',''),
      'riker', v_admin
    ) returning id into v_visit;

    insert into public.visit_dog_ratings (visit_id, dog_id, score)
    select v_visit, (e->>'dog_id')::uuid, (e->>'score')::int
      from jsonb_array_elements(coalesce(p_plan->'visit'->'dog_scores','[]')) e
     where nullif(e->>'score','') is not null and (e->>'score')::int between 1 and 5
       and exists (select 1 from public.dogs d where d.id = (e->>'dog_id')::uuid and d.client_id = v_client)
    on conflict (visit_id, dog_id) do update set score = excluded.score;
    get diagnostics v_scores = row_count;
  end if;

  if v_client is not null and nullif(btrim(coalesce(p_plan->>'client_note','')),'') is not null then
    update public.clients set note = coalesce(note || ' ; ', '') || btrim(p_plan->>'client_note'), updated_at = now()
     where id = v_client;
    v_note := true;
  end if;

  if v_client is not null then
    for r in select (e->>'dog_id')::uuid as dog_id, btrim(e->>'text') as text
               from jsonb_array_elements(coalesce(p_plan->'dog_notes','[]')) e
              where nullif(btrim(e->>'text'),'') is not null
    loop
      update public.dogs set notes = coalesce(notes || ' ; ', '') || r.text, updated_at = now()
       where id = r.dog_id and client_id = v_client;
      if found then v_dognotes := v_dognotes + 1; end if;
    end loop;

    for r in select (e->>'dog_id')::uuid as dog_id, e->>'status' as status, btrim(coalesce(e->>'note','')) as note
               from jsonb_array_elements(coalesce(p_plan->'dog_status','[]')) e
              where e->>'status' in ('regular','occasional','moved','former','deceased')
    loop
      update public.dogs
         set roster_status = r.status,
             notes = case when r.note <> '' then coalesce(notes || ' ; ', '') || r.note else notes end,
             updated_at = now()
       where id = r.dog_id and client_id = v_client;
      if found then v_status := v_status + 1; end if;
    end loop;

    v_np := p_plan->'notify_person';
    if jsonb_typeof(v_np) = 'object' then
      v_np_id := public.admin_upsert_notify_person(
        nullif(v_np->>'id','')::uuid,
        v_client,
        v_np->>'name',
        v_np->>'phone',
        v_np->>'email',
        v_np->>'relationship',
        coalesce(nullif(v_np->>'mode',''), 'in_addition'),
        nullif(v_np->>'until','')::date
      );
    end if;
  end if;

  -- The gateway half: an idea, rule, or business thought with no client
  -- record to touch lands in the wisdom inbox for the Archivist.
  if v_wisdom is not null then
    perform public.admin_capture_wisdom(v_wisdom,
      case when v_client is not null then 'client' else 'unsorted' end,
      v_client, 'riker');
    v_wisdom_saved := true;
  end if;

  return jsonb_build_object('visit_id', v_visit, 'scores_applied', v_scores,
                           'client_note_appended', v_note, 'dog_notes_appended', v_dognotes,
                           'dog_status_changes', v_status, 'notify_person_id', v_np_id,
                           'wisdom_saved', v_wisdom_saved);
end;
$$;
revoke all on function public.admin_riker_apply(jsonb) from public, anon;
grant execute on function public.admin_riker_apply(jsonb) to authenticated, service_role;
