-- 0196_library_unified.sql
-- The Library, rebuilt to Paul's model (library_assets_are_the_master, 2026-06-15):
--   Assets is the MASTER list of everything in the library. Team gallery and
--   Website are COPIES/shares of an Asset, not separate piles. Removing a copy
--   from Team or Website never loses the item; the master stays in Assets. The
--   only permanent loss is a real delete in Assets.
--
-- Two photo origins feed the library and stay in their own tables:
--   site_inbox   - photos/videos the owner uploads by hand. Always a library
--                  member; a real delete removes the file for good.
--   visit_photos - photos taken on a visit. A library member only once "kept"
--                  (someone shared it to Team / suggested it to Website / saved
--                  it). Removing from the library un-keeps it but leaves the
--                  photo in the client's visit; it never deletes the visit photo.
--
-- Team and Website are independent flags on a library item. Suggest/approve for
-- the website keeps the owner-approval gate from 0173/0174. The public gallery
-- feed and the internal team gallery now union both origins.

-- ---- Schema: let uploads carry the same destination flags as visit photos ----
alter table public.site_inbox add column if not exists team_visible boolean not null default false;
alter table public.site_inbox add column if not exists website_state text not null default 'none'
  check (website_state in ('none', 'queued', 'live'));
alter table public.site_inbox add column if not exists website_proposed_by uuid references public.admins(id) on delete set null;
alter table public.site_inbox add column if not exists website_approved_by uuid references public.admins(id) on delete set null;
alter table public.site_inbox add column if not exists website_live_at timestamptz;
alter table public.site_inbox add column if not exists website_public_url text;

-- ---- Schema: visit photos gain library membership + an editable caption -------
alter table public.visit_photos add column if not exists kept boolean not null default false;
alter table public.visit_photos add column if not exists library_caption text;
-- Backfill: anything already shared anywhere is already in the library.
update public.visit_photos set kept = true
 where kept = false and (team_visible or website_state <> 'none');

-- ---- The Assets master list (owner only): uploads + kept visit photos ---------
create or replace function public.admin_library_list()
returns jsonb language plpgsql security definer set search_path to ''
as $$
begin
  if public._admin_role() <> 'owner' then raise exception 'owner only'; end if;
  return coalesce((
    select jsonb_agg(item order by dated desc nulls last)
    from (
      select jsonb_build_object(
        'source', 'upload', 'id', si.id, 'path', si.storage_path,
        'caption', si.note, 'dog_name', null, 'client', null,
        'dated', si.created_at, 'team', si.team_visible, 'web', si.website_state,
        'kind', null
      ) item, si.created_at dated
      from public.site_inbox si
      union all
      select jsonb_build_object(
        'source', 'visit', 'id', p.id, 'path', p.storage_path,
        'caption', p.library_caption, 'dog_name', d.name, 'client', c.name,
        'dated', coalesce(v.visited_at, p.created_at),
        'team', p.team_visible, 'web', p.website_state, 'kind', p.kind
      ) item, coalesce(v.visited_at, p.created_at) dated
      from public.visit_photos p
      left join public.dogs d on d.id = p.dog_id
      left join public.visits v on v.id = p.visit_id
      left join public.clients c on c.id = v.client_id
     where p.kept
    ) u), '[]'::jsonb);
end;
$$;
revoke all on function public.admin_library_list() from public, anon;
grant execute on function public.admin_library_list() to authenticated, service_role;

-- ---- Team flag (any admin). Turning it on keeps a visit photo in the library --
create or replace function public.admin_library_set_team(p_source text, p_id uuid, p_on boolean)
returns void language plpgsql security definer set search_path to ''
as $$
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  if p_source = 'upload' then
    update public.site_inbox set team_visible = coalesce(p_on, false) where id = p_id;
  else
    update public.visit_photos
       set team_visible = coalesce(p_on, false),
           kept = case when coalesce(p_on, false) then true else kept end
     where id = p_id;
  end if;
  if not found then raise exception 'item not found'; end if;
end;
$$;
revoke all on function public.admin_library_set_team(text, uuid, boolean) from public, anon;
grant execute on function public.admin_library_set_team(text, uuid, boolean) to authenticated, service_role;

