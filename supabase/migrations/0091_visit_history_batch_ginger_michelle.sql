-- 0091_visit_history_batch_ginger_michelle.sql
-- Visit-history migration, batch A: Ginger Fink and Michelle Reiners. Each dated
-- sheet entry's per-dog score + note is attached to the EXISTING visit on that
-- date (time_is_money_is_source_of_truth: never changing a date or amount); where
-- the sheet recorded a word instead of a number (older entries) the score is left
-- null. Entries with no existing visit are created as source='contact_sheet'
-- (lower authority) so nothing is lost, including Bandit's 2022 bite. See
-- visit_history_migration + time_is_money_is_source_of_truth.

-- ===== Ginger Fink / Bruce =====
insert into public.visit_dog_ratings (visit_id, dog_id, score, note)
select v.id, d.id, x.score, x.note
from (values
  ('2026-03-06'::date, 4, null),
  ('2026-02-06'::date, 4, null),
  ('2026-01-07'::date, 4, 'Infested with fleas.'),
  ('2025-10-28'::date, 4, null),
  ('2025-09-30'::date, 4, null),
  ('2025-09-02'::date, 3, null),
  ('2025-08-05'::date, 3, null),
  ('2025-07-10'::date, 4, null),
  ('2025-06-12'::date, 4, null),
  ('2025-05-15'::date, 4, null),
  ('2025-04-17'::date, 4, 'Very dirty; the bath water looked like a mud puddle, so I flushed the system and started over with a fresh bath.'),
  ('2025-03-23'::date, 3, null),
  ('2024-08-23'::date, 2, 'Infested with fleas, mostly dead or dying.'),
  ('2024-06-27'::date, 2, 'Fleas.'),
  ('2024-05-29'::date, 3, 'Would be a 2 if he were not a pit bull; a dog that needed more labor and acted like him would be a problem. Lots of fleas, I think all dead.'),
  ('2024-05-01'::date, 2, 'A 2 by definition, but Bruce is ok to keep as a client; he is a good dog.')
) as x(d, score, note)
join public.clients c on c.name = 'Ginger Fink'
join public.dogs d on d.client_id = c.id and d.name = 'Bruce'
join public.visits v on v.client_id = c.id and v.visited_at::date = x.d
on conflict (visit_id, dog_id) do update set score = excluded.score, note = excluded.note;

-- Ginger orphan (no existing visit): 2023-03-23
insert into public.visits (client_id, visited_at, service_type, source, external_id)
select c.id, '2023-03-23T12:00:00Z'::timestamptz, 'full_groom', 'contact_sheet', 'ginger-2023-03-23'
from public.clients c where c.name = 'Ginger Fink'
on conflict (source, external_id) where external_id is not null do nothing;
insert into public.visit_dog_ratings (visit_id, dog_id, score, note)
select v.id, d.id, null, 'A handful but ok.'
from public.visits v join public.clients c on c.id = v.client_id
join public.dogs d on d.client_id = c.id and d.name = 'Bruce'
where v.source = 'contact_sheet' and v.external_id = 'ginger-2023-03-23'
on conflict (visit_id, dog_id) do nothing;

-- ===== Michelle Reiners / Bandit =====
insert into public.visit_dog_ratings (visit_id, dog_id, score, note)
select v.id, d.id, x.score, x.note
from (values
  ('2026-04-04'::date, 5, null),
  ('2026-03-06'::date, 5, null),
  ('2026-02-07'::date, 5, null),
  ('2026-01-11'::date, 5, null),
  ('2025-12-10'::date, 5, 'Looks like he has been chewing on himself and maybe someone else chewing on him too, especially around his tail; one on his neck he could not have reached himself.'),
  ('2025-11-10'::date, 5, null),
  ('2025-10-16'::date, 5, null),
  ('2025-09-20'::date, 5, 'Round irritated spot, visible only when the fur is lifted by the dryer.'),
  ('2025-08-23'::date, 5, null),
  ('2024-08-23'::date, 5, null),
  ('2024-06-27'::date, 2, null),
  ('2024-05-29'::date, 5, null),
  ('2024-05-01'::date, 5, null),
  ('2024-04-03'::date, 5, null),
  ('2024-03-07'::date, 5, null),
  ('2024-01-12'::date, 5, null),
  ('2023-11-30'::date, 5, null),
  ('2023-10-19'::date, 4, null),
  ('2023-09-07'::date, 3, null)
) as x(d, score, note)
join public.clients c on c.name = 'Michelle Reiners'
join public.dogs d on d.client_id = c.id and d.name = 'Bandit'
join public.visits v on v.client_id = c.id and v.visited_at::date = x.d
on conflict (visit_id, dog_id) do update set score = excluded.score, note = excluded.note;

