-- 0022_bath_durations_and_min_stop.sql
-- Starting bath visit durations and a minimum stop block, both per city.
-- Paul (2026-06-07): no good bath-only cycle data yet, so to start, quick baths
-- are 30 minutes and longer baths 60, refined from real data later. Mapped to the
-- existing coat tiers: smoothcoat = quick = 30, doublecoat = longer = 60. The
-- minimum stop block (30) is the floor any scheduled stop reserves regardless of
-- a lower historical median (e.g. Lisa Prater's 11-minute mixed nails median):
-- a mobile stop has irreducible drive-up and setup overhead.

alter table public.cities
  add column if not exists hb_smoothcoat_minutes integer
    check (hb_smoothcoat_minutes is null or hb_smoothcoat_minutes > 0),
  add column if not exists hb_doublecoat_minutes integer
    check (hb_doublecoat_minutes is null or hb_doublecoat_minutes > 0),
  add column if not exists hb_min_stop_minutes integer not null default 30
    check (hb_min_stop_minutes > 0);
