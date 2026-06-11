-- 0149: field batch three (Paul, 2026-06-10 evening).
--
-- 1. WINDSOR ARCHIVED (client_dispositions_are_migrations). Chester Weber's
--    Windsor has not been seen in a few years; Paul believes he moved away.
--    Ula is the only dog Paul sees. Status 'moved' (reversible, lose-nothing).
-- 2. STANDARD PHOTOS SHARE BY DEFAULT. Paul expected the before / after /
--    with-Paul photos to appear on the client's tracker the moment they are
--    uploaded (that is the spirit of tracking the visit), and found Michelle's
--    six photos invisible because every photo defaulted private behind the
--    per-photo Share toggle. Now: before, after, and with_dog default SHARED;
--    'extra' stays private until deliberately shared (extras can hold a skin
--    observation Paul may want to deliver with words first). The toggle still
--    un-shares anything. Backfills the existing standard-kind photos.
-- 3. IN-APP BOOKING FOR EXISTING CLIENTS (admin side). admin_open_slots lists
--    open times sized to the client's own duration; admin_book_appointment
--    books one, enforcing the slot engine for everyone EXCEPT Paul: with
--    p_override true it books anyway (operator_override_with_confirm made
--    real: rules bind clients hard and Paul softly). The one thing override
--    cannot cross is the no-overlap exclusion constraint: physics, not
--    policy. App-booked rows carry source null (app-native), which the
--    calendar sync and its prune never touch (they only own gcal_sync rows).
-- 4. RIKER LEARNS DOG ROSTER STATUS ("Windsor moved away, archive him"):
--    plan gains dog_status; apply validates ownership and writes
--    roster_status + an optional note. Context now carries each dog's
--    current roster_status so the parser proposes sensibly.
-- Grants explicit per rpc_grants_explicit.

-- 1 ─ Windsor ─────────────────────────────────────────────────────────────
update public.dogs d
   set roster_status = 'moved',
       notes = coalesce(notes || ' ; ', '') || 'Moved away (Paul, 2026-06-10): not seen in a few years; Ula is the only dog Paul sees.',
       updated_at = now()
  from public.clients c
 where d.client_id = c.id and c.name = 'Chester Weber' and d.name = 'Windsor'
   and d.roster_status = 'regular';

-- 2 ─ standard photo kinds share by default ───────────────────────────────
create or replace function public.admin_add_visit_photo(p_visit_id uuid, p_kind text, p_path text, p_dog_id uuid default null)
returns uuid language plpgsql security definer set search_path = public, pg_temp
as $$
declare v_id uuid; v_client uuid;
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  if p_kind not in ('before','after','with_dog','extra') then raise exception 'bad photo kind'; end if;
  select client_id into v_client from public.visits where id = p_visit_id;
  if not found then raise exception 'visit not found'; end if;
  if p_dog_id is not null and not exists (
    select 1 from public.dogs d where d.id = p_dog_id and d.client_id = v_client
  ) then raise exception 'dog does not belong to this client'; end if;
  insert into public.visit_photos (visit_id, kind, storage_path, dog_id, client_visible)
  values (p_visit_id, p_kind, p_path, p_dog_id, p_kind in ('before','after','with_dog'))
  returning id into v_id;
  return v_id;
end;
$$;
revoke all on function public.admin_add_visit_photo(uuid, text, text, uuid) from public, anon;
grant execute on function public.admin_add_visit_photo(uuid, text, text, uuid) to authenticated, service_role;

update public.visit_photos
   set client_visible = true
 where kind in ('before', 'after', 'with_dog') and not client_visible;

-- 3 ─ in-app booking for existing clients ─────────────────────────────────
create or replace function public._client_booking_context(p_client_id uuid,
  out o_sub uuid, out o_city uuid, out o_dur int, out o_subscription uuid,
  out o_price int, out o_service text, out o_dogs int)
