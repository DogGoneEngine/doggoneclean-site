-- 0129_cleanup_guest_dogs_to_visit_notes.sql
-- Lose-nothing cleanup: two guest dogs that appeared on existing visits before the
-- lose-nothing rule was set are folded into the visit's notes (they are not the
-- client's own dogs, so they get a visit_note rather than a false dog record):
--   Cynthia Tieche's guest "Stella" (12/24/24 and 11/4/23)
--   Mary Beth Anderson's guest "Benji" (her sister's stray, 12/29/23).
-- See visit_history_migration (the "lose nothing" clause).

update public.visits set visit_notes = 'Also did Stella (a guest dog), a 5; her feet look red and irritated.'
where client_id = (select id from public.clients where name='Cynthia Tieche') and visited_at::date='2024-12-24'
  and visit_notes is null;

update public.visits set visit_notes = 'Also did Stella (a guest dog), a 3.'
where client_id = (select id from public.clients where name='Cynthia Tieche') and visited_at::date='2023-11-04'
  and visit_notes is null;

update public.visits set visit_notes = 'Also did Benji, a 5 (Mary Beth''s sister''s dog, visiting; the sister also has two Chihuahuas, all strays got cheap a week and a half ago). Did a sanitary plus evened out his coat so the long and short hairs match. Very good dog, exceptionally agreeable; acted like he may never have been groomed before but went right along with anything. Used the 7/8 inch comb on his body to even everything out. Charged $65 for Benji.'
where client_id = (select id from public.clients where name='Mary Beth Anderson') and visited_at::date='2023-12-29'
  and visit_notes is null;
