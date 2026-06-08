-- 0034_notification_preferences.sql
-- Per-client reminder preferences for the portal: each client chooses which
-- reminders they want and on which channel (email and/or text). Only the
-- reminders are opt-out-able; the transactional messages (booking confirmation,
-- cancellation, reschedule) always send and are not listed here. Text is stored
-- as a preference but stays dormant until Twilio is wired (notification_email_first).
--
-- prefs shape: { "reminder_3d": {"email":bool,"sms":bool}, "reminder_26h": {...}, "reminder_day": {...} }
-- Service-role / SECURITY DEFINER only; RLS denies direct client access, the
-- portal goes through the two RPCs which scope to the caller's own subscriber.
create table if not exists public.notification_preferences (
  subscriber_id uuid        primary key references public.bath_subscribers(id) on delete cascade,
  prefs         jsonb       not null default '{}'::jsonb,
  updated_at    timestamptz not null default now()
);
alter table public.notification_preferences enable row level security;
revoke all on public.notification_preferences from anon, authenticated;

-- Read the caller's reminder preferences, merged over the defaults so the portal
-- always gets every toggle.
create or replace function public.bath_get_notification_prefs()
returns jsonb
language plpgsql security definer set search_path to 'public', 'pg_temp'
as $$
declare
  v_sub  uuid;
  v_prefs jsonb;
  v_def  jsonb := '{"reminder_3d":{"email":true,"sms":false},"reminder_26h":{"email":true,"sms":false},"reminder_day":{"email":true,"sms":false}}'::jsonb;
begin
  select id into v_sub from public.bath_subscribers where auth_user_id = auth.uid() limit 1;
  if v_sub is null then return jsonb_build_object('ok', false, 'reason', 'no_subscriber'); end if;
  select prefs into v_prefs from public.notification_preferences where subscriber_id = v_sub;
  return jsonb_build_object('ok', true, 'prefs', v_def || coalesce(v_prefs, '{}'::jsonb));
end;
$$;

-- Save the caller's reminder preferences. Whitelists the known reminder keys and
-- coerces each to {email,sms} booleans, so the client cannot write arbitrary keys.
create or replace function public.bath_set_notification_prefs(p_prefs jsonb)
returns jsonb
language plpgsql security definer set search_path to 'public', 'pg_temp'
as $$
declare
  v_sub   uuid;
  v_clean jsonb := '{}'::jsonb;
  k text;
  v jsonb;
begin
  select id into v_sub from public.bath_subscribers where auth_user_id = auth.uid() limit 1;
  if v_sub is null then return jsonb_build_object('ok', false, 'reason', 'no_subscriber'); end if;
  for k, v in select key, value from jsonb_each(coalesce(p_prefs, '{}'::jsonb)) loop
    if k in ('reminder_3d', 'reminder_26h', 'reminder_day') then
      v_clean := v_clean || jsonb_build_object(k, jsonb_build_object(
        'email', coalesce((v->>'email')::boolean, true),
        'sms',   coalesce((v->>'sms')::boolean, false)));
    end if;
  end loop;
  insert into public.notification_preferences (subscriber_id, prefs)
  values (v_sub, v_clean)
  on conflict (subscriber_id) do update set prefs = excluded.prefs, updated_at = now();
  return jsonb_build_object('ok', true, 'prefs', v_clean);
end;
$$;

revoke all on function public.bath_get_notification_prefs() from public;
revoke all on function public.bath_set_notification_prefs(jsonb) from public;
grant execute on function public.bath_get_notification_prefs() to authenticated;
grant execute on function public.bath_set_notification_prefs(jsonb) to authenticated;
