-- 0026_app_secrets.sql
-- Server-only secrets the edge functions read at runtime, because this
-- environment has no tool to set a Supabase function env secret. RLS is enabled
-- with NO policy, so anon and authenticated roles get nothing; only the service
-- role (used by the edge functions) bypasses RLS and can read a value. The
-- secret VALUES are injected out of band and never committed: e.g. the Google
-- Maps server key lives under name = 'maps_server_key' for the ocala-service-area
-- function.
create table if not exists public.app_secrets (
  name text primary key,
  value text not null,
  updated_at timestamptz not null default now()
);
alter table public.app_secrets enable row level security;
revoke all on public.app_secrets from anon, authenticated;
