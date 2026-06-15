-- 0189_delegated_not_re_raised.sql
--
-- Handed-off cards were duplicating. Paul's rule: "if I hand it to Jake it
-- should not be my card; it lives in the handed-to-Jake list until he does it,
-- and I can take it back if I need to."
--
-- What was happening: delegating a card flips its briefing to 'delegated' (off
-- Paul's feed) and opens a task for Jake, which is right. But every watcher
-- agent dedupes only on status in ('new','read'), so a 'delegated' card no
-- longer suppressed a fresh one. On the watcher's next run it re-raised an
-- identical card into Paul's feed, so the same item showed BOTH as Jake's task
-- and as a live card. All five cards Paul handed Jake hit this (all maintenance
-- watcher cards), but the dedupe gap is in ~14 watcher functions.
--
-- The fix is one durable guard instead of fourteen edits: a BEFORE INSERT
-- trigger on briefings that skips raising a card while the same card is already
-- an OPEN handed-off task (a task that came from a briefing). The open task is
-- the system of record while the work is in flight. Once the task is finished
-- (briefing resolves) or taken back / dropped (task no longer open), the
-- watcher is free to raise the card again. Matched on title, which the watcher
-- agents set deterministically per condition and which delegation copies onto
-- the task verbatim.

create or replace function public._suppress_briefing_while_delegated()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if exists (
    select 1 from public.tasks t
     where t.status = 'open'
       and t.briefing_id is not null
       and lower(btrim(t.title)) = lower(btrim(new.title))
  ) then
    return null;  -- already handed off and in flight; do not duplicate it on the feed
  end if;
  return new;
end;
$$;
revoke all on function public._suppress_briefing_while_delegated() from public, anon, authenticated;

drop trigger if exists trg_suppress_briefing_while_delegated on public.briefings;
create trigger trg_suppress_briefing_while_delegated
  before insert on public.briefings
  for each row execute function public._suppress_briefing_while_delegated();

-- admin_list_tasks: also return briefing_id so the Tasks panel can offer
-- "Take back" on a handed-off card (admin_reopen_briefing drops the task and
-- returns the card to the owner's feed). Otherwise unchanged from 0168.
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
      'briefing_id', t.briefing_id,
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
