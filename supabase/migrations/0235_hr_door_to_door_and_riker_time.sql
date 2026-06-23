-- 0235_hr_door_to_door_and_riker_time.sql
--
-- Two linked fixes so the HR floor tells the truth about hours.
--
-- The "hours per day" figure was reading low for a real reason: a chunk of
-- visits are logged by Riker voice capture, which recorded the money but no
-- time, so on busy days most jobs counted as zero hours. The tracker path
-- (tap arrived/departed on Today) records exact times and is clean; the leak
-- is the voice path.
--
-- 1) admin_hr_summary now reports BOTH measures Paul wants, each from the data
--    that can honestly feed it, never inventing a missing time:
--      - hands-on per day  = recorded grooming minutes / clocked work days
--      - door-to-door per day = first arrival (or "heading there") to last
--        departure, averaged over days that have those stamps
--    plus untimed_visits, an honesty count of visits still missing any time.
--
-- 2) admin_riker_apply can now take arrival/departure clock times (and a spoken
--    duration) from a voice capture, derive the on-site minutes the same way the
--    tracker does, and anchor the visit to the real arrival time instead of
--    defaulting to the moment Paul spoke. No time given still means no time
--    stored (a data gap, never a guess).

-- ===== 1. HR summary: hands-on AND door-to-door =====
create or replace function public.admin_hr_summary(p_window_days integer default 30)
returns jsonb language plpgsql security definer set search_path = public, pg_temp
as $$
declare
  v_visits int; v_minutes bigint; v_revenue bigint;
  v_workdays int; v_clocked_visits int; v_untimed int;
  v_door_days int; v_door_hours numeric; v_busiest jsonb;
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;

  -- Headline totals. A completed visit can never be in the future, so a
  -- future-dated row is bad data and is excluded everywhere.
  select count(*), coalesce(sum(actual_minutes),0), coalesce(sum(amount_collected_cents),0),
         count(*) filter (where actual_minutes is null)
    into v_visits, v_minutes, v_revenue, v_untimed
    from public.visits
   where visited_at >= now() - make_interval(days => p_window_days)
     and visited_at <= now();

  -- Hands-on per day: only days with at least one clocked visit count, and only
  -- the visits on those days feed the per-day visit count.
  with clocked_days as (
    select visited_at::date as d
      from public.visits
     where visited_at >= now() - make_interval(days => p_window_days)
       and visited_at <= now() and actual_minutes > 0
     group by 1
  )
  select count(*),
         coalesce((select count(*) from public.visits v
                    where v.visited_at::date in (select d from clocked_days)
                      and v.visited_at >= now() - make_interval(days => p_window_days)
                      and v.visited_at <= now()),0)
    into v_workdays, v_clocked_visits from clocked_days;

  -- Door-to-door per day: from the first "heading there"/arrival to the last
  -- departure on each day that has both stamps. Captures drive time between
  -- stops, which hands-on time leaves out.
  with door as (
    select visited_at::date d,
           min(coalesce(inbound_at, arrived_at)) s, max(departed_at) e
      from public.visits
     where visited_at >= now() - make_interval(days => p_window_days)
       and visited_at <= now()
       and departed_at is not null and coalesce(inbound_at, arrived_at) is not null
     group by 1
     having max(departed_at) > min(coalesce(inbound_at, arrived_at))
  )
  select count(*), coalesce(sum(extract(epoch from (e - s))/3600.0),0)
    into v_door_days, v_door_hours from door;

  select jsonb_build_object('date', to_char(d,'Mon DD'), 'hours', round(mins/60.0,1), 'visits', n)
    into v_busiest from (
      select visited_at::date d, sum(actual_minutes) mins, count(*) n from public.visits
       where visited_at >= now() - make_interval(days => p_window_days)
         and visited_at <= now() and actual_minutes > 0
       group by 1 order by mins desc nulls last limit 1) b;

  return jsonb_build_object(
    'window_days', p_window_days, 'visits', v_visits,
    'hours', round(v_minutes/60.0,1), 'work_days', v_workdays,
    'avg_hours_per_workday', case when v_workdays>0 then round((v_minutes/60.0)/v_workdays,1) end,
    'avg_hands_on_per_workday', case when v_workdays>0 then round((v_minutes/60.0)/v_workdays,1) end,
    'avg_visits_per_workday', case when v_workdays>0 then round(v_clocked_visits::numeric/v_workdays,1) end,
    'door_to_door_days', v_door_days,
    'avg_door_to_door_per_workday', case when v_door_days>0 then round(v_door_hours/v_door_days,1) end,
    'untimed_visits', v_untimed,
    'revenue', v_revenue, 'busiest_day', v_busiest);
