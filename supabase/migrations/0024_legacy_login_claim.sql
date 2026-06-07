-- 0024_legacy_login_claim.sql
-- Legacy login, step 1 of 2: the mechanism. A legacy client lives in
-- public.clients, not bath_subscribers, so signing in dead-ends at the portal's
-- empty state. This adds the contact columns the claim matches on, and a claim
-- RPC that links a verified sign-in (phone OTP / email magic link / Google) to
-- the matching legacy client by creating (or adopting) a bath_subscribers row.
--
-- Step 2 (separate pass) backfills clients.phone_e164 / clients.email from the
-- Acuity calendar feed so the claim actually matches real people. Until then the
-- mechanism is live but matches only clients whose contact info is filled in.

alter table public.clients
  add column if not exists phone_e164 text,
  add column if not exists email text;

-- Claim the caller's legacy account. Matches the verified identity in the JWT
-- (phone for SMS OTP, email for magic link / Google) to a clients row, then
-- links a bath_subscribers row to it. Idempotent: re-running once linked is a
-- no-op that reports already_linked.
create or replace function public.bath_claim_legacy_account()
returns jsonb
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $$
declare
  v_uid    uuid := auth.uid();
  v_phone  text := nullif(auth.jwt() ->> 'phone', '');
  v_email  text := nullif(auth.jwt() ->> 'email', '');
  v_digits text;
  v_client public.clients%rowtype;
  v_city   uuid;
  v_sub    uuid;
  v_first  text;
  v_last   text;
  v_e164   text;
begin
  if v_uid is null then
    return jsonb_build_object('claimed', false, 'reason', 'not_authenticated');
  end if;

  -- Already linked to this auth user? Nothing to do.
  select id into v_sub from public.bath_subscribers where auth_user_id = v_uid limit 1;
  if v_sub is not null then
    return jsonb_build_object('claimed', false, 'reason', 'already_linked', 'subscriber_id', v_sub);
  end if;

  v_digits := right(regexp_replace(coalesce(v_phone, ''), '\D', '', 'g'), 10);
  v_e164   := case when length(v_digits) = 10 then '+1' || v_digits else null end;

  -- Match a legacy client by verified phone (last 10 digits) or verified email.
  select c.* into v_client
  from public.clients c
  where not c.exclude_from_everything
    and c.roster_group <> 'banned'
    and (
      (length(v_digits) = 10 and right(regexp_replace(coalesce(c.phone_e164, ''), '\D', '', 'g'), 10) = v_digits)
      or (v_email is not null and lower(c.email) = lower(v_email))
    )
  order by c.roster_group
  limit 1;

  if v_client.id is null then
    return jsonb_build_object('claimed', false, 'reason', 'no_match');
  end if;

  -- Already claimed by a different auth user? Do not hand over someone's account.
  select id into v_sub from public.bath_subscribers
   where client_id = v_client.id and auth_user_id is not null limit 1;
  if v_sub is not null then
    return jsonb_build_object('claimed', false, 'reason', 'already_claimed');
  end if;

  select id into v_city from public.cities where slug = 'ocala' limit 1;

  v_first := split_part(v_client.name, ' ', 1);
  v_last  := nullif(btrim(substr(v_client.name, length(split_part(v_client.name, ' ', 1)) + 1)), '');

  -- Adopt an existing unclaimed subscriber row for this client if one exists
  -- (e.g. from an earlier anonymous booking), otherwise create one.
  select id into v_sub from public.bath_subscribers
   where client_id = v_client.id and auth_user_id is null limit 1;

  if v_sub is not null then
    update public.bath_subscribers
       set auth_user_id = v_uid,
           email      = coalesce(email, v_email, v_client.email),
           phone_e164 = coalesce(phone_e164, v_e164, v_client.phone_e164),
           updated_at = now()
     where id = v_sub;
  else
    insert into public.bath_subscribers (
      auth_user_id, client_id, first_name, last_name, email, phone_e164,
      address_line_1, address_city, address_state, address_zip, city_id,
      sms_opt_in, address_verified
    ) values (
      v_uid, v_client.id, v_first, v_last,
      coalesce(v_email, v_client.email),
      coalesce(v_e164, v_client.phone_e164),
      v_client.location_address, 'Ocala', 'FL', v_client.location_zip, v_city,
      true, false
    )
    returning id into v_sub;
  end if;

  return jsonb_build_object('claimed', true, 'subscriber_id', v_sub, 'name', v_client.name);
end;
$$;

revoke all on function public.bath_claim_legacy_account() from public;
grant execute on function public.bath_claim_legacy_account() to authenticated;
