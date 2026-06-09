-- 0118_visit_history_patricia_angelucci.sql
-- Visit-history migration for Patricia Angelucci / Jackpot (Australian Shepherd mix,
-- old). Single dog, steady 5s, with the note about her difficulty standing as she
-- ages. Score + note attached to the existing time_is_money visit by date; the
-- sheet's "1/14/24" maps to the imported 2024-01-13. Pre-import entries (before
-- 2023-09-20), back to the 2021 Evernote note, are source='contact_sheet'. One
-- undated "Jackpot. Ok." sheet entry has no date and is left out rather than dated by
-- guess. See visit_history_migration + time_is_money_is_source_of_truth.

insert into public.visit_dog_ratings (visit_id, dog_id, score, note)
select v.id, d.id, x.score, x.note from (values
  ('2026-02-19'::date, 5, null),
  ('2025-11-25'::date, 5, null),
  ('2025-10-03'::date, 5, null),
  ('2025-06-13'::date, 5, null),
  ('2025-04-04'::date, 5, null),
  ('2025-02-07'::date, 5, 'She had difficulty standing at first but did better as time went on. At first I thought I would have to do a quick abbreviated version, but she settled in and I was able to do a thorough job.'),
  ('2024-12-05'::date, 5, null),
  ('2024-09-20'::date, 5, null),
  ('2024-07-29'::date, 5, null),
  ('2024-05-24'::date, 5, null),
  ('2024-03-29'::date, 5, null),
  ('2024-01-13'::date, 3, null),
  ('2023-09-20'::date, 3, null)
) as x(d, score, note)
join public.clients c on c.name='Patricia Angelucci'
join public.dogs d on d.client_id=c.id and d.name='Jackpot'
join public.visits v on v.client_id=c.id and v.visited_at::date=x.d
on conflict (visit_id, dog_id) do update set score=excluded.score, note=excluded.note;

-- Pre-import orphans (before 2023-09-20)
insert into public.visits (client_id, visited_at, service_type, source, external_id)
select c.id, x.ts, 'full_groom', 'contact_sheet', x.ext
from (values
  ('2023-01-10T12:00:00Z'::timestamptz, 'patricia-2023-01-10'),
  ('2022-03-08T12:00:00Z'::timestamptz, 'patricia-2022-03-08'),
  ('2021-12-14T12:00:00Z'::timestamptz, 'patricia-2021-12-14')
) as x(ts, ext)
join public.clients c on c.name='Patricia Angelucci'
on conflict (source, external_id) where external_id is not null do nothing;

insert into public.visit_dog_ratings (visit_id, dog_id, score, note)
select v.id, d.id, null, x.note
from (values
  ('patricia-2023-01-10', 'Sometimes a little bit difficult. She is very old.'),
  ('patricia-2022-03-08', 'Snarling at me in the doorway of the house; as soon as we started moving toward the trailer she was fine. A good dog, very patient and easy to work with. Took 90 minutes.'),
  ('patricia-2021-12-14', 'Good dog. Thick, clumpy fur; took 2 hours. Might be easier next time if she gets groomed before it all grows back. Moved here from Wisconsin; it was extra work this time.')
) as x(ext, note)
join public.visits v on v.source='contact_sheet' and v.external_id=x.ext
join public.clients c on c.id=v.client_id and c.name='Patricia Angelucci'
join public.dogs d on d.client_id=c.id and d.name='Jackpot'
on conflict (visit_id, dog_id) do update set note=excluded.note;