end;
$$;
revoke all on function public.admin_hr_summary(integer) from public;
grant execute on function public.admin_hr_summary(integer) to authenticated;

-- ===== 2. Riker apply: capture arrival/departure times from voice =====
create or replace function public.admin_riker_apply(p_plan jsonb)
 returns jsonb
 language plpgsql
 security definer
 set search_path to 'public', 'pg_temp'
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
        v_np_missing boolean := false;
        v_access text; v_access_appended boolean := false;
        v_date_ny date; v_arr timestamptz; v_dep timestamptz; v_mins int;
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

  v_access := nullif(btrim(coalesce(p_plan->>'access_note','')),'');
  if v_client is not null and v_access is not null then
    update public.clients
       set access_notes = case when nullif(btrim(coalesce(access_notes,'')),'') is null
                                then v_access
                                else access_notes || ' ; ' || v_access end,
           updated_at = now()
     where id = v_client;
    v_access_appended := true;
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

    -- Arrival / departure clock times from a voice capture (24h HH:MM, local).
    -- Combine with the visit's calendar day in Eastern. If arrival is given,
    -- anchor the visit to it instead of leaving it at "now" (the old default
    -- that stamped visits at the moment Paul spoke, often hours off).
    v_date_ny := (v_visit_at at time zone 'America/New_York')::date;
    v_arr := case when nullif(p_plan->'visit'->>'arrived_at','') is not null
                  then (v_date_ny::timestamp + (p_plan->'visit'->>'arrived_at')::time) at time zone 'America/New_York'
                  end;
    v_dep := case when nullif(p_plan->'visit'->>'departed_at','') is not null
                  then (v_date_ny::timestamp + (p_plan->'visit'->>'departed_at')::time) at time zone 'America/New_York'
                  end;
    if v_arr is not null then v_visit_at := v_arr; end if;
    -- Minutes: explicit spoken duration wins; otherwise derive from the clock
    -- the same way the tracker does. No time given stays null (a real gap).
    v_mins := nullif(p_plan->'visit'->>'actual_minutes','')::int;
    if v_mins is null and v_arr is not null and v_dep is not null and v_dep > v_arr then
      v_mins := greatest(0, round(extract(epoch from (v_dep - v_arr)) / 60.0)::int);
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
        arrived_at = coalesce(v_arr, arrived_at),
        departed_at = coalesce(v_dep, departed_at),
        actual_minutes = coalesce(v_mins, actual_minutes),
        amount_collected_cents = coalesce(nullif(p_plan->'visit'->>'amount_cents','')::int, amount_collected_cents),
        charged_cents = coalesce(nullif(p_plan->'visit'->>'charged_cents','')::int, charged_cents),
        tip_cents = coalesce(nullif(p_plan->'visit'->>'tip_cents','')::int, tip_cents),
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
        work_done, visit_notes, arrived_at, departed_at, actual_minutes,
        amount_collected_cents, charged_cents, tip_cents, payment_method, source, completed_by
      ) values (
        v_client, v_sub, v_visit_at,
        nullif(p_plan->'visit'->>'service_type',''),
        v_new_dog_ids,
        nullif(p_plan->'visit'->>'work_done',''),
        nullif(p_plan->'visit'->>'visit_notes',''),
        v_arr,
        v_dep,
        v_mins,
        nullif(p_plan->'visit'->>'amount_cents','')::int,
        nullif(p_plan->'visit'->>'charged_cents','')::int,
        nullif(p_plan->'visit'->>'tip_cents','')::int,
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
      if nullif(btrim(coalesce(v_np->>'phone','')),'') is null
         and nullif(btrim(coalesce(v_np->>'email','')),'') is null then
        v_np_missing := true;
      else
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
                           'equipment_updated', v_equip, 'equipment_tasks_marked', v_equip_tasks,
                           'notify_person_missing_contact', v_np_missing,
                           'access_appended', v_access_appended);
end;
$function$;
