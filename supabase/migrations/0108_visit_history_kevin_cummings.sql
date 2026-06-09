-- 0108_visit_history_kevin_cummings.sql
-- Visit-history migration for Kevin Cummings (7 dogs: Klaus + Kacey GSDs, Molly
-- husky, Lexi + Izzie black labs, Ace yellow lab, Kage black lab puppy). Ace and
-- Kage moved to Tampa (roster_status 'moved') but their history is real and stays.
-- Score + note attached to the existing time_is_money visit by date; sheet 3/6/25
-- maps to the imported 2025-03-08. This pass covers the readable recent history
-- (2024-10-18 through 2026-02-06); Kevin's older tail (2023-07-29 through mid-2024)
-- and a few unscored recent visits remain to migrate on the next pass (a known gap,
-- not discarded). See visit_history_migration + time_is_money_is_source_of_truth.

-- Klaus
insert into public.visit_dog_ratings (visit_id, dog_id, score, note)
select v.id, d.id, x.score, x.note from (values
  ('2026-02-06'::date, 5, null),
  ('2025-12-18'::date, 5, 'Skin a little bit flaky.'),
  ('2025-09-29'::date, 5, null),
  ('2025-07-24'::date, 5, null),
  ('2025-06-09'::date, null, 'Erin told me to watch out for his left ear because it was bleeding; it left a few drops of blood on the table.'),
  ('2025-04-28'::date, 5, null),
  ('2025-03-08'::date, 5, null),
  ('2025-01-26'::date, 3, null),
  ('2024-11-25'::date, 5, null)
) as x(d, score, note)
join public.clients c on c.name='Kevin Cummings'
join public.dogs d on d.client_id=c.id and d.name='Klaus'
join public.visits v on v.client_id=c.id and v.visited_at::date=x.d
on conflict (visit_id, dog_id) do update set score=excluded.score, note=excluded.note;

-- Kacey
insert into public.visit_dog_ratings (visit_id, dog_id, score, note)
select v.id, d.id, x.score, x.note from (values
  ('2025-12-18'::date, 5, null),
  ('2025-09-29'::date, 5, null),
  ('2025-07-24'::date, 5, 'Getting frail.'),
  ('2025-06-09'::date, 5, 'Getting lame. All her weight on her front feet.'),
  ('2025-04-28'::date, 5, null),
  ('2025-03-08'::date, 5, null),
  ('2025-01-26'::date, 5, 'Boo boo at the top of her back foot pad; left a few bloody smudges on my table. Not sure if I aggravated it or it was there when I started; it was not leaving marks when I finished. It is on the leg she does not want to pick up, so maybe from putting all her weight on that foot she gets extra wear on that pad.'),
  ('2024-11-25'::date, 5, null)
) as x(d, score, note)
join public.clients c on c.name='Kevin Cummings'
join public.dogs d on d.client_id=c.id and d.name='Kacey'
join public.visits v on v.client_id=c.id and v.visited_at::date=x.d
on conflict (visit_id, dog_id) do update set score=excluded.score, note=excluded.note;

-- Molly
insert into public.visit_dog_ratings (visit_id, dog_id, score, note)
select v.id, d.id, x.score, x.note from (values
  ('2026-02-06'::date, 5, null),
  ('2025-12-19'::date, 5, 'Sores all over her body, visible when the dryer lifts the fur. Skin irritation; was very gentle and careful with my tools when combing and dematting.'),
  ('2025-09-29'::date, 5, null),
  ('2025-07-24'::date, 5, 'Heavily matted next to her skin. The most work I have done on any dog in a long time.'),
  ('2025-06-09'::date, 5, null),
  ('2025-04-28'::date, 5, null),
  ('2025-03-08'::date, 5, null),
  ('2025-01-26'::date, 5, null),
  ('2024-11-25'::date, 5, null)
) as x(d, score, note)
join public.clients c on c.name='Kevin Cummings'
join public.dogs d on d.client_id=c.id and d.name='Molly'
join public.visits v on v.client_id=c.id and v.visited_at::date=x.d
on conflict (visit_id, dog_id) do update set score=excluded.score, note=excluded.note;

