-- 0015_portal_update_profile.sql
--
-- Client self-service for contact details and preferences: name, phone,
-- email, gate code, text-reminder and email opt-ins. These go through a
-- SECURITY DEFINER function that writes ONLY those safe columns.
--
-- It also closes a latent hole: bath_subscribers had a broad self_update
-- RLS policy, which let a signed-in client PATCH any column on their own
-- row directly, including address_line_1 / service_lat / service_lng /
-- city_id. That would let someone move their service point outside the
-- verified in-area location without the polygon gate the booking funnel
-- enforces (require_verified_service_area). No client code uses that direct
-- path, so the policy is dropped: every subscriber write now flows through
-- a function that can enforce the rules. A verified service-address change
-- gets its own RPC (with the in-area check) in a later slice.

create or replace function public.bath_update_profile(
  p_first_name   text,
  p_last_name    text,
  p_phone_e164   text,
  p_email        text,
  p_gate_code    text,
  p_sms_opt_in   boolean,
  p_email_opt_in boolean
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_id uuid;
begin
  if coalesce(btrim(p_first_name), '') = '' then
    return jsonb_build_object('ok', false, 'error', 'name_required');
  end if;

  if p_phone_e164 is not null and p_phone_e164 !~ '^\+[0-9]{10,15}$' then
    return jsonb_build_object('ok', false, 'error', 'invalid_phone');
  end if;

  select id into v_id
    from public.bath_subscribers
   where auth_user_id = auth.uid();

  if v_id is null then
    return jsonb_build_object('ok', false, 'error', 'no_subscriber');
  end if;

  update public.bath_subscribers set
    first_name   = btrim(p_first_name),
    last_name    = nullif(btrim(p_last_name), ''),
    phone_e164   = p_phone_e164,
    email        = nullif(btrim(p_email), ''),
    gate_code    = nullif(btrim(p_gate_code), ''),
    sms_opt_in   = coalesce(p_sms_opt_in, sms_opt_in),
    email_opt_in = coalesce(p_email_opt_in, email_opt_in),
    updated_at   = now()
  where id = v_id;

  return jsonb_build_object('ok', true);
end;
$$;

revoke all on function public.bath_update_profile(text, text, text, text, text, boolean, boolean) from public, anon;
grant execute on function public.bath_update_profile(text, text, text, text, text, boolean, boolean) to authenticated;

-- Direct column writes are no longer allowed from the client; all
-- subscriber writes go through SECURITY DEFINER functions.
drop policy if exists bath_subscribers_self_update on public.bath_subscribers;