language plpgsql
security definer
set search_path to ''
as $$
begin
  select s.id, s.city_id into o_sub, o_city
    from public.bath_subscribers s where s.client_id = p_client_id
    order by s.created_at limit 1;
  if o_sub is null then
    insert into public.bath_subscribers (client_id, city_id)
    values (p_client_id, (select id from public.cities where slug = 'ocala'))
    returning id, city_id into o_sub, o_city;
  end if;
  if o_city is null then
    select id into o_city from public.cities where slug = 'ocala';
    update public.bath_subscribers set city_id = o_city where id = o_sub;
  end if;
  o_dur := coalesce(public.clean_effective_duration_minutes(o_sub),
                    greatest(coalesce((select visit_minutes from public.clients where id = p_client_id), 60), 30));
  select b.id, b.base_price_cents, b.service_type
    into o_subscription, o_price, o_service
    from public.bath_subscriptions b
   where b.subscriber_id = o_sub and b.status = 'active'
   order by b.created_at desc limit 1;
  if o_service is null then
    select case when c.service_type in ('full_groom','bath','nails') then c.service_type else 'full_groom' end
      into o_service from public.clients c where c.id = p_client_id;
  end if;
  select greatest(1, count(*))::int into o_dogs
    from public.dogs d
   where d.client_id = p_client_id
     and coalesce(d.roster_status, 'regular') in ('regular', 'occasional');
end;
$$;
revoke all on function public._client_booking_context(uuid) from public, anon, authenticated;
grant execute on function public._client_booking_context(uuid) to service_role;

-- Open times for one client on a span of days, sized to their real duration.
create or replace function public.admin_open_slots(p_client_id uuid, p_from date, p_days int default 1)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $$
declare ctx record;
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  select * into ctx from public._client_booking_context(p_client_id);
  return jsonb_build_object(
    'duration_minutes', ctx.o_dur,
    'slots', coalesce((
      select jsonb_agg(jsonb_build_object('start', s.slot_start, 'end', s.slot_end) order by s.slot_start)
        from public.bath_open_slots(
          ctx.o_city,
          greatest(p_from::timestamptz, now()),
          (p_from + greatest(p_days, 1))::timestamptz,
          ctx.o_dur) s
    ), '[]'::jsonb));
end;
$$;
revoke all on function public.admin_open_slots(uuid, date, int) from public, anon;
grant execute on function public.admin_open_slots(uuid, date, int) to authenticated, service_role;

-- Book it. The slot engine binds clients hard; Paul gets the soft override
-- (operator_override_with_confirm): p_override true books a time the engine
-- would refuse (an off-window evening, an off-week day). The no-overlap
-- exclusion constraint still stands either way: two stops cannot occupy the
-- same minutes, that is physics, not policy.
create or replace function public.admin_book_appointment(
  p_client_id uuid,
  p_start timestamptz,
  p_override boolean default false
) returns jsonb
language plpgsql
security definer
set search_path to ''
as $$
declare
  ctx record;
  v_open boolean;
  v_id uuid;
  v_end timestamptz;
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  if p_start is null or p_start <= now() then
    return jsonb_build_object('ok', false, 'error', 'start_in_past');
  end if;

  select * into ctx from public._client_booking_context(p_client_id);
  v_end := p_start + make_interval(mins => ctx.o_dur);

  select exists (
    select 1 from public.bath_open_slots(ctx.o_city, p_start - interval '1 second', p_start + interval '1 second', ctx.o_dur) s
     where s.slot_start = p_start
  ) into v_open;

  if not v_open and not p_override then
    return jsonb_build_object('ok', false, 'error', 'slot_conflict',
      'duration_minutes', ctx.o_dur,
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
      status, service_type, amount_cents, dog_count, notes
    ) values (
      ctx.o_sub, ctx.o_subscription, p_start, v_end, ctx.o_dur,
      'confirmed', ctx.o_service, coalesce(ctx.o_price, 0), ctx.o_dogs,
      case when not v_open then 'Booked with operator override' else null end
    ) returning id into v_id;
  exception when exclusion_violation then
    return jsonb_build_object('ok', false, 'error', 'overlaps_existing');
  end;

  return jsonb_build_object('ok', true, 'appointment_id', v_id,
    'scheduled_start', p_start, 'scheduled_end', v_end,
    'duration_minutes', ctx.o_dur, 'amount_cents', coalesce(ctx.o_price, 0),
    'overridden', not v_open);
