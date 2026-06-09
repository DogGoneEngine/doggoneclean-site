-- 0126_visit_history_donna_rodriquez.sql
-- Visit-history migration for Donna Rodriquez / Chris Votos household. Maggie
-- (Labradoodle, about 10, declining) carries the aging story: the large side tumor
-- removed, her growing unsteadiness on the wood floors. Jax (the other Labradoodle)
-- was put to sleep in September 2022 with spine cancer and is added as deceased
-- (lose-nothing). Maggie's birthday set approximate from "will be 10 in Sept 2024".
-- Score + note attached to the existing time_is_money visit by date; an undated
-- "Maggie. 5" entry maps to 2024-01-10. Pre-import entries (before 2023-08-09) are
-- source='contact_sheet'. See visit_history_migration + time_is_money_is_source_of_truth.

insert into public.dogs (client_id, name, breed, roster_status, notes)
select c.id, 'Jax', 'Labradoodle', 'deceased', 'Deceased September 2022 (spine cancer; put to sleep).'
from public.clients c where c.name='Donna Rodriquez'
and not exists (select 1 from public.dogs d where d.client_id=c.id and d.name='Jax');

update public.dogs set birth_date='2014-09-01', dob_approximate=true
where name='Maggie' and client_id=(select id from public.clients where name='Donna Rodriquez')
  and birth_date is null;

insert into public.visit_dog_ratings (visit_id, dog_id, score, note)
select v.id, d.id, x.score, x.note from (values
  ('2026-03-07'::date, 5, null),
  ('2026-01-12'::date, 5, null),
  ('2025-11-14'::date, 5, null),
  ('2025-09-20'::date, 5, null),
  ('2025-06-13'::date, 5, 'They are still talking about making sure I do her nails and pads because she slips on the floors. She is getting generally unstable; the nails and pads are not the main problem. Chris is having surgery soon, should be done before the next appointment.'),
  ('2025-04-04'::date, 5, 'She has had the large tumor removed from her side and seems to be doing a lot better. Donna mentioned her nails and the hair between the pads of her feet, and that she has been sleeping all over the wood floors. I took care of that as usual, but I am observing that Maggie may be generally unsteady regardless of her feet.'),
  ('2025-02-07'::date, 5, 'Large growth on her side is getting a lot worse.'),
  ('2024-12-12'::date, 5, null),
  ('2024-10-17'::date, 5, 'Extra dirty. Anal glands seemed full but squeezing did not release them, so I left them.'),
  ('2024-08-22'::date, 5, null),
  ('2024-06-27'::date, 5, null),
  ('2024-05-02'::date, 5, null),
  ('2024-03-07'::date, 5, null),
  ('2024-01-10'::date, 5, null),
  ('2023-09-21'::date, 4, null),
  ('2023-08-09'::date, 4, null)
) as x(d, score, note)
join public.clients c on c.name='Donna Rodriquez'
join public.dogs d on d.client_id=c.id and d.name='Maggie'
join public.visits v on v.client_id=c.id and v.visited_at::date=x.d
on conflict (visit_id, dog_id) do update set score=excluded.score, note=excluded.note;

-- Pre-import orphans (before 2023-08-09)
insert into public.visits (client_id, visited_at, service_type, source, external_id)
select c.id, x.ts, 'full_groom', 'contact_sheet', x.ext
from (values
  ('2023-06-28T12:00:00Z'::timestamptz, 'donnar-2023-06-28'),
  ('2023-05-20T12:00:00Z'::timestamptz, 'donnar-2023-05-20'),
  ('2023-03-22T12:00:00Z'::timestamptz, 'donnar-2023-03-22'),
  ('2023-01-31T12:00:00Z'::timestamptz, 'donnar-2023-01-31'),
  ('2022-12-14T12:00:00Z'::timestamptz, 'donnar-2022-12-14'),
  ('2022-11-02T12:00:00Z'::timestamptz, 'donnar-2022-11-02'),
  ('2022-09-21T12:00:00Z'::timestamptz, 'donnar-2022-09-21'),
  ('2022-07-01T12:00:00Z'::timestamptz, 'donnar-2022-07-01')
) as x(ts, ext)
join public.clients c on c.name='Donna Rodriquez'
on conflict (source, external_id) where external_id is not null do nothing;

update public.visits set visit_notes='Donna said she just got rid of the cleaning lady because everything is getting expensive.'
where source='contact_sheet' and external_id='donnar-2022-11-02';
update public.visits set visit_notes='Jax had cancer in his spine and was put to sleep. Chris was on the couch with a new knee replacement.'
where source='contact_sheet' and external_id='donnar-2022-09-21';

insert into public.visit_dog_ratings (visit_id, dog_id, score, note)
select v.id, d.id, null, x.note
from (values
  ('donnar-2023-06-28', 'Great.'),
  ('donnar-2023-05-20', 'Good.'),
  ('donnar-2023-03-22', 'Great dog.'),
  ('donnar-2023-01-31', 'Great dog.'),
  ('donnar-2022-12-14', 'Good dog.'),
  ('donnar-2022-11-02', 'Good.'),
  ('donnar-2022-09-21', 'Good dog. Used shampoo that Donna provided.'),
  ('donnar-2022-07-01', 'Only Maggie today; Jax had ear infections.')
) as x(ext, note)
join public.visits v on v.source='contact_sheet' and v.external_id=x.ext
join public.clients c on c.id=v.client_id and c.name='Donna Rodriquez'
join public.dogs d on d.client_id=c.id and d.name='Maggie'
on conflict (visit_id, dog_id) do update set note=excluded.note;
