-- 0029_legacy_subscription_fit.sql
-- Make the recurring-service tables fit the legacy full-grooming book so it can
-- migrate off Acuity without distortion.
--   1. cadence_days is the source of truth. The old cadence enum (4wk/2wk/oneoff)
--      cannot express the legacy book (q14..q98), so cadence becomes nullable and
--      legacy rows carry their real frequency in cadence_days.
--   2. Legacy full grooms are priced per dog and per breed (no flat first-dog +
--      decrement), and bath_dogs had nowhere to store that. Add price_cents so each
--      dog carries its own real price; the bath surface leaves it null and keeps
--      using the subscription base price.
alter table public.bath_subscriptions alter column cadence drop not null;

alter table public.bath_dogs
  add column if not exists price_cents integer
  check (price_cents is null or price_cents >= 0);
