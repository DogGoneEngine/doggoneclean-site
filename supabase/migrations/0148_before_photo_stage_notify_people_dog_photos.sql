-- 0148: field feedback round two (Paul, 2026-06-10, after the tracker's first
-- real client use with Michelle).
--
-- 1. UNDERWAY TRIGGERS ON THE BEFORE PHOTO, not a 10-minute timer. Paul can
--    still be in the client's living room at minute ten, and a tracker that
--    says "in the trailer" while he is on their couch is a lie. The before
--    photo is the one signal that is true by construction: he takes it in
--    the trailer, right before the work starts. No photo, no auto-advance;
--    the stage simply stays "We're here" until the bringing-them-back tap.
-- 2. notify_people: more people than the account holder can receive the
--    appointment messages. A spouse who also wants the texts (standing), or
--    Jane Henrich's dog sitter while she is away (temporary, with an end
--    date), in addition to or instead of the client. The dispatcher reads
--    _notify_recipients; Riker learns to file "text the sitter instead"
--    by voice. When Twilio lands, the first message to a new person opens
--    with "[Client] asked us to keep you up to speed on [dog]'s visits"
--    (opt_in_sent_at tracks it): courtesy and A2P compliance in one line.
-- 3. visit_photos.dog_id: photos can name which dog they show. The upload
--    UI was silently assuming a one-dog household; multi-dog clients are
--    the norm. Tag is optional (a whole-pack shot is real too).
-- Grants explicit per rpc_grants_explicit (functions are born locked).

-- 1 ─ tracker stage: before photo flips arrived -> underway ───────────────
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

  select coalesce(jsonb_agg(d.name order by d.name), '[]'::jsonb) into v_dogs
    from public.bath_dogs d where d.subscriber_id = a.subscriber_id;

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

-- 2 ─ people to notify ────────────────────────────────────────────────────
create table if not exists public.notify_people (
  id uuid primary key default gen_random_uuid(),
  client_id uuid references public.clients(id) on delete cascade,
  subscriber_id uuid references public.bath_subscribers(id) on delete cascade,
  name text not null,
  phone_e164 text,
  email text,
  relationship text,
  mode text not null default 'in_addition' check (mode in ('in_addition', 'instead')),
  active boolean not null default true,
  until_date date,
  opt_in_sent_at timestamptz,
  created_at timestamptz not null default now(),
  check (client_id is not null or subscriber_id is not null),
  check (phone_e164 is not null or email is not null)
);
alter table public.notify_people enable row level security;
create index if not exists notify_people_client_idx on public.notify_people (client_id);
create index if not exists notify_people_subscriber_idx on public.notify_people (subscriber_id);

create or replace function public.admin_upsert_notify_person(
  p_id uuid,
  p_client_id uuid,
  p_name text,
  p_phone text,
  p_email text,
  p_relationship text,
  p_mode text,
  p_until date
) returns uuid
language plpgsql
security definer
set search_path to ''
as $$
declare v_id uuid;
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  if nullif(btrim(coalesce(p_name, '')), '') is null then raise exception 'name required'; end if;
  if nullif(btrim(coalesce(p_phone, '')), '') is null and nullif(btrim(coalesce(p_email, '')), '') is null then
    raise exception 'phone or email required';
  end if;
  if p_mode not in ('in_addition', 'instead') then raise exception 'bad mode'; end if;

  if p_id is not null then
    update public.notify_people
       set name = btrim(p_name), phone_e164 = nullif(btrim(coalesce(p_phone, '')), ''),
           email = nullif(btrim(coalesce(p_email, '')), ''),
           relationship = nullif(btrim(coalesce(p_relationship, '')), ''),
           mode = p_mode, until_date = p_until
     where id = p_id
     returning id into v_id;
    if v_id is null then raise exception 'notify person not found'; end if;
    return v_id;
  end if;

  insert into public.notify_people (client_id, subscriber_id, name, phone_e164, email, relationship, mode, until_date)
  values (
    p_client_id,
    (select id from public.bath_subscribers where client_id = p_client_id limit 1),
    btrim(p_name),
    nullif(btrim(coalesce(p_phone, '')), ''),
    nullif(btrim(coalesce(p_email, '')), ''),
    nullif(btrim(coalesce(p_relationship, '')), ''),
    p_mode, p_until
  ) returning id into v_id;
  return v_id;
