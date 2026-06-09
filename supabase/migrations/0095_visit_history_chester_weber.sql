-- 0095_visit_history_chester_weber.sql
-- Visit-history migration for Chester Weber / Ula (Miniature Schnauzer). Ula is
-- the groomed dog; Windsor (Great Dane) only gets occasional nail files with no
-- recorded vibe, so he is not rated here. Score + note attached to the existing
-- time_is_money visit by date; pre-import entries (before 2023-09-10) created as
-- source='contact_sheet'. Blank-score entries skipped. See visit_history_migration
-- + time_is_money_is_source_of_truth.

insert into public.visit_dog_ratings (visit_id, dog_id, score, note)
select v.id, d.id, x.score, x.note
from (values
  ('2026-03-04'::date, 5, null),
  ('2026-01-21'::date, 5, null),
  ('2025-12-09'::date, 5, null),
  ('2025-11-12'::date, 5, null),
  ('2025-10-01'::date, 3, null),
  ('2025-09-03'::date, 5, null),
  ('2025-07-09'::date, 4, 'Looks like someone bit her on top of her head.'),
  ('2025-05-05'::date, 5, null),
  ('2025-04-18'::date, 5, 'Had something like gum or tar that hardened between the pads of one of her front feet. I shaved it out; it must have felt so good to have that cleaned out.'),
  ('2025-03-21'::date, 5, null),
  ('2025-02-28'::date, 3, null),
  ('2025-01-21'::date, 5, null),
  ('2024-11-04'::date, 5, null),
  ('2024-09-20'::date, 3, null),
  ('2024-08-21'::date, 5, null),
  ('2024-04-25'::date, 5, null),
  ('2024-03-06'::date, 5, null),
  ('2024-02-09'::date, 5, null),
  ('2024-01-12'::date, 2, null),
  ('2023-11-20'::date, 4, null),
  ('2023-10-31'::date, 3, null),
  ('2023-10-09'::date, 3, null)
) as x(d, score, note)
join public.clients c on c.name = 'Chester Weber'
join public.dogs d on d.client_id = c.id and d.name = 'Ula'
join public.visits v on v.client_id = c.id and v.visited_at::date = x.d
on conflict (visit_id, dog_id) do update set score = excluded.score, note = excluded.note;

-- Pre-import orphans (before 2023-09-10)
insert into public.visits (client_id, visited_at, service_type, source, external_id)
select c.id, x.ts, 'full_groom', 'contact_sheet', x.ext
from (values
  ('2023-06-15T12:00:00Z'::timestamptz, 'chester-2023-06-15'),
  ('2023-05-19T12:00:00Z'::timestamptz, 'chester-2023-05-19'),
  ('2023-03-17T12:00:00Z'::timestamptz, 'chester-2023-03-17'),
  ('2022-12-02T12:00:00Z'::timestamptz, 'chester-2022-12-02')
) as x(ts, ext)
join public.clients c on c.name = 'Chester Weber'
on conflict (source, external_id) where external_id is not null do nothing;

insert into public.visit_dog_ratings (visit_id, dog_id, score, note)
select v.id, d.id, null, x.note
from (values
  ('chester-2023-06-15', 'Ok.'),
  ('chester-2023-05-19', 'Good.'),
  ('chester-2023-03-17', 'Good.'),
  ('chester-2022-12-02', 'Good.')
) as x(ext, note)
join public.visits v on v.source = 'contact_sheet' and v.external_id = x.ext
join public.clients c on c.id = v.client_id and c.name = 'Chester Weber'
join public.dogs d on d.client_id = c.id and d.name = 'Ula'
on conflict (visit_id, dog_id) do update set note = excluded.note;
