-- 0222_emily_cummings_contact_and_subscriber.sql
-- Follow-up to 0221. Paul supplied Emily Cummings' contact info (phone
-- 352-445-7355, email emily.cummings41305@gmail.com), so Emily is now a complete
-- first-class legacy client rather than a roster-only stub. This mirrors the exact
-- shape every other legacy client carries (a bath_subscribers row + a
-- bath_subscriptions row + a bath_dogs row), using Kevin Cummings' legacy record as
-- the template: full_groom, billed square_in_person (no Stripe card, so the
-- 24-hour auto-charge never touches her), ~6wk cadence, Ocala city.
--
-- Klaus's bath_dogs row is reparented (not recreated) from Kevin's subscriber to
-- Emily's and set active again, so his coat tier, behavior notes, and price move
-- with him. 0221 had parked that row inactive under Kevin; this completes the move.
-- The _sync_dogs_roster_from_bath trigger (0215) is harmless here: it re-asserts
-- Klaus 'regular' under Emily, which he already is.

-- 1. Contact info on Emily's client record; drop the now-filled contact data gap.
update public.clients
   set phone_e164 = '+13524457355',
       email = 'emily.cummings41305@gmail.com',
       data_gaps = array['cadence at the new home unconfirmed (carried ~6wk from the Cummings household)'],
       note = 'Created 2026-06-19: Klaus moved from Kevin & Erin Cummings'' home to their daughter Emily''s. First appointment booked in Acuity (in-app reminders not yet live). Contact info supplied by Paul 2026-06-19.',
       updated_at = now()
 where name = 'Emily Cummings';

-- 2. bath_subscribers row for Emily (mirrors Kevin's legacy subscriber).
insert into public.bath_subscribers
  (client_id, first_name, last_name, email, phone_e164,
   address_line_1, address_city, address_state, address_zip, city_id,
   is_legacy, is_anchor, sms_opt_in, email_opt_in)
select
  (select id from public.clients where name = 'Emily Cummings'),
  'Emily', 'Cummings', 'emily.cummings41305@gmail.com', '+13524457355',
  '8946 SW 69th Terr, Ocala', 'Ocala', 'FL', '34476',
  (select city_id from public.bath_subscribers where client_id = 'c00e9b9f-b25a-4056-8582-b1a755c71d2d' limit 1),
  false, false, true, true
where not exists (
  select 1 from public.bath_subscribers
   where client_id = (select id from public.clients where name = 'Emily Cummings')
);

-- 3. bath_subscriptions row for Emily (Klaus is one dog at $105; in-person Square).
insert into public.bath_subscriptions
  (subscriber_id, city_id, base_price_cents, additional_dog_decrement_cents,
   service_type, payment_method, cadence_days, is_recurring, status)
select
  s.id,
  s.city_id,
  10500, 0,
  'full_groom', 'square_in_person', 42, true, 'active'
from public.bath_subscribers s
join public.clients c on c.id = s.client_id
where c.name = 'Emily Cummings'
  and not exists (
    select 1 from public.bath_subscriptions sub where sub.subscriber_id = s.id
  );

-- 4. Reparent Klaus's bath_dogs row to Emily's subscriber and reactivate it.
update public.bath_dogs bd
   set subscriber_id = (
         select s.id from public.bath_subscribers s
         join public.clients c on c.id = s.client_id
         where c.name = 'Emily Cummings'
       ),
       active = true,
       updated_at = now()
  from public.bath_subscribers ks
 where bd.subscriber_id = ks.id
   and ks.client_id = 'c00e9b9f-b25a-4056-8582-b1a755c71d2d'
   and lower(bd.name) = 'klaus';
