-- 0037_reminder_cadence_72_26_6.sql
--
-- Correct the reminder timing to the long-standing legacy cadence, which is fixed
-- in legacy/notifications/email_templates.md: three reminders at 72 hours, 26 hours,
-- and 6 hours before the appointment. 0035 shipped the third one ('reminder_day',
-- subject "Today is the day") firing ~14 hours out; it is the 6-hours-before day-of
-- reminder and must fire at 6 hours. This also tightens the first two bands onto
-- their named hours (the old bands fired at ~78h and ~30h).
--
-- Bands are contiguous and non-overlapping, so each appointment gets each reminder
-- exactly once. The hourly cron fires each one on the first run after the appointment
-- crosses the band ceiling, so the real send lands within an hour of the named time.
-- Key names are unchanged (reminder_3d / reminder_26h / reminder_day) so the edge
-- function templates, notification_preferences, and the portal screen keep working;
-- only the timing windows move.

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
      -- 72 hours before: "Heads up, your appointment is <day>"
      ('reminder_3d',  a.scheduled_start >  now() + interval '26 hours'
                   and a.scheduled_start <= now() + interval '72 hours'),
      -- 26 hours before: "Tomorrow is the day"
      ('reminder_26h', a.scheduled_start >  now() + interval '6 hours'
                   and a.scheduled_start <= now() + interval '26 hours'),
      -- 6 hours before (day of): "Today is the day"
      ('reminder_day', a.scheduled_start >  now()
                   and a.scheduled_start <= now() + interval '6 hours')
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