-- ---- Website suggest (any admin). Queues only; never goes live here -----------
create or replace function public.admin_library_suggest_website(p_source text, p_id uuid)
returns void language plpgsql security definer set search_path to ''
as $$
declare v_me uuid;
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  select id into v_me from public.admins where auth_user_id = auth.uid() and is_active;
  if p_source = 'upload' then
    update public.site_inbox set website_state = 'queued', website_proposed_by = v_me
     where id = p_id and website_state = 'none';
    if not found and not exists (select 1 from public.site_inbox where id = p_id) then
      raise exception 'item not found';
    end if;
  else
    update public.visit_photos set website_state = 'queued', website_proposed_by = v_me, kept = true
     where id = p_id and website_state = 'none';
    if not found and not exists (select 1 from public.visit_photos where id = p_id) then
      raise exception 'item not found';
    end if;
  end if;
end;
$$;
revoke all on function public.admin_library_suggest_website(text, uuid) from public, anon;
grant execute on function public.admin_library_suggest_website(text, uuid) to authenticated, service_role;

-- ---- Withdraw a website suggestion while still queued (any admin) -------------
create or replace function public.admin_library_withdraw_website(p_source text, p_id uuid)
returns void language plpgsql security definer set search_path to ''
as $$
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  if p_source = 'upload' then
    update public.site_inbox set website_state = 'none', website_proposed_by = null
     where id = p_id and website_state = 'queued';
  else
    update public.visit_photos set website_state = 'none', website_proposed_by = null
     where id = p_id and website_state = 'queued';
  end if;
  if not found then raise exception 'not a queued item'; end if;
end;
$$;
revoke all on function public.admin_library_withdraw_website(text, uuid) from public, anon;
grant execute on function public.admin_library_withdraw_website(text, uuid) to authenticated, service_role;

-- ---- Approve to live: OWNER ONLY. Stores the browser-signed URL, enforces the
--      combined FIFO cap across both origins (the public wall is one wall) ------
create or replace function public.admin_library_approve_website(p_source text, p_id uuid, p_public_url text default null)
returns void language plpgsql security definer set search_path to ''
as $$
declare v_me uuid; v_cap int; v_cutoff timestamptz;
begin
  if public._admin_role() <> 'owner' then raise exception 'owner only'; end if;
  select id into v_me from public.admins where auth_user_id = auth.uid() and is_active;
  if p_source = 'upload' then
    update public.site_inbox
       set website_state = 'live', website_approved_by = v_me, website_live_at = now(),
           website_public_url = coalesce(p_public_url, website_public_url)
     where id = p_id and website_state in ('queued', 'none');
  else
    update public.visit_photos
       set website_state = 'live', website_approved_by = v_me, website_live_at = now(),
           website_public_url = coalesce(p_public_url, website_public_url), kept = true
     where id = p_id and website_state in ('queued', 'none');
  end if;
  if not found then raise exception 'item not found or already live'; end if;

  -- Combined cap across both origins: find the live_at of the cap-th newest live
  -- item; anything strictly older rolls off the public wall.
  v_cap := public._website_gallery_cap();
  select lat into v_cutoff from (
    select website_live_at lat from public.visit_photos where website_state = 'live'
    union all
    select website_live_at from public.site_inbox where website_state = 'live'
  ) u where lat is not null order by lat desc offset greatest(v_cap - 1, 0) limit 1;
  if v_cutoff is not null then
    update public.visit_photos set website_state = 'none', website_public_url = null
     where website_state = 'live' and website_live_at < v_cutoff;
    update public.site_inbox set website_state = 'none', website_public_url = null
     where website_state = 'live' and website_live_at < v_cutoff;
  end if;
end;
$$;
revoke all on function public.admin_library_approve_website(text, uuid, text) from public, anon;
grant execute on function public.admin_library_approve_website(text, uuid, text) to authenticated, service_role;

