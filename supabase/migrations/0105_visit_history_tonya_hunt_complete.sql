-- 0105_visit_history_tonya_hunt_complete.sql
-- Completes Tonya Hunt's history so nothing is thrown away (follows 0103).
-- (1) Adds her own dogs that were missing from the DB: Andy (senior shepherd mix),
--     Scrappy and Pebbles (Yorkie mixes), and Polly (listed, no history) - same
--     treatment as Chloe's Whiskey/Skout.
-- (2) Adds the older 2023/early-2024 visits 0103 did not reach (matched by date;
--     sheet 5/4/24 -> imported 2024-05-03).
-- (3) Preserves the visiting/relatives' dogs (Charlie, Dash, Eula, and an unnamed
--     drop-in) in each visit's visit_notes, since they are not Tonya's dogs but the
--     observations are real data.
-- See visit_history_migration + time_is_money_is_source_of_truth.

-- ===== Add Tonya's own dogs that were missing =====
insert into public.dogs (client_id, name, breed, notes)
select c.id, x.name, x.breed, x.notes
from (values
  ('Andy',    'Shepherd mix', 'Senior (15-16 years old as of early 2023); last groomed Aug 2024.'),
  ('Scrappy', 'Yorkie Mix',   null),
  ('Pebbles', 'Yorkie Mix',   null),
  ('Polly',   null,           'Listed on the contact sheet; no visit history recorded.')
) as x(name, breed, notes)
join public.clients c on c.name = 'Tonya Hunt'
where not exists (select 1 from public.dogs d where d.client_id = c.id and d.name = x.name);

-- ===== Kai: additional dates =====
insert into public.visit_dog_ratings (visit_id, dog_id, score, note)
select v.id, d.id, x.score, x.note
from (values
  ('2024-03-08'::date, 3, null),
  ('2023-10-02'::date, 2, 'Leave feathers on the back legs longer. Bo likes it longer.')
) as x(d, score, note)
join public.clients c on c.name = 'Tonya Hunt'
join public.dogs d on d.client_id = c.id and d.name = 'Kai'
join public.visits v on v.client_id = c.id and v.visited_at::date = x.d
on conflict (visit_id, dog_id) do update set score = excluded.score, note = excluded.note;

-- ===== Lydia: additional dates =====
insert into public.visit_dog_ratings (visit_id, dog_id, score, note)
select v.id, d.id, x.score, x.note
from (values
  ('2024-05-03'::date, 3, 'Sweet dog.'),
  ('2024-03-08'::date, 3, null),
  ('2023-10-02'::date, 3, '7/8 inch comb on body to even it out. Lift and blend away from the ground.')
) as x(d, score, note)
join public.clients c on c.name = 'Tonya Hunt'
join public.dogs d on d.client_id = c.id and d.name = 'Lydia'
join public.visits v on v.client_id = c.id and v.visited_at::date = x.d
on conflict (visit_id, dog_id) do update set score = excluded.score, note = excluded.note;

-- ===== Koa: additional dates =====
insert into public.visit_dog_ratings (visit_id, dog_id, score, note)
select v.id, d.id, x.score, x.note
from (values
  ('2024-05-03'::date, 3, 'Sweet dog.'),
  ('2024-04-08'::date, 1, 'But also a 4, 3, and 2.'),
  ('2023-10-02'::date, 2, null)
) as x(d, score, note)
join public.clients c on c.name = 'Tonya Hunt'
join public.dogs d on d.client_id = c.id and d.name = 'Koa'
join public.visits v on v.client_id = c.id and v.visited_at::date = x.d
on conflict (visit_id, dog_id) do update set score = excluded.score, note = excluded.note;

-- ===== Ruthie: additional date =====
insert into public.visit_dog_ratings (visit_id, dog_id, score, note)
select v.id, d.id, x.score, x.note
from (values
  ('2024-03-08'::date, 5, 'Started on Friday. She was so dirty that after a bath and beginning to clip her she was still filthy underneath; returned Saturday to finish the job.')
) as x(d, score, note)
join public.clients c on c.name = 'Tonya Hunt'
join public.dogs d on d.client_id = c.id and d.name = 'Ruthie'
join public.visits v on v.client_id = c.id and v.visited_at::date = x.d
on conflict (visit_id, dog_id) do update set score = excluded.score, note = excluded.note;

