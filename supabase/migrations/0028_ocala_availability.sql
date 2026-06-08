-- 0028_ocala_availability.sql
-- Ocala working grid for the legacy full-grooming schedule that replaces Acuity:
-- Tuesday through Saturday, noon to 8pm. weekday is 0=Sun..6=Sat, so Tue..Sat = 2..6.
-- More days are added later by inserting rows. Every-other-week and each client's
-- frequency live in the subscription's cadence_days, NOT here (this is just which
-- days/hours Paul can work). Idempotent: clears Ocala's rows then reloads them.
delete from public.bath_availability_windows
 where city_id = (select id from public.cities where slug = 'ocala');

insert into public.bath_availability_windows (city_id, weekday, start_time, end_time, active)
select (select id from public.cities where slug = 'ocala'), w, time '12:00', time '20:00', true
from unnest(array[2, 3, 4, 5, 6]) as w;
