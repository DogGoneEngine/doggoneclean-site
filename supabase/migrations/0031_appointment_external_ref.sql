-- 0031_appointment_external_ref.sql
-- Lets the schedule mirror real bookings (schedule_mirrors_real_bookings): an
-- appointment imported from the calendar records where it came from (`source`,
-- e.g. 'acuity') and the upstream id (`external_id`, the Acuity appointment id),
-- so re-imports update in place instead of duplicating. Both NULL for an
-- appointment created natively in the app. The partial unique index makes a
-- double-import impossible at the DB layer.
alter table public.bath_appointments
  add column if not exists source      text,
  add column if not exists external_id text;

create unique index if not exists bath_appointments_source_external_id_key
  on public.bath_appointments (source, external_id)
  where external_id is not null;