-- Michelle Reiners / Bruno
insert into public.visit_dog_ratings (visit_id, dog_id, score, note)
select v.id, d.id, x.score, x.note
from (values
  ('2026-03-06'::date, 5, null),
  ('2026-02-07'::date, 5, null),
  ('2026-01-11'::date, 5, null),
  ('2025-12-10'::date, 5, null),
  ('2025-11-10'::date, 5, null),
  ('2025-10-16'::date, 5, null),
  ('2025-09-20'::date, 5, null),
  ('2025-08-23'::date, 5, null),
  ('2024-08-23'::date, 5, null),
  ('2024-06-27'::date, 4, null),
  ('2024-05-29'::date, 4, 'He started taking psych meds after he ate the couch.'),
  ('2024-05-01'::date, 4, null),
  ('2024-04-03'::date, 3, null),
  ('2024-03-07'::date, 5, null),
  ('2024-01-12'::date, 5, null),
  ('2023-11-30'::date, 5, null),
  ('2023-10-19'::date, 3, null),
  ('2023-09-07'::date, 3, null)
) as x(d, score, note)
join public.clients c on c.name = 'Michelle Reiners'
join public.dogs d on d.client_id = c.id and d.name = 'Bruno'
join public.visits v on v.client_id = c.id and v.visited_at::date = x.d
on conflict (visit_id, dog_id) do update set score = excluded.score, note = excluded.note;

-- Michelle orphans (no existing visit): create source='contact_sheet' visits, then ratings.
insert into public.visits (client_id, visited_at, service_type, source, external_id)
select c.id, x.ts, 'full_groom', 'contact_sheet', x.ext
from (values
  ('2022-11-09T12:00:00Z'::timestamptz, 'michelle-2022-11-09'),
  ('2022-12-26T12:00:00Z'::timestamptz, 'michelle-2022-12-26'),
  ('2023-02-08T12:00:00Z'::timestamptz, 'michelle-2023-02-08'),
  ('2023-05-04T12:00:00Z'::timestamptz, 'michelle-2023-05-04'),
  ('2023-06-12T12:00:00Z'::timestamptz, 'michelle-2023-06-12')
) as x(ts, ext)
join public.clients c on c.name = 'Michelle Reiners'
on conflict (source, external_id) where external_id is not null do nothing;

insert into public.visit_dog_ratings (visit_id, dog_id, score, note)
select v.id, d.id, null, x.note
from (values
  ('michelle-2022-11-09', 'Bandit', 'Attacked me while I was letting him in the gate and bit my arm. Left a mark but did not draw blood. Told Michelle that since it was out of character we would give him another chance, but any further aggression and he is no longer eligible.'),
  ('michelle-2022-11-09', 'Bruno',  'Difficult. Constantly pushes against me.'),
  ('michelle-2022-12-26', 'Bandit', 'Good dog.'),
  ('michelle-2022-12-26', 'Bruno',  'Good dog.'),
  ('michelle-2023-02-08', 'Bandit', 'Good.'),
  ('michelle-2023-02-08', 'Bruno',  'Puts all his weight on his front feet and the bottom of his chin, pushing down and hanging over the side of the table. Very frustrating. Good otherwise.'),
  ('michelle-2023-05-04', 'Bandit', 'Great dog.'),
  ('michelle-2023-05-04', 'Bruno',  'Ok.'),
  ('michelle-2023-06-12', 'Bandit', 'Great dog.')
) as x(ext, dogname, note)
join public.visits v on v.source = 'contact_sheet' and v.external_id = x.ext
join public.clients c on c.id = v.client_id and c.name = 'Michelle Reiners'
join public.dogs d on d.client_id = c.id and d.name = x.dogname
on conflict (visit_id, dog_id) do update set note = excluded.note;
