-- 0168_task_delegation_and_clear.sql
-- Three closures on the Today board so Paul routes work instead of doing all of
-- it (delegation_closes_the_loop):
--
-- (1) Clear finished tasks. An owner can clear a done task off the board now
--     (status -> 'cleared') instead of waiting for the 30-day auto-age. Cleared,
--     not deleted, so the audit trail survives (clean_stays_saleable).
--
-- (2) Delegate an agent card. Hand a briefing to whoever works for Clean as a
--     task. The task links back to the briefing; the briefing flips to
--     'delegated' so it leaves Paul's active feed but stays visible as in-flight
--     (the owner sees every open task in the Tasks panel). Completing the task
--     resolves the briefing and stamps a done note. No card falls into the void:
--     a delegated task open past 3 days flags overdue, and the watcher agent
--     re-raises the underlying condition on its own once its dedupe window passes
--     (the hours scan dedupes only on status in new/read, so a delegated card no
--     longer suppresses a fresh one).
--
-- (3) Carry the action. A delegated "Update hours" card becomes a task that
--     carries the equipment name, so the assignee enters the panel reading from
--     their own task, the number lands on the equipment, and the card resolves.
--     The write happens only through a task handed to that person, never as a
--     general operator power. Honors the no-data-into-the-void rule (the
--     641-hours lesson) for the one action card that exists today.

-- tasks: allow 'cleared'; link to the source card; carry an optional action.
alter table public.tasks drop constraint if exists tasks_status_check;
alter table public.tasks add constraint tasks_status_check
  check (status in ('open', 'done', 'dropped', 'cleared'));
alter table public.tasks add column if not exists briefing_id uuid references public.briefings(id) on delete set null;
alter table public.tasks add column if not exists action jsonb;

-- briefings: allow 'delegated' (off the active feed, still in-flight as a task).
alter table public.briefings drop constraint if exists briefings_status_check;
alter table public.briefings add constraint briefings_status_check
  check (status = any (array['new', 'read', 'approved', 'dismissed', 'acted', 'resolved', 'delegated']));

-- admin_list_tasks: now returns the source-card flag, the action payload, and an
-- overdue flag (open past 3 days) so a stale delegation surfaces loudly. Owner
-- sees all; everyone else sees only their own. Excludes dropped and cleared.
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
      'proof_photo_path', t.proof_photo_path, 'done_at', t.done_at,
      'created_at', t.created_at,
      'assigned_to', t.assigned_to,
      'assignee', btrim(coalesce(a.first_name, '') || ' ' || coalesce(a.last_name, '')),
      'mine', (t.assigned_to = v_me),
      'from_card', (t.briefing_id is not null),
      'action', t.action,
      'overdue', (t.status = 'open' and t.created_at < now() - interval '3 days')
    ) order by (t.status = 'open') desc,
               (t.status = 'open' and t.created_at < now() - interval '3 days') desc,
               t.created_at desc)
    from public.tasks t
    join public.admins a on a.id = t.assigned_to
   where (v_role = 'owner' or t.assigned_to = v_me)
     and t.status in ('open', 'done')
     and (t.status = 'open' or t.done_at > now() - interval '30 days')), '[]'::jsonb);
end;
$$;
revoke all on function public.admin_list_tasks() from public, anon;
grant execute on function public.admin_list_tasks() to authenticated, service_role;

-- admin_complete_task: same as before, plus two closures. If the task carries an
-- equipment_hours action it requires the reading and writes it to the equipment
-- (allowed here because the task was handed to this caller; security definer, no
-- general grant). If the task came from a card, that card resolves with a done
-- note. The 2-arg version from 0167 is dropped so the new signature is the only
-- one PostgREST can resolve.
drop function if exists public.admin_complete_task(uuid, text);
create or replace function public.admin_complete_task(
  p_id uuid, p_proof_path text default null, p_action_value text default null)
returns void language plpgsql security definer set search_path to ''
as $$
declare v_me uuid; t public.tasks%rowtype; v_hours numeric; v_equip text; v_who text;
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

  -- Carry-the-action: an equipment-hours task writes its reading on completion.
  if t.action ->> 'type' = 'equipment_hours' then
    if coalesce(trim(p_action_value), '') = '' then raise exception 'hours_required'; end if;
    if p_action_value !~ '^[0-9]+(\.[0-9]+)?$' then raise exception 'hours must be a number, zero or more'; end if;
    v_hours := p_action_value::numeric;
    v_equip := t.action ->> 'equipment';
    update public.equipment set current_hours = v_hours, hours_updated_at = now()
     where name = v_equip and coalesce(track_hours, false);
    if not found then raise exception 'no hours-tracked equipment named "%"', v_equip; end if;
  end if;

  update public.tasks
     set status = 'done', done_at = now(),
         proof_photo_path = coalesce(p_proof_path, proof_photo_path)
   where id = p_id;

  -- Close the loop on the card this task came from.
  if t.briefing_id is not null then
    select btrim(coalesce(first_name, '') || ' ' || coalesce(last_name, '')) into v_who
      from public.admins where id = v_me;
    update public.briefings set disposition = 'done', status = 'resolved' where id = t.briefing_id;
    insert into public.briefing_notes (briefing_id, author, body)
    values (t.briefing_id, 'agent', 'Done by ' || coalesce(nullif(v_who, ''), 'the assignee') || '.');
  end if;
