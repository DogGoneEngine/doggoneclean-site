-- 0254_owner_notification_copy_telegram.sql
-- Temporary watch (Paul, 2026-06-26): while client reminders are freshly live,
-- DM Paul on Telegram every time a client message actually goes out, with just
-- the client's name and which message, never the body. Self-expiring: it fires
-- only while now() is before owner_notify_copy_until, so it shuts itself off on
-- its own with no teardown. Reuses the telegram_bot_token + telegram_owner_chat_id
-- already stored and proven by the booking alerts (migration 0227).

-- Arm the watch for about a week. Bumping or clearing this one value is the whole
-- on/off switch; past the date the trigger no-ops.
insert into public.app_secrets (name, value)
values ('owner_notify_copy_until', '2026-07-06T23:59:59-04:00')
on conflict (name) do update set value = excluded.value;

-- One line to Paul's phone per client message that was actually sent. Reads the
-- client name and turns the message key into a plain label. Fires nothing once
-- the window passes or the Telegram channel is not armed.
create or replace function public.owner_notify_copy_emit()
returns trigger
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $function$
declare
  v_until text; v_token text; v_chat text; v_name text; v_label text; v_msg text;
begin
  -- Only real sends, never the skipped/failed log rows.
  if new.status is distinct from 'sent' then return null; end if;

  v_until := (select value from public.app_secrets where name = 'owner_notify_copy_until');
  if nullif(btrim(coalesce(v_until, '')), '') is null or now() >= v_until::timestamptz then
    return null;
  end if;

  v_token := (select value from public.app_secrets where name = 'telegram_bot_token');
  v_chat  := (select value from public.app_secrets where name = 'telegram_owner_chat_id');
  if nullif(btrim(coalesce(v_token, '')), '') is null
     or nullif(btrim(coalesce(v_chat, '')), '') is null then
    return null;
  end if;

  select coalesce(nullif(btrim(c.name), ''), nullif(btrim(s.first_name), ''), 'A client')
    into v_name
    from public.bath_subscribers s
    left join public.clients c on c.id = s.client_id
   where s.id = new.subscriber_id;

  v_label := case new.kind
               when 'booking_confirmation' then 'Booking confirmation'
               when 'reminder_3d' then '3-day reminder'
               when 'reminder_26h' then 'Tomorrow reminder'
               when 'reminder_day' then 'Day-of reminder'
               when 'cancellation' then 'Cancellation'
               when 'reschedule' then 'Reschedule'
               else new.kind end;

  v_msg := coalesce(v_name, 'A client') || ': ' || v_label;
  perform net.http_post(
    url     => 'https://api.telegram.org/bot' || v_token || '/sendMessage',
    headers => jsonb_build_object('Content-Type', 'application/json'),
    body    => jsonb_build_object('chat_id', v_chat, 'text', v_msg),
    timeout_milliseconds => 8000);
  return null;
end;
$function$;

-- Trigger-only; no web caller should reach it through /rest/v1/rpc.
revoke execute on function public.owner_notify_copy_emit() from public, anon, authenticated;

drop trigger if exists owner_notify_copy_trg on public.notification_log;
create trigger owner_notify_copy_trg
after insert on public.notification_log
for each row execute function public.owner_notify_copy_emit();