-- ---- Pull a live/queued item off the website. Owner only ---------------------
create or replace function public.admin_library_unpublish_website(p_source text, p_id uuid)
returns void language plpgsql security definer set search_path to ''
as $$
begin
  if public._admin_role() <> 'owner' then raise exception 'owner only'; end if;
  if p_source = 'upload' then
    update public.site_inbox set website_state = 'none', website_live_at = null, website_public_url = null
     where id = p_id and website_state in ('live', 'queued');
  else
    update public.visit_photos set website_state = 'none', website_live_at = null, website_public_url = null
     where id = p_id and website_state in ('live', 'queued');
  end if;
  if not found then raise exception 'not on the website track'; end if;
end;
$$;
revoke all on function public.admin_library_unpublish_website(text, uuid) from public, anon;
grant execute on function public.admin_library_unpublish_website(text, uuid) to authenticated, service_role;

-- ---- Edit a caption on any library item. Owner only --------------------------
create or replace function public.admin_library_set_caption(p_source text, p_id uuid, p_caption text)
returns void language plpgsql security definer set search_path to ''
as $$
begin
  if public._admin_role() <> 'owner' then raise exception 'owner only'; end if;
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

-- ---- Delete from the library. Owner only. The ONLY way to lose something.
--      Upload: the row goes and the caller removes the storage object for good.
--      Visit:  un-kept and unshared, but the photo stays in the client's visit -
create or replace function public.admin_library_delete(p_source text, p_id uuid)
returns jsonb language plpgsql security definer set search_path to ''
as $$
declare v_path text;
begin
  if public._admin_role() <> 'owner' then raise exception 'owner only'; end if;
  if p_source = 'upload' then
    select storage_path into v_path from public.site_inbox where id = p_id;
    if v_path is null then raise exception 'item not found'; end if;
    delete from public.site_inbox where id = p_id;
    return jsonb_build_object('source', 'upload', 'storage_path', v_path);
  else
    update public.visit_photos
       set kept = false, team_visible = false, website_state = 'none',
           website_live_at = null, website_public_url = null
     where id = p_id;
    if not found then raise exception 'item not found'; end if;
    return jsonb_build_object('source', 'visit');
  end if;
end;
$$;
revoke all on function public.admin_library_delete(text, uuid) from public, anon;
grant execute on function public.admin_library_delete(text, uuid) to authenticated, service_role;

-- ---- Team gallery (all admins): now unions kept uploads + team visit photos ---
create or replace function public.admin_team_gallery()
returns jsonb language plpgsql security definer set search_path to ''
as $$
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  return coalesce((
    select jsonb_agg(item order by dated desc nulls last)
    from (
      select jsonb_build_object(
        'source', 'upload', 'id', si.id, 'path', si.storage_path, 'kind', null,
        'dog_name', null, 'client', null, 'visited_at', si.created_at,
        'caption', si.note, 'website_state', si.website_state, 'client_visible', false
      ) item, si.created_at dated
      from public.site_inbox si where si.team_visible
      union all
      select jsonb_build_object(
        'source', 'visit', 'id', p.id, 'path', p.storage_path, 'kind', p.kind,
        'dog_name', d.name, 'client', c.name, 'visited_at', v.visited_at,
        'caption', p.library_caption, 'website_state', p.website_state, 'client_visible', p.client_visible
      ) item, coalesce(v.visited_at, p.created_at) dated
      from public.visit_photos p
      left join public.dogs d on d.id = p.dog_id
      left join public.visits v on v.id = p.visit_id
      left join public.clients c on c.id = v.client_id
     where p.team_visible
    ) u), '[]'::jsonb);
end;
$$;
revoke all on function public.admin_team_gallery() from public, anon;
grant execute on function public.admin_team_gallery() to authenticated, service_role;