end;
$$;
revoke all on function public.admin_complete_task(uuid, text, text) from public, anon;
grant execute on function public.admin_complete_task(uuid, text, text) to authenticated, service_role;

-- admin_clear_task: owner sweeps a single finished task off the board.
create or replace function public.admin_clear_task(p_id uuid)
returns void language plpgsql security definer set search_path to ''
as $$
begin
  if public._admin_role() <> 'owner' then raise exception 'owner only'; end if;
  update public.tasks set status = 'cleared' where id = p_id and status = 'done';
  if not found then raise exception 'done task not found'; end if;
end;
$$;
revoke all on function public.admin_clear_task(uuid) from public, anon;
grant execute on function public.admin_clear_task(uuid) to authenticated, service_role;

-- admin_clear_done_tasks: owner sweeps every finished task at once.
create or replace function public.admin_clear_done_tasks()
returns integer language plpgsql security definer set search_path to ''
as $$
declare v_n integer;
begin
  if public._admin_role() <> 'owner' then raise exception 'owner only'; end if;
  update public.tasks set status = 'cleared' where status = 'done';
  get diagnostics v_n = row_count;
  return v_n;
end;
$$;
revoke all on function public.admin_clear_done_tasks() from public, anon;
grant execute on function public.admin_clear_done_tasks() to authenticated, service_role;

-- admin_delegate_briefing: owner hands a card to a worker as a task. Carries the
-- equipment-hours action when the card is an hours-ask, links the task to the
-- card, flips the card to 'delegated', and drops a handoff note.
create or replace function public.admin_delegate_briefing(
  p_briefing_id uuid, p_assignee uuid, p_needs_proof boolean default false)
returns uuid language plpgsql security definer set search_path to ''
as $$
declare v_me uuid; b public.briefings%rowtype; v_id uuid; v_action jsonb; v_equip text; v_who text;
begin
  if public._admin_role() <> 'owner' then raise exception 'owner only'; end if;
  select id into v_me from public.admins where auth_user_id = auth.uid() and is_active;
  select * into b from public.briefings where id = p_briefing_id;
  if not found then raise exception 'briefing not found'; end if;
  if not exists (select 1 from public.admins where id = p_assignee and is_active) then
    raise exception 'assignee not an active admin';
  end if;

  -- The one action card that exists today: the hours-ask. Carry the equipment so
  -- the assignee can enter the reading from their own task.
  if b.evidence ->> 'kind' = 'hours_reminder' then
    select name into v_equip from public.equipment where id = (b.evidence ->> 'equipment_id')::uuid;
    if v_equip is not null then
      v_action := jsonb_build_object('type', 'equipment_hours', 'equipment', v_equip);
    end if;
  end if;

  insert into public.tasks (title, details, assigned_to, created_by, needs_proof, briefing_id, action)
  values (btrim(b.title), nullif(btrim(coalesce(b.body, '')), ''), p_assignee, v_me,
          coalesce(p_needs_proof, false), p_briefing_id, v_action)
  returning id into v_id;

  select btrim(coalesce(first_name, '') || ' ' || coalesce(last_name, '')) into v_who
    from public.admins where id = p_assignee;
  update public.briefings set status = 'delegated' where id = p_briefing_id;
  insert into public.briefing_notes (briefing_id, author, body)
  values (p_briefing_id, 'agent',
    'Handed to ' || coalesce(nullif(v_who, ''), 'a teammate') || '. I will close this when they finish it.');
  return v_id;
end;
$$;
revoke all on function public.admin_delegate_briefing(uuid, uuid, boolean) from public, anon;
grant execute on function public.admin_delegate_briefing(uuid, uuid, boolean) to authenticated, service_role;

-- Tighten direct equipment-hours entry to the owner. The owner still uses the
-- inline box on the hours-ask card; an operator now enters hours only through a
-- task handed to them (admin_complete_task above), never as a general power.
-- Paul's explicit scoping decision (2026-06-13).
create or replace function public.admin_set_equipment_hours_by_name(p_name text, p_hours numeric)
returns void language plpgsql security definer set search_path to ''
as $$
begin
  if public._admin_role() <> 'owner' then raise exception 'owner only'; end if;
  if p_hours is null or p_hours < 0 then raise exception 'hours must be a number, zero or more'; end if;
  update public.equipment
     set current_hours = p_hours, hours_updated_at = now()
   where name = p_name and coalesce(track_hours, false);
  if not found then
    raise exception 'no hours-tracked equipment named "%"', p_name;
  end if;
end;
$$;
revoke all on function public.admin_set_equipment_hours_by_name(text, numeric) from public, anon;
grant execute on function public.admin_set_equipment_hours_by_name(text, numeric) to authenticated, service_role;
