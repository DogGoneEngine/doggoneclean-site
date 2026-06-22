-- 0227_owner_schedule_alerts.sql
-- Owner schedule alerts: tell Paul the moment a visit is booked, moved, or canceled.
-- One event, two faces: a card on the Today feed (a "Front desk" department head,
-- Iris the messenger) and an optional Telegram DM to his phone for the first little
-- while. The card is the permanent home; the Telegram tail is dormant until a bot
-- token + chat id are stored and owner_alerts_telegram is flipped on, and is meant
-- to be switched off once Paul trusts the system (Paul, 2026-06-22).

-- 1. The "Front desk" department head the cards hang off (briefings.agent_key has a
--    FK to agents). Iris, the herald, announces the schedule.
insert into public.agents (agent_key, label, department, description, is_active)
values ('front_desk', 'Iris, Front desk', 'operations',
        'Announces new bookings, reschedules, and cancellations as they happen.', true)
on conflict (agent_key) do nothing;

-- 2. Emit one alert: always write the Today card; send the Telegram DM only when armed.
create or replace function public.bath_owner_alert_emit(p_kind text, p_appt_id uuid)
returns void
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $function$
declare
  v_name text; v_start timestamptz; v_dogs int; v_svc text;
  v_when text; v_label text; v_title text; v_body text;
  v_token text; v_chat text; v_live text; v_msg text;
begin
  select c.name, a.scheduled_start, coalesce(a.dog_count, 1), coalesce(a.service_type, 'full_groom')
    into v_name, v_start, v_dogs, v_svc
    from public.bath_appointments a
    join public.bath_subscribers s on s.id = a.subscriber_id
    left join public.clients c on c.id = s.client_id
   where a.id = p_appt_id;

  if v_name is null then v_name := 'A client'; end if;
  v_when := to_char(v_start at time zone 'America/New_York', 'Dy Mon FMDD, FMHH12:MI am');
  v_svc := case v_svc when 'full_groom' then 'full groom' when 'nails' then 'nails'
                      when 'bath' then 'bath' else v_svc end;
  v_label := case p_kind when 'booked' then 'New booking'
                         when 'rescheduled' then 'Visit moved'
                         when 'canceled' then 'Visit canceled'
                         else 'Schedule update' end;
  v_title := v_label || ': ' || v_name;
  v_body := v_name || ' · ' || coalesce(v_when, 'time unknown') || ' · '
            || v_dogs || ' dog' || case when v_dogs = 1 then '' else 's' end || ' · ' || v_svc;

  insert into public.briefings (agent_key, department, severity, title, body, evidence, status)
  values ('front_desk', 'operations', 'info', v_title, v_body,
          jsonb_build_object('kind', p_kind, 'appointment_id', p_appt_id), 'new');

  -- Telegram tail (dormant until armed): reuses Paul's phone DM channel.
  v_token := (select value from public.app_secrets where name = 'telegram_bot_token');
  v_chat  := (select value from public.app_secrets where name = 'telegram_owner_chat_id');
  v_live  := (select value from public.app_secrets where name = 'owner_alerts_telegram');
  if coalesce(v_live, 'false') = 'true'
     and nullif(btrim(coalesce(v_token, '')), '') is not null
     and nullif(btrim(coalesce(v_chat, '')), '') is not null then
    v_msg := v_label || E'\n' || v_body;
    perform net.http_post(
      url     => 'https://api.telegram.org/bot' || v_token || '/sendMessage',
      headers => jsonb_build_object('Content-Type', 'application/json'),
      body    => jsonb_build_object('chat_id', v_chat, 'text', v_msg),
      timeout_milliseconds => 8000);
  end if;
end;
$function$;

-- 3. Fire on the real events, for EVERY source (app booking, calendar sync, portal),
--    so Paul sees everything during the watch. Guards keep it to real client visits
--    (never the year-ahead pencil placeholders) and skip the routine re-sync that
--    rewrites the same time (the >= 60 second move guard).
create or replace function public.bath_appointment_owner_alert()
returns trigger
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $function$
begin
  if tg_op = 'INSERT' then
    if new.status in ('requested', 'confirmed') and new.scheduled_start > now() then
      perform public.bath_owner_alert_emit('booked', new.id);
    end if;
  elsif tg_op = 'UPDATE' then
    if new.status in ('cancelled', 'skipped') and old.status in ('requested', 'confirmed') then
      perform public.bath_owner_alert_emit('canceled', new.id);
    elsif new.status in ('requested', 'confirmed')
          and new.scheduled_start is distinct from old.scheduled_start
          and abs(extract(epoch from (new.scheduled_start - old.scheduled_start))) >= 60 then
      perform public.bath_owner_alert_emit('rescheduled', new.id);
    end if;
  end if;
  return null;
end;
$function$;

drop trigger if exists bath_appointment_owner_alert_trg on public.bath_appointments;
create trigger bath_appointment_owner_alert_trg
after insert or update on public.bath_appointments
for each row execute function public.bath_appointment_owner_alert();

-- 4. The Telegram switch, explicitly OFF until Paul provides a bot token + chat id.
insert into public.app_secrets (name, value)
select 'owner_alerts_telegram', 'false'
where not exists (select 1 from public.app_secrets where name = 'owner_alerts_telegram');

-- 5. These are internal (trigger-only). Revoke REST execute so no anonymous or
--    signed-in web caller can invoke them through /rest/v1/rpc; the trigger fires
--    them as the definer regardless.
revoke execute on function public.bath_owner_alert_emit(text, uuid) from public, anon, authenticated;
revoke execute on function public.bath_appointment_owner_alert() from public, anon, authenticated;
