-- 0153: Paul's 2026-06-11 evening batch.
--
-- 1. Adaptive appointment blocks. The block length now prefers reality: the
--    median on-site minutes of the client's last 5 completed visits (per
--    service, needs at least 3 samples) plus a tunable per-city breathing
--    buffer (cities.hb_buffer_minutes, default 15), rounded up to a 5-minute
--    grid. Static visit_minutes_* stay as the fallback for clients without
--    enough history. A 3-hour block shrinks toward 2 hours on its own as
--    real visits land; a tight 90-minute block grows if reality says so.
--    Buffer stays until the route engine prices drive time into the slot
--    engine itself; today the slots do not know which stop precedes them.
-- 2. Per-appointment dog assignment: bath_appointments.dog_ids. Null means
--    the whole regular roster (the old assumption); a set list means only
--    those dogs ride on this appointment (Emily Walker's Cavaliers together,
--    the Golden on her own schedule). admin_book_appointment takes the list,
--    tracker_status shows only the assigned dogs.
-- 3. Riker grows the powers Paul asked him for and could not do today:
--    dog_add (create dog cards with breed and price), dog_update (change a
--    price or breed on the card, not as a note), and backdated visits
--    (visit.visited_at) with dog scores resolvable by name for dogs created
--    in the same plan.
-- 4. Data entry, done directly instead of punted: Eric Shannon's dogs to $50
--    each on the cards; Becky Swinford's Maverick and Sammy created with
--    their April 4 scores attached to the real visit; Emily Walker's
--    Cavaliers to $105 each plus the grooming-groups note; Mary Brantley's
--    record unarchived and fully enriched (dogs, Scot, Lawana as toggleable
--    tracker contact, relationships to Jane Henrich, the 2-week callback
--    reminder).

-- 1. Adaptive blocks.
alter table public.cities add column if not exists hb_buffer_minutes integer not null default 15;

create or replace function public.clean_effective_duration_minutes(p_subscriber_id uuid, p_service_type text)
returns integer
language plpgsql
stable
security definer
set search_path to ''
as $$
declare
  v_city       public.cities%rowtype;
  v_client     uuid;
  v_hist       integer;
  v_live       integer;
  v_median     numeric;
  v_n          integer;
  v_default    integer;
  v_min        integer;
  v_has_double boolean;
begin
  select c.* into v_city
    from public.cities c
    join public.bath_subscribers s on s.city_id = c.id
   where s.id = p_subscriber_id;
  if not found then
    return null;
  end if;

  select client_id into v_client from public.bath_subscribers where id = p_subscriber_id;
  if v_client is not null then
    select coalesce(
             case p_service_type
               when 'full_groom' then visit_minutes_groom
               when 'nails' then visit_minutes_nails
               else null
             end,
             visit_minutes)
      into v_hist
      from public.clients where id = v_client;

    -- Reality first: median of the last 5 completed visits for this service.
    select count(*), percentile_cont(0.5) within group (order by sub.actual_minutes)
      into v_n, v_median
      from (
        select v.actual_minutes
          from public.visits v
         where v.client_id = v_client
           and v.actual_minutes is not null and v.actual_minutes > 0
           and v.visited_at <= now()
           and (p_service_type is null
                or coalesce(v.service_type, 'full_groom') = p_service_type)
         order by v.visited_at desc
         limit 5
      ) sub;
    if coalesce(v_n, 0) >= 3 then
      v_live := (ceil((v_median + coalesce(v_city.hb_buffer_minutes, 15)) / 5.0) * 5)::integer;
    end if;
  end if;

  select bool_or(coat_tier = 'doublecoat') into v_has_double
    from public.bath_dogs where subscriber_id = p_subscriber_id and active;

  v_default := case when coalesce(v_has_double, false)
                    then v_city.hb_doublecoat_minutes
                    else v_city.hb_smoothcoat_minutes end;
  v_min := coalesce(v_city.hb_min_stop_minutes, 30);
  return greatest(v_min, coalesce(v_live, v_hist, v_default, v_min));
end;
$$;