-- ===== Andy (newly added dog) =====
insert into public.visit_dog_ratings (visit_id, dog_id, score, note)
select v.id, d.id, x.score, x.note
from (values
  ('2024-08-07'::date, 3, null),
  ('2024-03-08'::date, 4, null),
  ('2023-10-02'::date, 4, '#7 blade on body.')
) as x(d, score, note)
join public.clients c on c.name = 'Tonya Hunt'
join public.dogs d on d.client_id = c.id and d.name = 'Andy'
join public.visits v on v.client_id = c.id and v.visited_at::date = x.d
on conflict (visit_id, dog_id) do update set score = excluded.score, note = excluded.note;

-- ===== Scrappy (newly added dog) =====
insert into public.visit_dog_ratings (visit_id, dog_id, score, note)
select v.id, d.id, x.score, x.note
from (values
  ('2024-03-09'::date, 5, null)
) as x(d, score, note)
join public.clients c on c.name = 'Tonya Hunt'
join public.dogs d on d.client_id = c.id and d.name = 'Scrappy'
join public.visits v on v.client_id = c.id and v.visited_at::date = x.d
on conflict (visit_id, dog_id) do update set score = excluded.score, note = excluded.note;

-- ===== Pre-import orphans (before 2023-10-02) =====
insert into public.visits (client_id, visited_at, service_type, source, external_id)
select c.id, x.ts, 'full_groom', 'contact_sheet', x.ext
from (values
  ('2023-07-01T12:00:00Z'::timestamptz, 'tonya-2023-07-01'),
  ('2023-06-17T12:00:00Z'::timestamptz, 'tonya-2023-06-17'),
  ('2023-01-09T12:00:00Z'::timestamptz, 'tonya-2023-01-09')
) as x(ts, ext)
join public.clients c on c.name = 'Tonya Hunt'
on conflict (source, external_id) where external_id is not null do nothing;

update public.visits set visit_notes = 'All three dogs were uncooperative. Did not enjoy working with them; possibly very thirsty.'
where source = 'contact_sheet' and external_id = 'tonya-2023-07-01';

insert into public.visit_dog_ratings (visit_id, dog_id, score, note)
select v.id, d.id, null, x.note
from (values
  ('tonya-2023-07-01', 'Lydia',   'Difficult. Used 7/8 inch comb on body to even her out; hard to make it look good because she was uncooperative.'),
  ('tonya-2023-07-01', 'Koa',     'Uncooperative.'),
  ('tonya-2023-07-01', 'Kai',     'Awful.'),
  ('tonya-2023-06-17', 'Ruthie',  'Noncompliant in the bath tub. Pretty good with everything else.'),
  ('tonya-2023-06-17', 'Andy',    'Good.'),
  ('tonya-2023-06-17', 'Scrappy', 'Great dog. Makes me happy.'),
  ('tonya-2023-06-17', 'Pebbles', 'Ok.'),
  ('tonya-2023-01-09', 'Kai',     'Good at first, a little uncooperative towards the end.'),
  ('tonya-2023-01-09', 'Lydia',   'Uncooperative at first, a little easier at the end.'),
  ('tonya-2023-01-09', 'Andy',    '15 or 16 years old.'),
  ('tonya-2023-01-09', 'Ruthie',  'Extremely uncooperative. Took hours.')
) as x(ext, dogname, note)
join public.visits v on v.source = 'contact_sheet' and v.external_id = x.ext
join public.clients c on c.id = v.client_id and c.name = 'Tonya Hunt'
join public.dogs d on d.client_id = c.id and d.name = x.dogname
on conflict (visit_id, dog_id) do update set note = excluded.note;

-- ===== Preserve visiting/relatives' dogs in visit_notes (not Tonya's dogs) =====
update public.visits set visit_notes = 'Also groomed guest dogs: Charlie (a 5) and Dash (a 3, shorter than Tonya''s dogs).'
where client_id = (select id from public.clients where name='Tonya Hunt') and visited_at::date = '2025-09-17';

update public.visits set visit_notes = 'Guest dog only this visit: Eula (a 3, sometimes a 2). Tonya''s brother Eddie''s in-law''s dog.'
where client_id = (select id from public.clients where name='Tonya Hunt') and visited_at::date = '2025-05-31';

update public.visits set visit_notes = 'Also groomed guest dog Charlie (a 2 and 3; 22mm comb on body).'
where client_id = (select id from public.clients where name='Tonya Hunt') and visited_at::date = '2025-05-29';

update public.visits set visit_notes = 'Also took care of a visiting dog''s nails and used a deshedding tool on her.'
where client_id = (select id from public.clients where name='Tonya Hunt') and visited_at::date = '2024-11-27';
