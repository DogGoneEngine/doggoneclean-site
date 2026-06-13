-- 0187_riker_equipment_service.sql
--
-- Teach Riker to log generator/equipment maintenance and hours by voice, the
-- same gateway pattern as visits and birthdays. Paul told Riker "we changed the
-- oil and the spark plug, the panel reads 662 hours on the passenger side
-- generator" and it had nowhere to put it: admin_riker_context did not list the
-- equipment, the parse had no field for service, and admin_riker_apply could not
-- write it. This adds all three:
--   1. admin_riker_context returns the active generators (id, name, side, what
--      each powers, current hours, and its task names) so the model can resolve
--      "passenger side" / "the one that runs the AC" to the right unit and use
--      the real task names.
--   2. admin_riker_apply consumes equipment_service: per unit, set the hour
--      reading and mark the named maintenance tasks done (last_done_hours +
--      last_done_date), matched against that unit's task list.
-- The riker edge function (prompt + JSON schema) is updated and redeployed
-- alongside this migration.

-- ── Context: include the generators so Riker can resolve and service them ────
create or replace function public.admin_riker_context(p_client_id uuid default null)
returns jsonb language plpgsql security definer set search_path to 'public', 'pg_temp'
as $function$
declare v_equipment jsonb;
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;

  v_equipment := coalesce((
    select jsonb_agg(jsonb_build_object(
        'id', e.id, 'name', e.name, 'side', e.side,
        'current_hours', e.current_hours, 'powers', e.notes,
        'tasks', coalesce((select jsonb_agg(t.task order by t.task)
                             from public.maintenance_tasks t
                            where t.equipment_id = e.id and coalesce(t.active, true)), '[]'::jsonb))
      order by e.name)
    from public.equipment e
   where coalesce(e.active, true) and e.kind = 'generator'), '[]'::jsonb);

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
                            from public.notify_people np where np.client_id = c.id), '[]'::jsonb),
        'equipment', v_equipment)
      from public.clients c where c.id = p_client_id);
  end if;
  return jsonb_build_object(
    'equipment', v_equipment,
    'clients', coalesce((
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
$function$;
revoke all on function public.admin_riker_context(uuid) from public, anon;
grant execute on function public.admin_riker_context(uuid) to authenticated, service_role;

-- ── Apply: write the generator hours and mark the serviced tasks done ────────
create or replace function public.admin_riker_apply(p_plan jsonb)
returns jsonb language plpgsql security definer set search_path to 'public', 'pg_temp'
as $function$
declare v_client uuid; v_sub uuid; v_admin uuid; v_visit uuid;
        v_scores int := 0; v_note boolean := false; v_dognotes int := 0; r record;
        v_np jsonb; v_np_id uuid; v_status int := 0; v_wisdom text; v_wisdom_saved boolean := false;
        v_rem jsonb; v_rem_id uuid;
        v_added int := 0; v_updated int := 0; v_dog uuid;
        v_scores_j jsonb; v_visit_at timestamptz; v_raw text;
        v_cli jsonb; v_client_updated boolean := false;
        v_vu jsonb; v_vu_id uuid; v_visit_corrected boolean := false; v_vu_missed boolean := false;
        v_visit_merged boolean := false; v_new_dog_ids uuid[];
        v_onsite text; v_onsite_appended boolean := false;
        v_es jsonb; v_equip int := 0; v_equip_tasks int := 0; v_etask_count int;
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  v_client := nullif(p_plan->>'client_id','')::uuid;
  v_wisdom := nullif(btrim(coalesce(p_plan->>'wisdom','')),'');
  v_rem := p_plan->'reminder';
  v_es := p_plan->'equipment_service';
  if v_client is null and v_wisdom is null and jsonb_typeof(v_rem) <> 'object'
     and not (jsonb_typeof(v_es) = 'array' and jsonb_array_length(v_es) > 0) then
    raise exception 'riker: no client resolved';
  end if;
  if v_client is not null and not exists (select 1 from public.clients where id = v_client) then
    raise exception 'riker: client not found';
  end if;
  select id into v_admin from public.admins where auth_user_id = auth.uid();
  if v_client is not null then
    select id into v_sub from public.bath_subscribers where client_id = v_client limit 1;
  end if;

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

  v_onsite := nullif(btrim(coalesce(p_plan->>'onsite_update','')),'');
  if v_client is not null and v_onsite is not null then
    update public.clients
       set onsite_people = case when nullif(btrim(coalesce(onsite_people,'')),'') is null
                                then v_onsite
                                else onsite_people || ' ' || v_onsite end,
           updated_at = now()
     where id = v_client;
    v_onsite_appended := true;
  end if;

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
                    nullif(btrim(coalesce(e->>'breed','')),'') as breed,
                    nullif(btrim(coalesce(e->>'birthday', e->>'birth_date', '')),'')::date as birth_date,
                    nullif(e->>'dob_approximate','')::boolean as dob_approx
               from jsonb_array_elements(coalesce(p_plan->'dog_update','[]')) e
    loop
      v_dog := coalesce(r.dog_id,
        (select d.id from public.dogs d where d.client_id = v_client and lower(d.name) = lower(r.dog_name) limit 1));
      if v_dog is null then continue; end if;
      update public.dogs
         set price_cents = coalesce(r.price_cents, price_cents),
             breed = coalesce(r.breed, breed),
             birth_date = coalesce(r.birth_date, birth_date),
             dob_approximate = case when r.birth_date is not null then coalesce(r.dob_approx, false) else dob_approximate end,
             updated_at = now()
       where id = v_dog and client_id = v_client
         and (r.price_cents is not null or r.breed is not null or r.birth_date is not null);
      if found then v_updated := v_updated + 1; end if;
    end loop;
  end if;

  if v_client is not null and jsonb_typeof(p_plan->'visit') = 'object' then
    v_raw := nullif(p_plan->'visit'->>'visited_at','');
    if v_raw is null then
      v_visit_at := now();
    elsif length(v_raw) <= 10 then
      v_visit_at := ((v_raw::date)::timestamp + interval '12 hours') at time zone 'America/New_York';
    else
      v_visit_at := v_raw::timestamptz;
    end if;

    select coalesce(jsonb_agg(jsonb_build_object(
             'dog_id', coalesce(nullif(e->>'dog_id',''),
               (select d.id::text from public.dogs d
                 where d.client_id = v_client and lower(d.name) = lower(btrim(coalesce(e->>'dog_name',''))) limit 1)),
             'score', e->>'score')), '[]'::jsonb)
      into v_scores_j
      from jsonb_array_elements(coalesce(p_plan->'visit'->'dog_scores','[]')) e;
    select coalesce(array_agg((e->>'dog_id')::uuid), '{}') into v_new_dog_ids
      from jsonb_array_elements(v_scores_j) e
     where nullif(e->>'dog_id','') is not null
       and exists (select 1 from public.dogs d where d.id = (e->>'dog_id')::uuid and d.client_id = v_client);

    select id into v_visit from public.visits
     where client_id = v_client
       and (visited_at at time zone 'America/New_York')::date
           = (v_visit_at at time zone 'America/New_York')::date
     order by (appointment_id is not null) desc, created_at desc
     limit 1;

    if v_visit is not null then
      update public.visits set
        service_type = coalesce(nullif(p_plan->'visit'->>'service_type',''), service_type),
        work_done = coalesce(nullif(p_plan->'visit'->>'work_done',''), work_done),
        visit_notes = case when nullif(btrim(coalesce(p_plan->'visit'->>'visit_notes','')),'') is not null
                           then coalesce(visit_notes || ' ; ', '') || btrim(p_plan->'visit'->>'visit_notes')
                           else visit_notes end,
        actual_minutes = coalesce(nullif(p_plan->'visit'->>'actual_minutes','')::int, actual_minutes),
        amount_collected_cents = coalesce(nullif(p_plan->'visit'->>'amount_cents','')::int, amount_collected_cents),
        payment_method = coalesce(nullif(p_plan->'visit'->>'payment_method',''), payment_method),
        dog_ids = case when array_length(v_new_dog_ids, 1) > 0
                       then (select coalesce(array_agg(distinct x), '{}')
                               from unnest(coalesce(dog_ids, '{}') || v_new_dog_ids) x)
                       else dog_ids end
       where id = v_visit;
      v_visit_merged := true;
    else
      insert into public.visits (
        client_id, subscriber_id, visited_at, service_type, dog_ids,
        work_done, visit_notes, actual_minutes, amount_collected_cents, payment_method, source, completed_by
      ) values (
        v_client, v_sub, v_visit_at,
        nullif(p_plan->'visit'->>'service_type',''),
        v_new_dog_ids,
        nullif(p_plan->'visit'->>'work_done',''),
        nullif(p_plan->'visit'->>'visit_notes',''),
        nullif(p_plan->'visit'->>'actual_minutes','')::int,
        nullif(p_plan->'visit'->>'amount_cents','')::int,
        nullif(p_plan->'visit'->>'payment_method',''),
        'riker', v_admin
      ) returning id into v_visit;
    end if;

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

  -- Generator / equipment maintenance: set the hour reading and mark the named
  -- service tasks done. No client needed; works from QuickCapture.
  if jsonb_typeof(v_es) = 'array' then
    for r in select nullif(e->>'equipment_id','')::uuid as eid,
                    nullif(e->>'hours','')::numeric as hours,
                    e->'tasks' as tasks
               from jsonb_array_elements(v_es) e
              where nullif(e->>'equipment_id','') is not null
    loop
      if not exists (select 1 from public.equipment where id = r.eid) then continue; end if;
      if r.hours is not null then
        update public.equipment set current_hours = r.hours, hours_updated_at = now() where id = r.eid;
      end if;
      v_equip := v_equip + 1;
      if jsonb_typeof(r.tasks) = 'array' and jsonb_array_length(r.tasks) > 0 then
        update public.maintenance_tasks t
           set last_done_hours = coalesce(r.hours, (select current_hours from public.equipment where id = r.eid)),
               last_done_date  = (now() at time zone 'America/New_York')::date
         where t.equipment_id = r.eid and coalesce(t.active, true)
           and exists (select 1 from jsonb_array_elements_text(r.tasks) tn
                        where lower(t.task) like '%' || lower(btrim(tn)) || '%'
                           or lower(btrim(tn)) like '%' || lower(t.task) || '%');
        get diagnostics v_etask_count = row_count;
        v_equip_tasks := v_equip_tasks + v_etask_count;
      end if;
    end loop;
  end if;

  return jsonb_build_object('visit_id', v_visit, 'scores_applied', v_scores,
                           'client_note_appended', v_note, 'dog_notes_appended', v_dognotes,
                           'dog_status_changes', v_status, 'notify_person_id', v_np_id,
                           'wisdom_saved', v_wisdom_saved, 'reminder_id', v_rem_id,
                           'dogs_added', v_added, 'dogs_updated', v_updated,
                           'client_updated', v_client_updated, 'visit_merged', v_visit_merged,
                           'onsite_appended', v_onsite_appended,
                           'visit_corrected', v_visit_corrected, 'visit_update_missed', v_vu_missed,
                           'equipment_updated', v_equip, 'equipment_tasks_marked', v_equip_tasks);
end;
$function$;
revoke all on function public.admin_riker_apply(jsonb) from public, anon;
grant execute on function public.admin_riker_apply(jsonb) to authenticated, service_role;