-- 2. Per-appointment dogs.
alter table public.bath_appointments add column if not exists dog_ids uuid[];

drop function if exists public.admin_book_appointment(uuid, timestamptz, boolean);
create or replace function public.admin_book_appointment(
  p_client_id uuid, p_start timestamptz, p_override boolean default false, p_dog_ids uuid[] default null)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $$
declare
  ctx record;
  v_open boolean;
  v_id uuid;
  v_end timestamptz;
  v_dogs uuid[];
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
      status, service_type, amount_cents, dog_count, dog_ids, notes
    ) values (
      ctx.o_sub, ctx.o_subscription, p_start, v_end, ctx.o_dur,
      'confirmed', ctx.o_service, coalesce(ctx.o_price, 0),
      coalesce(array_length(v_dogs, 1), ctx.o_dogs), v_dogs,
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
revoke all on function public.admin_book_appointment(uuid, timestamptz, boolean, uuid[]) from public, anon;
grant execute on function public.admin_book_appointment(uuid, timestamptz, boolean, uuid[]) to authenticated, service_role;

create or replace function public.tracker_status(p_token text)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $$
declare
  a public.bath_appointments%rowtype;
  v public.visits%rowtype;
  v_first text;
  v_dogs jsonb;
  v_stage text;
begin
  if p_token is null or length(p_token) < 16 then
    return jsonb_build_object('found', false);
  end if;

  select * into a from public.bath_appointments where tracker_token = p_token;
  if not found then
    return jsonb_build_object('found', false);
  end if;

  if a.scheduled_end is not null and now() > a.scheduled_end + interval '7 days' then
    return jsonb_build_object('found', true, 'stage', 'expired');
  end if;

  select * into v from public.visits
   where appointment_id = a.id
   order by created_at desc
   limit 1;

  select s.first_name into v_first
    from public.bath_subscribers s where s.id = a.subscriber_id;

  -- An appointment with an assigned dog list shows only those dogs.
  if a.dog_ids is not null and array_length(a.dog_ids, 1) > 0 then
    select coalesce(jsonb_agg(d.name order by d.name), '[]'::jsonb) into v_dogs
      from public.dogs d where d.id = any(a.dog_ids);
  else
    select coalesce(jsonb_agg(d.name order by d.name), '[]'::jsonb) into v_dogs
      from public.bath_dogs d where d.subscriber_id = a.subscriber_id;
  end if;

  v_stage := case
    when a.status in ('cancelled', 'no_show', 'skipped') then 'inactive'
    when a.status = 'completed' or v.departed_at is not null then 'done'
    when a.status = 'returning' then 'returning'
    when a.status = 'in_service' then 'underway'
    when a.status = 'on_site' or v.arrived_at is not null then
      case
        when v.id is not null and exists (
          select 1 from public.visit_photos vp
           where vp.visit_id = v.id and vp.kind = 'before')
          then 'underway'
        else 'arrived'
      end
    when a.status = 'on_the_way' or v.inbound_at is not null then 'on_the_way'
    else 'scheduled'
  end;

  return jsonb_build_object(
    'found', true,
    'stage', v_stage,
    'scheduled_start', a.scheduled_start,
    'scheduled_end', a.scheduled_end,
    'first_name', v_first,
    'dogs', v_dogs
  );
end;
$$;
revoke all on function public.tracker_status(text) from public;
grant execute on function public.tracker_status(text) to anon, authenticated, service_role;

-- 3. Riker: dog_add, dog_update, backdated visits, scores by dog name.
create or replace function public.admin_riker_apply(p_plan jsonb)
returns jsonb
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $$
declare v_client uuid; v_sub uuid; v_admin uuid; v_visit uuid;
        v_scores int := 0; v_note boolean := false; v_dognotes int := 0; r record;
        v_np jsonb; v_np_id uuid; v_status int := 0; v_wisdom text; v_wisdom_saved boolean := false;
        v_rem jsonb; v_rem_id uuid;
        v_added int := 0; v_updated int := 0; v_dog uuid;
        v_scores_j jsonb; v_visit_at timestamptz;
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  v_client := nullif(p_plan->>'client_id','')::uuid;
  v_wisdom := nullif(btrim(coalesce(p_plan->>'wisdom','')),'');
  v_rem := p_plan->'reminder';
  if v_client is null and v_wisdom is null and jsonb_typeof(v_rem) <> 'object' then
    raise exception 'riker: no client resolved';
  end if;
  if v_client is not null and not exists (select 1 from public.clients where id = v_client) then
    raise exception 'riker: client not found';
  end if;
  select id into v_admin from public.admins where auth_user_id = auth.uid();
  if v_client is not null then
    select id into v_sub from public.bath_subscribers where client_id = v_client limit 1;
  end if;

  -- New dog cards first, so the rest of the plan can reference them by name.
  if v_client is not null then
    for r in select btrim(e->>'name') as name, nullif(btrim(coalesce(e->>'breed','')),'') as breed,
                    nullif(e->>'price_cents','')::int as price_cents,
                    nullif(btrim(coalesce(e->>'notes','')),'') as notes
               from jsonb_array_elements(coalesce(p_plan->'dog_add','[]')) e
              where nullif(btrim(coalesce(e->>'name','')),'') is not null
    loop
      if not exists (select 1 from public.dogs d where d.client_id = v_client and lower(d.name) = lower(r.name)) then
        insert into public.dogs (client_id, name, breed, price_cents, notes)
        values (v_client, r.name, r.breed, r.price_cents, r.notes);
        v_added := v_added + 1;
      end if;
    end loop;

    -- Card updates (price, breed) land on the card, never as a note.
    for r in select nullif(e->>'dog_id','')::uuid as dog_id, btrim(coalesce(e->>'dog_name','')) as dog_name,
                    nullif(e->>'price_cents','')::int as price_cents,
                    nullif(btrim(coalesce(e->>'breed','')),'') as breed
               from jsonb_array_elements(coalesce(p_plan->'dog_update','[]')) e
    loop
      v_dog := coalesce(r.dog_id,
        (select d.id from public.dogs d where d.client_id = v_client and lower(d.name) = lower(r.dog_name) limit 1));
      if v_dog is null then continue; end if;
      update public.dogs
         set price_cents = coalesce(r.price_cents, price_cents),
             breed = coalesce(r.breed, breed),
             updated_at = now()
       where id = v_dog and client_id = v_client
         and (r.price_cents is not null or r.breed is not null);
      if found then v_updated := v_updated + 1; end if;
    end loop;
  end if;

  if v_client is not null and jsonb_typeof(p_plan->'visit') = 'object' then
    v_visit_at := coalesce(nullif(p_plan->'visit'->>'visited_at','')::timestamptz, now());

    -- Resolve score entries to dog ids; names work for dogs added above.
    select coalesce(jsonb_agg(jsonb_build_object(
             'dog_id', coalesce(nullif(e->>'dog_id',''),
               (select d.id::text from public.dogs d
                 where d.client_id = v_client and lower(d.name) = lower(btrim(coalesce(e->>'dog_name',''))) limit 1)),
             'score', e->>'score')), '[]'::jsonb)
      into v_scores_j
      from jsonb_array_elements(coalesce(p_plan->'visit'->'dog_scores','[]')) e;

    insert into public.visits (
      client_id, subscriber_id, visited_at, service_type, dog_ids,
      work_done, visit_notes, actual_minutes, amount_collected_cents, payment_method, source, completed_by
    ) values (
      v_client, v_sub, v_visit_at,
      nullif(p_plan->'visit'->>'service_type',''),
      coalesce((select array_agg((e->>'dog_id')::uuid)
                  from jsonb_array_elements(v_scores_j) e
                 where nullif(e->>'dog_id','') is not null
                   and exists (select 1 from public.dogs d where d.id = (e->>'dog_id')::uuid and d.client_id = v_client)), '{}'),
      nullif(p_plan->'visit'->>'work_done',''),
      nullif(p_plan->'visit'->>'visit_notes',''),
      nullif(p_plan->'visit'->>'actual_minutes','')::int,
      nullif(p_plan->'visit'->>'amount_cents','')::int,
      nullif(p_plan->'visit'->>'payment_method',''),
      'riker', v_admin
    ) returning id into v_visit;

    insert into public.visit_dog_ratings (visit_id, dog_id, score)
    select v_visit, (e->>'dog_id')::uuid, (e->>'score')::int
      from jsonb_array_elements(v_scores_j) e
     where nullif(e->>'dog_id','') is not null
       and nullif(e->>'score','') is not null and (e->>'score')::int between 1 and 5
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

  if v_wisdom is not null then
    perform public.admin_capture_wisdom(v_wisdom,
      case when v_client is not null then 'client' else 'unsorted' end,
      v_client, 'riker');
    v_wisdom_saved := true;
  end if;

  if jsonb_typeof(v_rem) = 'object'
     and nullif(btrim(coalesce(v_rem->>'body','')),'') is not null
     and nullif(v_rem->>'due','') is not null then
    v_rem_id := public.admin_add_reminder(
      btrim(v_rem->>'body'), (v_rem->>'due')::date, v_client, 'riker');
  end if;

  return jsonb_build_object('visit_id', v_visit, 'scores_applied', v_scores,
                           'client_note_appended', v_note, 'dog_notes_appended', v_dognotes,
                           'dog_status_changes', v_status, 'notify_person_id', v_np_id,
                           'wisdom_saved', v_wisdom_saved, 'reminder_id', v_rem_id,
                           'dogs_added', v_added, 'dogs_updated', v_updated);
end;
$$;
revoke all on function public.admin_riker_apply(jsonb) from public, anon;
grant execute on function public.admin_riker_apply(jsonb) to authenticated, service_role;

-- 4. Data entry.

-- Eric Shannon: $50 per dog on the cards (Kiera, Rebel).
update public.dogs set price_cents = 5000, updated_at = now()
 where id in ('5ee827ba-c17e-4913-89fd-391d72a58d9b', '9feba0b6-9a5b-49f1-b9cf-a301fed9dc4e');

-- Becky Swinford: Maverick and Sammy as real dog cards.
insert into public.dogs (client_id, name, breed, price_cents)
select '0c16410f-6346-4dba-b3a4-f35592eed0c4', x.name, x.breed, x.price
  from (values ('Maverick', 'French Bulldog', 7500), ('Sammy', 'Mini Aussie', 10500)) x(name, breed, price)
 where not exists (select 1 from public.dogs d
                    where d.client_id = '0c16410f-6346-4dba-b3a4-f35592eed0c4' and lower(d.name) = lower(x.name));

-- Their scores from the April 4 visit (Sammy 4, Maverick 3), on the visit row.
insert into public.visit_dog_ratings (visit_id, dog_id, score)
select '686b1983-df5c-41ef-9f76-036eb29a8c29', d.id, case when d.name = 'Sammy' then 4 else 3 end
  from public.dogs d
 where d.client_id = '0c16410f-6346-4dba-b3a4-f35592eed0c4' and d.name in ('Maverick', 'Sammy')
on conflict (visit_id, dog_id) do update set score = excluded.score;

update public.visits v
   set dog_ids = (select coalesce(array_agg(d.id), '{}') from public.dogs d
                   where d.client_id = v.client_id and d.name in ('Maverick', 'Sammy'))
 where v.id = '686b1983-df5c-41ef-9f76-036eb29a8c29';

-- Clear the mis-filed instruction note now that the dogs exist.
update public.clients set note = null, updated_at = now()
 where id = '0c16410f-6346-4dba-b3a4-f35592eed0c4'
   and note = 'Add two new dogs: Maverick (French Bulldog, $75) and Sammy (Mini Aussie, $105).';

-- Emily Walker: Cavaliers to $105 each, grooming groups noted.
update public.dogs set price_cents = 10500, updated_at = now()
 where id in ('ca2651cf-2d08-4999-b4ca-07ef1d4cf7b2', '95338ce2-2d38-4336-b6d8-385e2955eb65');
update public.clients
   set note = coalesce(note || ' ; ', '') ||
       'Grooming groups: the two Cavaliers (Reagan and Daisy) are usually groomed together; Summer the Golden is on her own separate schedule. Assign dogs per appointment.',
       updated_at = now()
 where id = '78753a8f-f535-4f25-ac7d-090a40c546ea'
   and coalesce(note, '') not like '%Grooming groups%';

-- Mary Brantley: unarchive and enrich the real record.
update public.clients set
  archived_at = null,
  status = 'active',
  service_type = 'full_groom',
  location_address = '727 NW 56th St, Ocala, FL 34475',
  location_zip = '34475',
  email = 'mfbrantley59@aol.com',
  relationships = array['Jane Henrich is her daughter, lives next door; Kuku''s nails have historically been done during Jane''s appointments'],
  onsite_people = 'Scot Brantley (husband; Lewy body dementia; former Tampa Bay Buccaneers linebacker). Lawana Glover (Scot''s daytime caregiver while Mary works, 352-299-6598); sometimes the contact when she is there taking care of the dogs.',
  data_gaps = array['phone_number', 'cadence_unknown'],
  note = 'Enriched 2026-06-11 from Paul. Previously groomed her two Great Pyrenees (Anna and Elsa) until they went to a new home; since then Kuku nails $30 cash alongside Jane Henrich''s appointments next door.',
  updated_at = now()
 where id = '212a24e9-ab33-4f4f-9981-ad539945e7f5';

update public.clients
   set relationships = array_append(relationships, 'Mary Brantley is her mother, lives next door; Scot Brantley is her stepfather'),
       updated_at = now()
 where id = 'dc20f4a6-354c-416f-8eab-fd19af242384'
   and not ('Mary Brantley is her mother, lives next door; Scot Brantley is her stepfather' = any(relationships));

insert into public.dogs (client_id, name, breed, price_cents, notes, standing_instructions, roster_status)
select '212a24e9-ab33-4f4f-9981-ad539945e7f5', x.name, x.breed, x.price, x.notes, x.standing, x.status
  from (values
    ('Mutley', 'Poodle mix (many breeds in her)', 10500,
     'Scot got her for Christmas. Needs her first groom ASAP.', null, 'regular'),
    ('Kuku', 'Mixed breed (medium)', 3000,
     'Nails for several years, usually $30 cash, historically done alongside Jane Henrich''s appointments next door.',
     'Nails plus shave the foot pads so she does not slip on the hard floors.', 'regular'),
    ('Anna', 'Great Pyrenees', null, 'Went to a new home; groomed for a while years ago.', null, 'former'),
    ('Elsa', 'Great Pyrenees', null, 'Went to a new home; groomed for a while years ago.', null, 'former')
  ) x(name, breed, price, notes, standing, status)
 where not exists (select 1 from public.dogs d
                    where d.client_id = '212a24e9-ab33-4f4f-9981-ad539945e7f5' and lower(d.name) = lower(x.name));

-- Lawana as a toggleable tracker/notification contact, off until Paul flips her on.
insert into public.notify_people (client_id, name, phone_e164, relationship, mode, active)
select '212a24e9-ab33-4f4f-9981-ad539945e7f5', 'Lawana Glover', '+13522996598', 'caregiver for Scot, weekdays', 'in_addition', false
 where not exists (select 1 from public.notify_people
                    where client_id = '212a24e9-ab33-4f4f-9981-ad539945e7f5' and phone_e164 = '+13522996598');

-- The commitment Paul made at the door: opening in the next few days, or contact in 2 weeks.
insert into public.reminders (body, due_date, client_id, source)
select 'Contact Mary Brantley about grooming Mutley ($105, needs it ASAP). Told her 2026-06-11: maybe an opening in the next few days, otherwise contact her in 2 weeks. No phone on file yet, email mfbrantley59@aol.com, or via Jane Henrich next door.',
       '2026-06-25', '212a24e9-ab33-4f4f-9981-ad539945e7f5', 'manual'
 where not exists (select 1 from public.reminders
                    where client_id = '212a24e9-ab33-4f4f-9981-ad539945e7f5' and status = 'open');
