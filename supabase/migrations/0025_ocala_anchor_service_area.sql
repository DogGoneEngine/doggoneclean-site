-- 0025_ocala_anchor_service_area.sql
-- Open Ocala to new bath clients, gated to within ~15 minutes of an existing
-- client (an "anchor"), so a new stop is always near a stop Paul already makes
-- (ocala_service_area_by_anchor). The Villages uses a service polygon; Ocala has
-- no polygon, so its service area is "near an anchor" instead.
--
-- v1 uses straight-line distance to the nearest anchor as the gate (no extra
-- Google API: Clean's Maps key is Maps JS + Places only). ~6 straight-line miles
-- approximates a 15-minute Ocala drive (road distance runs longer than crow-flies).
-- The drive-time-exact upgrade (Distance Matrix) is a later swap behind the same
-- function. The gate stays fail-closed: it returns false for any point until the
-- anchors carry coordinates, and Ocala stays hb_active=false until then.

alter table public.clients
  add column if not exists geo_lat  double precision,
  add column if not exists geo_lng  double precision,
  add column if not exists is_anchor boolean not null default false;

-- Anchors are the recurring backbone Paul reliably visits: standing + at-will.
-- One-off clients are not routing anchors. Tunable later.
update public.clients
   set is_anchor = true
 where roster_group in ('standing', 'at_will')
   and not exclude_from_everything;

-- Great-circle distance in miles (no PostGIS / earthdistance dependency).
create or replace function public.haversine_miles(
  lat1 double precision, lng1 double precision,
  lat2 double precision, lng2 double precision)
returns double precision
language sql immutable
as $$
  select 3958.7613 * 2 * asin(sqrt(
    power(sin(radians(lat2 - lat1) / 2), 2) +
    cos(radians(lat1)) * cos(radians(lat2)) *
    power(sin(radians(lng2 - lng1) / 2), 2)
  ));
$$;

-- True if (p_lat,p_lng) is within p_radius_miles of any geocoded anchor. This is
-- the Ocala service-area gate; bath_start_subscription will call it for cities
-- with no polygon, and the funnel can pre-check it.
create or replace function public.bath_ocala_in_service_area(
  p_lat double precision,
  p_lng double precision,
  p_radius_miles double precision default 6)
returns boolean
language sql
stable
security definer
set search_path to 'public', 'pg_temp'
as $$
  select coalesce((
    select true
    from public.clients c
    where c.is_anchor
      and c.geo_lat is not null
      and c.geo_lng is not null
      and public.haversine_miles(p_lat, p_lng, c.geo_lat, c.geo_lng) <= p_radius_miles
    limit 1
  ), false);
$$;

revoke all on function public.bath_ocala_in_service_area(double precision, double precision, double precision) from public;
grant execute on function public.bath_ocala_in_service_area(double precision, double precision, double precision) to anon, authenticated;