end;
$$;
revoke all on function public.admin_book_appointment(uuid, timestamptz, boolean) from public, anon;
grant execute on function public.admin_book_appointment(uuid, timestamptz, boolean) to authenticated, service_role;

-- 4 ─ Riker learns dog roster status ──────────────────────────────────────
create or replace function public.admin_riker_context(p_client_id uuid default null)
returns jsonb language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  if p_client_id is not null then
    return (select jsonb_build_object(
        'client', jsonb_build_object('id', c.id, 'name', c.name),
        'dogs', coalesce((select jsonb_agg(jsonb_build_object('id', d.id, 'name', d.name,
                            'roster_status', coalesce(d.roster_status, 'regular')) order by d.name)
                            from public.dogs d where d.client_id = c.id), '[]'::jsonb),
        'notify_people', coalesce((select jsonb_agg(jsonb_build_object(
                            'id', np.id, 'name', np.name, 'phone', np.phone_e164, 'email', np.email,
                            'mode', np.mode, 'active', np.active, 'until', np.until_date) order by np.created_at)
                            from public.notify_people np where np.client_id = c.id), '[]'::jsonb))
      from public.clients c where c.id = p_client_id);
  end if;
  return jsonb_build_object('clients', coalesce((
    select jsonb_agg(jsonb_build_object(
        'id', c.id, 'name', c.name,
        'aliases', coalesce((select jsonb_agg(a.alias) from public.client_aliases a where a.client_id = c.id), '[]'::jsonb),
        'dogs', coalesce((select jsonb_agg(jsonb_build_object('id', d.id, 'name', d.name,
                            'roster_status', coalesce(d.roster_status, 'regular')) order by d.name)
                            from public.dogs d where d.client_id = c.id), '[]'::jsonb))
      order by c.name)
    from public.clients c
   where c.exclude_from_everything = false and c.archived_at is null), '[]'::jsonb));
end;
$$;
revoke all on function public.admin_riker_context(uuid) from public, anon;
grant execute on function public.admin_riker_context(uuid) to authenticated, service_role;

create or replace function public.admin_riker_apply(p_plan jsonb)
returns jsonb language plpgsql security definer set search_path = public, pg_temp
as $$
declare v_client uuid; v_sub uuid; v_admin uuid; v_visit uuid;
        v_scores int := 0; v_note boolean := false; v_dognotes int := 0; r record;
        v_np jsonb; v_np_id uuid; v_status int := 0;
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  v_client := nullif(p_plan->>'client_id','')::uuid;
  if v_client is null then raise exception 'riker: no client resolved'; end if;
  if not exists (select 1 from public.clients where id = v_client) then raise exception 'riker: client not found'; end if;
  select id into v_admin from public.admins where auth_user_id = auth.uid();
  select id into v_sub from public.bath_subscribers where client_id = v_client limit 1;

  if jsonb_typeof(p_plan->'visit') = 'object' then
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

  if nullif(btrim(coalesce(p_plan->>'client_note','')),'') is not null then
    update public.clients set note = coalesce(note || ' ; ', '') || btrim(p_plan->>'client_note'), updated_at = now()
     where id = v_client;
    v_note := true;
  end if;

  for r in select (e->>'dog_id')::uuid as dog_id, btrim(e->>'text') as text
             from jsonb_array_elements(coalesce(p_plan->'dog_notes','[]')) e
            where nullif(btrim(e->>'text'),'') is not null
  loop
    update public.dogs set notes = coalesce(notes || ' ; ', '') || r.text, updated_at = now()
     where id = r.dog_id and client_id = v_client;
    if found then v_dognotes := v_dognotes + 1; end if;
  end loop;

  -- "Windsor moved away, archive him" lands here, by voice. Reversible by
  -- construction (roster_status flips back to regular), never a delete.
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

  return jsonb_build_object('visit_id', v_visit, 'scores_applied', v_scores,
                           'client_note_appended', v_note, 'dog_notes_appended', v_dognotes,
                           'dog_status_changes', v_status, 'notify_person_id', v_np_id);
end;
$$;
revoke all on function public.admin_riker_apply(jsonb) from public, anon;
grant execute on function public.admin_riker_apply(jsonb) to authenticated, service_role;
