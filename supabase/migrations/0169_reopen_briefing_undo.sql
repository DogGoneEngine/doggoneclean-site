-- 0169_reopen_briefing_undo.sql
-- Undo for a card answer (cards_resolve_or_stay). Every answer on a Today card
-- (Handle it / Leave it alone / Dismiss / Hand off) collapses the card to a
-- one-line outcome with an Undo. Undo reopens the card: it goes back to 'read'
-- with its disposition cleared, so an accidental "Leave it alone" no longer
-- suppresses the agent, and an accidental delegation drops the task it created.
-- A delegation can only be undone while its task is still open; once the
-- assignee has finished it, the work happened and there is nothing to take back.
create or replace function public.admin_reopen_briefing(p_id uuid)
returns void language plpgsql security definer set search_path to ''
as $$
declare v_task public.tasks%rowtype;
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  -- If this card was handed off, find its task. A finished task cannot be undone.
  select * into v_task from public.tasks
    where briefing_id = p_id and status in ('open', 'done')
    order by created_at desc limit 1;
  if found and v_task.status = 'done' then raise exception 'already_done'; end if;
  if found then update public.tasks set status = 'dropped' where id = v_task.id; end if;
  update public.briefings set status = 'read', disposition = null where id = p_id;
  insert into public.briefing_notes (briefing_id, author, body)
  values (p_id, 'agent', 'Reopened. Back on your list.');
end;
$$;
revoke all on function public.admin_reopen_briefing(uuid) from public, anon;
grant execute on function public.admin_reopen_briefing(uuid) to authenticated, service_role;
