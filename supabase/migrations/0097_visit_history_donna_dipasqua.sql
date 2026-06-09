-- 0097_visit_history_donna_dipasqua.sql
-- Visit-history migration for Donna DiPasqua / Fledge (German Shepherd; earlier
-- entries spell her "Fletch", same dog). Single dog, monthly. Score + note
-- attached to the existing time_is_money visit by date; pre-import entries (before
-- 2023-08-26) created as source='contact_sheet'. The "constantly on the move"
-- 2s in 2024 and the belly/vet note are preserved. See visit_history_migration +
-- time_is_money_is_source_of_truth.

insert into public.visit_dog_ratings (visit_id, dog_id, score, note)
select v.id, d.id, x.score, x.note
from (values
  ('2026-02-03'::date, 5, 'Flaky. Dry skin.'),
  ('2026-01-06'::date, 5, null),
  ('2025-12-09'::date, 5, null),
  ('2025-11-11'::date, 5, 'Heavy shedding.'),
  ('2025-10-14'::date, 5, 'She is having issues with her belly. Going to the vet after Donna gets back from a trip.'),
  ('2025-09-16'::date, 5, null),
  ('2025-08-19'::date, 5, null),
  ('2025-07-22'::date, 5, null),
  ('2025-06-27'::date, 5, null),
  ('2025-05-27'::date, 5, null),
  ('2025-04-29'::date, 5, null),
  ('2025-04-01'::date, 5, null),
  ('2025-03-04'::date, 4, null),
  ('2025-02-04'::date, 3, null),
  ('2025-01-07'::date, 5, null),
  ('2024-12-10'::date, 5, null),
  ('2024-11-12'::date, 5, null),
  ('2024-10-15'::date, 5, null),
  ('2024-09-15'::date, 4, null),
  ('2024-08-20'::date, 4, null),
  ('2024-07-23'::date, 4, null),
  ('2024-06-25'::date, 2, 'She should be a 4. She will do anything you ask her to but she will not do nothing; she is constantly on the move.'),
  ('2024-05-28'::date, 2, 'She should be a 4. She will do anything you ask her to but she will not do nothing; she is constantly on the move.'),
  ('2024-04-30'::date, 2, null),
  ('2024-04-02'::date, 4, null),
  ('2024-03-05'::date, 4, 'Started as a 5, was a 2 at the end. A 4 overall. Good dog.'),
  ('2024-02-06'::date, 5, null),
  ('2024-01-12'::date, 2, 'A likeable dog.'),
  ('2023-12-15'::date, 2, 'Started at a solid 5 and quickly devolved. By the end she would not even cooperate for the after photo. Still, I like her.'),
  ('2023-11-17'::date, 3, null),
  ('2023-10-20'::date, 2, 'Non-compliant but she is a good dog. I like her.'),
  ('2023-09-22'::date, 2, 'Started at a 4 and devolved.')
) as x(d, score, note)
join public.clients c on c.name = 'Donna DiPasqua'
join public.dogs d on d.client_id = c.id and d.name = 'Fledge'
join public.visits v on v.client_id = c.id and v.visited_at::date = x.d
on conflict (visit_id, dog_id) do update set score = excluded.score, note = excluded.note;

-- Pre-import orphans (before 2023-08-26)
insert into public.visits (client_id, visited_at, service_type, source, external_id)
select c.id, x.ts, 'full_groom', 'contact_sheet', x.ext
from (values
  ('2023-06-01T12:00:00Z'::timestamptz, 'donnad-2023-06-01'),
  ('2023-04-20T12:00:00Z'::timestamptz, 'donnad-2023-04-20'),
  ('2023-04-06T12:00:00Z'::timestamptz, 'donnad-2023-04-06'),
  ('2023-03-03T12:00:00Z'::timestamptz, 'donnad-2023-03-03'),
  ('2023-01-31T12:00:00Z'::timestamptz, 'donnad-2023-01-31'),
  ('2022-12-14T12:00:00Z'::timestamptz, 'donnad-2022-12-14')
) as x(ts, ext)
join public.clients c on c.name = 'Donna DiPasqua'
on conflict (source, external_id) where external_id is not null do nothing;

insert into public.visit_dog_ratings (visit_id, dog_id, score, note)
select v.id, d.id, null, x.note
from (values
  ('donnad-2023-06-01', 'Ok. Tries to push forward constantly.'),
  ('donnad-2023-04-20', 'Same as last time. Difficult but likeable.'),
  ('donnad-2023-04-06', 'Difficult. Discrete; an observer might not notice how difficult she is. But I like her. Nice dog.'),
  ('donnad-2023-03-03', 'Good dog.'),
  ('donnad-2023-01-31', 'A little uncooperative. Good enough. Nice dog.'),
  ('donnad-2022-12-14', 'Good dog. A little squirmy but will probably get better.')
) as x(ext, note)
join public.visits v on v.source = 'contact_sheet' and v.external_id = x.ext
join public.clients c on c.id = v.client_id and c.name = 'Donna DiPasqua'
join public.dogs d on d.client_id = c.id and d.name = 'Fledge'
on conflict (visit_id, dog_id) do update set note = excluded.note;
