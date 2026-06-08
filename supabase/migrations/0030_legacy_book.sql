-- 0030_legacy_book.sql
-- Load the legacy full-grooming book into the recurring-service tables so the
-- schedule runs in the app and Acuity can be dropped. For each STANDING client:
--   * one public.bath_subscribers row, linked by client_id, auth_user_id NULL so
--     bath_claim_legacy_account() (0024) ADOPTS it on first login instead of
--     creating a duplicate;
--   * one active recurring public.bath_subscriptions row carrying the real
--     cadence_days, the service_type mapped onto the 3-value enum, in-person
--     payment, and the per-visit price;
--   * public.bath_dogs from public.dogs, carrying each dog's price_cents.
-- Drives entirely off public.clients/public.dogs (already seeded from
-- clients.json), so there is no name-matching. Idempotent via NOT EXISTS guards.
-- Scope note: at_will (Karen, Garret) and one_off clients are intentionally left
-- out here; they are not the recurring book. Mapping notes: nails_only / nails_only_legacy
-- -> 'nails'; mixed_groom_and_nails (Lisa Prater) -> 'full_groom'. Steve Crandall
-- ($65 for four) and Patty Brown ($45 for two) are bundle-priced (per-dog price
-- unknown), so their visit total is set explicitly rather than summed.
do $$
declare v_city uuid;
begin
  select id into v_city from public.cities where slug = 'ocala';

  insert into public.bath_subscribers (
    client_id, first_name, last_name, email, phone_e164,
    address_line_1, address_city, address_state, address_zip,
    service_lat, service_lng, city_id, sms_opt_in, address_verified)
  select c.id,
         split_part(c.name, ' ', 1),
         nullif(btrim(substr(c.name, length(split_part(c.name, ' ', 1)) + 1)), ''),
         c.email, c.phone_e164,
         c.location_address, 'Ocala', 'FL', c.location_zip,
         c.geo_lat, c.geo_lng, v_city, true, false
  from public.clients c
  where c.roster_group = 'standing' and not c.exclude_from_everything
    and not exists (select 1 from public.bath_subscribers bs where bs.client_id = c.id);

  insert into public.bath_subscriptions (
    subscriber_id, city_id, cadence, cadence_days, service_type, payment_method,
    base_price_cents, additional_dog_decrement_cents, visit_minutes, is_recurring, status)
  select bs.id, v_city, null, c.cadence_days,
         case when c.service_type like 'nails%' then 'nails'
              when c.service_type = 'bath'      then 'bath'
              else 'full_groom' end,
         'square_in_person',
         case c.name
           when 'Steve Crandall' then 6500
           when 'Patty Brown'    then 4500
           else coalesce((select sum(d.price_cents) from public.dogs d where d.client_id = c.id), 0)
         end,
         0, c.visit_minutes, true, 'active'
  from public.bath_subscribers bs
  join public.clients c on c.id = bs.client_id
  where c.roster_group = 'standing'
    and not exists (select 1 from public.bath_subscriptions s where s.subscriber_id = bs.id);

  insert into public.bath_dogs (subscriber_id, name, breed, price_cents, behavior_notes, active)
  select bs.id, d.name, d.breed, d.price_cents, d.notes, true
  from public.bath_subscribers bs
  join public.clients c on c.id = bs.client_id
  join public.dogs   d on d.client_id = c.id
  where c.roster_group = 'standing'
    and not exists (select 1 from public.bath_dogs bd where bd.subscriber_id = bs.id and bd.name = d.name);
end $$;
