-- 0174_website_gallery_feed.sql
-- Phase 2 of photo_destinations: the public homepage gallery feed.
--
-- The visit-photos bucket is private (signed URLs), and a public visitor has no
-- auth and no edge function to sign for them (edge deploys are gated). So at the
-- moment the owner APPROVES a photo, the owner's browser (which can sign) mints a
-- long-lived signed URL and stores it on the row; the anon website_gallery() feed
-- hands those URLs to the homepage. No public bucket, no copy, no edge function.
-- A pulled photo drops out of the feed; its stored URL is cleared on unpublish.

alter table public.visit_photos add column if not exists website_public_url text;

-- Approve now also stores the public URL the browser signed. Owner only. The
-- 1-arg version is dropped so the new signature is unambiguous.
drop function if exists public.admin_approve_photo_website(uuid);
create or replace function public.admin_approve_photo_website(p_id uuid, p_public_url text default null)
returns void language plpgsql security definer set search_path to ''
as $$
declare v_me uuid; v_cap int;
begin
  if public._admin_role() <> 'owner' then raise exception 'owner only'; end if;
  select id into v_me from public.admins where auth_user_id = auth.uid() and is_active;
  update public.visit_photos
     set website_state = 'live', website_approved_by = v_me, website_live_at = now(),
         website_public_url = coalesce(p_public_url, website_public_url)
   where id = p_id and website_state in ('queued', 'none');
  if not found then raise exception 'photo not found or already live'; end if;

  v_cap := public._website_gallery_cap();
  update public.visit_photos
     set website_state = 'none'
   where id in (
     select id from public.visit_photos
      where website_state = 'live'
      order by website_live_at desc nulls last
      offset v_cap);
end;
$$;
revoke all on function public.admin_approve_photo_website(uuid, text) from public, anon;
grant execute on function public.admin_approve_photo_website(uuid, text) to authenticated, service_role;

-- Unpublish also clears the stored public URL so a pulled photo carries nothing.
create or replace function public.admin_unpublish_photo_website(p_id uuid)
returns void language plpgsql security definer set search_path to ''
as $$
begin
  if public._admin_role() <> 'owner' then raise exception 'owner only'; end if;
  update public.visit_photos
     set website_state = 'none', website_live_at = null, website_public_url = null
   where id = p_id and website_state in ('live', 'queued');
  if not found then raise exception 'not on the website track'; end if;
end;
$$;
revoke all on function public.admin_unpublish_photo_website(uuid) from public, anon;
grant execute on function public.admin_unpublish_photo_website(uuid) to authenticated, service_role;

-- The public homepage gallery feed: live photos with a stored URL, newest first,
-- capped. Anon-callable (it is the public marketing page). Returns only the URL
-- and the dog's first name, never client or visit detail.
create or replace function public.website_gallery()
returns jsonb language plpgsql security definer set search_path to ''
as $$
begin
  return coalesce((
    select jsonb_agg(jsonb_build_object('id', p.id, 'url', p.website_public_url, 'dog_name', d.name)
                     order by p.website_live_at desc nulls last)
    from public.visit_photos p
    left join public.dogs d on d.id = p.dog_id
   where p.website_state = 'live' and p.website_public_url is not null), '[]'::jsonb);
end;
$$;
revoke all on function public.website_gallery() from public;
grant execute on function public.website_gallery() to anon, authenticated, service_role;
