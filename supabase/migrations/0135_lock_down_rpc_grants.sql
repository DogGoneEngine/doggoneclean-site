-- 0135: lock down RPC execute grants (security advisor sweep, 2026-06-10).
-- The advisors showed ~110 SECURITY DEFINER functions executable by anon,
-- including ungated internal helpers (_apply_visit_dog_scores,
-- _archive_stale_clients, the agent scans). Postgres grants EXECUTE to
-- PUBLIC on function creation by default, so every new RPC shipped this
-- month was born anon-callable unless a session remembered to revoke.
--
-- The posture after this migration:
--   * The four deliberately-anonymous booking RPCs stay anon-callable
--     (bath_start_subscription, bath_open_slots, bath_lookup_subscriber,
--     bath_founders_remaining): the funnel runs with no account.
--   * admin_* and the authenticated portal bath_* RPCs: authenticated +
--     service_role only. The admin gate inside them (_is_admin / auth.uid())
--     still applies; this removes the anonymous front door.
--   * Everything else SECURITY DEFINER (internal _ helpers, agent scans,
--     cron dispatchers, edge-function data feeds): service_role only.
--     pg_cron runs as the owner and is unaffected; SECURITY DEFINER
--     functions calling helpers internally check privileges as the owner,
--     so nested calls keep working.
--   * Default privileges change: future functions no longer get PUBLIC
--     execute. A new RPC must be granted to its audience explicitly.

DO $$
DECLARE
  f record;
BEGIN
  FOR f IN
    SELECT p.oid::regprocedure AS sig, p.proname AS name,
           p.prorettype = 'trigger'::regtype AS is_trigger
      FROM pg_proc p
      JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname = 'public' AND p.prosecdef
  LOOP
    IF f.is_trigger THEN
      CONTINUE; -- trigger functions are fired by triggers, not callers
    END IF;

    IF f.name IN ('bath_start_subscription', 'bath_open_slots',
                  'bath_lookup_subscriber', 'bath_founders_remaining') THEN
      EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC', f.sig);
      EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO anon, authenticated, service_role', f.sig);
    ELSIF f.name LIKE 'admin\_%' ESCAPE '\'
       OR f.name IN ('bath_claim_legacy_account', 'bath_get_notification_prefs',
                     'bath_set_notification_prefs', 'bath_change_cadence',
                     'bath_confirm_profile', 'bath_reschedule_appointment',
                     'bath_skip_appointment', 'bath_update_profile',
                     'bath_update_service_address', 'bath_cancel_subscription',
                     'bath_pause_subscription', 'bath_resume_subscription') THEN
      EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC, anon', f.sig);
      EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO authenticated, service_role', f.sig);
    ELSE
      EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC, anon, authenticated', f.sig);
      EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO service_role', f.sig);
    END IF;
  END LOOP;
END $$;

-- Future functions created by migrations no longer ship anon-callable by
-- default; each new RPC declares its audience with an explicit GRANT.
ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;
