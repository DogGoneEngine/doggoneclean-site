-- 0229_karen_anderson_willie_comp_client.sql
-- Paul's mother, Karen Anderson (Willie's owner), becomes a complete first-class
-- comp client. The record existed as a calendar-sourced stub named
-- "Willie (Paul's mom's dog)" with the SW 114th Ct address but no contact info and
-- a leftover TEST RECORD note. Paul supplied her name, email, and phone, and set
-- her comp / no charge (family). Mirrors the legacy-client shape (0222 Emily
-- Cummings): a contact-complete clients row + a bath_subscribers row + a
-- bath_subscriptions row, billed square_in_person at $0 so nothing ever charges her
-- (no Stripe card, and Clean has no auto-charge anyway). Willie's dog price is set
-- to $0 to match. Idempotent: re-running makes no further change.
--
-- The today-noon appointment itself is transactional data (a normal booking, which
-- fires the standard confirmation + reminders), so it is inserted live, not here.

-- 1. Karen's client record: real name, contact info, comp note, cleared stub cruft.
update public.clients
   set name = 'Karen Anderson',
       phone_e164 = '+13528955311',
       email = 'nickersonkaren@gmail.com',
       relationships = array['Paul''s mother'],
       data_gaps = '{}'::text[],
       note = 'Paul''s mother. Comp, no charge (family). Willie is her dog. (Any earlier test photos on file were of Charlie, not Willie.)',
       updated_at = now()
 where id = 'd4d1c957-ccf7-4a16-8637-ff38f4e744a4';

-- 2. Willie's dog price -> $0 (comp), so any booked amount computes to zero.
update public.dogs
   set price_cents = 0, updated_at = now()
 where client_id = 'd4d1c957-ccf7-4a16-8637-ff38f4e744a4';

-- 3. bath_subscribers row for Karen (mirrors the legacy-client shape).
insert into public.bath_subscribers
  (client_id, first_name, last_name, email, phone_e164,
   address_line_1, address_city, address_state, address_zip, city_id,
   is_legacy, is_anchor, sms_opt_in, email_opt_in)
select
  'd4d1c957-ccf7-4a16-8637-ff38f4e744a4',
  'Karen', 'Anderson', 'nickersonkaren@gmail.com', '+13528955311',
  '3885 SW 114th Ct', 'Ocala', 'FL', '34481',
  (select id from public.cities where slug = 'ocala'),
  false, false, true, true
where not exists (
  select 1 from public.bath_subscribers
   where client_id = 'd4d1c957-ccf7-4a16-8637-ff38f4e744a4'
);

-- 4. bath_subscriptions row: comp ($0), full groom, in-person, non-recurring.
insert into public.bath_subscriptions
  (subscriber_id, city_id, base_price_cents, additional_dog_decrement_cents,
   service_type, payment_method, cadence, is_recurring, status)
select
  s.id, s.city_id, 0, 0,
  'full_groom', 'square_in_person', 'oneoff', false, 'active'
from public.bath_subscribers s
where s.client_id = 'd4d1c957-ccf7-4a16-8637-ff38f4e744a4'
  and not exists (
    select 1 from public.bath_subscriptions sub where sub.subscriber_id = s.id
  );
