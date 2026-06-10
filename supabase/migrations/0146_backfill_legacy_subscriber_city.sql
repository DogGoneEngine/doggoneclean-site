-- 0146: 8 legacy-claimed subscriber rows carried city_id = null (created by
-- the claim path before the city default existed). A null city makes
-- clean_effective_duration_minutes return null and would make a portal
-- reschedule raise, the same class of legacy-reschedule breakage 0143 fixed
-- in the engine. Found live by the capacity watcher's first scan (Jane
-- Henrich reported "nothing in 28 days" with minutes null). Every legacy
-- client's service address is Ocala (ocala_is_a_served_city), so the
-- backfill is fact, not guess.

update public.bath_subscribers
   set city_id = (select id from public.cities where slug = 'ocala')
 where city_id is null
   and client_id is not null;
