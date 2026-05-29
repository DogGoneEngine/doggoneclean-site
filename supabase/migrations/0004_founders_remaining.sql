-- 0004_founders_remaining.sql
--
-- Booking slice 3: the founders-spots-remaining counter feed.
--
-- bath_subscriptions is RLS self-read only, so an anonymous visitor on
-- /the-villages cannot count founders subscriptions directly. This
-- SECURITY DEFINER function exposes ONLY a single integer (remaining
-- founders spots for a city), never any subscriber data, so the public
-- page can render the scarcity counter without a PII leak.
--
-- Serves founders_spots_remaining_counter (the page hides the counter
-- until remaining drops below its visibility threshold; this just feeds
-- the number, auto-updated from the live count, no manual maintenance).

CREATE OR REPLACE FUNCTION public.bath_founders_remaining(p_city_slug text)
RETURNS integer
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT GREATEST(0, c.hb_founders_cap - (
    SELECT count(*)::int
    FROM public.bath_subscriptions s
    WHERE s.city_id = c.id
      AND s.is_founders = true
      AND s.status IN ('active', 'paused')
  ))
  FROM public.cities c
  WHERE c.slug = p_city_slug AND c.hb_active = true;
$$;

REVOKE ALL ON FUNCTION public.bath_founders_remaining(text) FROM public;
GRANT EXECUTE ON FUNCTION public.bath_founders_remaining(text) TO anon, authenticated;