end;
$$;
revoke all on function public.admin_upsert_notify_person(uuid, uuid, text, text, text, text, text, date) from public;
grant execute on function public.admin_upsert_notify_person(uuid, uuid, text, text, text, text, text, date) to authenticated, service_role;

create or replace function public.admin_set_notify_person_active(p_id uuid, p_active boolean)
returns void
language plpgsql
security definer
set search_path to ''
as $$
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  update public.notify_people set active = p_active where id = p_id;
  if not found then raise exception 'notify person not found'; end if;
end;
$$;
revoke all on function public.admin_set_notify_person_active(uuid, boolean) from public;
grant execute on function public.admin_set_notify_person_active(uuid, boolean) to authenticated, service_role;

create or replace function public.admin_delete_notify_person(p_id uuid)
returns void
language plpgsql
security definer
set search_path to ''
as $$
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  delete from public.notify_people where id = p_id;
end;
$$;
revoke all on function public.admin_delete_notify_person(uuid) from public;
grant execute on function public.admin_delete_notify_person(uuid) to authenticated, service_role;

create or replace function public.admin_list_notify_people(p_client_id uuid)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $$
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  return coalesce((
    select jsonb_agg(to_jsonb(np.*) order by np.created_at)
      from public.notify_people np
     where np.client_id = p_client_id
        or np.subscriber_id in (select id from public.bath_subscribers where client_id = p_client_id)
  ), '[]'::jsonb);
end;
$$;
revoke all on function public.admin_list_notify_people(uuid) from public;
grant execute on function public.admin_list_notify_people(uuid) to authenticated, service_role;

-- The dispatcher's one question: who actually receives this subscriber's
-- messages right now? The client themselves, unless an active 'instead'
-- person covers today; plus every active 'in_addition' person. A lapsed
-- until_date silently drops the person out (the sitter toggle expires on
-- its own; nobody has to remember to turn it off).
create or replace function public._notify_recipients(p_subscriber_id uuid)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $$
declare
  s public.bath_subscribers%rowtype;
  v_replaced boolean;
  v_out jsonb := '[]'::jsonb;
begin
  select * into s from public.bath_subscribers where id = p_subscriber_id;
  if not found then return '[]'::jsonb; end if;

  select exists (
    select 1 from public.notify_people np
     where (np.subscriber_id = s.id or (s.client_id is not null and np.client_id = s.client_id))
       and np.active and np.mode = 'instead'
       and (np.until_date is null or np.until_date >= current_date)
  ) into v_replaced;

  if not v_replaced then
    v_out := v_out || jsonb_build_object(
      'name', coalesce(s.first_name, '') || case when s.last_name is not null then ' ' || s.last_name else '' end,
      'email', s.email, 'phone', s.phone_e164, 'source', 'client', 'notify_person_id', null);
  end if;

  return v_out || coalesce((
    select jsonb_agg(jsonb_build_object(
      'name', np.name, 'email', np.email, 'phone', np.phone_e164,
      'source', np.mode, 'notify_person_id', np.id) order by np.created_at)
      from public.notify_people np
     where (np.subscriber_id = s.id or (s.client_id is not null and np.client_id = s.client_id))
       and np.active
       and (np.until_date is null or np.until_date >= current_date)
  ), '[]'::jsonb);
end;
$$;
revoke all on function public._notify_recipients(uuid) from public;
grant execute on function public._notify_recipients(uuid) to service_role;

-- 3 ─ per-dog photo tagging ───────────────────────────────────────────────
alter table public.visit_photos
  add column if not exists dog_id uuid references public.dogs(id) on delete set null;

drop function if exists public.admin_add_visit_photo(uuid, text, text);
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
  insert into public.visit_photos (visit_id, kind, storage_path, dog_id)
  values (p_visit_id, p_kind, p_path, p_dog_id) returning id into v_id;
  return v_id;
