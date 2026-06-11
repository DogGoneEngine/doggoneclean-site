-- 0156: Paul's 2026-06-11 late batch: Riker round two (contact and visit
-- corrections, with the failures fixed in data), Brooksley closed out, the
-- Mary Jane Hunt capacity false alarm resolved (root cause: the calendar
-- sync window was 45 days while Paul pencils a year ahead; the Apps Script
-- now reads 366 days), bogus shared geocodes cleared (three clients whose
-- address column literally said "PlusCode Ocala" all geocoded to the same
-- point, poisoning drive times), calendar sync hardening (adopt app-booked
-- rows instead of duplicating them, never die on one collision), and the
-- infrastructure watcher (database + storage usage against plan limits).

-- 1. Mary Brantley: the 2025-05-14 visit was Kuku's nails, not a full
-- groom; Riker's duplicate row from the failed correction is removed; her
-- phone is on file now so the data gap closes.
update public.visits set service_type = 'nails'
 where id = 'd4f216ef-086b-4921-8ac6-fbed8fdc9621';
delete from public.visit_dog_ratings
 where visit_id = 'c62cb9d6-09ba-4c48-94f7-ac230f3e8fa2';
delete from public.visits
 where id = 'c62cb9d6-09ba-4c48-94f7-ac230f3e8fa2' and source = 'riker';
update public.clients set
  phone_e164 = '+13528754172',
  data_gaps = array_remove(coalesce(data_gaps, '{}'), 'phone_number'),
  updated_at = now()
 where id = '212a24e9-ab33-4f4f-9981-ad539945e7f5';

-- 2. Brooksley Sheehe: moved away, may or may not be back, knows to contact
-- us. No outreach; the win-back card closes with the reason.
update public.clients set
  status = 'moved_away',
  suppress_winback = true,
  note = coalesce(note || ' ; ', '') ||
    '2026-06-11 Paul: moved away, may or may not be back; she knows to contact us if she will be in Ocala. No outreach.',
  updated_at = now()
 where id = 'a87cc22c-b66d-48ce-8477-b236ba9397de' and not suppress_winback;
update public.briefings set status = 'resolved', acted_at = now(),
  disposition = 'Marked moved away and win-back suppressed (Paul, 2026-06-11): she knows to contact us if she returns to Ocala.'
 where id = '275e4b25-e7b5-452d-ad4f-a769d8544ce5' and status <> 'resolved';

-- 3. Capacity card on Mary Jane Hunt: false alarm. Her future appointments
-- live in Paul's Google Calendar beyond the old 45-day sync window, so the
-- app could not see them. The Apps Script window is now 366 days; once Paul
-- re-pastes it her bookings sync in and the scan skips her like anyone else
-- with a future appointment.
update public.briefings set status = 'resolved', acted_at = now(),
  disposition = 'False alarm: the client has future appointments in the Google calendar beyond the old 45-day sync window. Sync window widened to 366 days; they will count once the updated Apps Script is pasted.'
 where id = '15e94dd2-98f6-4f0a-b214-605a15b49d7d' and status <> 'resolved';

-- 4. Three clients whose address column literally says "PlusCode Ocala"
-- were all geocoded to one identical point. Clear it; the edge functions
-- now geocode from the real plus code and persist honest coordinates.
update public.bath_subscribers s set service_lat = null, service_lng = null
  from public.clients c
 where c.id = s.client_id and c.location_address ilike 'PlusCode Ocala%';
update public.clients set geo_lat = null, geo_lng = null, updated_at = now()
 where location_address ilike 'PlusCode Ocala%';

-- 5. Calendar sync hardening. (a) When a synced event lands on top of an
-- app-booked appointment (Paul booked in Orbit and tapped Add to Google
-- Calendar), ADOPT the existing row by stamping its external_id instead of
-- inserting a duplicate; from then on moving the event in Google Calendar
-- moves the appointment here. Adopted rows keep source null so the prune
-- (which only deletes source='gcal_sync') can never remove an app booking.
-- (b) One exclusion-constraint collision no longer aborts the whole run.
-- (c) The update branch no longer overwrites source.
create or replace function public._sync_appointments(p_events jsonb)
returns jsonb
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $$
declare e record; v_name text; v_tentative boolean; v_status text;
        v_client uuid; v_sub uuid; v_appt uuid; v_starts timestamptz; v_ends timestamptz;
        v_ins int:=0; v_upd int:=0; v_adopt int:=0; v_skip int:=0; v_unmatched jsonb:='[]'::jsonb;