-- Lexi
insert into public.visit_dog_ratings (visit_id, dog_id, score, note)
select v.id, d.id, x.score, x.note from (values
  ('2025-12-19'::date, 3, null),
  ('2025-09-29'::date, 5, null),
  ('2025-07-24'::date, 5, null),
  ('2025-06-09'::date, 5, null),
  ('2025-04-28'::date, 5, null),
  ('2025-03-08'::date, 5, null),
  ('2025-01-26'::date, 3, null),
  ('2024-11-25'::date, 5, null)
) as x(d, score, note)
join public.clients c on c.name='Kevin Cummings'
join public.dogs d on d.client_id=c.id and d.name='Lexi'
join public.visits v on v.client_id=c.id and v.visited_at::date=x.d
on conflict (visit_id, dog_id) do update set score=excluded.score, note=excluded.note;

-- Izzie
insert into public.visit_dog_ratings (visit_id, dog_id, score, note)
select v.id, d.id, x.score, x.note from (values
  ('2026-02-06'::date, 5, null),
  ('2025-12-19'::date, 2, 'Uncooperative.'),
  ('2025-09-29'::date, 5, null),
  ('2025-07-24'::date, 5, null),
  ('2025-06-09'::date, 4, null),
  ('2025-04-28'::date, 5, null),
  ('2025-03-08'::date, 5, 'Left ear looks red and gunky.'),
  ('2024-11-25'::date, 5, null),
  ('2024-10-18'::date, 4, null)
) as x(d, score, note)
join public.clients c on c.name='Kevin Cummings'
join public.dogs d on d.client_id=c.id and d.name='Izzie'
join public.visits v on v.client_id=c.id and v.visited_at::date=x.d
on conflict (visit_id, dog_id) do update set score=excluded.score, note=excluded.note;

-- Ace (moved to Tampa; history kept)
insert into public.visit_dog_ratings (visit_id, dog_id, score, note)
select v.id, d.id, x.score, x.note from (values
  ('2025-12-18'::date, 5, 'Extra super good.'),
  ('2025-09-29'::date, 5, null),
  ('2025-07-24'::date, 5, null),
  ('2025-06-09'::date, 5, null),
  ('2025-04-28'::date, 5, null),
  ('2025-03-08'::date, 5, null),
  ('2025-01-26'::date, 3, null),
  ('2024-11-25'::date, 5, null),
  ('2024-10-18'::date, 5, null)
) as x(d, score, note)
join public.clients c on c.name='Kevin Cummings'
join public.dogs d on d.client_id=c.id and d.name='Ace'
join public.visits v on v.client_id=c.id and v.visited_at::date=x.d
on conflict (visit_id, dog_id) do update set score=excluded.score, note=excluded.note;

-- Kage (moved to Tampa; history kept)
insert into public.visit_dog_ratings (visit_id, dog_id, score, note)
select v.id, d.id, x.score, x.note from (values
  ('2025-12-18'::date, 2, 'The opposite of how good Ace was. Skin a little bit flaky.'),
  ('2025-09-29'::date, 3, null),
  ('2025-07-24'::date, 5, null),
  ('2025-06-09'::date, 3, null),
  ('2025-04-28'::date, 3, null),
  ('2025-03-08'::date, 5, null),
  ('2025-01-26'::date, 2, null),
  ('2024-11-25'::date, 2, 'Laid flat and refused to stand. Very difficult to handle and took extra long to dry him.'),
  ('2024-10-18'::date, 3, 'Wants to lay flat the whole time; makes it difficult to dry him.')
) as x(d, score, note)
join public.clients c on c.name='Kevin Cummings'
join public.dogs d on d.client_id=c.id and d.name='Kage'
join public.visits v on v.client_id=c.id and v.visited_at::date=x.d
on conflict (visit_id, dog_id) do update set score=excluded.score, note=excluded.note;

-- Visit-level note (the wet-dogs / vet incident)
update public.visits set visit_notes = 'Erin said the dogs were left wet last time and had to go to the vet for medication for itchy skin. I asked her to confirm all the dogs were dry when I brought them back this time.'
where client_id=(select id from public.clients where name='Kevin Cummings') and visited_at::date='2025-12-18';
