-- 0039_waitlist.sql
-- Launch waitlist for cities that are served but not yet open for new-client
-- booking (currently Ocala: ocala_is_a_served_city, hb_active false). The
-- coming-soon city page captures interest so Paul can notify them when the city
-- opens. Mirrors the Dog Gone Nails waitlist. Anon can insert (join the list)
-- but cannot read the table back; only the service role reads it.
create table if not exists public.waitlist (
  id         uuid        primary key default gen_random_uuid(),
  email      text        not null,
  city_slug  text        not null,
  zip_code   text,
  dog_count  integer,
  created_at timestamptz not null default now()
);

alter table public.waitlist enable row level security;

-- A visitor may add themselves to the list; they may not read anyone's entries.
drop policy if exists waitlist_anon_insert on public.waitlist;
create policy waitlist_anon_insert
  on public.waitlist for insert
  to anon, authenticated
  with check (true);

revoke select on public.waitlist from anon, authenticated;

create index if not exists waitlist_city_idx on public.waitlist (city_slug, created_at desc);