begin
  for e in select * from jsonb_to_recordset(p_events) as x(
      external_id text, starts timestamptz, ends timestamptz, client_name text, client_email text,
      dog_count int, service_type text, amount_cents int, notes text, tentative boolean)
  loop
    v_tentative := coalesce(e.tentative, false) or right(btrim(e.client_name), 1) = '?';
    v_status := case when v_tentative then 'tentative' else 'confirmed' end;
    v_name := lower(btrim(rtrim(btrim(e.client_name), '? ')));
    select c.id into v_client from public.clients c
     where not c.exclude_from_everything and (
        lower(btrim(c.name)) = v_name
        or exists (select 1 from public.client_aliases a where a.client_id=c.id and lower(btrim(a.alias))=v_name)
        or (nullif(btrim(e.client_email),'') is not null and lower(c.email)=lower(btrim(e.client_email)))
     )
     order by (lower(btrim(c.name))=v_name) desc
     limit 1;
    if v_client is null then v_unmatched := v_unmatched || to_jsonb(e.client_name); continue; end if;
    select id into v_sub from public.bath_subscribers where client_id=v_client limit 1;
    if v_sub is null then insert into public.bath_subscribers (client_id) values (v_client) returning id into v_sub; end if;
    select id into v_appt from public.bath_appointments where external_id = e.external_id;

    if v_appt is null then
      -- Adopt an overlapping app-booked row for the same subscriber.
      v_starts := e.starts; v_ends := coalesce(e.ends, e.starts + interval '60 minutes');
      select id into v_appt from public.bath_appointments a
       where a.subscriber_id = v_sub and a.external_id is null
         and a.status not in ('cancelled', 'no_show', 'skipped')
         and a.scheduled_start < v_ends and coalesce(a.scheduled_end, a.scheduled_start) > v_starts
       order by a.scheduled_start limit 1;
      if v_appt is not null then
        update public.bath_appointments set external_id = e.external_id, updated_at = now()
         where id = v_appt;
        v_adopt := v_adopt + 1;
        continue;
      end if;
      begin
        insert into public.bath_appointments (subscriber_id, scheduled_start, scheduled_end, status, service_type, amount_cents, dog_count, source, external_id, notes)
        values (v_sub, e.starts, e.ends, v_status, coalesce(e.service_type,'full_groom'), coalesce(e.amount_cents,0), coalesce(e.dog_count,1), 'gcal_sync', e.external_id, e.notes);
        v_ins := v_ins + 1;
      exception when exclusion_violation then
        v_skip := v_skip + 1;
        v_unmatched := v_unmatched || to_jsonb('overlap skipped: ' || e.client_name);
      end;
    else
      begin
        update public.bath_appointments set subscriber_id=v_sub, scheduled_start=e.starts, scheduled_end=e.ends,
          status = case when status in ('requested','confirmed','tentative') then v_status else status end,
          service_type=coalesce(e.service_type,service_type), amount_cents=coalesce(e.amount_cents,amount_cents),
          dog_count=coalesce(e.dog_count,dog_count,1), notes=coalesce(e.notes,notes), updated_at=now()
         where id=v_appt;
        v_upd := v_upd + 1;
      exception when exclusion_violation then
        v_skip := v_skip + 1;
        v_unmatched := v_unmatched || to_jsonb('move skipped (overlap): ' || e.client_name);
      end;
    end if;
  end loop;
  return jsonb_build_object('inserted', v_ins, 'updated', v_upd, 'adopted', v_adopt,
                            'skipped', v_skip, 'unmatched', v_unmatched);
end;
$$;
revoke all on function public._sync_appointments(jsonb) from public, anon, authenticated;
grant execute on function public._sync_appointments(jsonb) to service_role;

-- 6. Infrastructure watcher: usage snapshots + a daily check against plan
-- limits (limits live in app_secrets so a plan change is one row, not a
-- deploy: infra_db_limit_mb default 500, infra_storage_limit_mb default 1000,
-- the Supabase free-tier numbers).
create table if not exists public.infra_metrics (
  id uuid primary key default gen_random_uuid(),
  db_bytes bigint not null,
  storage_bytes bigint not null,
  storage_objects integer not null,
  taken_at timestamptz not null default now()
);
alter table public.infra_metrics enable row level security;

