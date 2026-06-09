-- 0115_visit_history_mary_jane_hunt.sql
-- Visit-history migration for Mary Jane Hunt / Caesar (medium mix), Ringo (Cavalier
-- King Charles), Pancho (Havanese). Seasonal client (in Ocala through May). Score +
-- note attached to the existing time_is_money visit by date; the sheet's "3/6/26"
-- maps to the imported 2026-03-05. Covers the readable recent history (2024-01-25
-- through 2026-03-05); the 2023 / early-2024 tail (2023-08-08 through 2024-01-11)
-- sits below the readable part of the sheet and remains a known gap. See
-- visit_history_migration + time_is_money_is_source_of_truth.

-- Pancho
insert into public.visit_dog_ratings (visit_id, dog_id, score, note)
select v.id, d.id, x.score, x.note from (values
  ('2026-03-05'::date, 5, null), ('2026-02-19'::date, 5, null), ('2026-01-22'::date, 5, null),
  ('2026-01-08'::date, 5, null), ('2025-11-26'::date, 5, null), ('2025-11-13'::date, 5, null),
  ('2025-10-30'::date, 5, null), ('2025-05-26'::date, 5, null), ('2025-05-15'::date, 5, null),
  ('2025-05-01'::date, 5, null), ('2025-04-03'::date, 5, null), ('2025-03-20'::date, 5, null),
  ('2025-03-06'::date, 5, null), ('2025-02-20'::date, 5, null), ('2025-02-06'::date, 5, null),
  ('2025-01-23'::date, 5, null), ('2025-01-09'::date, 5, null), ('2024-12-12'::date, 5, null),
  ('2024-11-29'::date, 5, null), ('2024-11-14'::date, 5, null), ('2024-10-31'::date, 5, null),
  ('2024-08-01'::date, 4, null), ('2024-05-16'::date, 5, null), ('2024-02-08'::date, 5, null),
  ('2024-01-25'::date, 5, null)
) as x(d, score, note)
join public.clients c on c.name='Mary Jane Hunt'
join public.dogs d on d.client_id=c.id and d.name='Pancho'
join public.visits v on v.client_id=c.id and v.visited_at::date=x.d
on conflict (visit_id, dog_id) do update set score=excluded.score, note=excluded.note;

-- Ringo
insert into public.visit_dog_ratings (visit_id, dog_id, score, note)
select v.id, d.id, x.score, x.note from (values
  ('2026-03-05'::date, 5, null), ('2026-02-19'::date, 5, null), ('2026-01-22'::date, 5, null),
  ('2025-11-26'::date, 5, null), ('2025-11-13'::date, 5, 'Today was his 10th birthday.'),
  ('2025-10-30'::date, 5, null), ('2025-05-26'::date, 5, null), ('2025-05-15'::date, 5, null),
  ('2025-05-01'::date, 5, null), ('2025-04-03'::date, 5, null), ('2025-03-20'::date, 5, null),
  ('2025-03-06'::date, 5, null), ('2025-02-20'::date, 5, null), ('2025-02-06'::date, 5, null),
  ('2025-01-23'::date, 5, null), ('2025-01-09'::date, 5, null), ('2024-12-12'::date, 5, null),
  ('2024-11-29'::date, 5, null), ('2024-11-14'::date, 5, null), ('2024-10-31'::date, 5, null),
  ('2024-08-01'::date, 5, null), ('2024-05-16'::date, 5, null),
  ('2024-02-08'::date, 5, 'Urine stains on feet; clipped short to remove them.'),
  ('2024-01-25'::date, 5, 'Urine stains on feet; clipped short to remove them.')
) as x(d, score, note)
join public.clients c on c.name='Mary Jane Hunt'
join public.dogs d on d.client_id=c.id and d.name='Ringo'
join public.visits v on v.client_id=c.id and v.visited_at::date=x.d
on conflict (visit_id, dog_id) do update set score=excluded.score, note=excluded.note;

-- Caesar
insert into public.visit_dog_ratings (visit_id, dog_id, score, note)
select v.id, d.id, x.score, x.note from (values
  ('2026-03-05'::date, 5, null), ('2026-02-19'::date, 5, null), ('2026-01-22'::date, 5, null),
  ('2026-01-08'::date, 5, null), ('2025-11-26'::date, 5, null), ('2025-11-13'::date, 5, null),
  ('2025-10-30'::date, 5, null), ('2025-05-26'::date, 5, null), ('2025-05-15'::date, 5, null),
  ('2025-05-01'::date, 5, null), ('2025-04-03'::date, 5, null),
  ('2025-03-20'::date, 5, 'I hit his dewclaw on his back left leg with the clippers; it bled several drops then oozed. Sprayed liquid bandage. It was not bleeding when I took him back in, but I was concerned that if he ran around it could start again and make a mess on the furniture, so I put him in the crate to keep him quiet for a while and told Mary Jane what happened.'),
  ('2025-03-06'::date, 5, null),
  ('2025-02-20'::date, 5, 'New lump near the front left lower side of his neck (touching it in the last photo). Also appears he had surgery since last appointment: a leg is shaved where an IV would go, and his belly is shaved.'),
  ('2025-02-06'::date, 5, null), ('2025-01-23'::date, 5, null), ('2025-01-09'::date, 5, null),
  ('2024-12-12'::date, 5, null), ('2024-11-29'::date, 3, null), ('2024-11-14'::date, 5, null),
  ('2024-10-31'::date, 5, null), ('2024-08-01'::date, 4, null), ('2024-05-16'::date, 5, null),
  ('2024-02-08'::date, 5, null), ('2024-01-25'::date, 5, null)
) as x(d, score, note)
join public.clients c on c.name='Mary Jane Hunt'
join public.dogs d on d.client_id=c.id and d.name='Caesar'
join public.visits v on v.client_id=c.id and v.visited_at::date=x.d
on conflict (visit_id, dog_id) do update set score=excluded.score, note=excluded.note;

update public.visits set visit_notes='$1000 cash with the Christmas card.'
where client_id=(select id from public.clients where name='Mary Jane Hunt') and visited_at::date='2024-11-29';
