-- 0038_confirm_profile.sql
-- The returning-client welcome flow (portal parity with Nails' WelcomeBack):
-- a lapsed client who signs in confirms their address and pack, then taps a
-- single "everything's current" button. That tap stamps last_profile_confirmed_at
-- so the welcome gate does not show again until they lapse again. Address and
-- pack edits already have their own RPCs; this only records the confirmation.
-- SECURITY DEFINER, scoped to the caller's own subscriber via auth.uid().
create or replace function public.bath_confirm_profile()
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_sub uuid;
begin
  select id into v_sub from public.bath_subscribers where auth_user_id = auth.uid() limit 1;
  if v_sub is null then
    return jsonb_build_object('ok', false, 'reason', 'no_subscriber');
  end if;
  update public.bath_subscribers
     set last_profile_confirmed_at = now(), updated_at = now()
   where id = v_sub;
  return jsonb_build_object('ok', true);
end;
$$;

revoke all on function public.bath_confirm_profile() from public, anon;
grant execute on function public.bath_confirm_profile() to authenticated;
