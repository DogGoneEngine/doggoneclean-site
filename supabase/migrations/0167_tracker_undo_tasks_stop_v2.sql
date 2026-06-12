-- 0167: Paul's 2026-06-12 evening batch, four pieces.
--
-- (1) admin_tracker_undo (tracker_undo_is_deliberate): the Today stop card's
-- step button is one big fat-finger-proof target, but a wrong tap still
-- advanced the stage with no way back short of SQL. Undo rolls back exactly
-- one step: it reverts the appointment status and clears the matching
-- time_is_money stamp, so the big button, the client's tracker page, and
-- the clocks all agree again. The UI gates it behind a deliberate
-- tap-then-confirm; the server just does one honest step back.
--
-- (2) Tasks (tasks_with_receipts): Paul assigns a task ("clean the filter")
-- to Jake or any future operator; it shows on the assignee's Today; they
-- mark it done, optionally with a photo receipt the task can require; Paul
-- sees status and receipt in the same panel. Owner creates and drops;
-- assignee or owner completes.
--
-- (3) admin_get_client returns departed_at on each visit, so the client
-- sheet can pin only the visit still being worked and let a departed visit
-- rejoin the history (Paul: after Departed the card moves down where it
-- belongs).
--
-- (4) bath_cancel_subscription v2: the portal stop sign now also cancels
-- pencilled (tentative) future appointments (they previously survived a
-- stop), cards Paul's Today with a Plan-stopped briefing, and sends the
-- client the promised cancellation notice by email for their next upcoming
-- appointment via notify_appointment.
--
-- Applied to dgc-prod 2026-06-12.

create or replace function public.admin_tracker_undo(p_appointment uuid)
returns jsonb language plpgsql security definer set search_path to ''
as $$
declare
  a public.bath_appointments%rowtype;
  v record;
  v_new_status text;
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  select * into a from public.bath_appointments where id = p_appointment;
  if not found then raise exception 'appointment not found'; end if;
  select id, inbound_at, arrived_at, departed_at into v
    from public.visits where appointment_id = p_appointment
   order by created_at limit 1;

  if v.departed_at is not null or a.status = 'completed' then
    if v.id is not null then
      perform public.admin_stamp_appointment_time(p_appointment, 'departed', null);
    end if;
    v_new_status := 'returning';
  elsif a.status = 'returning' then
    v_new_status := 'on_site';
  elsif a.status in ('on_site', 'in_service') then
    if v.id is not null then
      perform public.admin_stamp_appointment_time(p_appointment, 'arrived', null);
    end if;
    v_new_status := 'on_the_way';
  elsif a.status = 'on_the_way' then
    if v.id is not null then
      perform public.admin_stamp_appointment_time(p_appointment, 'inbound', null);
    end if;
    -- The pre-departure fine print (tentative vs requested) is not retained;
    -- confirmed is the honest default for a stop being worked today.
    v_new_status := 'confirmed';
  else
    return jsonb_build_object('status', a.status, 'undone', false);
  end if;

  update public.bath_appointments set status = v_new_status, updated_at = now()
   where id = p_appointment;
  select inbound_at, arrived_at, departed_at into v
    from public.visits where appointment_id = p_appointment
   order by created_at limit 1;
  return jsonb_build_object('status', v_new_status, 'undone', true,
    'inbound_at', v.inbound_at, 'arrived_at', v.arrived_at, 'departed_at', v.departed_at);
end;
$$;
revoke all on function public.admin_tracker_undo(uuid) from public, anon;
grant execute on function public.admin_tracker_undo(uuid) to authenticated, service_role;

create table if not exists public.tasks (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  details text,
  assigned_to uuid not null references public.admins(id),
  created_by uuid references public.admins(id),
  needs_proof boolean not null default false,
  status text not null default 'open' check (status in ('open', 'done', 'dropped')),
  proof_photo_path text,
  done_at timestamptz,
  created_at timestamptz not null default now()
);
alter table public.tasks enable row level security;

create or replace function public.admin_add_task(
  p_title text, p_assignee uuid, p_details text default null, p_needs_proof boolean default false)
returns uuid language plpgsql security definer set search_path to ''
as $$
declare v_me uuid; v_id uuid;
begin
  if public._admin_role() <> 'owner' then raise exception 'owner only'; end if;
  select id into v_me from public.admins where auth_user_id = auth.uid() and is_active;
  if not exists (select 1 from public.admins where id = p_assignee and is_active) then
    raise exception 'assignee not an active admin';
  end if;
  if nullif(btrim(coalesce(p_title, '')), '') is null then raise exception 'title required'; end if;
  insert into public.tasks (title, details, assigned_to, created_by, needs_proof)
  values (btrim(p_title), nullif(btrim(coalesce(p_details, '')), ''), p_assignee, v_me, coalesce(p_needs_proof, false))
  returning id into v_id;
  return v_id;
end;
$$;
revoke all on function public.admin_add_task(text, uuid, text, boolean) from public, anon;
grant execute on function public.admin_add_task(text, uuid, text, boolean) to authenticated, service_role;

