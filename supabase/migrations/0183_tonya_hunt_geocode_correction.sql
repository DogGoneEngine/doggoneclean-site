-- 0183_tonya_hunt_geocode_correction.sql
--
-- Bug: Tonya Hunt's client record carried geo_lat/geo_lng = 29.1850783,
-- -82.1342596, which is the Ocala city centroid, ~20 miles from her actual
-- home in East Williston. Her real location is plus code 9J52+WJW (driveway),
-- East Williston, FL 32696 -> 29.359859, -82.398413.
--
-- Provenance: an early geocoding pass geocoded her placeholder address string
-- "PlusCode East Williston" (not a real street address) and Google returned the
-- Ocala centroid. Migration 0156 found and cleared this exact failure for three
-- clients whose address said "PlusCode Ocala", but its filter only matched
-- 'PlusCode Ocala%', so Tonya ("PlusCode East Williston") kept the bad shared
-- point. Her location_plus text was always correct; only the coordinates lied.
--
-- Why this matters: clients.geo_lat/geo_lng is the destination the tracker-eta
-- edge function uses for the live drive ETA and the home pin on the client's
-- tracker map (her subscriber row has no service_lat/lng), and the coordinate
-- any route/drive-time math reads. The wrong point put her stop and her tracker
-- pin in downtown Ocala.
--
-- Coordinates are the deterministic decode of her own plus code (verified
-- against a known-good control record, Heather Albinson's 3RM3+J29), not an
-- invented value. Matched by the exact poisoned point so this is idempotent and
-- cannot touch a correctly geocoded row.

update public.clients
   set geo_lat = 29.359859,
       geo_lng = -82.398413,
       updated_at = now()
 where name = 'Tonya Hunt'
   and round(geo_lat::numeric, 3) = 29.185
   and round(geo_lng::numeric, 3) = -82.134;
