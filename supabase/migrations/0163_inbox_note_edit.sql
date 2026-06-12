-- 0163: The inbox note must never go into the void. Paul typed descriptions
-- after picking the photo and they were lost, because the upload fires on
-- file pick with whatever note text existed at that instant. Fix has two
-- halves: the UI lets a note be added or edited on an item after upload,
-- and this RPC persists it. Also the inbox accepts videos now, not just
-- photos (the bucket never restricted mime types; only the file picker did).
--
-- Applied to dgc-prod 2026-06-12.

create or replace function public.admin_update_inbox_note(p_id uuid, p_note text)
returns void language plpgsql security definer set search_path to ''
as $$
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  update public.site_inbox
     set note = nullif(btrim(coalesce(p_note, '')), '')
   where id = p_id;
  if not found then raise exception 'inbox item not found'; end if;
end;
$$;
revoke all on function public.admin_update_inbox_note(uuid, text) from public, anon;
grant execute on function public.admin_update_inbox_note(uuid, text) to authenticated, service_role;
