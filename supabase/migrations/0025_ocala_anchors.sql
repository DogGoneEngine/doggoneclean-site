-- 0025_ocala_anchors.sql
-- Anchors for the Ocala drive-time service area. A new Ocala bath client is
-- gated to within 15 minutes' DRIVE of an existing client (an "anchor"); the
-- drive time is computed by the ocala-service-area edge function, which feeds
-- the anchor addresses straight to Google Distance Matrix (Google geocodes them
-- internally, so no Geocoding API is needed). geo_lat/geo_lng are an OPTIONAL
-- coordinate cache the function prefers when present; left null until any future
-- caching pass populates them. Anchors are the recurring backbone (standing +
-- at-will); one-off clients are not routing anchors.
alter table public.clients
  add column if not exists geo_lat  double precision,
  add column if not exists geo_lng  double precision,
  add column if not exists is_anchor boolean not null default false;

update public.clients
   set is_anchor = true
 where roster_group in ('standing', 'at_will')
   and not exclude_from_everything;

-- Favor / outlier clients are still served but must not extend the service area
-- (ocala_service_area_by_anchor): flag them out as anchors.
update public.clients
   set is_anchor = false
 where name in ('Tonya Hunt', 'Greta Custer');
