-- 0197_library_team_uploads_and_captions.sql
-- Two follow-ons to the unified Library (library_assets_are_the_master):
--
-- 1) Crew can upload straight to the Team gallery (Paul, 2026-06-15). An upload
--    is a site_inbox row, so it automatically appears in the owner's Assets
--    master too; the owner can re-caption, pull, or delete it. admin_add_inbox
--    stays owner-only (the owner's general upload); this is the scoped crew path
--    that always lands the photo in the team gallery.
--
-- 2) Captions are editable by any admin, not just the owner, so a crew member can
--    caption a team photo and the owner can override it. Low-stakes and the owner
--    is always the final word (owner sees every item in Assets).

create or replace function public.admin_add_team_photo(p_path text, p_note text default null)
returns uuid language plpgsql security definer set search_path to ''
as $$
declare v_id uuid;
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  insert into public.site_inbox (storage_path, note, team_visible)
  values (p_path, nullif(btrim(coalesce(p_note, '')), ''), true)
  returning id into v_id;
  return v_id;
end;
$$;
revoke all on function public.admin_add_team_photo(text, text) from public, anon;
grant execute on function public.admin_add_team_photo(text, text) to authenticated, service_role;

-- Caption editing relaxed from owner-only to any active admin.
create or replace function public.admin_library_set_caption(p_source text, p_id uuid, p_caption text)
returns void language plpgsql security definer set search_path to ''
as $$
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  if p_source = 'upload' then
    update public.site_inbox set note = nullif(btrim(coalesce(p_caption, '')), '') where id = p_id;
  else
    update public.visit_photos set library_caption = nullif(btrim(coalesce(p_caption, '')), '') where id = p_id;
  end if;
  if not found then raise exception 'item not found'; end if;
end;
$$;
revoke all on function public.admin_library_set_caption(text, uuid, text) from public, anon;
grant execute on function public.admin_library_set_caption(text, uuid, text) to authenticated, service_role;
