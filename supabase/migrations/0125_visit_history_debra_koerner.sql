-- 0125_visit_history_debra_koerner.sql
-- Visit-history migration for Debra Koerner (account Raymond Koerner) / Gabe (Black
-- Lab) + Gibbs (Yellow Lab), bath only, infrequent (every few months). Both have
-- been difficult to handle; Gibbs's leash-training session is preserved. Score +
-- note attached to the existing time_is_money visit by date. Pre-import entries
-- (before 2023-11-15), back to the 2021 Evernote note, are source='contact_sheet'.
-- See visit_history_migration + time_is_money_is_source_of_truth.

-- Gabe
insert into public.visit_dog_ratings (visit_id, dog_id, score, note)
select v.id, d.id, x.score, x.note from (values
  ('2026-03-06'::date, 5, null),
  ('2025-12-12'::date, 2, null),
  ('2024-08-22'::date, 4, null),
  ('2023-11-15'::date, 1, null)
) as x(d, score, note)
join public.clients c on c.name='Debra Koerner'
join public.dogs d on d.client_id=c.id and d.name='Gabe'
join public.visits v on v.client_id=c.id and v.visited_at::date=x.d
on conflict (visit_id, dog_id) do update set score=excluded.score, note=excluded.note;

-- Gibbs
insert into public.visit_dog_ratings (visit_id, dog_id, score, note)
select v.id, d.id, x.score, x.note from (values
  ('2026-03-06'::date, 5, null),
  ('2025-12-12'::date, 2, null),
  ('2024-08-22'::date, 3, null),
  ('2023-11-15'::date, 3, null)
) as x(d, score, note)
join public.clients c on c.name='Debra Koerner'
join public.dogs d on d.client_id=c.id and d.name='Gibbs'
join public.visits v on v.client_id=c.id and v.visited_at::date=x.d
on conflict (visit_id, dog_id) do update set score=excluded.score, note=excluded.note;

-- Pre-import orphans (before 2023-11-15)
insert into public.visits (client_id, visited_at, service_type, source, external_id)
select c.id, x.ts, 'bath', 'contact_sheet', x.ext
from (values
  ('2022-12-21T12:00:00Z'::timestamptz, 'debra-2022-12-21'),
  ('2022-05-25T12:00:00Z'::timestamptz, 'debra-2022-05-25'),
  ('2021-11-17T12:00:00Z'::timestamptz, 'debra-2021-11-17')
) as x(ts, ext)
join public.clients c on c.name='Debra Koerner'
on conflict (source, external_id) where external_id is not null do nothing;

insert into public.visit_dog_ratings (visit_id, dog_id, score, note)
select v.id, d.id, null, x.note
from (values
  ('debra-2022-12-21', 'Gibbs', 'Good dog.'),
  ('debra-2022-12-21', 'Gabe',  'Difficult.'),
  ('debra-2022-05-25', 'Gabe',  'Difficult to work with.'),
  ('debra-2022-05-25', 'Gibbs', 'Had been walking on a leash before I arrived; tongue hanging out and thirsty. Became wild and would not go near the trailer, so I put my leash on him and walked him around it many times to desensitize him. He pulls on the leash, so I walked back and forth to train him not to pull. Good dog during grooming.'),
  ('debra-2021-11-17', 'Gibbs', 'Wild at first but then really good.'),
  ('debra-2021-11-17', 'Gabe',  'Difficult to handle.')
) as x(ext, dogname, note)
join public.visits v on v.source='contact_sheet' and v.external_id=x.ext
join public.clients c on c.id=v.client_id and c.name='Debra Koerner'
join public.dogs d on d.client_id=c.id and d.name=x.dogname
on conflict (visit_id, dog_id) do update set note=excluded.note;
