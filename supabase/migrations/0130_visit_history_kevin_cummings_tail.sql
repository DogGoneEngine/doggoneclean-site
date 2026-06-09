-- 0130_visit_history_kevin_cummings_tail.sql
-- Completes Kevin Cummings's older history (the tail 0108 did not reach): the imported
-- visits from 2023-07-29 through 2024-10-16, plus the deep 2022/early-2023 orphans with
-- their behavioral notes (Molly the leash-biter, the uncooperative labs). Score + note
-- attached to the existing time_is_money visit by date; the sheet's "Cage" is Kage and
-- "Izzy"/"Lexie"/"Kacy" are Izzie/Lexi/Kacey. See visit_history_migration.

-- Klaus
insert into public.visit_dog_ratings (visit_id, dog_id, score, note)
select v.id, d.id, x.score, x.note from (values
  ('2024-10-16'::date, 5, null),
  ('2024-07-14'::date, 5, null),
  ('2024-05-18'::date, 3, null),
  ('2024-02-24'::date, 5, null),
  ('2024-01-13'::date, null, 'I cannot figure out if he is a 4 or a 2. Likeable dog, sometimes uncooperative.'),
  ('2023-12-02'::date, 5, 'Heavy shedding. Walks into the trailer and puts his feet up on the tub to jump in.'),
  ('2023-10-21'::date, 5, null),
  ('2023-09-09'::date, 3, null),
  ('2023-07-29'::date, 3, null)
) as x(d, score, note)
join public.clients c on c.name='Kevin Cummings'
join public.dogs d on d.client_id=c.id and d.name='Klaus'
join public.visits v on v.client_id=c.id and v.visited_at::date=x.d
on conflict (visit_id, dog_id) do update set score=excluded.score, note=excluded.note;

-- Kacey
insert into public.visit_dog_ratings (visit_id, dog_id, score, note)
select v.id, d.id, x.score, x.note from (values
  ('2024-10-16'::date, 5, null),
  ('2024-07-14'::date, 5, null),
  ('2024-05-18'::date, 3, null),
  ('2024-02-24'::date, 5, null),
  ('2023-12-02'::date, 5, null),
  ('2023-10-21'::date, 4, null),
  ('2023-09-09'::date, 3, 'Nails only.')
) as x(d, score, note)
join public.clients c on c.name='Kevin Cummings'
join public.dogs d on d.client_id=c.id and d.name='Kacey'
join public.visits v on v.client_id=c.id and v.visited_at::date=x.d
on conflict (visit_id, dog_id) do update set score=excluded.score, note=excluded.note;

-- Molly
insert into public.visit_dog_ratings (visit_id, dog_id, score, note)
select v.id, d.id, x.score, x.note from (values
  ('2024-10-16'::date, 3, null),
  ('2024-07-14'::date, 5, null),
  ('2024-05-18'::date, 5, null),
  ('2024-02-24'::date, 5, null),
  ('2024-01-13'::date, 4, null),
  ('2023-12-02'::date, 3, null),
  ('2023-10-21'::date, 5, null),
  ('2023-09-09'::date, 4, null),
  ('2023-07-29'::date, 4, null)
) as x(d, score, note)
join public.clients c on c.name='Kevin Cummings'
join public.dogs d on d.client_id=c.id and d.name='Molly'
join public.visits v on v.client_id=c.id and v.visited_at::date=x.d
on conflict (visit_id, dog_id) do update set score=excluded.score, note=excluded.note;

-- Lexi
insert into public.visit_dog_ratings (visit_id, dog_id, score, note)
select v.id, d.id, x.score, x.note from (values
  ('2024-07-14'::date, 3, null),
  ('2024-05-18'::date, 4, null),
  ('2024-02-24'::date, 4, null),
  ('2023-12-02'::date, null, 'They could hardly get her out of the house, but then she walked to the trailer and eagerly jumped in when I opened the door.'),
  ('2023-10-21'::date, 3, null),
  ('2023-09-09'::date, 1, null)
) as x(d, score, note)
join public.clients c on c.name='Kevin Cummings'
join public.dogs d on d.client_id=c.id and d.name='Lexi'
join public.visits v on v.client_id=c.id and v.visited_at::date=x.d
on conflict (visit_id, dog_id) do update set score=excluded.score, note=excluded.note;

