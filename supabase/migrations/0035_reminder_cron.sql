-- 0035_reminder_cron.sql
--
-- The Acuity replacement's beating heart: an hourly job that fires the pre-visit
-- reminders (reminder_3d / reminder_26h / reminder_day) plus a trigger that fires
-- the transactional confirmations (booking / reschedule / cancellation) the moment
-- a client acts. Both call the send-notification edge function (0033), which renders
-- the legacy templates, dedups on notification_log, and fail-closes when Resend is
-- not yet configured. This is the piece that lets Acuity be cancelled: once a real
-- client gets a real reminder from here, Acuity's one remaining job is gone.
--
-- Durability: the schedule lives in pg_cron, the dispatch logic in SQL functions,
-- the transactional fire in a table trigger. No page or client app carries any of
-- it, so it survives a full website redesign (redesign_survival_is_a_ship_gate).
--
-- SAFETY GUARD (the one that matters): transactional confirmations fire ONLY for
-- app-native appointments (source IS NULL, the same line drawn in 0032). Calendar-
-- imported rows (source set to 'acuity' / 'gcal') NEVER get a confirmation,
-- reschedule, or cancellation email, so a calendar backfill that inserts or updates
-- hundreds of historical rows can never blast clients. Imported rows still get
-- REMINDERS from the cron, which is exactly the point of replacing Acuity.
--
-- Config (data, not schema; set per-project in app_secrets alongside the other
-- secrets, so no project ref is hardcoded and Clean stays sellable):
--   edge_base_url        = https://<project-ref>.supabase.co/functions/v1
--   notifications_secret = caller auth shared with the edge function (already set)

create extension if not exists pg_cron;
create extension if not exists pg_net;

-- One place that calls the dispatcher edge function. SECURITY DEFINER so it can
-- read app_secrets; locked away from clients. pg_net's http_post is async and
-- enqueues inside the caller's transaction, so a rolled-back booking sends no mail.
create or replace function public.notify_appointment(p_kind text, p_appointment_id uuid)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_secret text;
  v_base   text;
begin
  select value into v_secret from public.app_secrets where name = 'notifications_secret';
  select value into v_base   from public.app_secrets where name = 'edge_base_url';
  -- No config means the pipeline is not wired yet; do nothing rather than error.
  if v_secret is null or v_base is null then
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

-- Hourly reminder sweep. Non-overlapping time bands so each appointment gets each
-- reminder once, with copy that matches the timing (3d "heads up", 26h "tomorrow",
-- day-of "today"). The edge function's unique-on-sent index makes a second send
-- impossible even if a run repeats; the NOT EXISTS below stops re-calling once sent
-- and throttles retries to once per 6h while Resend is still unconfigured (so the
-- skipped rows do not pile up before the key lands).
create or replace function public.bath_dispatch_reminders()
returns integer
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  r       record;
  v_count int := 0;
begin
  for r in
    select a.id, k.kind
    from public.bath_appointments a
    cross join lateral (values
      ('reminder_3d',  a.scheduled_start >  now() + interval '30 hours'
                   and a.scheduled_start <= now() + interval '78 hours'),
      ('reminder_26h', a.scheduled_start >  now() + interval '14 hours'
                   and a.scheduled_start <= now() + interval '30 hours'),
      ('reminder_day', a.scheduled_start >  now()
                   and a.scheduled_start <= now() + interval '14 hours'
                   and (a.scheduled_start at time zone 'America/New_York')::date
                       = (now() at time zone 'America/New_York')::date)
    ) as k(kind, due)
    where a.status in ('requested', 'confirmed')
      and k.due
      and not exists (
        select 1 from public.notification_log nl
        where nl.appointment_id = a.id
          and nl.kind = k.kind
          and (nl.status = 'sent' or nl.sent_at > now() - interval '6 hours')
      )
  loop
    perform public.notify_appointment(r.kind, r.id);
    v_count := v_count + 1;
  end loop;
  return v_count;
end;
$$;

revoke all on function public.bath_dispatch_reminders() from public, anon, authenticated;

-- Transactional confirmations. App-native rows only (source IS NULL): an INSERT is
-- a new booking, a scheduled_start change is a reschedule, a move to cancelled /
-- skipped is a cancellation. Imported rows return early, so no backfill can fire mail.
create or replace function public.bath_appointment_notify()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if new.source is not null then
    return null;
  end if;

  if tg_op = 'INSERT' then
    if new.status in ('requested', 'confirmed') and new.scheduled_start > now() then
      perform public.notify_appointment('booking_confirmation', new.id);
    end if;
  elsif tg_op = 'UPDATE' then
    if new.status in ('cancelled', 'skipped')
       and old.status not in ('cancelled', 'skipped') then
      perform public.notify_appointment('cancellation', new.id);
    elsif new.scheduled_start is distinct from old.scheduled_start
          and new.status in ('requested', 'confirmed') then
      perform public.notify_appointment('reschedule', new.id);
    end if;
  end if;
  return null;
end;
$$;

-- Trigger functions are never meant to be called as a PostgREST RPC; lock it down
-- so it is not an externally executable SECURITY DEFINER surface.
revoke all on function public.bath_appointment_notify() from public, anon, authenticated;

drop trigger if exists bath_appointment_notify_trg on public.bath_appointments;
create trigger bath_appointment_notify_trg
  after insert or update on public.bath_appointments
  for each row execute function public.bath_appointment_notify();

-- Schedule the sweep at the top of every hour. Idempotent re-apply.
do $$
begin
  if exists (select 1 from cron.job where jobname = 'bath-reminders') then
    perform cron.unschedule('bath-reminders');
  end if;
end $$;

select cron.schedule('bath-reminders', '0 * * * *', $cron$select public.bath_dispatch_reminders();$cron$);