-- ---- The owner's website review surface: queued + live across both origins ----
create or replace function public.admin_website_review()
returns jsonb language plpgsql security definer set search_path to ''
as $$
declare q jsonb; l jsonb;
begin
  if public._admin_role() <> 'owner' then raise exception 'owner only'; end if;
  select coalesce(jsonb_agg(item order by dated desc nulls last), '[]'::jsonb) into q from (
    select jsonb_build_object('source','upload','id',si.id,'path',si.storage_path,'kind',null,
      'dog_name',null,'client',null,'visited_at',si.created_at,'caption',si.note,
      'proposed_by', btrim(coalesce(a.first_name,'') || ' ' || coalesce(a.last_name,''))) item, si.created_at dated
      from public.site_inbox si left join public.admins a on a.id = si.website_proposed_by
     where si.website_state = 'queued'
    union all
    select jsonb_build_object('source','visit','id',p.id,'path',p.storage_path,'kind',p.kind,
      'dog_name',d.name,'client',c.name,'visited_at',v.visited_at,'caption',p.library_caption,
      'proposed_by', btrim(coalesce(a.first_name,'') || ' ' || coalesce(a.last_name,''))) item, p.created_at dated
      from public.visit_photos p
      left join public.dogs d on d.id = p.dog_id
      left join public.visits v on v.id = p.visit_id
      left join public.clients c on c.id = v.client_id
      left join public.admins a on a.id = p.website_proposed_by
     where p.website_state = 'queued'
  ) u;
  select coalesce(jsonb_agg(item order by live_at desc nulls last), '[]'::jsonb) into l from (
    select jsonb_build_object('source','upload','id',si.id,'path',si.storage_path,'kind',null,
      'dog_name',null,'client',null,'caption',si.note,'live_at',si.website_live_at) item, si.website_live_at live_at
      from public.site_inbox si where si.website_state = 'live'
    union all
    select jsonb_build_object('source','visit','id',p.id,'path',p.storage_path,'kind',p.kind,
      'dog_name',d.name,'client',c.name,'caption',p.library_caption,'live_at',p.website_live_at) item, p.website_live_at live_at
      from public.visit_photos p
      left join public.dogs d on d.id = p.dog_id
      left join public.visits v on v.id = p.visit_id
      left join public.clients c on c.id = v.client_id
     where p.website_state = 'live'
  ) u;
  return jsonb_build_object('queued', q, 'live', l, 'cap', public._website_gallery_cap());
end;
$$;
revoke all on function public.admin_website_review() from public, anon;
grant execute on function public.admin_website_review() to authenticated, service_role;

-- ---- Public homepage gallery feed: live items from both origins, anon-safe ----
create or replace function public.website_gallery()
returns jsonb language plpgsql security definer set search_path to ''
as $$
begin
  return coalesce((
    select jsonb_agg(item order by live_at desc nulls last)
    from (
      select jsonb_build_object('id', si.id, 'url', si.website_public_url, 'dog_name', null) item, si.website_live_at live_at
        from public.site_inbox si where si.website_state = 'live' and si.website_public_url is not null
      union all
      select jsonb_build_object('id', p.id, 'url', p.website_public_url, 'dog_name', d.name) item, p.website_live_at live_at
        from public.visit_photos p left join public.dogs d on d.id = p.dog_id
       where p.website_state = 'live' and p.website_public_url is not null
    ) u), '[]'::jsonb);
end;
$$;
revoke all on function public.website_gallery() from public;
grant execute on function public.website_gallery() to anon, authenticated, service_role;

-- ---- Sharing from the visit screen now keeps the photo in the library too -----
create or replace function public.admin_set_photo_team(p_id uuid, p_val boolean)
returns void language plpgsql security definer set search_path to ''
as $$
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  update public.visit_photos
     set team_visible = coalesce(p_val, false),
         kept = case when coalesce(p_val, false) then true else kept end
   where id = p_id;
  if not found then raise exception 'photo not found'; end if;
end;
$$;
revoke all on function public.admin_set_photo_team(uuid, boolean) from public, anon;
grant execute on function public.admin_set_photo_team(uuid, boolean) to authenticated, service_role;

create or replace function public.admin_suggest_photo_website(p_id uuid)
returns void language plpgsql security definer set search_path to ''
as $$
declare v_me uuid;
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  select id into v_me from public.admins where auth_user_id = auth.uid() and is_active;
  update public.visit_photos
     set website_state = 'queued', website_proposed_by = v_me, kept = true
   where id = p_id and website_state = 'none';
  if not found and not exists (select 1 from public.visit_photos where id = p_id) then
    raise exception 'photo not found';
  end if;
end;
$$;
revoke all on function public.admin_suggest_photo_website(uuid) from public, anon;
grant execute on function public.admin_suggest_photo_website(uuid) to authenticated, service_role;
