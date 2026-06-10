-- 0142: photo uploads and thumbnails broke with "permission denied for
-- function _is_admin" the moment 0135 locked the RPC grants down. Root
-- cause: the visit-photos storage RLS policies (0080) call public._is_admin()
-- and a row-level policy runs AS THE INVOKER (the signed-in authenticated
-- role), not as the function owner, so the policy itself needs EXECUTE on
-- the helper. 0135's revoke-from-PUBLIC default removed it, which killed
-- every storage upload, signed-URL read, and delete in Orbit at once (the
-- "photos go into the void" Paul saw: thumbnails stopped rendering AND new
-- uploads errored).
--
-- The grant is safe: _is_admin() only reads auth.uid() against the admins
-- table and returns a boolean. anon gets it too so an anonymous storage
-- request is cleanly denied (false) instead of erroring mid-policy.
--
-- Refines rpc_grants_explicit: a helper referenced by an RLS policy is
-- invoker-context and MUST keep an explicit grant to every role whose
-- queries that policy can gate. Checked here for all of them: _is_admin is
-- the only function any RLS policy on this project calls.

grant execute on function public._is_admin() to authenticated, anon;
