-- 0018_generalize_for_legacy_fold.sql
-- Generalize the bath_* operational tables to carry any Clean service type
-- (full groom, bath, nails), in-person Square payment, a per-client on-site
-- block time, and explicit recurrence, so legacy clients fold into the one app
-- (legacy_folds_into_v2). Additive and non-destructive: existing bath rows
-- default to service_type 'bath', payment_method 'stripe_card', is_recurring
-- true, so the live bath booking and portal flow is unaffected. The bath_
-- table names are kept on purpose (Option 1); the cosmetic rename is a deferred
-- follow-up because the rules live in these columns and constraints, not names.

-- Recurring relationship: service type, billing method, per-visit block time,
-- arbitrary legacy cadence, and an explicit recurring-versus-on-demand flag.
alter table public.bath_subscriptions
  add column if not exists service_type text not null default 'bath'
    check (service_type in ('full_groom', 'bath', 'nails')),
  add column if not exists payment_method text not null default 'stripe_card'
    check (payment_method in ('stripe_card', 'square_in_person')),
  add column if not exists visit_minutes integer
    check (visit_minutes is null or visit_minutes > 0),
  add column if not exists cadence_days integer
    check (cadence_days is null or cadence_days > 0),
  add column if not exists is_recurring boolean not null default true;

-- The cadence enum was bath-only and NOT NULL. Loosen it so a grooming or nails
-- relationship can express its interval in cadence_days (or be on demand with
-- is_recurring = false) instead of the bath 4wk/2wk/oneoff enum. A NULL cadence
-- still satisfies the existing enum check.
alter table public.bath_subscriptions
  alter column cadence drop not null;

-- Per-appointment service type, actual block duration, and billing method.
-- duration_minutes is the on-site block reserved for this appointment; NULL
-- falls back to the city slot for bath.
alter table public.bath_appointments
  add column if not exists service_type text not null default 'bath'
    check (service_type in ('full_groom', 'bath', 'nails')),
  add column if not exists payment_method text not null default 'stripe_card'
    check (payment_method in ('stripe_card', 'square_in_person')),
  add column if not exists duration_minutes integer
    check (duration_minutes is null or duration_minutes > 0);

-- Link an operational account to its rich legacy CRM record (clients): hardness,
-- access, availability windows, route zone. NULL for native bath subscribers,
-- set for folded-in legacy clients.
alter table public.bath_subscribers
  add column if not exists client_id uuid references public.clients(id),
  add column if not exists is_legacy boolean not null default false;
