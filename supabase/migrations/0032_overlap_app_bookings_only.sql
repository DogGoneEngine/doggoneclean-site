-- 0032_overlap_app_bookings_only.sql
-- schedule_mirrors_real_bookings: the app must be able to hold the real schedule,
-- and a legacy full-grooming "block" is a padded time window that legitimately
-- overlaps the next one (Paul sequences within them; the NE Thursday evening
-- pinch, Ginger 5-7pm overlapping Michelle 6-9pm, is the classic case). So the
-- no-overlap guard now applies ONLY to app-native bookings (source IS NULL, the
-- bath surface where slots are exact and one operator cannot double-book).
-- Appointments imported from the calendar (source set, e.g. 'acuity'/'gcal') are
-- exempt, because their overlap is real and the app mirrors it rather than
-- rejecting it.
alter table public.bath_appointments drop constraint bath_appointments_no_overlap;

alter table public.bath_appointments add constraint bath_appointments_no_overlap
  exclude using gist (tstzrange(scheduled_start, scheduled_end, '[)') with &&)
  where (status <> all (array['cancelled'::text, 'skipped'::text, 'no_show'::text])
         and source is null);
