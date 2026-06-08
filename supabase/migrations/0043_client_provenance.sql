-- 0043_client_provenance.sql
-- Open the client book up from the 52 curated legacy records to Paul's whole
-- real book, sourced from his calendar and verified against the Drive contact
-- sheets. Adds:
--   * an 'active' roster group for current (Acuity-era) customers, alongside
--     the existing legacy groups;
--   * provenance: where a record came from and a stable external reference
--     (the Acuity appointment/customer id) so re-imports never duplicate;
--   * first/last seen timestamps for the active book.
-- Existing 52 records are stamped source='legacy_seed' and keep their group.

alter table public.clients drop constraint if exists clients_roster_group_check;
alter table public.clients add constraint clients_roster_group_check
  check (roster_group = any (array['standing','one_off','at_will','banned','active']));

alter table public.clients add column if not exists source text not null default 'legacy_seed';
alter table public.clients add column if not exists external_ref text;
alter table public.clients add column if not exists first_seen_at timestamptz;
alter table public.clients add column if not exists last_seen_at timestamptz;

-- Idempotent imports: an external_ref (e.g. an Acuity customer id) maps to at
-- most one client record.
create unique index if not exists clients_external_ref_uidx
  on public.clients (external_ref) where external_ref is not null;
