-- 0184_backfill_pluscode_coordinates.sql
--
-- Backfill geo_lat/geo_lng for every client that had a plus code but no
-- coordinates, so each stop has a reliable map pin and the admin maps link,
-- tracker drive-ETA, and route math all resolve to the real driveway instead of
-- falling back to a plus-code string Google often cannot parse (no town, or
-- "driveway .../parking ..." label noise). Same class of fix as 0183 (Tonya
-- Hunt), done for the rest of the book in one pass.
--
-- Coordinates are the deterministic decode of each client's own driveway plus
-- code (Open Location Code), recovered against the Marion County 1-degree cell
-- prefix 76XV (covers Ocala, Williston, Dunnellon, Fellowship). Each result was
-- validated two ways: it lands inside the service-area bounding box, and for the
-- clients that also carry a real street address the decode matches it (e.g.
-- David Midgett SW 37th Pl 34471, Jane Henrich NW 56th St 34475, Sally Alderman
-- SE 22nd Ave). Not invented values: a plus code IS a coordinate.
--
-- Matched by name and guarded on geo_lat is null, so this is idempotent and
-- never overwrites a coordinate set by a later honest geocode.

update public.clients set geo_lat = 29.139359, geo_lng = -82.252112, updated_at = now()
 where name = 'Beverly Gilbert'  and geo_lat is null;   -- driveway 4PQX+P5Q
update public.clients set geo_lat = 29.170609, geo_lng = -82.279188, updated_at = now()
 where name = 'Chester Weber'    and geo_lat is null;   -- 5PCC+68V (near base anchor)
update public.clients set geo_lat = 29.146984, geo_lng = -82.150388, updated_at = now()
 where name = 'David Midgett'     and geo_lat is null;   -- 4RWX+QRX
update public.clients set geo_lat = 29.147922, geo_lng = -82.204838, updated_at = now()
 where name = 'Donna Rodriquez'   and geo_lat is null;   -- 4QXW+538
update public.clients set geo_lat = 29.143016, geo_lng = -82.208787, updated_at = now()
 where name = 'Hope Brooks'       and geo_lat is null;   -- 4QVR+6F5 (anchor)
update public.clients set geo_lat = 29.244953, geo_lng = -82.144063, updated_at = now()
 where name = 'Jane Henrich'      and geo_lat is null;   -- 6VV4+X9J
update public.clients set geo_lat = 29.234703, geo_lng = -82.276263, updated_at = now()
 where name = 'Mary Ford'         and geo_lat is null;   -- driveway 6PMF+VFP Fellowship
update public.clients set geo_lat = 29.177891, geo_lng = -82.108063, updated_at = now()
 where name = 'Sally Alderman'    and geo_lat is null;   -- 5VHR+5Q4
update public.clients set geo_lat = 29.207797, geo_lng = -82.205562, updated_at = now()
 where name = 'Sally O''Laughlin' and geo_lat is null;   -- 6Q5V+4Q9
update public.clients set geo_lat = 29.267234, geo_lng = -82.225113, updated_at = now()
 where name = 'Tommy Burns'       and geo_lat is null;   -- driveway 7Q8F+VXQ
