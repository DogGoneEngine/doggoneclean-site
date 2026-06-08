-- 0036_notifications_killswitch.sql
--
-- Cutover safety. The legacy appointments are ALREADY on Acuity's reminder
-- schedule, so our pipeline must stay silent until Acuity is shut off, or every
-- client gets reminded twice. This adds one master switch, app_secrets key
-- 'notifications_live', that gates the single chokepoint every send passes through
-- (notify_appointment, used by both the reminder cron and the confirmation trigger).
--
-- Default is OFF: with no 'notifications_live' row, coalesce makes it 'false' and
-- nothing leaves the building, even once the Resend key is in place. Flip it to
-- 'true' only at the moment Acuity is cancelled. Until then the cron still runs and
-- logs would show it is alive, but no email is ever queued.

create or replace function public.notify_appointment(p_kind text, p_appointment_id uuid)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_secret text;
  v_base   text;
  v_live   text;
begin
  select value into v_secret from public.app_secrets where name = 'notifications_secret';
  select value into v_base   from public.app_secrets where name = 'edge_base_url';
  select value into v_live    from public.app_secrets where name = 'notifications_live';

  -- Not wired yet, or the cutover switch is still off (Acuity still live): do nothing.
  if v_secret is null or v_base is null then
    return;
  end if;
  if coalesce(v_live, 'false') <> 'true' then
    return;
  end if;

  perform net.http_post(
    url     => v_base || '/send-notification',
    headers => jsonb_build_object(
                 'Content-Type', 'application/json',
                 'x-notifications-secret', v_secret),
    body    => jsonb_build_object('kind', p_kind, 'appointment_id', p_appointment_id),
    timeout_milliseconds => 8000
  );
end;
$$;

revoke all on function public.notify_appointment(text, uuid) from public, anon, authenticated;