create or replace function public._infra_scan()
returns void
language plpgsql
security definer
set search_path to ''
as $$
declare
  v_db bigint; v_st bigint; v_objs int;
  v_db_limit numeric; v_st_limit numeric;
  v_db_mb numeric; v_st_mb numeric;
  v_msgs text := '';
begin
  select pg_database_size(current_database()) into v_db;
  select coalesce(sum((metadata->>'size')::bigint), 0), count(*) into v_st, v_objs from storage.objects;
  insert into public.infra_metrics (db_bytes, storage_bytes, storage_objects) values (v_db, v_st, v_objs);
  delete from public.infra_metrics where taken_at < now() - interval '400 days';

  v_db_limit := coalesce((select value::numeric from public.app_secrets where name = 'infra_db_limit_mb'), 500);
  v_st_limit := coalesce((select value::numeric from public.app_secrets where name = 'infra_storage_limit_mb'), 1000);
  v_db_mb := v_db / 1048576.0;
  v_st_mb := v_st / 1048576.0;

  if v_db_mb > v_db_limit * 0.7 then
    v_msgs := v_msgs || format('Database is at %s MB of the %s MB plan limit (%s%%). ',
      round(v_db_mb), round(v_db_limit), round(v_db_mb / v_db_limit * 100));
  end if;
  if v_st_mb > v_st_limit * 0.7 then
    v_msgs := v_msgs || format('Storage is at %s MB of the %s MB plan limit (%s%%). ',
      round(v_st_mb), round(v_st_limit), round(v_st_mb / v_st_limit * 100));
  end if;

  if v_msgs <> '' and not exists (
    select 1 from public.briefings where agent_key = 'infra' and status in ('new', 'read')
  ) then
    insert into public.briefings (agent_key, department, severity, title, body, status)
    values ('infra', 'operations', 'alert', 'Infrastructure usage approaching plan limits',
      v_msgs || 'Options: prune old photos, or move up a Supabase plan tier. Limits are set in app_secrets (infra_db_limit_mb, infra_storage_limit_mb); update them if the plan changed.',
      'new');
  end if;
end;
$$;
revoke all on function public._infra_scan() from public, anon, authenticated;
grant execute on function public._infra_scan() to service_role;

create or replace function public.admin_infra_status()
returns jsonb
language plpgsql
security definer
set search_path to ''
as $$
declare v_db bigint; v_st bigint; v_objs int; v_prev record;
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  select pg_database_size(current_database()) into v_db;
  select coalesce(sum((metadata->>'size')::bigint), 0), count(*) into v_st, v_objs from storage.objects;
  select db_bytes, storage_bytes into v_prev from public.infra_metrics
   where taken_at < now() - interval '25 days' order by taken_at desc limit 1;
  return jsonb_build_object(
    'db_bytes', v_db,
    'storage_bytes', v_st,
    'storage_objects', v_objs,
    'db_limit_mb', coalesce((select value::numeric from public.app_secrets where name = 'infra_db_limit_mb'), 500),
    'storage_limit_mb', coalesce((select value::numeric from public.app_secrets where name = 'infra_storage_limit_mb'), 1000),
    'db_bytes_30d_ago', v_prev.db_bytes,
    'storage_bytes_30d_ago', v_prev.storage_bytes,
    'top_tables', coalesce((
      select jsonb_agg(jsonb_build_object('name', relname, 'bytes', sz) order by sz desc)
        from (select c.relname, pg_total_relation_size(c.oid) as sz
                from pg_class c join pg_namespace n on n.oid = c.relnamespace
               where n.nspname = 'public' and c.relkind = 'r'
               order by pg_total_relation_size(c.oid) desc limit 5) t), '[]'::jsonb));
end;
$$;
revoke all on function public.admin_infra_status() from public, anon;
grant execute on function public.admin_infra_status() to authenticated, service_role;

insert into public.agents (agent_key, label, department, description, schedule_cron, is_active)
values ('infra', 'Infrastructure', 'operations',
        'Watches database and storage usage against plan limits and cards Today before anything fills up.',
        '45 11 * * *', true)
on conflict (agent_key) do nothing;
select cron.schedule('infra-daily', '45 11 * * *', 'select public._infra_scan();');

