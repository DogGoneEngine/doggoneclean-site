-- 0040_admin_console.sql
-- Orbit (Clean admin console) foundation: the admins table, the _is_admin
-- guard, and admin_self(). Mirrors the Dog Gone Nails admin auth pattern but
-- lives only in dgc-prod and shares no data with DGN. Every admin RPC added in
-- later migrations is SECURITY DEFINER and re-checks _is_admin() so the teeth
-- live in the database, not the page (redesign_survival_is_a_ship_gate).
--
-- Single active admin row == god mode. No role column until HR grows; when it
-- does, add role ('owner'|'manager'|'specialist') and branch RPC permissions.
-- Handing Clean off to a buyer means deleting Paul's row here, nothing else
-- (clean_stays_saleable).

create extension if not exists citext;

create table if not exists public.admins (
  id uuid primary key default gen_random_uuid(),
  auth_user_id uuid unique references auth.users(id) on delete set null,
  email citext unique,
  first_name text,
  last_name text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.admins enable row level security;
drop policy if exists admins_self_read on public.admins;
create policy admins_self_read on public.admins
  for select to authenticated
  using (auth_user_id = auth.uid());

create or replace function public._is_admin()
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists(
    select 1 from public.admins
    where auth_user_id = auth.uid() and is_active
  );
$$;
revoke all on function public._is_admin() from public;
grant execute on function public._is_admin() to authenticated;

create or replace function public.admin_self()
returns table (
  id uuid, first_name text, last_name text, email citext, is_active boolean
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  return query
    select a.id, a.first_name, a.last_name, a.email, a.is_active
      from public.admins a
     where a.auth_user_id = auth.uid() and a.is_active
     limit 1;
end;
$$;
revoke all on function public.admin_self() from public;
grant execute on function public.admin_self() to authenticated;

-- Seed Paul as the owner admin (idempotent). Links to the auth.users row if he
-- has already signed in; otherwise the email match fills auth_user_id on first
-- Google sign-in via the on-conflict update below once the row exists.
insert into public.admins (auth_user_id, email, first_name, last_name, is_active)
select u.id, u.email::citext, 'Paul', 'Nickerson', true
  from auth.users u
 where lower(u.email) = lower('nickerson.paul@gmail.com')
on conflict (email) do update
  set auth_user_id = excluded.auth_user_id, is_active = true;

-- If Paul has not signed in yet there is no auth.users row to join, so ensure
-- the email is registered so the console authorizes him the moment he does.
insert into public.admins (email, first_name, last_name, is_active)
values ('nickerson.paul@gmail.com', 'Paul', 'Nickerson', true)
on conflict (email) do nothing;
