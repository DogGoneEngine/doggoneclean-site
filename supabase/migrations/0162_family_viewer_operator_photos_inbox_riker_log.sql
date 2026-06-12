-- 0162: Paul's 2026-06-12 batch. (1) Operator profile photos and bios live
-- on the admins row, uploaded from HR, served to the tracker, so a new
-- operator's face and words reach clients with zero code changes (Jake's
-- photo was still Paul's tonight). (2) The viewer role: Kristin gets her own
-- Orbit login with a stakeholder's view (the Family floor), per
-- family_window_into_the_business. (3) The photo inbox: a drop spot in Orbit
-- for photos Paul wants Claude to use (site imagery, profiles), ending the
-- how-do-I-get-you-this-file friction. (4) riker_log: every parse recorded
-- so a "Riker would not cooperate" report is diagnosable from data instead
-- of memory. (5) Riker learns onsite_update: household people facts land in
-- the who's-on-site field, not the void (the Alan-is-Becky's-husband miss).
--
-- Applied to dgc-prod 2026-06-12. Full definitions below.

alter table public.admins
  add column if not exists photo_path text,
  add column if not exists bio text;
alter table public.admins drop constraint if exists admins_role_check;
alter table public.admins add constraint admins_role_check
  check (role = any (array['owner'::text, 'operator'::text, 'viewer'::text]));

insert into public.admins (email, first_name, last_name, role, is_active)
select 'kwallace9791@gmail.com', 'Kristin', 'Nickerson', 'viewer', true
where not exists (select 1 from public.admins where email = 'kwallace9791@gmail.com');

update public.admins set bio = 'Owner and Hurricane Bath Operator. Over 20 years of Ocala''s dogs, one driveway at a time.'
 where role = 'owner' and bio is null;
update public.admins set bio = 'Jake is the kind of young man people are happy to see doing honest work. Calm, respectful, patient, and serious about doing things right. Dogs notice it.'
 where email = 'jakewnickerson@gmail.com';

create or replace function public.admin_set_admin_photo(p_admin uuid, p_path text)
returns void language plpgsql security definer set search_path to ''
as $$
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  update public.admins set photo_path = p_path, updated_at = now() where id = p_admin;
  if not found then raise exception 'admin not found'; end if;
end;
$$;
revoke all on function public.admin_set_admin_photo(uuid, text) from public, anon;
grant execute on function public.admin_set_admin_photo(uuid, text) to authenticated, service_role;

create or replace function public.admin_set_admin_bio(p_admin uuid, p_bio text)
returns void language plpgsql security definer set search_path to ''
as $$
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  update public.admins set bio = nullif(btrim(coalesce(p_bio, '')), ''), updated_at = now() where id = p_admin;
  if not found then raise exception 'admin not found'; end if;
end;
$$;
revoke all on function public.admin_set_admin_bio(uuid, text) from public, anon;
grant execute on function public.admin_set_admin_bio(uuid, text) to authenticated, service_role;

-- admin_list_team gains title for viewers plus bio + photo_path; the live
-- definition was replaced in full (see dgc-prod), adding:
--   'title' case: 'viewer' -> 'Family'
--   'bio', a.bio, 'photo_path', a.photo_path

-- tracker_status gains 'bio' inside the operator object (full function
-- replaced in dgc-prod; see 0160 for the prior shape).

create table if not exists public.site_inbox (
  id uuid primary key default gen_random_uuid(),
  storage_path text not null,
  note text,
  status text not null default 'new' check (status in ('new', 'used', 'dropped')),
  created_at timestamptz not null default now()
);
alter table public.site_inbox enable row level security;

create or replace function public.admin_add_inbox(p_path text, p_note text default null)
returns uuid language plpgsql security definer set search_path to ''
as $$
declare v_id uuid;
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
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
  if not public._is_admin() then raise exception 'not authorized'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object(
      'id', id, 'storage_path', storage_path, 'note', note, 'status', status, 'created_at', created_at)
      order by created_at desc)
    from public.site_inbox), '[]'::jsonb);
end;
$$;
revoke all on function public.admin_list_inbox() from public, anon;
grant execute on function public.admin_list_inbox() to authenticated, service_role;

create table if not exists public.riker_log (
  id uuid primary key default gen_random_uuid(),
  utterance text not null,
  client_id uuid,
  plan jsonb,
  created_at timestamptz not null default now()
);
alter table public.riker_log enable row level security;

-- admin_riker_apply v6: adds onsite_update (appends to clients.onsite_people,
-- returned as onsite_appended). Full function replaced in dgc-prod; the
-- complete body is 0159's with the onsite_update block added after
-- client_update handling.
