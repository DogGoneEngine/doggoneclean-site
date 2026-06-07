-- 0027_ocala_perimeter.sql
-- The Ocala service-area perimeter: a containment fence Paul drew by hand on
-- geojson.io around his outermost existing clients (2026-06-07), with the
-- southern edge then nudged down ~1 mile so it takes in three clients (Bradley
-- Johnson, Patricia Angelucci, Peter Moran) it had clipped, plus a small cushion.
-- All 33 anchors fall inside. A new Ocala bath signup must fall INSIDE this
-- polygon AND within a 15-minute drive of an existing client
-- (ocala_service_area_by_anchor). The polygon is the hard cap that stops edge
-- clients from breadcrumbing the area outward; the drive-time gate keeps each
-- stop efficient. The polygon is FROZEN: it is never recomputed from new clients.
-- Stored as GeoJSON Polygon coordinates ([[ [lng,lat], ... ]]). Public-readable (a
-- boundary, not client data) so the booking form can do an instant client-side
-- pre-check; the drive-time half stays server-side.
create table if not exists public.service_perimeters (
  slug       text primary key,
  polygon    jsonb not null,
  updated_at timestamptz not null default now()
);
alter table public.service_perimeters enable row level security;
drop policy if exists "service_perimeters_public_read" on public.service_perimeters;
create policy "service_perimeters_public_read"
  on public.service_perimeters for select using (true);

insert into public.service_perimeters (slug, polygon) values
('ocala', '[[[-82.2931753,29.2822555],[-82.2303114,29.269306],[-82.1940512,29.2678161],[-82.1783516,29.2677015],[-82.1689582,29.2639767],[-82.1529302,29.2601372],[-82.1371649,29.2595068],[-82.1214653,29.2593349],[-82.0951899,29.2592775],[-82.0936791,29.2592202],[-82.0908545,29.2526869],[-82.08078,29.2242798],[-82.0781989,29.21665],[-82.071205,29.2074207],[-82.0664592,29.2082201],[-82.0546362,29.2056038],[-82.0537204,29.1913584],[-82.0534708,29.1395928],[-82.0573841,29.1371202],[-82.0739529,29.1211196],[-82.0896058,29.106717],[-82.1080896,29.0859823],[-82.1550483,29.035],[-82.3056954,29.035],[-82.3101299,29.1675274],[-82.3305158,29.1956957],[-82.3212341,29.2256295],[-82.2931753,29.2822555]]]'::jsonb)
on conflict (slug) do update set polygon = excluded.polygon, updated_at = now();
