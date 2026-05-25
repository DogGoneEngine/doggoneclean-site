-- Dog Gone Clean v1 schema: the client book (clients + dogs).
-- Clean is greenlit to build iteratively; these early tables are rebuildable until
-- they settle (Oracle: no_database_until_rules_agreed). This lives in Clean's OWN
-- Supabase project (dgc-prod), never dgn-prod (Oracle: own_infrastructure).
--
-- The records hold real client PII: home addresses, gate codes, door codes, and
-- access notes. Every table is therefore RLS-locked with NO policy, so only the
-- service role reaches the data until the portal's auth is built. Do not add a
-- permissive policy without an auth model behind it.

create table public.clients (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  aka text,
  roster_group text not null
    check (roster_group in ('standing', 'one_off', 'at_will', 'banned')),
  status text not null,
  service_type text
    check (service_type in (
      'full_groom', 'bath', 'nails_only_legacy', 'mixed_groom_and_nails', 'nails_only'
    )),
  cadence_days integer check (cadence_days is null or cadence_days > 0),
  cadence_confidence text check (cadence_confidence in ('high', 'medium', 'low')),
  cadence_note text,
  hardness text check (hardness in ('HARD', 'SOFT', 'FLEX', 'FLEX+')),
  location_address text,
  location_zip text,
  location_zone text,
  location_plus text,
  location_geo_notes text,
  access jsonb not null default '{}'::jsonb,
  availability_hard text,
  availability_soft text,
  availability_not_days text[] not null default '{}',
  availability_seasonal text,
  flags text[] not null default '{}',
  relationships text[] not null default '{}',
  data_gaps text[] not null default '{}',
  routed boolean not null default false,
  exclude_from_everything boolean not null default false,
  note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.dogs (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references public.clients(id) on delete cascade,
  name text not null,
  breed text,
  price_cents integer check (price_cents is null or price_cents >= 0),
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index clients_roster_group_idx on public.clients (roster_group);
create index clients_status_idx on public.clients (status);
create index clients_service_type_idx on public.clients (service_type);
create index dogs_client_id_idx on public.dogs (client_id);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger clients_set_updated_at
  before update on public.clients
  for each row execute function public.set_updated_at();

create trigger dogs_set_updated_at
  before update on public.dogs
  for each row execute function public.set_updated_at();

alter table public.clients enable row level security;
alter table public.dogs enable row level security;
