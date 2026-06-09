-- 0127_visit_history_eric_shannon.sql
-- Visit-history migration for Eric Shannon / Kiera + Rebel (both Pit Bulls). Kiera's
-- hindquarter-weakness and back-left-leg-surgery arc is preserved. Score + note
-- attached to the existing time_is_money visit by date; the sheet's "1/25/24" is a
-- typo for 1/25/25 and "9/22/24" for 9/22/23 (the imported dates confirm). Autumn (a
-- dachshund that belonged to Crystal, who moved to Alabama) and neighbor drop-ins are
-- not Eric's dogs and are kept in visit_notes. Pre-import entries (before 2023-07-28)
-- are source='contact_sheet'. See visit_history_migration + time_is_money_is_source_of_truth.

-- Kiera
insert into public.visit_dog_ratings (visit_id, dog_id, score, note)
select v.id, d.id, x.score, x.note from (values
  ('2025-09-06'::date, 5, null),
  ('2025-08-09'::date, 5, 'Spaghetti on the back of her head.'),
  ('2025-06-14'::date, 5, null),
  ('2025-05-17'::date, 5, null),
  ('2025-04-05'::date, 5, null),
  ('2025-02-27'::date, 5, null),
  ('2025-01-25'::date, 2, null),
  ('2024-12-15'::date, 5, null),
  ('2024-08-02'::date, 5, null),
  ('2024-05-30'::date, 4, null),
  ('2024-04-20'::date, 5, null),
  ('2023-11-03'::date, 3, 'Puts all her weight on her front feet because her hind end is weak; stands hanging over the table with her toes right at the edge. Nails extra long this time.'),
  ('2023-09-22'::date, 3, null),
  ('2023-08-25'::date, 3, null)
) as x(d, score, note)
join public.clients c on c.name='Eric Shannon'
join public.dogs d on d.client_id=c.id and d.name='Kiera'
join public.visits v on v.client_id=c.id and v.visited_at::date=x.d
on conflict (visit_id, dog_id) do update set score=excluded.score, note=excluded.note;

-- Rebel
insert into public.visit_dog_ratings (visit_id, dog_id, score, note)
select v.id, d.id, x.score, x.note from (values
  ('2025-09-06'::date, 5, null),
  ('2025-08-09'::date, 5, null),
  ('2025-06-14'::date, 5, null),
  ('2025-05-17'::date, 5, null),
  ('2025-04-05'::date, 5, null),
  ('2025-02-27'::date, 5, null),
  ('2025-01-25'::date, 5, null),
  ('2024-12-15'::date, 5, null),
  ('2024-08-02'::date, 5, null),
  ('2024-04-20'::date, 5, null),
  ('2023-11-03'::date, 5, null),
  ('2023-09-22'::date, 4, null),
  ('2023-08-25'::date, 3, null)
) as x(d, score, note)
join public.clients c on c.name='Eric Shannon'
join public.dogs d on d.client_id=c.id and d.name='Rebel'
join public.visits v on v.client_id=c.id and v.visited_at::date=x.d
on conflict (visit_id, dog_id) do update set score=excluded.score, note=excluded.note;

-- Pre-import orphans (before 2023-07-28)
insert into public.visits (client_id, visited_at, service_type, source, external_id)
select c.id, x.ts, 'full_groom', 'contact_sheet', x.ext
from (values
  ('2023-06-27T12:00:00Z'::timestamptz, 'eric-2023-06-27'),
  ('2023-05-30T12:00:00Z'::timestamptz, 'eric-2023-05-30'),
  ('2023-04-28T12:00:00Z'::timestamptz, 'eric-2023-04-28'),
  ('2023-02-28T12:00:00Z'::timestamptz, 'eric-2023-02-28'),
  ('2023-01-31T12:00:00Z'::timestamptz, 'eric-2023-01-31'),
  ('2022-12-29T12:00:00Z'::timestamptz, 'eric-2022-12-29'),
  ('2022-12-02T12:00:00Z'::timestamptz, 'eric-2022-12-02'),
  ('2022-10-28T12:00:00Z'::timestamptz, 'eric-2022-10-28'),
  ('2022-09-30T12:00:00Z'::timestamptz, 'eric-2022-09-30')
) as x(ts, ext)
join public.clients c on c.name='Eric Shannon'
on conflict (source, external_id) where external_id is not null do nothing;

update public.visits set visit_notes='Also did a neighbor''s dog (charged the neighbor $45). Good dog; the owner asked about flea shampoo and I said I would only use theirs if provided, so used my regular shampoo. Saw a few fleas but they appeared dead or very sick.'
where source='contact_sheet' and external_id='eric-2023-05-30';
update public.visits set visit_notes='Also did Autumn (Crystal''s dachshund); forgot to take pictures. The client provided shampoo. Her nails were very long, so most of the session was spent filing them.'
where source='contact_sheet' and external_id='eric-2022-09-30';

insert into public.visit_dog_ratings (visit_id, dog_id, score, note)
select v.id, d.id, null, x.note
from (values
  ('eric-2023-06-27', 'Kiera', 'Good.'),
  ('eric-2023-06-27', 'Rebel', 'Good.'),
  ('eric-2023-05-30', 'Kiera', 'Good.'),
  ('eric-2023-05-30', 'Rebel', 'Good.'),
  ('eric-2023-04-28', 'Rebel', 'Great dog.'),
  ('eric-2023-04-28', 'Kiera', 'Back legs a lot better.'),
  ('eric-2023-02-28', 'Kiera', 'Just had surgery on her back left leg. Uncooperative.'),
  ('eric-2023-02-28', 'Rebel', 'Ok. Easier than Kiera.'),
  ('eric-2023-01-31', 'Kiera', 'Maybe stronger in the hindquarters than before. Eric said she is having surgery next week.'),
  ('eric-2023-01-31', 'Rebel', 'Good dog.'),
  ('eric-2022-12-29', 'Rebel', 'Good dog.'),
  ('eric-2022-12-29', 'Kiera', 'Has trouble standing. A little bit difficult to handle.'),
  ('eric-2022-12-02', 'Kiera', 'Lame in the hindquarters. Difficult to handle.'),
  ('eric-2022-12-02', 'Rebel', 'Good.'),
  ('eric-2022-10-28', 'Kiera', 'Still puts all her weight on her front feet, back legs still shaky. Good dog.'),
  ('eric-2022-09-30', 'Kiera', 'Puts most of her weight on her front feet; back legs are shaky.'),
  ('eric-2022-09-30', 'Rebel', 'Best dog all week.')
) as x(ext, dogname, note)
join public.visits v on v.source='contact_sheet' and v.external_id=x.ext
join public.clients c on c.id=v.client_id and c.name='Eric Shannon'
join public.dogs d on d.client_id=c.id and d.name=x.dogname
on conflict (visit_id, dog_id) do update set note=excluded.note;