-- Izzie
insert into public.visit_dog_ratings (visit_id, dog_id, score, note)
select v.id, d.id, x.score, x.note from (values
  ('2024-07-14'::date, 3, null),
  ('2024-05-18'::date, 4, null),
  ('2024-02-24'::date, 3, null),
  ('2023-12-02'::date, 3, 'Dirty, not shedding as much as Lexi.'),
  ('2023-10-21'::date, 2, null),
  ('2023-09-09'::date, 1, null)
) as x(d, score, note)
join public.clients c on c.name='Kevin Cummings'
join public.dogs d on d.client_id=c.id and d.name='Izzie'
join public.visits v on v.client_id=c.id and v.visited_at::date=x.d
on conflict (visit_id, dog_id) do update set score=excluded.score, note=excluded.note;

-- Ace
insert into public.visit_dog_ratings (visit_id, dog_id, score, note)
select v.id, d.id, x.score, x.note from (values
  ('2024-07-14'::date, 2, null),
  ('2024-05-18'::date, 3, null)
) as x(d, score, note)
join public.clients c on c.name='Kevin Cummings'
join public.dogs d on d.client_id=c.id and d.name='Ace'
join public.visits v on v.client_id=c.id and v.visited_at::date=x.d
on conflict (visit_id, dog_id) do update set score=excluded.score, note=excluded.note;

-- Kage (sheet "Cage")
insert into public.visit_dog_ratings (visit_id, dog_id, score, note)
select v.id, d.id, x.score, x.note from (values
  ('2024-07-14'::date, 2, null),
  ('2024-05-18'::date, 5, 'Nails only. I shaved his pads and deshedded him also.')
) as x(d, score, note)
join public.clients c on c.name='Kevin Cummings'
join public.dogs d on d.client_id=c.id and d.name='Kage'
join public.visits v on v.client_id=c.id and v.visited_at::date=x.d
on conflict (visit_id, dog_id) do update set score=excluded.score, note=excluded.note;

-- Pre-import orphans (before 2023-07-29)
insert into public.visits (client_id, visited_at, service_type, source, external_id)
select c.id, x.ts, 'full_groom', 'contact_sheet', x.ext
from (values
  ('2023-06-13T12:00:00Z'::timestamptz, 'kevin-2023-06-13'),
  ('2023-05-05T12:00:00Z'::timestamptz, 'kevin-2023-05-05'),
  ('2023-03-30T12:00:00Z'::timestamptz, 'kevin-2023-03-30'),
  ('2023-01-20T12:00:00Z'::timestamptz, 'kevin-2023-01-20'),
  ('2022-10-21T12:00:00Z'::timestamptz, 'kevin-2022-10-21'),
  ('2022-06-29T12:00:00Z'::timestamptz, 'kevin-2022-06-29'),
  ('2022-03-31T12:00:00Z'::timestamptz, 'kevin-2022-03-31')
) as x(ts, ext)
join public.clients c on c.name='Kevin Cummings'
on conflict (source, external_id) where external_id is not null do nothing;

insert into public.visit_dog_ratings (visit_id, dog_id, score, note)
select v.id, d.id, null, x.note
from (values
  ('kevin-2023-06-13', 'Klaus', 'Good. (Labs just nails this visit.)'),
  ('kevin-2023-06-13', 'Molly', 'Good.'),
  ('kevin-2023-06-13', 'Kacey', 'Good.'),
  ('kevin-2023-05-05', 'Klaus', 'Good.'),
  ('kevin-2023-05-05', 'Molly', 'Difficult.'),
  ('kevin-2023-05-05', 'Lexi',  'Very uncooperative.'),
  ('kevin-2023-05-05', 'Izzie', 'Uncooperative; at times will cooperate.'),
  ('kevin-2023-05-05', 'Kacey', 'Ok.'),
  ('kevin-2023-03-30', 'Klaus', 'Ok.'),
  ('kevin-2023-03-30', 'Molly', 'Ok.'),
  ('kevin-2023-01-20', 'Klaus', 'Good.'),
  ('kevin-2023-01-20', 'Molly', 'Uncooperative to walk on a leash; tries to bite the leash. If the leash were a hand she would likely bite that too.'),
  ('kevin-2023-01-20', 'Lexi',  'Uncooperative.'),
  ('kevin-2022-10-21', 'Klaus', 'Difficult.'),
  ('kevin-2022-10-21', 'Kacey', 'Difficult.'),
  ('kevin-2022-10-21', 'Molly', 'Difficult.'),
  ('kevin-2022-06-29', 'Kacey', 'Extreme shedding.'),
  ('kevin-2022-03-31', 'Kacey', 'Difficult.')
) as x(ext, dogname, note)
join public.visits v on v.source='contact_sheet' and v.external_id=x.ext
join public.clients c on c.id=v.client_id and c.name='Kevin Cummings'
join public.dogs d on d.client_id=c.id and d.name=x.dogname
on conflict (visit_id, dog_id) do update set note=excluded.note;