create or replace function public.admin_list_tasks()
returns jsonb language plpgsql security definer set search_path to ''
as $$
declare v_me uuid; v_role text;
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  select id into v_me from public.admins where auth_user_id = auth.uid() and is_active;
  v_role := public._admin_role();
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', t.id, 'title', t.title, 'details', t.details,
      'needs_proof', t.needs_proof, 'status', t.status,
      'proof_photo_path', t.proof_photo_path, 'done_at', t.done_at, 'created_at', t.created_at,
      'assigned_to', t.assigned_to,
      'assignee', btrim(coalesce(a.first_name, '') || ' ' || coalesce(a.last_name, '')),
      'mine', (t.assigned_to = v_me)
    ) order by (t.status = 'open') desc, t.created_at desc)
    from public.tasks t
    join public.admins a on a.id = t.assigned_to
   where (v_role = 'owner' or t.assigned_to = v_me)
     and (t.status = 'open' or t.created_at > now() - interval '30 days')
     and t.status <> 'dropped'), '[]'::jsonb);
end;
$$;
revoke all on function public.admin_list_tasks() from public, anon;
grant execute on function public.admin_list_tasks() to authenticated, service_role;

create or replace function public.admin_complete_task(p_id uuid, p_proof_path text default null)
returns void language plpgsql security definer set search_path to ''
as $$
declare v_me uuid; t public.tasks%rowtype;
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  select id into v_me from public.admins where auth_user_id = auth.uid() and is_active;
  select * into t from public.tasks where id = p_id;
  if not found then raise exception 'task not found'; end if;
  if t.status <> 'open' then raise exception 'task not open'; end if;
  if t.assigned_to <> v_me and public._admin_role() <> 'owner' then
    raise exception 'not your task';
  end if;
  if t.needs_proof and coalesce(p_proof_path, t.proof_photo_path) is null then
    raise exception 'proof_required';
  end if;
  update public.tasks
     set status = 'done', done_at = now(),
         proof_photo_path = coalesce(p_proof_path, proof_photo_path)
   where id = p_id;
end;
$$;
revoke all on function public.admin_complete_task(uuid, text) from public, anon;
grant execute on function public.admin_complete_task(uuid, text) to authenticated, service_role;

create or replace function public.admin_drop_task(p_id uuid)
returns void language plpgsql security definer set search_path to ''
as $$
begin
  if public._admin_role() <> 'owner' then raise exception 'owner only'; end if;
  update public.tasks set status = 'dropped' where id = p_id and status = 'open';
  if not found then raise exception 'open task not found'; end if;
end;
$$;
revoke all on function public.admin_drop_task(uuid) from public, anon;
grant execute on function public.admin_drop_task(uuid) to authenticated, service_role;

-- admin_get_client: full replace of the live definition with one added key,
-- 'departed_at' on each visit row, so the sheet can unpin departed visits.
-- (Definition otherwise identical to the live dgc-prod version.)
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
        'departed_at', v.departed_at,
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

-- bath_cancel_subscription v2: tentative appointments cancel too, Paul gets
-- a Today card, and the client gets the promised cancellation email for
-- their next upcoming appointment.
CREATE OR REPLACE FUNCTION public.bath_cancel_subscription()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_sub_id  uuid;
  v_subr_id uuid;
  v_next    uuid;
  v_count   int;
  v_client  text;
begin
  select s.id, s.subscriber_id
    into v_sub_id, v_subr_id
  from public.bath_subscriptions s
  join public.bath_subscribers b on b.id = s.subscriber_id
  where b.auth_user_id = auth.uid()
    and s.status in ('active', 'paused')
  order by s.started_at desc
  limit 1;

  if v_sub_id is null then
    return jsonb_build_object('ok', false, 'error', 'no_active_subscription');
  end if;

  select a.id into v_next
    from public.bath_appointments a
   where a.subscriber_id = v_subr_id
     and a.scheduled_start > now()
     and a.status in ('requested', 'confirmed', 'tentative', 'on_the_way', 'on_site', 'in_service')
   order by a.scheduled_start
   limit 1;

  update public.bath_subscriptions
     set status = 'cancelled', cancelled_at = now(), updated_at = now()
   where id = v_sub_id;

  update public.bath_appointments
     set status = 'cancelled', updated_at = now()
   where subscriber_id = v_subr_id
     and scheduled_start > now()
     and status in ('requested', 'confirmed', 'tentative', 'on_the_way', 'on_site', 'in_service');
  get diagnostics v_count = row_count;

  select coalesce(c.name, nullif(btrim(coalesce(b.first_name, '') || ' ' || coalesce(b.last_name, '')), ''), 'A client')
    into v_client
  from public.bath_subscribers b
  left join public.clients c on c.id = b.client_id
  where b.id = v_subr_id;

  insert into public.briefings (agent_key, department, severity, title, body, status)
  values ('retention', 'growth', 'alert',
    'Plan stopped: ' || v_client,
    v_client || ' tapped the stop sign in the portal. ' || v_count ||
    ' upcoming appointment' || case when v_count = 1 then '' else 's' end || ' cancelled.' ||
    case when v_next is not null then ' Their cancellation notice went out by email.' else '' end,
    'new');

  if v_next is not null then
    perform public.notify_appointment('cancellation', v_next);
  end if;

  return jsonb_build_object('ok', true, 'status', 'cancelled');
end;
$function$;
