-- 0152: batch of five durable changes from Paul's 2026-06-11 field feedback.
--
-- 1. Jake Nickerson joins HR as a Hurricane Bath Operator (adopt-by-email
--    binds his auth user on first Google sign-in, same as Paul's row did).
-- 2. agent_costs: every LLM-backed edge function logs its token usage here,
--    so HR can show what each agent has cost historically and project the
--    month ahead. SQL-only agents (capacity watcher, charge cron) cost
--    nothing and never write rows.
-- 3. reminders: the one-gateway time-based commitment store. "Contact Jane's
--    mother in 2 weeks" goes in through Riker, surfaces on Today when due.
-- 4. drive_cache: drive seconds between two clients' homes, cached forever
--    (homes do not move), feeding the suggest-drive annotator.
-- 5. Banana pencils: Paul's year-ahead penciled appointments live in Google
--    Calendar in banana color and are NOT client-official. The sync now
--    accepts a per-event tentative flag (set by the Apps Script for banana
--    events) in addition to the trailing "?" marker, mapping both onto
--    status = 'tentative' (already hidden from every client surface per
--    tentative_marker_is_private). admin_suggest_slots surfaces the status
--    of the next booked appointment and of each day stop so Orbit can label
--    penciled time as penciled.

-- 1. Jake, Hurricane Bath Operator.
insert into public.admins (email, first_name, last_name, role, is_active)
select 'jakewnickerson@gmail.com', 'Jake', 'Nickerson', 'operator', true
where not exists (
  select 1 from public.admins where email = 'jakewnickerson@gmail.com');

-- 2. Agent cost ledger.
create table if not exists public.agent_costs (
  id uuid primary key default gen_random_uuid(),
  agent_key text not null,
  model text not null,
  input_tokens bigint not null default 0,
  output_tokens bigint not null default 0,
  created_at timestamptz not null default now()
);
create index if not exists agent_costs_key_time
  on public.agent_costs (agent_key, created_at desc);
alter table public.agent_costs enable row level security;

-- Dollar cost per call from the published per-million-token rates.
create or replace function public._agent_cost_usd(p_model text, p_in bigint, p_out bigint)
returns numeric
language sql
immutable
set search_path to ''
as $$
  select round((case
      when p_model like 'claude-opus%'  then p_in * 5.0 + p_out * 25.0
      when p_model like 'claude-haiku%' then p_in * 1.0 + p_out * 5.0
      else p_in * 3.0 + p_out * 15.0   -- sonnet rates, also the fallback
    end) / 1000000.0, 4)
$$;
revoke all on function public._agent_cost_usd(text, bigint, bigint) from public, anon, authenticated;
grant execute on function public._agent_cost_usd(text, bigint, bigint) to service_role;

create or replace function public.admin_agent_costs()
returns jsonb
language plpgsql
security definer
set search_path to ''
as $$
declare
  v_agents jsonb;
  v_30d numeric;
  v_all numeric;
  v_days numeric;
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;

  select coalesce(jsonb_agg(a order by (a->>'cost_30d')::numeric desc), '[]'::jsonb)
    into v_agents
    from (
      select jsonb_build_object(
        'agent_key', agent_key,
        'model', max(model),
        'runs_30d', count(*) filter (where created_at > now() - interval '30 days'),
        'input_tokens_30d', coalesce(sum(input_tokens) filter (where created_at > now() - interval '30 days'), 0),
        'output_tokens_30d', coalesce(sum(output_tokens) filter (where created_at > now() - interval '30 days'), 0),
        'cost_30d', coalesce(sum(public._agent_cost_usd(model, input_tokens, output_tokens))
                      filter (where created_at > now() - interval '30 days'), 0),
        'runs_total', count(*),
        'cost_total', coalesce(sum(public._agent_cost_usd(model, input_tokens, output_tokens)), 0),
        'last_run', max(created_at)
      ) as a
      from public.agent_costs
      group by agent_key
    ) t;

  select coalesce(sum(public._agent_cost_usd(model, input_tokens, output_tokens))
           filter (where created_at > now() - interval '30 days'), 0),
         coalesce(sum(public._agent_cost_usd(model, input_tokens, output_tokens)), 0),
         greatest(1, least(30, extract(epoch from now() - min(created_at)) / 86400.0))
    into v_30d, v_all, v_days
    from public.agent_costs;

  return jsonb_build_object(
    'agents', v_agents,
    'cost_30d', coalesce(v_30d, 0),
    'cost_all_time', coalesce(v_all, 0),
    'observed_days', coalesce(round(v_days, 1), 0),
    'projected_month', case when v_days is null or v_days = 0 then 0
                            else round(v_30d / v_days * 30.0, 2) end);
end;
$$;
revoke all on function public.admin_agent_costs() from public, anon;
grant execute on function public.admin_agent_costs() to authenticated, service_role;

-- 3. Reminders: time-based commitments, in through Riker, out on Today.
create table if not exists public.reminders (
  id uuid primary key default gen_random_uuid(),
  body text not null,
  due_date date not null,
  client_id uuid references public.clients(id) on delete set null,
  status text not null default 'open' check (status in ('open', 'done')),
  source text not null default 'manual',
  created_at timestamptz not null default now(),
  done_at timestamptz
);
create index if not exists reminders_open_due
  on public.reminders (due_date) where status = 'open';
alter table public.reminders enable row level security;

create or replace function public.admin_add_reminder(
  p_body text, p_due date, p_client_id uuid default null, p_source text default 'manual')
returns uuid
language plpgsql
security definer
set search_path to ''
as $$
declare v_id uuid;
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  if nullif(btrim(coalesce(p_body, '')), '') is null then raise exception 'reminder: empty body'; end if;
  if p_due is null then raise exception 'reminder: no due date'; end if;
  insert into public.reminders (body, due_date, client_id, source)
  values (btrim(p_body), p_due, p_client_id, coalesce(p_source, 'manual'))
  returning id into v_id;
  return v_id;
end;
$$;
revoke all on function public.admin_add_reminder(text, date, uuid, text) from public, anon;
grant execute on function public.admin_add_reminder(text, date, uuid, text) to authenticated, service_role;

create or replace function public.admin_list_reminders()
returns jsonb
language plpgsql
security definer
set search_path to ''
as $$
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  return jsonb_build_object(
    'open', coalesce((
      select jsonb_agg(jsonb_build_object(
          'id', r.id, 'body', r.body, 'due_date', r.due_date,
          'client_id', r.client_id, 'client_name', c.name,
          'overdue', r.due_date < current_date,
          'due', r.due_date <= current_date)
        order by r.due_date, r.created_at)
        from public.reminders r
        left join public.clients c on c.id = r.client_id
       where r.status = 'open'), '[]'::jsonb),
    'recently_done', coalesce((
      select jsonb_agg(jsonb_build_object(
          'id', r.id, 'body', r.body, 'due_date', r.due_date,
          'client_name', c.name, 'done_at', r.done_at)
        order by r.done_at desc)
        from public.reminders r
        left join public.clients c on c.id = r.client_id
       where r.status = 'done' and r.done_at > now() - interval '7 days'), '[]'::jsonb));
end;
$$;
revoke all on function public.admin_list_reminders() from public, anon;
grant execute on function public.admin_list_reminders() to authenticated, service_role;

create or replace function public.admin_set_reminder_done(p_id uuid, p_done boolean default true)
returns void
language plpgsql
security definer
set search_path to ''
as $$
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  update public.reminders
     set status = case when p_done then 'done' else 'open' end,
         done_at = case when p_done then now() else null end
   where id = p_id;
  if not found then raise exception 'reminder not found'; end if;
end;
$$;
revoke all on function public.admin_set_reminder_done(uuid, boolean) from public, anon;
grant execute on function public.admin_set_reminder_done(uuid, boolean) to authenticated, service_role;

-- 4. Drive-seconds cache between two clients' homes. Homes are fixed, so a
-- computed pair never expires; computed_at is provenance, not a TTL.
create table if not exists public.drive_cache (
  origin_client uuid not null references public.clients(id) on delete cascade,
  dest_client uuid not null references public.clients(id) on delete cascade,
  seconds integer not null,
  computed_at timestamptz not null default now(),
  primary key (origin_client, dest_client)
);
alter table public.drive_cache enable row level security;

-- 5a. Sync accepts an explicit tentative flag (banana-colored events) on top
-- of the trailing-"?" marker. Both mean the same thing: Paul's private pencil.
create or replace function public._sync_appointments(p_events jsonb)
returns jsonb
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $$
declare e record; v_name text; v_tentative boolean; v_status text;
        v_client uuid; v_sub uuid; v_appt uuid; v_ins int:=0; v_upd int:=0; v_unmatched jsonb:='[]'::jsonb;
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
      insert into public.bath_appointments (subscriber_id, scheduled_start, scheduled_end, status, service_type, amount_cents, dog_count, source, external_id, notes)
      values (v_sub, e.starts, e.ends, v_status, coalesce(e.service_type,'full_groom'), coalesce(e.amount_cents,0), coalesce(e.dog_count,1), 'gcal_sync', e.external_id, e.notes);
      v_ins := v_ins + 1;
    else
      update public.bath_appointments set subscriber_id=v_sub, scheduled_start=e.starts, scheduled_end=e.ends,
        status = case when status in ('requested','confirmed','tentative') then v_status else status end,
        service_type=coalesce(e.service_type,service_type), amount_cents=coalesce(e.amount_cents,amount_cents),
        dog_count=coalesce(e.dog_count,dog_count,1), source='gcal_sync', notes=coalesce(e.notes,notes), updated_at=now()
       where id=v_appt;
      v_upd := v_upd + 1;
    end if;
  end loop;
  return jsonb_build_object('inserted', v_ins, 'updated', v_upd, 'unmatched', v_unmatched);
end;
$$;
revoke all on function public._sync_appointments(jsonb) from public, anon, authenticated;
grant execute on function public._sync_appointments(jsonb) to service_role;

-- 5b. Suggestions surface the status of booked time so Orbit can say
-- "penciled in" instead of presenting Paul's pencil as a firm booking.
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
  v_next_status text;
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

  -- Already booked ahead? Surface it (with its status: a tentative row is
  -- Paul's banana pencil, not a client commitment); do not absorb it.
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
                 ctx.o_dur) s
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
    'duration_minutes', ctx.o_dur,
    'window_note', nullif(coalesce(v_hard, ''), ''),
    'not_days', to_jsonb(coalesce(v_nd, '{}'::text[])),
    'days', v_days);
end;
$$;
revoke all on function public.admin_suggest_slots(uuid) from public, anon;
grant execute on function public.admin_suggest_slots(uuid) to authenticated, service_role;

-- 6. Riker can now carry a reminder ("contact her in 2 weeks") and a plan may
-- be reminder-only (no client, no wisdom).
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
                           'wisdom_saved', v_wisdom_saved, 'reminder_id', v_rem_id);
end;
$$;
revoke all on function public.admin_riker_apply(jsonb) from public, anon;
grant execute on function public.admin_riker_apply(jsonb) to authenticated, service_role;
