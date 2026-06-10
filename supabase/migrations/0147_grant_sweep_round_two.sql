-- 0147: grant lockdown, round two (rpc_grants_explicit). 0135 revoked the
-- PUBLIC default, but Supabase projects ALSO ship per-role default
-- privileges (pg_default_acl: postgres grants EXECUTE to anon,
-- authenticated, service_role on every new public function), so every
-- function created since 0135 (the tracker RPCs, the capacity watcher, the
-- per-service duration form) was born anon-callable again, and "REVOKE ...
-- FROM PUBLIC" in each migration never touched those explicit role grants.
-- Caught by the security advisors during the 2026-06-10 tracker build.
--
-- Two fixes:
--   1. The default itself: postgres's per-role function defaults drop anon
--      and authenticated, so future functions are born service_role-only
--      and each new RPC must name its audience explicitly (now true for
--      real).
--   2. Re-run the 0135 tier sweep over every public function (not just
--      SECURITY DEFINER this time), with the post-0135 functions placed in
--      their tiers: tracker_status joins the anon tier (token-scoped read),
--      bath_my_visit_photos joins the authenticated portal tier, _is_admin
--      keeps the invoker-context exception from 0142.

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
  REVOKE EXECUTE ON FUNCTIONS FROM anon, authenticated;

DO $$
DECLARE
  f record;
BEGIN
  FOR f IN
    SELECT p.oid::regprocedure AS sig, p.proname AS name,
           p.prorettype = 'trigger'::regtype AS is_trigger
      FROM pg_proc p
      JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname = 'public'
  LOOP
    IF f.is_trigger THEN
      CONTINUE; -- trigger functions are fired by triggers, not callers
    END IF;

    IF f.name = '_is_admin' THEN
      -- Invoker-context exception (0142): storage RLS policies evaluate it
      -- as the signed-in role, so anon + authenticated keep EXECUTE.
      EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC', f.sig);
      EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO anon, authenticated, service_role', f.sig);
    ELSIF f.name IN ('bath_start_subscription', 'bath_open_slots',
                     'bath_lookup_subscriber', 'bath_founders_remaining',
                     'tracker_status') THEN
      EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC', f.sig);
      EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO anon, authenticated, service_role', f.sig);
    ELSIF f.name LIKE 'admin\_%' ESCAPE '\'
       OR f.name IN ('bath_claim_legacy_account', 'bath_get_notification_prefs',
                     'bath_set_notification_prefs', 'bath_change_cadence',
                     'bath_confirm_profile', 'bath_reschedule_appointment',
                     'bath_skip_appointment', 'bath_update_profile',
                     'bath_update_service_address', 'bath_cancel_subscription',
                     'bath_pause_subscription', 'bath_resume_subscription',
                     'bath_my_visit_photos') THEN
      EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC, anon', f.sig);
      EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO authenticated, service_role', f.sig);
    ELSE
      EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC, anon, authenticated', f.sig);
      EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO service_role', f.sig);
    END IF;
  END LOOP;
END $$;
