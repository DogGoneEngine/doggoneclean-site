-- 0020_ocala_anchors.sql
-- Ocala's service area for new clients is a drive-time gate, not a polygon
-- (ocala_service_area_by_anchor): a new address qualifies if it is within a
-- 15-minute drive of an existing anchor stop. Anchors are routed legacy standing
-- clients plus active bath clients; exception clients Paul serves as favors are
-- flagged out. This schema is the durable foundation; the live drive-time check
-- (Google Distance Matrix on Clean's Maps key) and the one-time anchor geocode
-- are wired on top.

-- Geocoded coordinates for legacy clients (populated by the one-time anchor
-- geocode) and whether the stop counts as a service-area anchor.
alter table public.clients
  add column if not exists geo_lat numeric,
  add column if not exists geo_lng numeric,
  add column if not exists is_anchor boolean not null default false;

-- New bath clients anchor by default (the area grows organically as Paul takes
-- them on), each individually toggleable.
alter table public.bath_subscribers
  add column if not exists is_anchor boolean not null default true;
