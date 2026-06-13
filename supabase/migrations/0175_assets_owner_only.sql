-- 0175_assets_owner_only.sql
-- Library access tightening (library_tabs_by_role). The Team gallery opens to
-- employees and stakeholders, but Assets (the owner's upload/curation shelf) and
-- the Website approval queue stay owner-only. The UI hides those tabs for
-- non-owners; this makes it a real boundary, not just a hidden tab: the Assets
-- (site_inbox) RPCs now require the owner role, so an operator on the Library
-- floor cannot read or change Assets by calling the RPC directly. (admin_website_*
-- and admin_website_review were already owner-only.) When a future teammate needs
-- more, it is granted, not default; see access_grants_live_on_the_access_page.
create or replace function public.admin_add_inbox(p_path text, p_note text default null)
returns uuid language plpgsql security definer set search_path to ''
as $$
declare v_id uuid;
begin
  if public._admin_role() <> 'owner' then raise exception 'owner only'; end if;
  insert into public.site_inbox (storage_path, note) values (p_path, p_note) returning id into v_id;
  return v_id;
end;
$$;
revoke all on function public.admin_add_inbox(text, text) from public, anon;
grant execute on function public.admin_add_inbox(text, text) to authenticated, service_role;

create or replace function public.admin_list_inbox()
returns jsonb language plpgsql security definer set search_path to ''
as $$
begin
  if public._admin_role() <> 'owner' then raise exception 'owner only'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object(
      'id', id, 'storage_path', storage_path, 'note', note, 'status', status, 'created_at', created_at)
      order by created_at desc)
    from public.site_inbox), '[]'::jsonb);
end;
$$;
revoke all on function public.admin_list_inbox() from public, anon;
grant execute on function public.admin_list_inbox() to authenticated, service_role;

create or replace function public.admin_update_inbox_note(p_id uuid, p_note text)
returns void language plpgsql security definer set search_path to ''
as $$
begin
  if public._admin_role() <> 'owner' then raise exception 'owner only'; end if;
  update public.site_inbox
     set note = nullif(btrim(coalesce(p_note, '')), '')
   where id = p_id;
  if not found then raise exception 'inbox item not found'; end if;
end;
$$;
revoke all on function public.admin_update_inbox_note(uuid, text) from public, anon;
grant execute on function public.admin_update_inbox_note(uuid, text) to authenticated, service_role;

create or replace function public.admin_set_inbox_status(p_id uuid, p_status text)
returns void language plpgsql security definer set search_path to ''
as $$
begin
  if public._admin_role() <> 'owner' then raise exception 'owner only'; end if;
  if p_status not in ('new', 'shelf', 'used', 'dropped') then
    raise exception 'bad status';
  end if;
  update public.site_inbox set status = p_status where id = p_id;
  if not found then raise exception 'inbox item not found'; end if;
end;
$$;
revoke all on function public.admin_set_inbox_status(uuid, text) from public, anon;
grant execute on function public.admin_set_inbox_status(uuid, text) to authenticated, service_role;