-- 7. Riker round two. Context: the fixed-client payload now carries contact
-- facts and the recent visit list, so corrections can target real rows.
create or replace function public.admin_riker_context(p_client_id uuid default null::uuid)
returns jsonb
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $$
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  if p_client_id is not null then
    return (select jsonb_build_object(
        'client', jsonb_build_object('id', c.id, 'name', c.name),
        'contact', jsonb_build_object('phone', c.phone_e164, 'email', c.email,
                     'address', c.location_address, 'status', c.status,
                     'suppress_winback', c.suppress_winback),
        'last_visit', (select max(v.visited_at)::date from public.visits v
                        where v.client_id = c.id and v.visited_at <= now()),
        'next_appointment', (select min(a.scheduled_start) from public.bath_appointments a
                              join public.bath_subscribers s on s.id = a.subscriber_id
                             where s.client_id = c.id and a.scheduled_start > now()
                               and a.status not in ('cancelled', 'no_show', 'skipped')),
        'recent_visits', coalesce((select jsonb_agg(jsonb_build_object(
                            'date', (v.visited_at)::date, 'service_type', v.service_type,
                            'amount_cents', v.amount_collected_cents, 'minutes', v.actual_minutes)
                            order by v.visited_at desc)
                            from (select * from public.visits where client_id = c.id
                                   order by visited_at desc limit 6) v), '[]'::jsonb),
        'dogs', coalesce((select jsonb_agg(jsonb_build_object('id', d.id, 'name', d.name,
                            'breed', d.breed, 'price_cents', d.price_cents,
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

-- Apply: client_update (contact facts, moved away, win-back suppression)
-- and visit_update (correct an existing visit instead of inventing one).
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
        v_cli jsonb; v_client_updated boolean := false;
        v_vu jsonb; v_vu_id uuid; v_visit_corrected boolean := false; v_vu_missed boolean := false;
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

  -- Contact-sheet facts: phone, email, address, moved away, no-outreach.
  v_cli := p_plan->'client_update';
  if v_client is not null and jsonb_typeof(v_cli) = 'object' then
    update public.clients set
      phone_e164 = coalesce(nullif(v_cli->>'phone',''), phone_e164),
      email = coalesce(nullif(v_cli->>'email',''), email),
      location_address = coalesce(nullif(v_cli->>'address',''), location_address),
      suppress_winback = coalesce(nullif(v_cli->>'suppress_winback','')::boolean, suppress_winback),
      status = case when v_cli->>'status' in ('active','standing','one_off','at_will','inactive','moved_away')
                    then v_cli->>'status' else status end,
      data_gaps = case when nullif(v_cli->>'phone','') is not null
                       then array_remove(coalesce(data_gaps,'{}'), 'phone_number') else data_gaps end,
      updated_at = now()
     where id = v_client;
    v_client_updated := true;
  end if;

  -- Correct an EXISTING visit (wrong service, wrong amount) by its date.
  v_vu := p_plan->'visit_update';
  if v_client is not null and jsonb_typeof(v_vu) = 'object' and nullif(v_vu->>'date','') is not null then
    select id into v_vu_id from public.visits
     where client_id = v_client
       and visited_at::date between (v_vu->>'date')::date - 1 and (v_vu->>'date')::date + 1
     order by abs(extract(epoch from visited_at - ((v_vu->>'date')::date::timestamp + interval '16 hours')))
     limit 1;
    if v_vu_id is null then
      v_vu_missed := true;
    else
      update public.visits set
        service_type = coalesce(nullif(v_vu->>'service_type',''), service_type),
        amount_collected_cents = coalesce(nullif(v_vu->>'amount_cents','')::int, amount_collected_cents),
        actual_minutes = coalesce(nullif(v_vu->>'actual_minutes','')::int, actual_minutes),
        visit_notes = case when nullif(btrim(coalesce(v_vu->>'visit_notes','')),'') is not null
                           then coalesce(visit_notes || ' ; ', '') || btrim(v_vu->>'visit_notes')
                           else visit_notes end
       where id = v_vu_id;
      v_visit_corrected := true;
    end if;
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
                           'dogs_added', v_added, 'dogs_updated', v_updated,
                           'client_updated', v_client_updated,
                           'visit_corrected', v_visit_corrected, 'visit_update_missed', v_vu_missed);
end;
$$;
revoke all on function public.admin_riker_apply(jsonb) from public, anon;
grant execute on function public.admin_riker_apply(jsonb) to authenticated, service_role;
