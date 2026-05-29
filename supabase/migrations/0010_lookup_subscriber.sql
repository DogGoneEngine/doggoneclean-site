-- 0010_lookup_subscriber.sql
--
-- Returning-client recognition for the booking funnel (Step 1), matching the
-- Dog Gone Nails flow: when a visitor types a phone number we already have, the
-- funnel greets them by name instead of treating them like a stranger. This is
-- the anon-callable lookup behind that greeting.
--
-- Returns ONLY { found, first_name } - the minimum needed to say "Welcome back,
-- <name>". No address, email, or other PII is exposed, so a phone guess reveals
-- nothing beyond a first name (same posture as the nails lookup). Keyed on the
-- E164 phone, which is how bath_subscribers are identified.

CREATE OR REPLACE FUNCTION public.bath_lookup_subscriber(p_phone_e164 text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_first text;
BEGIN
  IF p_phone_e164 IS NULL OR length(trim(p_phone_e164)) = 0 THEN
    RETURN jsonb_build_object('found', false);
  END IF;
  SELECT first_name INTO v_first
    FROM public.bath_subscribers
   WHERE phone_e164 = p_phone_e164
   ORDER BY created_at
   LIMIT 1;
  IF v_first IS NULL THEN
    RETURN jsonb_build_object('found', false);
  END IF;
  RETURN jsonb_build_object('found', true, 'first_name', v_first);
END;
$$;

REVOKE ALL ON FUNCTION public.bath_lookup_subscriber(text) FROM public;
GRANT EXECUTE ON FUNCTION public.bath_lookup_subscriber(text) TO anon, authenticated;
