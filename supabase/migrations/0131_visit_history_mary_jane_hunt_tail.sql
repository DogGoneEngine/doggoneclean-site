-- 0131_visit_history_mary_jane_hunt_tail.sql
-- Completes Mary Jane Hunt's older history (Caesar, Pancho, Ringo): the imported
-- time_is_money visits 2023-11-02 through 2024-05-02 get their per-dog scores, and the
-- 2022/early-2023 entries below the import become source='contact_sheet' orphans with
-- their notes (the hitchhiker trims, Ringo's acupuncture, the beard-length requests).
-- The sheet spells Caesar as "Ceaser" in places; the dog is Caesar. The DB's 2023-08-08
-- visit has no matching sheet entry, so it is left an honest gap. The 2024-03-21 visit
-- has no scores on the sheet, so it too stays a gap. See visit_history_migration +
-- time_is_money_is_source_of_truth.

-- Pancho (imported dates)
insert into public.visit_dog_ratings (visit_id, dog_id, score, note)
select v.id, d.id, x.score, x.note from (values
  ('2024-04-04'::date, 4, null),
  ('2024-03-07'::date, 5, null),
  ('2024-02-22'::date, 5, null),
  ('2024-01-11'::date, 4, null),
  ('2023-12-14'::date, 5, null),
  ('2023-11-30'::date, 5, null),
  ('2023-11-16'::date, 5, null),
  ('2023-11-02'::date, 4, null)
) as x(d, score, note)
join public.clients c on c.name='Mary Jane Hunt'
join public.dogs d on d.client_id=c.id and d.name='Pancho'
join public.visits v on v.client_id=c.id and v.visited_at::date=x.d
on conflict (visit_id, dog_id) do update set score=excluded.score, note=excluded.note;

-- Ringo (imported dates)
insert into public.visit_dog_ratings (visit_id, dog_id, score, note)
select v.id, d.id, x.score, x.note from (values
  ('2024-05-02'::date, 5, null),
  ('2024-04-04'::date, 4, null),
  ('2024-03-07'::date, 5, null),
  ('2024-01-11'::date, 4, null),
  ('2023-12-14'::date, 5, null),
  ('2023-11-30'::date, 4, null),
  ('2023-11-16'::date, 5, null),
  ('2023-11-02'::date, 4, null)
) as x(d, score, note)
join public.clients c on c.name='Mary Jane Hunt'
join public.dogs d on d.client_id=c.id and d.name='Ringo'
join public.visits v on v.client_id=c.id and v.visited_at::date=x.d
on conflict (visit_id, dog_id) do update set score=excluded.score, note=excluded.note;

-- Caesar (imported dates)
insert into public.visit_dog_ratings (visit_id, dog_id, score, note)
select v.id, d.id, x.score, x.note from (values
  ('2024-05-02'::date, 5, null),
  ('2024-04-04'::date, 4, null),
  ('2024-03-07'::date, 5, null),
  ('2024-01-11'::date, 3, null),
  ('2023-12-14'::date, 4, null),
  ('2023-11-30'::date, 4, null),
  ('2023-11-16'::date, 5, null),
  ('2023-11-02'::date, 4, null)
) as x(d, score, note)
join public.clients c on c.name='Mary Jane Hunt'
join public.dogs d on d.client_id=c.id and d.name='Caesar'
join public.visits v on v.client_id=c.id and v.visited_at::date=x.d
on conflict (visit_id, dog_id) do update set score=excluded.score, note=excluded.note;

-- Pre-import orphans (before the imported history began), back to 2022
insert into public.visits (client_id, visited_at, service_type, source, external_id)
select c.id, x.ts, 'full_groom', 'contact_sheet', x.ext
from (values
  ('2023-05-11T12:00:00Z'::timestamptz, 'maryjane-2023-05-11'),
  ('2023-04-27T12:00:00Z'::timestamptz, 'maryjane-2023-04-27'),
  ('2023-04-13T12:00:00Z'::timestamptz, 'maryjane-2023-04-13'),
  ('2023-03-16T12:00:00Z'::timestamptz, 'maryjane-2023-03-16'),
  ('2023-03-02T12:00:00Z'::timestamptz, 'maryjane-2023-03-02'),
  ('2023-02-16T12:00:00Z'::timestamptz, 'maryjane-2023-02-16'),
  ('2023-01-19T12:00:00Z'::timestamptz, 'maryjane-2023-01-19'),
  ('2022-11-10T12:00:00Z'::timestamptz, 'maryjane-2022-11-10'),
  ('2022-10-27T12:00:00Z'::timestamptz, 'maryjane-2022-10-27'),
  ('2022-05-19T12:00:00Z'::timestamptz, 'maryjane-2022-05-19'),
  ('2022-05-05T12:00:00Z'::timestamptz, 'maryjane-2022-05-05'),
  ('2022-04-21T12:00:00Z'::timestamptz, 'maryjane-2022-04-21'),
  ('2022-03-24T12:00:00Z'::timestamptz, 'maryjane-2022-03-24')
) as x(ts, ext)
join public.clients c on c.name='Mary Jane Hunt'
on conflict (source, external_id) where external_id is not null do nothing;

-- The 3/24/22 grooming instructions did not name a dog, so they live on the visit.
update public.visits set visit_notes='Mary Jane''s note: trim his body and leave the eyebrows the same; also trim legs and stomach.'
where source='contact_sheet' and external_id='maryjane-2022-03-24' and visit_notes is null;

insert into public.visit_dog_ratings (visit_id, dog_id, score, note)
select v.id, d.id, null, x.note
from (values
  ('maryjane-2023-05-11', 'Pancho', 'Good.'),
  ('maryjane-2023-05-11', 'Caesar', 'Good.'),
  ('maryjane-2023-05-11', 'Ringo',  'Good.'),
  ('maryjane-2023-04-13', 'Caesar', 'Good.'),
  ('maryjane-2023-04-13', 'Pancho', 'Good.'),
  ('maryjane-2023-04-13', 'Ringo',  'Good.'),
  ('maryjane-2023-03-16', 'Pancho', 'Mary Jane asked me to leave his beard longer.'),
  ('maryjane-2023-03-16', 'Ringo',  'Good. Was clawing at me in the house when I picked him up. He does not usually do that.'),
  ('maryjane-2023-03-16', 'Caesar', 'Good dog.'),
  ('maryjane-2023-03-02', 'Pancho', 'Mary Jane requested trimming off half an inch.'),
  ('maryjane-2023-03-02', 'Ringo',  'Mary Jane requested trimming off half an inch.'),
  ('maryjane-2023-02-16', 'Pancho', 'Great dog. Excessive shedding.'),
  ('maryjane-2023-02-16', 'Caesar', 'Great dog.'),
  ('maryjane-2023-02-16', 'Ringo',  'Mary Jane asked me to clip under his tail so nothing gets stuck there.'),
  ('maryjane-2023-01-19', 'Pancho', 'Good dog.'),
  ('maryjane-2023-01-19', 'Caesar', 'Good dog.'),
  ('maryjane-2023-01-19', 'Ringo',  'Good dog.'),
  ('maryjane-2022-10-27', 'Pancho', 'Mary Jane requested legs and stomach trimmed because he is picking up hitchhikers.'),
  ('maryjane-2022-10-27', 'Caesar', 'Offered me his paw a couple of times like he wanted to shake hands.'),
  ('maryjane-2022-10-27', 'Ringo',  'At the vet getting acupuncture when I arrived.'),
  ('maryjane-2022-05-19', 'Pancho', 'Legs shorter than the rest of his body.'),
  ('maryjane-2022-04-21', 'Pancho', 'Mary Jane''s note says trim off half an inch.')
) as x(ext, dogname, note)
join public.visits v on v.source='contact_sheet' and v.external_id=x.ext
join public.clients c on c.id=v.client_id and c.name='Mary Jane Hunt'
join public.dogs d on d.client_id=c.id and d.name=x.dogname
on conflict (visit_id, dog_id) do update set note=excluded.note;
