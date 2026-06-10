-- 0140: stragglers from Paul's 2026-06-10 list.
--
-- 1. RECOVER the generator hours that went into the void. Paul answered the
--    maintenance watcher's hours-ask cards in plain text ("641 hours" /
--    "Bathing generator has 905 hours on it", briefing_notes 2026-06-09);
--    the replies were saved as notes but nothing parsed them into
--    equipment.current_hours. The numbers are recovered here, stamped at his
--    reply times, guarded so a replay never clobbers a newer reading.
-- 2. admin_set_equipment_hours_by_name: the RPC behind the new inline hours
--    box on the hours-ask briefing card, so entering hours is type-a-number,
--    tap save, card resolves. Never again a free-text reply into the void.
-- 3. The Dog Gone Tracker heads-up joins the notification preferences: a
--    'tracker' key in the get/set whitelist (default email on, text saved
--    now and live when Twilio lands), surfaced as a row in the portal's
--    reminders card.

update public.equipment
   set current_hours = 641, hours_updated_at = '2026-06-09 21:11:17+00'
 where name = 'Infrastructure generator' and current_hours is null;

update public.equipment
   set current_hours = 905, hours_updated_at = '2026-06-09 21:10:30+00'
 where name = 'Bathing generator' and current_hours is null;

create or replace function public.admin_set_equipment_hours_by_name(p_name text, p_hours numeric)
returns void
language plpgsql
security definer
set search_path to ''
as $$
begin
  if not public._is_admin() then raise exception 'not authorized'; end if;
  if p_hours is null or p_hours < 0 then raise exception 'hours must be a number, zero or more'; end if;
  update public.equipment
     set current_hours = p_hours, hours_updated_at = now()
   where name = p_name and coalesce(track_hours, false);
  if not found then
    raise exception 'no hours-tracked equipment named "%"', p_name;
  end if;
end;
$$;
revoke all on function public.admin_set_equipment_hours_by_name(text, numeric) from public, anon;
grant execute on function public.admin_set_equipment_hours_by_name(text, numeric) to authenticated, service_role;

CREATE OR REPLACE FUNCTION public.bath_get_notification_prefs()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_sub  uuid;
  v_prefs jsonb;
  v_def  jsonb := '{"reminder_3d":{"email":true,"sms":false},"reminder_26h":{"email":true,"sms":false},"reminder_day":{"email":true,"sms":false},"tracker":{"email":true,"sms":false}}'::jsonb;
begin
  select id into v_sub from public.bath_subscribers where auth_user_id = auth.uid() limit 1;
  if v_sub is null then return jsonb_build_object('ok', false, 'reason', 'no_subscriber'); end if;
  select prefs into v_prefs from public.notification_preferences where subscriber_id = v_sub;
  return jsonb_build_object('ok', true, 'prefs', v_def || coalesce(v_prefs, '{}'::jsonb));
end;
$function$;

CREATE OR REPLACE FUNCTION public.bath_set_notification_prefs(p_prefs jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_sub   uuid;
  v_clean jsonb := '{}'::jsonb;
  k text;
  v jsonb;
begin
  select id into v_sub from public.bath_subscribers where auth_user_id = auth.uid() limit 1;
  if v_sub is null then return jsonb_build_object('ok', false, 'reason', 'no_subscriber'); end if;
  for k, v in select key, value from jsonb_each(coalesce(p_prefs, '{}'::jsonb)) loop
    if k in ('reminder_3d', 'reminder_26h', 'reminder_day', 'tracker') then
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
$function$;
