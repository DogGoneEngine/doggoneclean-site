-- 0002_hurricane_bath_v2_schema.sql
--
-- Hurricane Bath v2.0 surface tables. Lives alongside the legacy book
-- (public.clients, public.dogs) which is the operator's route book for
-- doggoneclean.us. These new tables back the hurricanebath.com surface:
-- the portal, the booking flow, and the operator app's view of v2.0
-- subscribers.
--
-- Naming: every v2.0 table is prefixed `bath_` so a future operator UI
-- cannot confuse a Hurricane Bath subscriber (`bath_subscribers`) with
-- a legacy Ocala client (`clients`). `cities` is shared (a city is a
-- city), but only Hurricane Bath columns are populated on cities today.
--
-- Locked rules this schema serves:
--   bath_only_no_mats              -> bath_dogs.coat_tier check
--   villages_only_at_launch        -> cities.polygon + active flag
--   three_dog_cap                  -> bath_appointments.dog_count check
--   premium_inclusive_no_addons    -> bath_appointments.amount_cents only
--   breed_tier_pricing             -> cities.hb_*_recurring_cents + tier on dog
--   cadence_4wk_or_2wk_same_price  -> bath_subscriptions.cadence check
--   single_oneoff_higher           -> cadence='oneoff'
--   tiered_founders_rate           -> bath_subscriptions.is_founders +
--                                     founders_locked_until + city.hb_founders_*
--   card_on_file_at_signup         -> bath_subscriptions.stripe_payment_method_id
--   auto_charge_at_24h             -> bath_appointments.charged_at + payment_status
--   within_24h_non_refundable      -> enforced at RPC layer (deferred)
--   no_show_pause_at_two           -> bath_subscriptions.consecutive_no_shows
--   one_free_skip_per_52w          -> bath_subscriptions.last_skip_at
--   paid_skip_resets_*             -> bath_subscriptions.last_skip_priced_at
--   reschedule_step_up_weekly      -> bath_appointments.original_scheduled_start
--   founders_spots_remaining_counter -> public read mechanism on
--                                       bath_subscriptions (deferred to
--                                       the counter wire-up slice)
--   specialist_assigned_per_route  -> routes/operators model deferred
--                                     to the operator-app chapter
--
-- RLS: every table has RLS enabled. The legacy approach (service-role-only
-- with no policy) gave way here to per-user policies so the portal can
-- read/write a signed-in subscriber's own data via Supabase auth. The
-- key principle: a row's `auth_user_id` (or its chain back to one) is
-- the gate. Anon has read on `cities` only (the public site needs the
-- service-area polygon and pricing); no anon access elsewhere.