end;
$$;
revoke all on function public.admin_add_visit_photo(uuid, text, text, uuid) from public;
grant execute on function public.admin_add_visit_photo(uuid, text, text, uuid) to authenticated, service_role;

create or replace function public.admin_set_photo_dog(p_id uuid, p_dog_id uuid)
returns void language plpgsql security definer set search_path = public, pg_temp
as $$
declare v_client uuid;
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  select v.client_id into v_client
    from public.visit_photos vp join public.visits v on v.id = vp.visit_id
   where vp.id = p_id;
  if not found then raise exception 'photo not found'; end if;
  if p_dog_id is not null and not exists (
    select 1 from public.dogs d where d.id = p_dog_id and d.client_id = v_client
  ) then raise exception 'dog does not belong to this client'; end if;
  update public.visit_photos set dog_id = p_dog_id where id = p_id;
end;
$$;
revoke all on function public.admin_set_photo_dog(uuid, uuid) from public;
grant execute on function public.admin_set_photo_dog(uuid, uuid) to authenticated, service_role;

-- admin_get_client: photos carry dog_id + dog_name; the sheet renders and
-- retro-tags them.
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
  return result;
end;
$function$;
revoke all on function public.admin_get_client(uuid) from public, anon;
grant execute on function public.admin_get_client(uuid) to authenticated, service_role;

-- The client's portal photos carry the dog's name too ("Before, Bella").
create or replace function public.bath_my_visit_photos()
returns jsonb
language plpgsql
security definer
set search_path to ''
as $$
declare
  s public.bath_subscribers%rowtype;
begin
  select * into s from public.bath_subscribers where auth_user_id = auth.uid() limit 1;
  if not found then
    return '[]'::jsonb;
  end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', vp.id,
      'kind', vp.kind,
      'path', vp.storage_path,
      'visited_at', v.visited_at,
      'dog_name', d.name
    ) order by v.visited_at desc, vp.created_at)
      from public.visit_photos vp
      join public.visits v on v.id = vp.visit_id
      left join public.dogs d on d.id = vp.dog_id
     where vp.client_visible
       and (v.subscriber_id = s.id
            or (v.client_id is not null and v.client_id = s.client_id))
  ), '[]'::jsonb);
end;
$$;
revoke all on function public.bath_my_visit_photos() from public, anon;
grant execute on function public.bath_my_visit_photos() to authenticated, service_role;

-- 4 ─ Riker learns notify people ──────────────────────────────────────────
-- Context: a fixed client's existing notify people ride along so the parser
-- can update rather than duplicate.
create or replace function public.admin_riker_context(p_client_id uuid default null)
returns jsonb language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  if p_client_id is not null then
    return (select jsonb_build_object(
        'client', jsonb_build_object('id', c.id, 'name', c.name),
        'dogs', coalesce((select jsonb_agg(jsonb_build_object('id', d.id, 'name', d.name) order by d.name)
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
        'dogs', coalesce((select jsonb_agg(jsonb_build_object('id', d.id, 'name', d.name) order by d.name)
                            from public.dogs d where d.client_id = c.id), '[]'::jsonb))
      order by c.name)
    from public.clients c
   where c.exclude_from_everything = false and c.archived_at is null), '[]'::jsonb));
end;
$$;
revoke all on function public.admin_riker_context(uuid) from public, anon;
grant execute on function public.admin_riker_context(uuid) to authenticated, service_role;

-- Apply: the plan may carry a notify_person to add (or re-point by id).
create or replace function public.admin_riker_apply(p_plan jsonb)
returns jsonb language plpgsql security definer set search_path = public, pg_temp
as $$
declare v_client uuid; v_sub uuid; v_admin uuid; v_visit uuid;
        v_scores int := 0; v_note boolean := false; v_dognotes int := 0; r record;
        v_np jsonb; v_np_id uuid;
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

  -- "Text the sitter instead of Jane until July" lands here, by voice.
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
                           'notify_person_id', v_np_id);
end;
$$;
revoke all on function public.admin_riker_apply(jsonb) from public, anon;
grant execute on function public.admin_riker_apply(jsonb) to authenticated, service_role;