-- ── cities ────────────────────────────────────────────────────────────
CREATE TABLE public.cities (
  id                              uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  slug                            text        UNIQUE NOT NULL,
  name                            text        NOT NULL,
  state                           text        NOT NULL,
  -- Polygon as JSONB: array of rings, each ring an array of [lng, lat] pairs.
  -- Empty array until Paul provides the real polygon (real_data_only).
  polygon                         jsonb       NOT NULL DEFAULT '[]'::jsonb,
  center_lat                      numeric,
  center_lng                      numeric,
  -- Hurricane Bath pricing in cents. NULL on cities without v2.0 yet.
  hb_smoothcoat_recurring_cents   integer     CHECK (hb_smoothcoat_recurring_cents IS NULL OR hb_smoothcoat_recurring_cents >= 0),
  hb_smoothcoat_single_cents      integer     CHECK (hb_smoothcoat_single_cents IS NULL OR hb_smoothcoat_single_cents >= 0),
  hb_doublecoat_recurring_cents   integer     CHECK (hb_doublecoat_recurring_cents IS NULL OR hb_doublecoat_recurring_cents >= 0),
  hb_doublecoat_single_cents      integer     CHECK (hb_doublecoat_single_cents IS NULL OR hb_doublecoat_single_cents >= 0),
  hb_addon_decrement_cents        integer     NOT NULL DEFAULT 2000 CHECK (hb_addon_decrement_cents >= 0),
  hb_founders_smoothcoat_cents    integer     CHECK (hb_founders_smoothcoat_cents IS NULL OR hb_founders_smoothcoat_cents >= 0),
  hb_founders_doublecoat_cents    integer     CHECK (hb_founders_doublecoat_cents IS NULL OR hb_founders_doublecoat_cents >= 0),
  hb_founders_cap                 integer     NOT NULL DEFAULT 25 CHECK (hb_founders_cap > 0),
  -- True when Hurricane Bath is open for signup in this city.
  hb_active                       boolean     NOT NULL DEFAULT false,
  created_at                      timestamptz NOT NULL DEFAULT now(),
  updated_at                      timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX cities_slug_idx ON public.cities(slug);
CREATE INDEX cities_hb_active_idx ON public.cities(hb_active) WHERE hb_active = true;

ALTER TABLE public.cities ENABLE ROW LEVEL SECURITY;

-- Public read: the homepage and /the-villages need polygon + pricing to
-- run the address check and render prices. No PII here.
CREATE POLICY cities_anon_read ON public.cities
  FOR SELECT
  TO anon, authenticated
  USING (true);


-- ── bath_subscribers ──────────────────────────────────────────────────
-- The Hurricane Bath end-user. One row per signed-in client. Joined to
-- auth.users via auth_user_id, which is the RLS gate.
CREATE TABLE public.bath_subscribers (
  id                          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  -- The Supabase auth user. Unique so one auth identity maps to one
  -- subscriber row. ON DELETE SET NULL preserves the subscriber row
  -- (and its appointment history) if the auth user is purged.
  auth_user_id                uuid        UNIQUE REFERENCES auth.users(id) ON DELETE SET NULL,
  first_name                  text,
  last_name                   text,
  email                       text,
  -- Phone in E.164 (+15551234567), the format Supabase phone auth uses.
  phone_e164                  text,
  -- Service address (where the trailer parks).
  address_line_1              text,
  address_city                text,
  address_state               text,
  address_zip                 text,
  service_lat                 numeric,
  service_lng                 numeric,
  city_id                     uuid        REFERENCES public.cities(id),
  -- Stripe customer (created at first SetupIntent per card_on_file_at_signup).
  stripe_customer_id          text        UNIQUE,
  -- Notification preferences. SMS default-on so reminders + heads-up go.
  -- Client can flip off in the portal's Notifications section.
  sms_opt_in                  boolean     NOT NULL DEFAULT true,
  email_opt_in                boolean     NOT NULL DEFAULT true,
  -- Test client flag for pre-launch Stripe-skip path (matches DGN pattern).
  is_test                     boolean     NOT NULL DEFAULT false,
  -- Welcome Back trigger basis: set whenever the client confirms their
  -- profile. NULL until first confirmation.
  last_profile_confirmed_at   timestamptz,
  created_at                  timestamptz NOT NULL DEFAULT now(),
  updated_at                  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX bath_subscribers_auth_user_idx ON public.bath_subscribers(auth_user_id);
CREATE INDEX bath_subscribers_city_idx ON public.bath_subscribers(city_id);
CREATE INDEX bath_subscribers_phone_idx ON public.bath_subscribers(phone_e164);
CREATE INDEX bath_subscribers_email_idx ON public.bath_subscribers(email);

ALTER TABLE public.bath_subscribers ENABLE ROW LEVEL SECURITY;

-- A signed-in user can read their own subscriber row.
CREATE POLICY bath_subscribers_self_read ON public.bath_subscribers
  FOR SELECT
  TO authenticated
  USING (auth_user_id = auth.uid());

-- A signed-in user can update their own subscriber row. RPC layer will
-- restrict which columns are settable (e.g. never auth_user_id or
-- stripe_customer_id from client code). For now the policy gates by row.
CREATE POLICY bath_subscribers_self_update ON public.bath_subscribers
  FOR UPDATE
  TO authenticated
  USING (auth_user_id = auth.uid())
  WITH CHECK (auth_user_id = auth.uid());


-- ── bath_dogs ─────────────────────────────────────────────────────────
-- A subscriber's dogs. Coat tier drives pricing (breed_tier_pricing).
CREATE TABLE public.bath_dogs (
  id              uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  subscriber_id   uuid        NOT NULL REFERENCES public.bath_subscribers(id) ON DELETE CASCADE,
  name            text        NOT NULL,
  breed           text,
  -- Tier per breed_tier_pricing. NULL until classified (eligibility check).
  coat_tier       text        CHECK (coat_tier IS NULL OR coat_tier = ANY (ARRAY['smoothcoat'::text, 'doublecoat'::text, 'not_accepted'::text])),
  birth_date      date,
  -- True when the client only knows the approximate birth date (used in
  -- the portal's age display: "~3 years" rather than "3 years").
  dob_approximate boolean     NOT NULL DEFAULT false,
  behavior_notes  text,
  -- Pack flag: a dog marked gone is preserved for history but hidden
  -- from active views and the dog_count cap.
  active          boolean     NOT NULL DEFAULT true,
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX bath_dogs_subscriber_idx ON public.bath_dogs(subscriber_id);
CREATE INDEX bath_dogs_active_subscriber_idx ON public.bath_dogs(subscriber_id) WHERE active = true;

ALTER TABLE public.bath_dogs ENABLE ROW LEVEL SECURITY;

-- A signed-in user can do full CRUD on dogs belonging to their own
-- subscriber row. Insert path has WITH CHECK because subscriber_id is
-- not derivable from the user's existing rows.
CREATE POLICY bath_dogs_self_read ON public.bath_dogs
  FOR SELECT
  TO authenticated
  USING (subscriber_id IN (SELECT id FROM public.bath_subscribers WHERE auth_user_id = auth.uid()));

CREATE POLICY bath_dogs_self_insert ON public.bath_dogs
  FOR INSERT
  TO authenticated
  WITH CHECK (subscriber_id IN (SELECT id FROM public.bath_subscribers WHERE auth_user_id = auth.uid()));

CREATE POLICY bath_dogs_self_update ON public.bath_dogs
  FOR UPDATE
  TO authenticated
  USING (subscriber_id IN (SELECT id FROM public.bath_subscribers WHERE auth_user_id = auth.uid()))
  WITH CHECK (subscriber_id IN (SELECT id FROM public.bath_subscribers WHERE auth_user_id = auth.uid()));

CREATE POLICY bath_dogs_self_delete ON public.bath_dogs
  FOR DELETE
  TO authenticated
  USING (subscriber_id IN (SELECT id FROM public.bath_subscribers WHERE auth_user_id = auth.uid()));


-- ── bath_subscriptions ────────────────────────────────────────────────
-- One row per active or historical subscription. The 24-rule pack lives
-- here (cadence, pricing baseline, founders, skip counters, no-show
-- counter, status).
CREATE TABLE public.bath_subscriptions (
  id                              uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  -- One active subscription per subscriber. (Historical cancelled rows
  -- may also exist; the UNIQUE constraint is partial on status='active'.)
  subscriber_id                   uuid        NOT NULL REFERENCES public.bath_subscribers(id) ON DELETE CASCADE,
  city_id                         uuid        NOT NULL REFERENCES public.cities(id),
  -- Cadence per cadence_4wk_or_2wk_same_price + single_oneoff_higher.
  cadence                         text        NOT NULL CHECK (cadence = ANY (ARRAY['4wk'::text, '2wk'::text, 'oneoff'::text])),
  -- First-dog price for this subscription, in cents. Snapshot at signup
  -- so a city price change does not silently move an existing sub's rate.
  base_price_cents                integer     NOT NULL CHECK (base_price_cents >= 0),
  additional_dog_decrement_cents  integer     NOT NULL DEFAULT 2000 CHECK (additional_dog_decrement_cents >= 0),
  -- Founders flag + lock-until per tiered_founders_rate.
  is_founders                     boolean     NOT NULL DEFAULT false,
  founders_locked_until           date,
  -- Stripe payment method (one card on file per sub) per card_on_file_at_signup.
  stripe_payment_method_id        text,
  -- Skip tracking per one_free_skip_per_52w + paid_skip_resets_*.
  last_skip_at                    timestamptz,
  last_skip_priced_at             text        CHECK (last_skip_priced_at IS NULL OR last_skip_priced_at = ANY (ARRAY['maintenance'::text, 'single'::text])),
  -- No-show counter per no_show_pause_at_two.
  consecutive_no_shows            integer     NOT NULL DEFAULT 0 CHECK (consecutive_no_shows >= 0),
  -- Lifecycle.
  status                          text        NOT NULL DEFAULT 'active' CHECK (status = ANY (ARRAY['active'::text, 'paused'::text, 'cancelled'::text])),
  paused_at                       timestamptz,
  paused_reason                   text        CHECK (paused_reason IS NULL OR paused_reason = ANY (ARRAY['no_shows'::text, 'card_expired'::text, 'self'::text])),
  cancelled_at                    timestamptz,
  started_at                      timestamptz NOT NULL DEFAULT now(),
  created_at                      timestamptz NOT NULL DEFAULT now(),
  updated_at                      timestamptz NOT NULL DEFAULT now()
);

-- One active subscription per subscriber (cancelled rows allowed alongside).
CREATE UNIQUE INDEX bath_subscriptions_one_active_per_subscriber
  ON public.bath_subscriptions(subscriber_id)
  WHERE status IN ('active', 'paused');

CREATE INDEX bath_subscriptions_city_idx ON public.bath_subscriptions(city_id);
CREATE INDEX bath_subscriptions_founders_active_idx
  ON public.bath_subscriptions(city_id)
  WHERE is_founders = true AND status IN ('active', 'paused');
CREATE INDEX bath_subscriptions_status_idx ON public.bath_subscriptions(status);

ALTER TABLE public.bath_subscriptions ENABLE ROW LEVEL SECURITY;

-- Read: a signed-in user can see their own subscription rows (active or historical).
CREATE POLICY bath_subscriptions_self_read ON public.bath_subscriptions
  FOR SELECT
  TO authenticated
  USING (subscriber_id IN (SELECT id FROM public.bath_subscribers WHERE auth_user_id = auth.uid()));

-- No direct INSERT/UPDATE/DELETE from authenticated. Subscription
-- mutations go through SECURITY DEFINER RPCs (start, pause, resume,
-- cancel, skip, reschedule) that enforce the rule pack and write
-- atomically. RPCs land in their own slice.


-- ── bath_appointments ─────────────────────────────────────────────────
-- One row per scheduled visit. Status drives the operator app and the
-- portal day-of UX. Pricing snapshot frozen at booking time so a city
-- price change does not retro-edit an old invoice.
CREATE TABLE public.bath_appointments (
  id                          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  subscriber_id               uuid        NOT NULL REFERENCES public.bath_subscribers(id) ON DELETE CASCADE,
  -- NULL when this is a one-off visit not tied to a subscription.
  subscription_id             uuid        REFERENCES public.bath_subscriptions(id) ON DELETE SET NULL,
  scheduled_start             timestamptz NOT NULL,
  scheduled_end               timestamptz,
  -- Per three_dog_cap.
  dog_count                   integer     NOT NULL DEFAULT 1 CHECK (dog_count >= 1 AND dog_count <= 3),
  -- Pricing snapshot at booking time, in cents.
  amount_cents                integer     NOT NULL CHECK (amount_cents >= 0),
  -- Status: matches DGN's UPCOMING_STATUSES set used by the portal.
  status                      text        NOT NULL DEFAULT 'requested' CHECK (status = ANY (ARRAY['requested'::text, 'confirmed'::text, 'on_the_way'::text, 'on_site'::text, 'in_service'::text, 'completed'::text, 'no_show'::text, 'cancelled'::text, 'skipped'::text])),
  -- Payment lifecycle per auto_charge_at_24h + within_24h_non_refundable.
  payment_status              text        NOT NULL DEFAULT 'pending' CHECK (payment_status = ANY (ARRAY['pending'::text, 'charged'::text, 'failed'::text, 'refunded'::text, 'not_applicable'::text])),
  stripe_payment_intent_id    text,
  charged_at                  timestamptz,
  -- For reschedule_step_up_weekly: distance from original drives the price.
  original_scheduled_start    timestamptz,
  notes                       text,
  created_at                  timestamptz NOT NULL DEFAULT now(),
  updated_at                  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX bath_appointments_subscriber_idx ON public.bath_appointments(subscriber_id);
CREATE INDEX bath_appointments_subscription_idx ON public.bath_appointments(subscription_id);
CREATE INDEX bath_appointments_scheduled_start_idx ON public.bath_appointments(scheduled_start);
CREATE INDEX bath_appointments_status_idx ON public.bath_appointments(status);
-- Hot index for the charge-appointment cron: pending visits within 24h.
CREATE INDEX bath_appointments_charge_candidates_idx
  ON public.bath_appointments(scheduled_start)
  WHERE status IN ('requested', 'confirmed') AND payment_status = 'pending';

ALTER TABLE public.bath_appointments ENABLE ROW LEVEL SECURITY;

-- Read: a signed-in user can see their own appointment history.
CREATE POLICY bath_appointments_self_read ON public.bath_appointments
  FOR SELECT
  TO authenticated
  USING (subscriber_id IN (SELECT id FROM public.bath_subscribers WHERE auth_user_id = auth.uid()));

-- No direct write. Appointment mutations go through RPCs (book, cancel,
-- skip, reschedule, charge) so the 24-rule pack is enforced atomically.


-- ── updated_at triggers ───────────────────────────────────────────────
-- Auto-bump updated_at on every UPDATE. One function shared by all tables.
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

CREATE TRIGGER cities_set_updated_at BEFORE UPDATE ON public.cities
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
CREATE TRIGGER bath_subscribers_set_updated_at BEFORE UPDATE ON public.bath_subscribers
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
CREATE TRIGGER bath_dogs_set_updated_at BEFORE UPDATE ON public.bath_dogs
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
CREATE TRIGGER bath_subscriptions_set_updated_at BEFORE UPDATE ON public.bath_subscriptions
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
CREATE TRIGGER bath_appointments_set_updated_at BEFORE UPDATE ON public.bath_appointments
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


-- ── Seed: The Villages (the launch city) ──────────────────────────────
-- Pricing from breed_tier_pricing + tiered_founders_rate.
-- Polygon empty until Paul provides the real boundary (real_data_only).
-- Center is approximate The Villages, FL.
INSERT INTO public.cities (
  slug, name, state,
  center_lat, center_lng,
  hb_smoothcoat_recurring_cents, hb_smoothcoat_single_cents,
  hb_doublecoat_recurring_cents, hb_doublecoat_single_cents,
  hb_addon_decrement_cents,
  hb_founders_smoothcoat_cents, hb_founders_doublecoat_cents,
  hb_founders_cap,
  hb_active
) VALUES (
  'the-villages', 'The Villages', 'FL',
  28.93, -81.99,
  7500, 9500,
  10000, 12000,
  2000,
  5500, 8000,
  25,
  true
);
