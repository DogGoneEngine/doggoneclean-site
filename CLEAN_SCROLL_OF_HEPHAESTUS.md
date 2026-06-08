# CLEAN_SCROLL_OF_HEPHAESTUS - Dog Gone Clean build narrative

## Header mandate (discipline for every session)

- **Read this file fully before doing any work.** It carries the decisions that context
  resets would otherwise erase.
- **On "lock it in" (or a clear equivalent), capture immediately and commit.** Write the
  decision to its live home (an Oracle rule, a CLAUDE.md constraint, a record field) and add
  a dated line to the Decisions log below, then run `scripts/check.py` and commit/push the
  same turn. While Paul is still musing, record nothing.
- **Rebuild this file only at end of session, on Paul's explicit instruction**, as a
  polish-and-reconcile pass (dedupe, reorganize, refresh the focus block), not a rescue;
  durability already happened at each lock. Never rewrite it mid-session, and never lose a
  decision in the rebuild.
- **If history and reality disagree, reality wins** and this file is corrected.
- **Dates use Paul's local time (US Eastern), not the container's UTC clock**, which can read a
  day ahead in the evening Eastern. Stamp the decisions log, commits, and doc dates in Eastern;
  when unsure, ask. See `dates_use_local_eastern`.
- Keep the "Current focus / next action" block at the top current, so a session that ends
  abruptly still orients the next one fast.

To resume cold: read CLAUDE.md, then this Scroll, then CLEAN_ORACLE.md.

---

## Current focus / next action

- **Next action (end of 2026-05-29 session):** The `/book` signup funnel is built and on
  `main`: four steps, anonymous (keyed on phone), server-enforced in-area gate (no manual
  path), per-coat pricing, founders cap, returning-client recognition, in the Neural
  Expressive look. Deploy is now gated on `scripts/check.py`. The gate to going live is the
  Stripe card step (needs the Dog Gone Clean test keys for the SetupIntent edge function)
  and real availability data for the slot picker; the Maps autocomplete needs the Google
  Cloud console setting flipped on Paul's side before it renders. See the 2026-05-29
  "continued" entry below for the full session.
- **Direction:** Two businesses in Paul's portfolio. DGN (Dog Gone Nails): new, nails only,
  the Villages, fully separate (own repo `doggonenails-site`). Clean (this repo): the
  existing ~20-year business, one evolving business, a fork of the DGN platform, running on
  TWO URL surfaces during the transition. **Legacy surface** (doggoneclean.us): the
  ~20-year Ocala full-grooming book, continues on Squarespace + Square + Acuity (with the
  scheduler swapped out per `string_of_pearls_is_a_service`) until its own rebuild. **v2.0
  surface** (hurricanebath.com): Dog Gone Clean v2.0, the bath-only, subscription-default
  product, launches in The Villages with Stripe card-on-file at signup. Both surfaces
  carry the Dog Gone Clean brand. Destination: bath only in the Villages by morphing the
  same business; the two surfaces eventually converge as the legacy book winds down. The
  three-business plan was retired as too complicated (it survives in git history, `0c37403`
  and `9ee4aa3`).
- **State:** Branches reconciled into `main` (this commit folds in the Hurricane Bath rule
  pack that lived on a parallel branch). `main` is the single trunk. Clean's own Supabase
  project is LIVE: `dgc-prod`, ref `urebdrosrxejhubpbxsa`, us-east-1, in the shared "Mount
  Olympus" org (the project is the hard line, never `dgn-prod`); the client book is built
  and seeded (`public.clients` 47, `public.dogs` 61), RLS-locked with no policy,
  schema-as-code in `supabase/migrations/`, reproducible seed via `scripts/gen_seed_sql.py`
  from `legacy/data/clients.json`, TS types in `supabase/database.types.ts`. The foundation
  is deep: the prime directive and two decision lenses (`elons_algorithm`, `dig_the_moat`),
  the idea-capture workflow, `the_oracle_journal` absorbed into the Oracle and
  CLEAN_FIELD_MANUAL.md, the live site mined into `marketing/`. The homepage is REBUILT in
  the Neural Expressive look (blue gradient washes and glows, the master logo in
  `public/logo.png`, bath-forward content) and is live at hurricanebath.com as a
  single-page placeholder. A `.claude/settings.json` permission allow-list is in place.
  The Hurricane Bath v2.0 rule pack (24 rules: pricing, skip, reschedule, UX, money) is
  locked in the Oracle, and the `/book` signup funnel now implements its booking slice
  (anonymous booking, server-enforced service-area gate, per-coat pricing, founders cap);
  the Stripe card step is still parked. `scripts/check.py` green and now gates the deploy.
- **Marketing content (in `marketing/`):** the Hurricane Bath hero showcase, the
  power-and-fast-drying showcase, and the origin/brand source (story, taglines, doorstep
  copy). The live site's old "Grooming. No Chaos." hero is recorded there but was rejected.
  Waiting on Paul's real photos and video. Build details stay in CLEAN_FIELD_MANUAL.md, off
  the public page.
- **Site fork: DONE 2026-05-27.** Eight routes live (`/`, `/the-villages`, `/process`,
  `/book`, `/portal`, `/privacy`, `/terms`, `/sms`), Neural Expressive look consistent
  across all of them, zero DGN aesthetic imported. Shipped in six thin slices, all
  merged to `main`. See the 2026-05-27 session entry below for the slice list and
  what each one contained.
- **Hurricane Bath v2.0 schema: DONE 2026-05-27.** Five new tables on `dgc-prod`
  (`cities`, `bath_subscribers`, `bath_dogs`, `bath_subscriptions`,
  `bath_appointments`) with RLS policies, indexes, and updated_at triggers. The
  Villages seeded as the launch city with tiered pricing and the 25-household
  founders cap. Migration: `supabase/migrations/0002_hurricane_bath_v2_schema.sql`.
  Legacy `clients` + `dogs` left untouched; v2.0 tables are prefixed `bath_` so
  a future operator UI cannot confuse a Hurricane Bath subscriber with a legacy
  Ocala client.
- **Portal Phase 1: DONE 2026-05-27.** Real sign-in (Google OAuth + phone OTP +
  email magic link) plus an honest authenticated empty state replacing the
  `/portal` stub. A signed-in user with no `bath_subscribers` row sees "Book
  your first visit to get started"; a subscriber row triggers a placeholder
  dashboard that points at the views landing in Phase 2/3. The booking flow
  chapter creates the first real subscriber rows.
- **Next chapter (Phase 2: data views):** port the read-only portions of DGN's
  `PortalViews.jsx` to Clean. Dashboard (next appointment, card-expiry banners
  per `card_expiry_60_30_7`, status chips), Appointments list and detail, Pack
  view (subscriber's dogs with the smoothcoat/doublecoat tier on each). All
  read-side, no mutations yet; mutations land in Phase 3. The dashboard's
  "your specialist" element uses the `specialist_assigned_per_route` pattern
  once routes/operators exist (deferred to the operator-app chapter).
- **Phase 3 (mutating views):** Stripe card-on-file management (`PaymentSection`),
  Plan section with the two-tap stop sign (`stop_sign_two_taps`), Reschedule
  with `calendar_shows_price_per_date` and the step-up curve, Skip flow
  (`one_free_skip_per_52w` + `paid_skip_resets_next_visit_to_single_rate`),
  Notifications preferences. Each one is its own SECURITY DEFINER RPC plus the
  portal UI that calls it.
- **Hurricane Bath v2.0 booking surface:** still ahead, builds against the
  schema that now exists. Replaces the `/book` stub. Stripe SetupIntent at
  completion (`card_on_file_at_signup`), address polygon check
  (`villages_only_at_launch`), coat eligibility (`bath_only_no_mats`), octane
  cadence picker (`octane_selector_cadence_picker`), three-dog cap selector
  (`three_dog_cap`), breed-tier-priced first dog (`breed_tier_pricing`,
  `tiered_founders_rate`). Creates the first `bath_subscriptions` rows, at
  which point the founders counter on `/the-villages` starts having
  something real to count.
- **String of Pearls scheduler service** (`string_of_pearls_is_a_service`),
  operator app + pizza tracker, then the `business_rules` table mirroring
  the Oracle. All downstream of the booking surface.
- **Needs Paul to unblock the remaining pieces:** (1) create the Dog Gone Clean Stripe
  account (separate from any DGN/personal account per `own_infrastructure`) and hand
  over the publishable + secret keys (gates the Hurricane Bath booking flow, the chapter
  after the site fork); (2) Clean's own Twilio account, number, and A2P registration
  (SMS + phone login). DONE: `dgc-prod` keys + DB password; Google Cloud Maps key +
  Google sign-in; the deploy publishes to hurricanebath.com (confirmed live); DGN repo
  access granted 2026-05-27 (the fork is unblocked). Also supplies only Paul can give:
  real photos/video for the showcases, a photo of Paul for the city page specialist
  section, and starting the review-gathering. Repo housekeeping is DONE: GitHub default
  branch is `main`, all stale `claude/*` branches deleted (2026-05-26).
- **Moat backlog (parked, do now, not website-gated):** gather Google reviews from
  grateful long-time clients, build an owned before/after photo and video library, start a
  per-appointment data log, keep feeding the Oracle and field manual, and protect the
  Hurricane Bath name. See CLEAN_PARKING_LOT.md.
- **Open questions:** Peter Moran cadence (~8 vs ~12wk); Lisa Irwin current home vs office
  address; Terri McDonnell works-from-home; Mary Beth's Theo breed; Patty Brown availability;
  Chester bearing from base; whether Paul's FL/GA travel constrains the Clean route.

---

## Phase map

- **Phase 1 - Authoritative client records.** DONE. 33 standing + 11 one-off + 2 at-will + 1
  banned in `legacy/data/clients.json`, verified against the current contact sheets. (Path
  moved from `data/` to `legacy/data/` on 2026-05-26 because these records belong to the
  legacy doggoneclean.us surface; the v2.0 surface gets its own subscriber data in Supabase.)
- **Phase 2 - First zone-day route template.** DRAFTED (`legacy/data/route_template.md`).
  Pending the last cadence lock and a rebalance against corrected stop sizes.
- **Phase 3 - Doc / handoff system + foundation.** DONE. CLAUDE.md + this Scroll +
  CLEAN_ORACLE.md + CLEAN_BUSINESS_RULES.md + CLEAN_PARKING_LOT.md + CLEAN_FIELD_MANUAL.md +
  `scripts/check.py`, plus the prime directive, the two decision lenses, and the
  idea-capture workflow.
- **Phase 4 - Clean website + ops app (fork of the DGN platform).** IN PROGRESS, well underway.
  `dgc-prod` is a real app database: the legacy book in `clients`/`dogs` plus the recurring-service
  tables it was loaded into (`bath_subscribers/subscriptions/appointments/dogs`), `cities`,
  `service_perimeters`, `app_secrets`, `notification_log`, `notification_preferences`, all
  RLS-locked. The Astro site builds and deploys the marketing pages, the `/book` funnel, and the
  `/portal` client portal. Built so far: the Ocala service-area gate (a hand-drawn perimeter ANDed
  with a real Google drive-time check, `ocala-service-area` edge function); the legacy full-grooming
  book loaded into the recurring-service model with real cadence + per-dog prices (migrations
  0029-0030); the Tue-Sat noon-to-8 availability grid (0028); the notification dispatcher
  (`send-notification`, reminders + confirmations in Paul's voice, fail-closed) + `notification_log`
  (0033); and the client reminder-preferences screen (0034 + portal UI). The Hurricane Bath v2.0
  rule pack stays locked in the Oracle. The ACTIVE work is the Acuity + Squarespace teardown
  (`legacy_folds_into_v2`): legacy clients fold into this one app, the calendar is the schedule
  source (import now, two-way sync at cutover), and doggoneclean.us redirects in. The remaining
  build and the cutover order live in CLEAN_PARKING_LOT.md under "Acuity + Squarespace teardown".
  Surface-scoped payments hold: legacy bills in person via Square, Hurricane Bath uses Stripe
  card-on-file. Build details stay in CLEAN_FIELD_MANUAL.md and off the public page.
- **Phase 5 - Later.** Villages bath expansion; route automation and true drive-time as
  density grows; multi-specialist routing (apprentice Jake).

---

## Session history

### 2026-06-08 (photo redo: quality pass after Paul rejected the first cut)

Paul rejected the first photo pass (specialist avatar cropped his face off, a generic 4-up grid
"shoved to the bottom" of the homepage, a dim "sad" shepherd on the Ocala hero) and added a much
better photo (PXL_20210220: him facing camera, white dog on his shoulder, well lit). Redone with
care: (1) specialist avatar recropped from the new photo to cleanly frame Paul's face and enlarged
96px -> 128px; (2) the homepage 4-up grid is deleted and replaced with one strong 16:9 feature image
high on the page (right under the hero) with a caption, the bright white-Pyrenees shot; (3) the Ocala
hero swapped from the dim shepherd to a bright, friendly black-Lab face. Removed the now-unused
trailer-1..4 and the heavy new original from public/photos; only paul-specialist, home-feature,
og-cover, ocala-hero remain (all referenced). Each crop was reviewed by eye before shipping. The
homepage still cannot SSG-verify locally (the-villages egress abort) but compiles and builds in CI.

### 2026-06-08 (real photos wired in: Paul + dogs in the trailer)

Paul uploaded 10 full-size phone photos (him with client dogs in the bath trailer) to the repo's
public/ via GitHub web (the chat-attached images can't transfer as files; the GitHub upload was the
bridge, then the local mirror fast-forwarded to his commit). Pulled them locally, installed sharp
(local only, --no-save, NOT a project dep), generated small previews to view all 10, and chose
placements. Optimized the keepers with sharp (32 MB of originals -> 392 KB of web JPEGs) into
public/photos/, then removed the 10 heavy originals from public/ so they do not deploy. Wired:
paul-specialist.jpg into the Villages specialist card (replacing the "P" initial); og-cover.jpg as
the site-wide Open Graph / Twitter share image (BaseLayout default ogImage, now an absolute URL);
trailer-1..4 into a new "Real dogs, real trailer" strip on the homepage; ocala-hero.jpg into the
Ocala coming-soon hero. Left 3 photos unplaced (dryer shot, rotary-tool pit bull, one yellow Lab)
per Paul's "don't force them". Verified the two key crops by eye (specialist square frames Paul's
face, og cover is bright and landscape) and that the optimized files land in dist/photos. The
homepage HTML can't be SSG-verified locally (the-villages cities fetch aborts the build on the
sandbox egress allowlist, as all session) but all pages compiled and it builds in CI. Note for
later: Clean 2.0 is bath-PLUS (no haircuts), not bath-only, so grooming/nail tools in photos are
fine; the earlier "skip the rotary tool" instinct was from a prior-session misunderstanding Paul
is still sorting out.

### 2026-06-08 (Ocala redone to the real Nails format: cities dropdown, coming-soon page, waitlist)

Corrected the first Ocala pass per Paul. Three fixes: (1) the nav is now a Cities DROPDOWN (desktop)
+ accordion (mobile) mirroring the Nails nav, not two flat links; The Villages is plain, Ocala carries
a "Coming soon" pill. (2) The homepage no longer leads with one city: the hero eyebrow is "Mobile dog
baths, in your driveway" and the service area reads "live in The Villages, coming soon to Ocala". (3)
The Ocala page is rebuilt to the Nails coming-soon city format (hero + waitlist), with ALL full-groom /
legacy / grandfather copy removed; new Ocala clients are bath only and Paul notifies legacy clients
about the new site himself, so that policy stays off public pages. Net-new: a real `waitlist` table
(migration 0039: anon can insert, cannot read; verified via the anon role) backing the Ocala waitlist
form, mirroring the Nails waitlist. The earlier Ocala page (bath offer + a legacy-grandfather section)
is superseded by this coming-soon version.

### 2026-06-08 (Ocala folded in as a served location; blocker list captured)

Two things from Paul. (1) Captured the launch-blocker list (his external setup that gates the v2.0
online path and the cutover) in the parking lot under "Launch blockers": iPostal1 address, Sunbiz
fictitious name, IRS EIN, Relay bank accounts, Twilio, Stripe, with the dependency chain and what
each unblocks. (2) Folded Ocala into the site as a served location, on Paul's direction that the
website reflect Ocala (the legacy site folds into v2.0, like a Pizza Hut that still has a dining
room). New Ocala clients are bath v2.0 only; legacy full-groom clients are grandfathered
(`new_ocala_clients_are_v2_only`). The cities DB row for 'ocala' already existed (polygon, center,
pricing equal to The Villages, hb_active false). Built `src/pages/ocala.astro` (a Clean city page
mirroring the the-villages format, pricing hydrated from the 'ocala' row), surfaced Ocala in the
nav, footer, and homepage service area, and updated the homepage title/meta. Honored the Oracle
gate: Ocala is NOT flipped live for booking (hb_active stays false until the anchor drive-time gate
is wired), so the page presents the offer with new-client booking "opening soon" and routes existing
clients to the portal, rather than a live /book CTA that would dead-end. Resolved the long-open
`villages_only_in_copy` question: it now means served-cities-only (The Villages and Ocala), updated
in the Oracle and the audit (check.py no longer forbids "Ocala"; still forbids the Nails-only cities).
Audit green; ocala.astro builds in CI (it fails the local SSG only on the egress-blocked cities
fetch, exactly like the-villages).

### 2026-06-08 (portal parity with Nails, slice 5: returning-client welcome flow)

Built the returning-client welcome gate (parity with Nails' WelcomeBack). A lapsed client signing
in confirms their service address and pack, then one tap stamps last_profile_confirmed_at and drops
them into the portal. New bath_confirm_profile() RPC (migration 0038, applied + verified, advisor
shows the same intended authenticated-RPC pattern as the other portal RPCs, revoked from anon). New
exported WelcomeBack component in PortalViews reusing the existing AddressEditor and PackSection (one
home per edit), plus confirmProfile() in supabase.js and a staleness gate in PortalApp. CAUGHT a
false-positive while verifying against real data: a naive "no service in a year" check flagged 20 of
33 clients, because their appointment history is not backfilled yet (only this week is loaded) and
last_profile_confirmed_at is null. Fixed the heuristic to NOT gate a client who has zero loaded
appointments (we cannot tell lapsed from un-backfilled), so only a client with a real loaded visit
over a year old is treated as lapsed. With current data 0 clients see the gate (correct: the 13 with
upcoming visits are active, the 20 with no loaded history are not gated); it activates correctly once
appointment history exists. This closes the unblocked portal-parity work: slices 1 (shell), 2-legacy
(payment note), and 5 (welcome) shipped; slices 2-card, 3 (book-a-visit), 4 (tipping) remain gated on
Clean's Stripe account + the live calendar sync.

### 2026-06-08 (portal parity with Nails, slice 2: gated payment section)

Added the Payment section to the Account tab, gated by how the client actually pays so a legacy
client is never shown a card field (Paul's hard requirement). Logic: payment_method !== 'stripe_card'
(legacy square_in_person and any unknown) renders the in-person note ("You pay in person: card, cash,
or mobile wallet via Square. There is no card on file and nothing is charged online."); stripe_card
renders the honest card-on-file state ("On file" charged the day before, or "None yet"). Verified
against the real book: 33 of 34 subscriptions are square_in_person and hit the in-person branch; the
lone stripe_card test sub hits the card branch with "None yet". Builds clean, audit green.

HONEST SCOPE on the rest of the Nails payment surface (see card brand/last4/expiry, update card,
failed-charge + card-expiry banners): NOT buildable as real work yet, and not faked (no_mockups).
Confirmed Clean has no card-detail columns (only stripe_customer_id + stripe_payment_method_id), zero
stored payment methods, and no Stripe edge functions. The full card-management flow is gated on Clean's
own Stripe account (Paul action: create the Dog Gone Clean Stripe account + keys, per clean_stays_saleable)
plus the Stripe wiring (create-setup-intent edge fn, webhook, card columns, Stripe Elements). Parked.
Same Stripe dependency blocks in-portal tipping (parity slice 4); legacy clients tip in person anyway.

### 2026-06-08 (portal parity with Nails, slice 1: tabbed app shell)

Paul's call: the Clean portal should match the Dog Gone Nails portal so Nails has nothing to flex.
Compared the two: Nails is a four-tab app (bottom nav: Home / Appointments / Pack / Account) with a
payment surface (see/update card, failed-charge + expiry banners), tipping, book-a-visit-from-portal,
and a returning-client welcome flow; Clean was a single scrolling page with none of those. Decided to
match fully, in order, starting with the shell. KEY GATING DECISION on payment (Paul raised it): no
legacy client is ever shown a card field. The payment surface gates on payment_method (stripe_card =
bath gets full card management; square_in_person = legacy gets only a short "you pay in person via
Square" note). Slice 1 shipped: restructured PortalHome into a tabbed app (pt-app shell, sticky
pt-topbar, fixed pt-bottomnav with Home/Visits/Pack/Account, inline SVG icons), reusing every existing
section component (VisitActions, CadenceControl, PlanActions, PackSection, ProfileSection,
NotificationsSection) rehomed into tabs. Home = next visit + plan glance; Visits = upcoming + history;
Pack = dogs; Account = plan controls + details + reminders. "two taps" stays in PortalApp.jsx
(audit guard) and the legacy cadence fix is preserved. Verified by clean vite build + reference review;
full visual check needs Paul's device (this env cannot render the authed island). REMAINING parity
slices (in order): payment surface (gated as above), book-a-visit from portal, tipping, returning-client
welcome flow. Tracked in the parking lot.

### 2026-06-08 (portal legacy landmine sweep: clean after the cadence fix)

Swept the whole logged-in legacy experience for bath-only assumptions beyond the cadence one
already fixed. Result: the portal renders correctly and safely for a full-groom, pay-in-person
client. Verified the data-level safety directly: all 61 legacy dogs have coat_tier null and no
birth_date, and coatLabel(null)/ageFromBirthDate(null) both return empty and get filtered out, so
a legacy dog shows just name + breed + notes (no broken or bath-labeled row). Plan/visit actions,
the 24-hour lock, reminder labels (3 days / day before / day of), price, status, and history all
render right. Found one genuine bath-ism that does not break anything: the Add-a-dog form forces a
bath coat tier (smooth/double) to save, which is a bath pricing concept inert for full groom. Left
it unchanged because how legacy clients add dogs (and whether coat tier should be optional for them)
is a design call for Paul, not a blind fix; parked it. The empty-state "no Hurricane Bath
subscription / founders rate" copy is bath-only but unreachable for a claimed legacy client (they
have a subscriber row), so it is not a live landmine.

### 2026-06-08 (legal docs rewritten to match Nails, real, no draft hand-waving)

Rewrote privacy.astro, terms.astro, and sms.astro to mirror the Dog Gone Nails legal pages
exactly, stripping the prior session's lazy "this is a draft, final attorney-reviewed copy lands
before launch / contact details land before launch" hand-waving. Differences from Nails are
context-only: dog grooming service (not nails, terminology kept correct per grooming_vocab),
Stripe plus Square in Third Parties (Clean's legacy clients pay in person via Square), the terms
Payment section states both the Hurricane Bath card-on-file model (card on file, charged the day
before at the 24-hour mark, non-refundable inside 24 hours, two-tap cancel, all required by the
audit) and the legacy in-person Square reality, and Clean's domain/contact (service@doggoneclean.us).
Business mailing address is a single labeled drop-in ("[mailing address added after iPostal1
setup]") in both privacy and terms, pending Paul's iPostal1 box next week. This also clears the
real privacy-policy prerequisite for Resend sender verification. Audit passes (the legal-copy
guards: two taps, the day before, 24-hour, non-refundable, card on file, no DGN nail vocab, no
jargon, dog-grooming terminology). One judgment call to confirm: the terms describe payment by
both surfaces rather than Hurricane-Bath-only; flag raised to Paul.

### 2026-06-08 (portal verified for legacy clients: cadence render fix)

Verified item (d) of the teardown checklist: a logged-in legacy client renders correctly in the
portal. Traced the real getPortalData payload for actual legacy subscribers (all 33 are full-groom
or nails, square_in_person, cadence enum null with the real interval in cadence_days). Found one
bath-only defect: the Plan card "Cadence" row called `cadenceLabel(subscription.cadence)`, which is
null for legacy, so it rendered blank. Fixed `cadenceLabel` to take the subscription and fall back
to cadence_days (21 -> "Every 3 weeks", 14 -> "Every 2 weeks"), still backward-compatible with the
bath enum. The rest of the home view is coherent for a full-groom, pay-in-person client: real price
($80 etc.), status, dogs, next visit, history all correct; the founders-rate row and the 4wk/2wk
cadence switcher correctly stay hidden (their guards already handle the legacy case). Data check
across the book: 0 of 33 clients missing a price or cadence, so no $0 or blank rows. Portal island
bundles clean (vite, 77 modules) and the audit passes; the only local build error is the
the-villages SSG cities fetch hitting the sandbox egress allowlist, which is environmental and
unrelated (CI has network).

### 2026-06-08 (reminder cadence corrected to 72/26/6 + 26h wording + a governance rule)

Two corrections and a new rule. (1) The reminder timing was wrong: 0035 fired the three
reminders at ~78h / ~30h / ~14h, but the locked legacy cadence in
`legacy/notifications/email_templates.md` is 72h / 26h / 6h. The day-of reminder ("Today is
the day") is the 6-hours-before message, not 14h. Migration 0037 retimes all three bands onto
72 / 26 / 6 (key names unchanged, so templates and prefs keep working). (2) The 26-hour
reminder's cancellation-policy line was marked [OPEN] in the template doc. Paul settled it: the
legacy 26h reminder DOES state the policy (`lock_in_timing`'s no-mention rule is bath-surface
only), and the line is reworded to lead with the commitment and demote "canceled or
rescheduled" to a trailing clause, so it gives fair warning of the 24h billing lock without
reading as a last-chance prompt that invites cancellations. New copy: "Once your appointment is
inside 24 hours, that time is reserved just for you, and is billed in full even if canceled or
rescheduled." Updated in the deployed `send-notification` (version 3, verified live) and the
template doc; the [OPEN] note is marked RESOLVED. On Paul's call the same reorder was then
applied to the booking confirmation's sister sentence for consistency (deployed version 4).

(3) Captured a governance rule Paul set: `no_unilateral_deviation`. I am never to change an
already-decided thing (locked copy, timing, scope, a standing rule) on my own; if a settled
decision looks wrong, I stop, bring it to Paul with the exact change and my reason, and do
nothing until he says yes. The trigger was my reflex to "improve" his years-settled reminder
copy. Filed in CLEAN_ORACLE.md, indexed in CLEAN_BUSINESS_RULES.md, and added to CLAUDE.md
"How Paul works".

### 2026-06-08 (reminder cron + confirmation trigger: the Acuity gate closed on our side)

Built the hourly reminder engine and the transactional confirmation trigger that
replace what Acuity does, the last build-side gate before Acuity can be cancelled
(migration 0035). pg_cron and pg_net are now enabled on `dgc-prod`. A pg_cron job
`bath-reminders` runs `public.bath_dispatch_reminders()` at the top of every hour;
it sweeps `bath_appointments` in three non-overlapping time bands (reminder_3d at
30-78h out, reminder_26h at 14-30h, reminder_day same Eastern calendar day) and
calls the `send-notification` edge function via `notify_appointment()` (pg_net
http_post, secret + edge URL read from `app_secrets`). The edge function's
unique-on-sent index plus a 6h retry throttle make double-sends impossible. A
trigger `bath_appointment_notify_trg` fires booking_confirmation on insert,
reschedule on a scheduled_start change, and cancellation on a move to
cancelled/skipped. The guard that matters: it fires ONLY for app-native rows
(`source IS NULL`), so a calendar backfill (source 'acuity'/'gcal') can never blast
historical clients; imported rows still get reminders, which is the point.

Verified live against the 13 real upcoming appointments: a manual dispatch fired 7
reminders, the edge function returned 200 for all, rendered the real legacy copy
(client names, dates, time blocks), logged 4 as `resend_not_configured` (clients
with email, ready the instant the Resend key lands) and 3 as `no_recipient_on_file`
(the contact-omitted-intentional clients, gracefully skipped); an immediate re-run
dispatched 0 (dedup/throttle holds). The confirmation trigger was checked with an
insert+self-rollback: app-native queued exactly 1, imported queued 0, nothing left
behind. New config key `edge_base_url` added to `app_secrets`. Advisor regression
from the new trigger function (externally executable SECURITY DEFINER) was closed by
revoking EXECUTE.

Then added the cutover kill-switch (migration 0036) after Paul flagged the
double-send risk: the legacy appointments are already on Acuity's reminder schedule,
so our pipeline must stay silent until Acuity is off. `notify_appointment` (the one
chokepoint both the cron and the trigger pass through) now checks
`app_secrets.notifications_live`; default OFF, so even with the Resend key in place
nothing fires. Verified both ways with rolled-back tests: switch off queues 0,
switch on queues 1. Corrected cutover order: Resend key in -> CANCEL ACUITY ->
flip `notifications_live='true'` -> next hourly cron sends the first real reminders.
Pre-flip verification uses a test appointment (is_test, Paul's email, source NULL,
never in Acuity), never a real Acuity client.

### 2026-05-27 (`post_appointment_show_someone_nudge` captured)

Locked the standard post-appointment SMS nudge for both businesses
(Dog Gone Clean and Dog Gone Nails). Rule lives in CLEAN_ORACLE.md as
`post_appointment_show_someone_nudge` (copy domain) and is mirrored
verbatim into DGN's ORACLE.md (notifications domain) so neither repo
loses it.

**The format.** Every post-appointment client text is two lines, with
photos attached as MMS:

```
[Dog's name] before and after.
Show someone.
```

"Show someone." is the literal second line, two words. The nudge is
deliberately bare: no brand handle, no @-mention, no "tag us" line,
no platform-specific share call, no pre-filled social caption.

**The constraint.** The rule's hard line, identical across DGC and DGN,
is that the message never contains a pre-filled brand handle, an
embedded "@doggoneclean" / "@doggonenails" caption, or a "tag us"
appendage. A future companion share page using the Web Share API is
allowed once each business's Supabase booking pipeline writes
per-appointment photo records, but the share page stays under the
same hard line: no pre-filled brand handles, no embedded captions, no
"tag us" prompt. The helper only removes the steps of saving to
camera roll and opening another app.

**The principle.** The nudge's strategic value lives entirely in
being unprompted. Pre-filling brand handles or appending "tag us"
copy converts organic enthusiasm into a recognizable marketing
channel, which simultaneously destroys the unprompted-word-of-mouth
dynamic and crosses the line from making sharing easy into using the
client as a promotion channel. The honest position is that we want
clients to share these photos and we want to make that easy, and if
it sometimes comes back to the business that is fine because it
arrived without an ask; embedding the ask in the message itself
converts kindness into an ask and collapses the value.

**Phasing.** Effective immediately on Paul's existing post-appointment
send (Google Voice MMS today, Twilio MMS once A2P 10DLC clears). The
share page is parked in CLEAN_PARKING_LOT.md (and PARKING_LOT.md in
the DGN repo) until the photo pipeline lands; the bare two-line MMS
needs none of that and is shipping today.

**Filed in:**
- `CLEAN_ORACLE.md`: new rule `post_appointment_show_someone_nudge` in
  the Copy and terminology section.
- `CLEAN_PARKING_LOT.md`: forward entry under "Portal and subscription
  ideas" for the future share page.
- `CLEAN_BUSINESS_RULES.md`: new index row.
- `doggonenails-site/ORACLE.md`: parallel rule in the Notifications
  section.
- `doggonenails-site/PARKING_LOT.md`: forward entry for the share page.
- `doggonenails-site/BUSINESS_RULES.md`: parallel index row.

### 2026-05-27 (redesign-survival closure)

Closed the remaining six gaps so the rulebook fully survives a major
website redesign. Added six narrowly-scoped lint patterns to
`scripts/check.py`:

- `no_dgn_import`: forbids DGN nail vocab ("rotary tool", "sculpt nails",
  "grind nails") on customer-facing pages.
- `no_jargon`: forbids "reach out", "circle back", "bandwidth", and
  "free up the slot" (the slot-context phrasing, not "free up"
  generally, to avoid tripping on legitimate sentences).
- `reminder_voice`: forbids the banned-phrase list ("friendly
  reminder", "just a reminder", "reaching out", "please be advised",
  "last chance", "make changes now").
- `founders_spots_remaining_counter`: asserts `id="launch-spot-count"`
  present on `/the-villages` (the counter element).
- `supabase_rpc_not_raw_fetch`: forbids `fetch(...SUPABASE_URL...)` in
  `src/components/portal/` (the raw-REST-call pattern). Legitimate
  edge-function calls via the client's `.functions.invoke()` and the
  separate-session-token path do not match this regex.
- `auth_listener_sets_state_only`: paren-matches each
  `onAuthStateChange((...))` block and forbids `.from(`, `.rpc(`,
  `await fetch(`, `loadPortalData(` inside it. The current portal
  separates these (the listener sets state, a useEffect watches auth
  state and calls `loadPortalData()`), so the lint passes.

All 25 customer-facing and engineering rules with site-or-portal
expressions are now build-time enforced. The lint caught zero
false-positives on its first run, confirming the patterns are scoped
narrowly enough not to risk normal operations. `cancellation_24h`
remains the one rule with its lint deferred (its exact-wording
requirement applies to the legacy doggoneclean.us surface that has
not been rebuilt yet).

### 2026-05-27 (`toes_over_the_precipice` captured)

A client-side rule, captured today, prompted by reflection during the
strategy discussion. The incident itself happened 2026-04-24. Rule lives
in the Oracle as `toes_over_the_precipice` (roster).

**The incident.** A 5-year, very profitable client claimed her
"intuitive" dog was distraught for hours after Paul's son was present at
the appointment. Paul did the grooming as he always does; his son never
touched the dog, just stood nearby. No incident, no injury, no rough
handling. The client decided the dog was traumatized by the son's
"energy" and demanded Paul come alone and be supervised in the trailer
going forward.

**Why it ends the relationship.** Stripped of the spiritual framing, the
demand is a plain accusation: the client believes Paul (or anyone
present with him) is a danger to her dog. Mobile dog grooming runs
entirely on being trusted alone with the animal. Once a client holds
that suspicion it never leaves. Every future off-day for the dog
becomes Paul's fault, with no possible defense, because you cannot
disprove something that never happened. Profitability and five-year
tenure do not change this. Revenue hides the risk; it does not cancel
it.

**The rule action.** Do not try to win them back, and do not accept the
supervised-only conditions. Both legitimize the accusation. End the
relationship cleanly.

**The text exchange (primary source, 2026-04-24).**

Client's message:
> Spoke with Scott this morning
> Bitty is a very intuitive dog
> She's was absolutely distraught for hours after your son was here. We
> would feel much more comfortable if these requests work to for you?
> You are only to come alone please.
> One of us will always be in the trailer with you.
> Trim only for Bitty
> Full wash for smudge
> Let me know if that is ok?
> Also please delay next wash by two weeks please
> Thank you

Paul's reply:
> Hi Lynne, I understand what you're asking about Bitty, the next
> appointment, and who comes with me.
> You and Scott have been wonderful clients for a long time. You've
> never felt like just another stop on my route, and taking care of
> Bitty and Smudge has always been a bright spot in my day.
> Before we sort through the details, I think we should first make sure
> Dog Gone Clean is still the right service for you going forward.
> I would be sad to lose you, but I would fully understand if you feel
> another plan would be better for them.

The reply is the textbook execution: warm, no defense (because
defending against a no-cause accusation legitimizes it), no negotiation
of the conditions, the exit framed as the client's choice.

### 2026-05-27 (redesign-survival hardening)

Paul asked the audit question: if a future session does a major website
redesign, what survives and what gets silently wiped out? The honest
answer was that around 19 customer-facing rules had their only live
enforcement in copy on a page I had written, with no lint to catch a
rewrite that dropped them. Eight were "high risk" (no DB backstop) and
eleven were "medium" (DB backstops the rule itself, but the customer
expression on the site relies on copy alone). Three commits to close
this:

1. **Price hydration** (commit `857952c`). `/the-villages` was carrying
   the tier prices and the founders cap as hardcoded literals in a
   `tiers` array at the top of the page, duplicating the values in the
   `cities` row. A price change in the DB would not have propagated.
   New `src/lib/cities.js` does a build-time fetch of the city row;
   the page hydrates `tiers` and `FOUNDERS_CAP` from there. Copy was
   updated to template the cap (`{FOUNDERS_CAP}`) in the eyebrow,
   headline, subhead, and terms-tile. Trade-off: deploys now depend
   on dgc-prod being reachable at build time. Acceptable: the live
   site keeps serving on a build failure, and the same dependency
   exists for the portal already. Live customer behavior unchanged.
   `if_payments_added_handle_money_safely` was the rule the fix
   served (fail loud on missing pricing columns, single source of
   truth for money).

2. **Rule-survival lint, first 8** (commit `e412c18`). Added
   `check_rule_survival()` to `scripts/check.py` covering:
   `villages_only_in_copy`, `founders_cap_statement_always_visible`,
   `single_visit_as_own_path`, `specialist_named_not_promised`,
   `appointment_block_not_window`, `language_bank`,
   `neural_expressive_design` (brand color tokens), and
   `nav_no_backdrop_filter`. Each rule names the file it lives in and
   the pattern that has to stay there. The lint caught two
   false-positives on its first run (my own copy used "arrival
   window" in a negating sentence and a Nav comment mentioned
   "backdrop-filter"); both fixed in the same commit. Verification by
   real-world catch, not synthetic test.

3. **Rule-survival lint, additional 11 + Oracle sharpened**
   (this commit). Added patterns for: `stop_sign_two_taps` (four
   surfaces: home, city, book stub, terms, portal island),
   `auto_charge_at_24h` ("the day before" customer promise),
   `within_24h_non_refundable` ("24 hour" + "non-refundable" on terms),
   `three_dog_cap` ("three dogs" on city + book), `friendly_dogs_only`
   ("friendly dogs" + "aggression" on home + city), `premium_inclusive_
   no_addons` ("no add ons" on city), `cadence_4wk_or_2wk_same_price`
   ("same price" on home), `card_on_file_at_signup` ("card on file" on
   three pages), `core_is_no_haircut_dogs` ("bath only" on city +
   process), `bath_only_no_mats` (tier names + eligibility headers on
   city). The `require_present` helper now defaults to case-insensitive
   matching and normalizes whitespace so multi-word patterns survive
   line wraps in Astro source. Caught three real copy gaps in my own
   pages (terms missed "the day before" framing, process page missed
   "bath only" statement, portal copy was on the React island not the
   route file). All fixed in the same commit. The Oracle's "How to
   add a rule" section was sharpened: lint enforcement lands the same
   commit as the rule by default, not as a later step. The previous
   practice of "land the rule now, defer the lint" repeatedly produced
   rules-in-name-only.

Net: 19 rules now have build-time enforcement that asserts their
customer-facing or structural expression on the page that carries it.
A redesign that drops any of them fails the audit in three places
(SessionStart hook, pre-commit hook, GitHub Actions audit workflow).
`cancellation_24h`'s lint is parked for the legacy doggoneclean.us
rebuild (the rule's exact wording applies to the legacy surface, not
the bath surface where `within_24h_non_refundable` governs).

### 2026-05-27 (schema + portal Phase 1 shipped)

After the pricing redesign locked, Paul greenlit starting the portal in the
same session rather than punting to a fresh one. Two slices landed in order:

1. **Schema** (`supabase/migrations/0002_hurricane_bath_v2_schema.sql`,
   commit `a728529`). Five tables on `dgc-prod`: `cities`, `bath_subscribers`,
   `bath_dogs`, `bath_subscriptions`, `bath_appointments`. RLS on every
   table, policies scoped to `auth.uid()` chained through the subscriber
   row, anon read on `cities` only (public site needs polygon + pricing).
   Indexes including the hot one for the charge-appointment cron
   (`bath_appointments_charge_candidates_idx` on `scheduled_start` where
   status is requested/confirmed and payment_status is pending). Shared
   `set_updated_at()` trigger on all five tables. The Villages seeded as
   the launch city with the locked founders + tier pricing ($55/$80
   founders, $75/$100 standard, $95/$120 single, 25-household cap).
   TypeScript types regenerated to `supabase/database.types.ts`. The
   legacy `clients` + `dogs` tables sit alongside untouched: every v2.0
   table is prefixed `bath_` so a future operator UI cannot confuse a
   Hurricane Bath subscriber with a legacy Ocala client. Advisors clean
   (only the pre-existing intentional INFO on `clients`/`dogs` which are
   service-role-only by design).

2. **Portal Phase 1** (commit `b364a4d`). React integration added to
   Astro; `@supabase/supabase-js` installed. New island at
   `src/components/portal/`: `supabase.js` (Clean's project, persistSession
   true, sendOtp/verifyOtp/signInWithGoogle/getPortalData helpers),
   `AuthScreen.jsx` (Google primary, phone-or-email fallback, ported
   from DGN and rewritten in Clean voice), `PortalApp.jsx` (auth state
   orchestrator with three render branches: anonymous, authenticated
   with no subscriber row, authenticated with subscriber), `portal.css`
   (Neural Expressive idiom: blue gradient buttons, soft glow on the
   auth card, system sans, no Google Fonts). `src/pages/portal.astro`
   replaced from stub to a real island mount. The honest empty-state
   landing for a signed-in user with no subscriber row points at
   `/the-villages` to book; the placeholder dashboard for a subscriber
   acknowledges that the data views (Dashboard, Pack, Plan, Reschedule,
   Skip, Cancel) ship in subsequent slices.

What Phase 1 will NOT do today: there is no `bath_subscribers` row for
anyone yet (no booking flow). A real sign-in lands every user in the
empty state. That is correct: Paul can test sign-in end-to-end (Google
verified working below; phone OTP needs Twilio which is still on his
plate; email magic link works via Supabase's default mailer). When the
booking flow chapter creates the first subscriber rows, the placeholder
dashboard becomes the surface that Phase 2 fills in.

**Verified end-to-end same day.** Paul tested Google sign-in from his
Pixel and confirmed the round-trip lands on the portal's empty state.
One config fix was needed before it worked: Supabase Auth's Site URL on
dgc-prod still defaulted to `http://localhost:3000`, so the OAuth
callback landed there after Google succeeded. Paul fixed it in the
Supabase dashboard (Authentication > URL Configuration):

- Site URL: `https://hurricanebath.com`
- Additional Redirect URLs:
  - `https://hurricanebath.com/portal/`
  - `https://hurricanebath.com/portal/**`
  - `http://localhost:4321/portal/` (for local `npm run dev`)
  - `http://localhost:4321/portal/**`

This category of configuration (Supabase Auth URL settings) lives in
the dashboard and is not exposed by the Supabase MCP, so a future
session diagnosing a similar "Google sign-in lands on localhost"
symptom should look here first rather than at the code.

The founders counter on `/the-villages` still ships hidden per
`founders_spots_remaining_counter` (the table exists but with 0 rows
and a 10-spot threshold, the rule's correct behavior is hidden). The
counter wiring (a SECURITY DEFINER read function for anon, or an
anon-readable view) lands in the slice that opens the founders cohort
for sign-ups.

### 2026-05-27 (pricing redesign on /the-villages)

Right after the fork shipped, Paul caught two issues on the city page pricing
area: the founders rate did not visually pop as a scarcity offer, and the
single-visit option was buried inside the recurring pricing card as a row
instead of being its own path. Two adjustments shipped (commit `fac3894`):

1. **Founders launch card states the 25-household cap up front.** The cap is
   now stated four places in always-visible copy: the eyebrow ("Founders rate
   · First 25 households"), the headline ("Be one of the first 25 households
   on the route."), the subhead body, and a "25 households" tile in the
   terms-grid. Each tier price now shows a "Saves $20 per visit vs standard
   recurring" line in cyan so the value of being early sits right next to the
   number. The terms paragraph was replaced with a 2x2 grid of bolded
   mini-statements (25 households / 12 months locked / No add ons / Two-tap
   cancel) so a scanning reader cannot miss any of them. The counter element
   still hides until remaining drops below 10 per
   `founders_spots_remaining_counter`; the cap statement is what carries the
   scarcity until the counter becomes meaningful.

2. **New "Other ways in" section** between founders and eligibility, with two
   side-by-side cards: "Try us once / Single visit" ($95 smoothcoat / $120
   doublecoat) with its own CTA `/book?plan=single`, and "After founders
   fills / Standard recurring" ($75 / $100) with `/book`. The single-visit is
   now a top-level path on the page, not a row.

Two new Oracle rules captured from the correction, each in its own commit
(`b049d86`, `269bcc9`):
`founders_cap_statement_always_visible` (cap and counter are distinct things;
the cap is always visible, the counter is the urgency layer that fires when
supply runs low) and `single_visit_as_own_path` (the trial path is the main
feeder of the recurring funnel; burying it starves recurring of its on-ramp).
Both indexed in `CLEAN_BUSINESS_RULES.md`.

Lesson encoded: when the implementation of a rule produces an outcome the
rule did not intend, the missing constraint is itself a rule worth capturing.
A future session reading just `founders_spots_remaining_counter` and not the
pair rule could rebuild the buried-cap failure verbatim.

### 2026-05-27 (fork shipped)

The DGN multi-page site structure was forked into Clean over six thin
slices that each merged to `main` and deployed to hurricanebath.com:

1. **Foundation:** design tokens in `src/styles/global.css`, BaseLayout +
   Legal layout in `src/layouts/`, Nav + Footer + FloatBookButton in
   `src/components/`. Build chain extended: `npm run build` now runs
   `python3 scripts/check.py` then `astro build`. `astro.config.mjs`
   updated: `site: 'https://hurricanebath.com'` and
   `build.format: 'directory'` for clean URLs. No visible site change
   (the new files were not yet imported by any page).
2. **Home page:** rewritten as a multi-page funnel (hero, fast lane,
   value props, the loop, recurring model, single Villages tile,
   friendly dogs only). Bath-forward copy; no nail vocab; no
   `grooming_vocab` violations.
3. **/the-villages:** hero, founders launch card with the
   `founders_spots_remaining_counter` element in place (JS wiring lands
   with the booking flow when `bath_subscriptions` exists), tiered
   pricing card (smoothcoat / doublecoat), eligibility (we bath / we do
   not), how-the-visit-unfolds, specialist section naming Paul with a
   placeholder avatar per `specialist_named_not_promised`, reminders,
   final CTA.
4. **/process:** six-step Hurricane Bath protocol (Set up, Soak, Drive
   water to the skin, Flush if filthy, Clean tank finish, Dry in the
   trailer), intro stats, the-standard-belongs-to-the-process section.
5. **Stubs:** /book and /portal honest "coming soon" pages so the
   homepage CTAs no longer 404. Same commit dropped the dead
   `PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD` env var from `deploy.yml`.
6. **Legal stubs:** privacy, terms, SMS (each with a "draft, real
   before launch" notice up top), using the new Legal layout.

Zero DGN aesthetic imported. Clean's blue gradient and soft glow idiom
runs through every page. The Neural Expressive look is consistent
across the eight routes. Per `villages_only_in_copy`, no other cities
are mentioned anywhere. Per `grooming_vocab`, the bare word
"grooming" never appears (the bath surface avoids the word entirely;
the rule is enforced by `scripts/check.py`).

All eight routes (`/`, `/the-villages`, `/process`, `/book`, `/portal`,
`/privacy`, `/terms`, `/sms`) build clean; `scripts/check.py` green;
the unused-CSS-classes cleanup parked 2026-05-26 was auto-resolved
because the rewritten homepage dropped those classes.

What still needs Paul (unchanged from the earlier focus block, refined):
photo of Paul for the city page specialist section (placeholder "P"
avatar in place); Stripe account + keys (gates the booking flow);
Twilio + A2P (gates SMS); attorney review of the legal pages before
launch.

### 2026-05-29 (booking flow chapter started: availability, funnel, counter)

Picked the next priority with Paul: the booking flow, because the live site
was a polished brochure that could not take a customer or a dollar, and
booking is the prerequisite that gives the portal and the founders counter
real rows. Paul chose a real slot picker at signup over capture-prefs or
schedule-later. Implementation call (mine): a lean availability layer, not
the drive-time route optimizer (deferred per elons_algorithm; clients
picking a slot does not need auto-sequencing). Built against real services
from commit one (no_mockups). Three slices shipped to `main`:

- Slice 1 (migration 0003, applied to dgc-prod): city booking config,
  `bath_availability_windows` + `bath_availability_exceptions`,
  `bath_open_slots()` (free slots only, no PII, anon-callable), and
  `bath_start_subscription()` enforcing the rule pack atomically (coat
  eligibility, three-dog cap, cadence + founders pricing with a one-year
  lock, price snapshot, one-bath-at-a-time). Verified via a rolled-back
  test: a 9-12 window gave the right 90-min Eastern grid; booking a slot
  removed exactly that slot.
- Slice 2: `/book` is now `BookingApp.jsx`, a React island reusing the
  portal auth (AuthScreen gained a redirectPath prop) and pt-* styles.
  Steps place -> dogs -> plan -> real slot picker -> review, live pricing
  from the city row. The card step is gated (no fake form) until Stripe.
  check.py's book-surface copy lints now point at the island.
- Slice 3 (migration 0004): `bath_founders_remaining(slug)` feeds the
  hidden `#launch-spot-count` on `/the-villages`; reveals below threshold.

Same day, second pass on the funnel: Paul flagged that the nails booking
flow is the proven baseline and Clean must match it or beat it, and that
my first cut diverged worse. Studied the nails flow in full and rebuilt
Clean's funnel as a faithful port (friendly-dogs callout + eligibility
checklist, address + gate code, contact + dogs with coat tier and optional
DOB, plan cards, next-available/specific-month slot picker with a "Best
fit" badge, card-on-file trust framing, review with a recurring preview).
The big correction: nails requires NO account to book, so Clean shouldn't
either. Migration 0007 reworked `bath_start_subscription` to run
anonymously (keyed on phone, auth_user_id NULL until the portal is
claimed), reversing the earlier account-required model. Verified end-to-end
on dgc-prod (rolled back). Bath-only divergences kept: coat-tier pricing
per dog (0005 fix: each dog its own tier, stacking discount), 2-week
cadence, three-dog cap, no add-ons. Parked the portal-claim path and
returning-client lookup as follow-ons.

Same day, third pass: Paul supplied the Clean Google Maps BROWSER key and
I wired it (`src/components/portal/maps.js`). Step 1's address field is now
Google Places Autocomplete; on pick it captures lat/lng and runs a ray-cast
point-in-polygon against the real 308-point `cities.polygon` Villages
boundary. In-area reveals the gate code + the rest of the funnel and stores
serviceLat/serviceLng for the signup payload; out-of-area routes to the
waitlist and blocks. Manual-entry fallback if the Maps script fails (no dead
end). Verified the in-area math against an independent SQL ray-cast on the
real polygon (interior + exterior points all agreed). The key is a source
constant (ships in the page like the Supabase publishable key); its
protection is the HTTP-referrer + API restrictions in Google Cloud, which
Paul holds. Refined `maps_js_api_only` to record that the browser key also
needs the Places API enabled (for the JS Places library / Autocomplete),
still referrer-locked and still not a REST call, so a future session does
not strip it. Still open: per-address allow/deny exceptions over the polygon.

Fourth pass (correction): Paul reported the address box never showed
suggestions and that page one diverged from nails. Read the real nails
`src/components/booking/steps.jsx` (not memory) and found two faults. (1)
The Maps loader used `&loading=async`, which leaves `google.maps.places`
unpopulated at `script.onload`, so the synchronous `new Autocomplete(...)`
found places undefined and silently no-opped (the dead box); nails uses the
plain `libraries=places` + async+defer loader, which has places ready at
onload. Matched it (verified gone from the built bundle). (2) Page-one parity
gaps: nails requires email, breed, and date-of-birth (with an exact/approx
toggle) and uses the single service-address input with the "Are you in our
service area?" heading + success banner. Aligned all of it, keeping the bath
divergences (coat tier, three-dog cap, no silk upsell, anonymous). Lesson
reinforced: when the task is "match nails," read the nails source first, do
not reconstruct from memory.

Fifth pass (the real address fix): with the loader corrected, the box still
errored. The console (Paul's screenshot) was decisive: `LegacyApiNotActivated
MapError` plus "as of March 1 2025 `google.maps.places.Autocomplete` is not
available to new customers, use `PlaceAutocompleteElement`." Google blocked the
legacy autocomplete widget for new Cloud projects; Clean's Maps project is new,
so nails' legacy-widget code cannot work here no matter what (nails works only
because its project predates the cutoff). It was not the referrer (the key
already allows hurricanebath.com per the build record) and not billing. Migrated
the address field to the modern `PlaceAutocompleteElement` (Places API New,
already enabled on Clean's project, which is what drew the suggestions). Used
the classic `libraries=places&v=weekly` loader (the form Clean's project loads
cleanly) with `google.maps.places.PlaceAutocompleteElement` directly off the
namespace; on `gmp-select` -> `placePrediction.toPlace()` ->
`fetchFields(['formattedAddress','addressComponents','location'])` -> parse (New
API uses longText/shortText + `location`) -> in-area polygon check. The address
field is now a SINGLE box in all cases: the Maps-failed fallback is one plain
text input, not the old multi-field form (Paul disliked the form). Confirmed the
event/fetchFields shape against Google's current docs. A forced divergence from
nails (Google policy, not a choice); nails will face the same migration. NOTE
the standing limit: this session cannot run a real browser (no headless +
referrer-locked key), so interactive autocomplete is verified by code/docs and
the built bundle, NOT by a live click; final confirmation is Paul on the
deployed page. `maps_js_api_only` refinement updated to say New, not the legacy
widget.

Sixth pass (correction, Paul's call): removed the manual address path
entirely. Paul's rule is that there is no manual option: the address
autocompletes, you tap it, in-polygon passes and out-of-polygon fails, full
stop. The funnel had a "Can't find your address? Enter it manually" link that
dropped to a plain text box and passed the gate on any typed text, and the
server (0008) accepted a coordinate-less signup as `address_verified = false`
to confirm later. Both are the unverified "we will sort it out" hole Paul does
not want. Fixed in both layers: `BookingApp.jsx` now offers autocomplete plus
the in-area check only (when Maps cannot load it shows an honest "booking opens
shortly" notice and the gate stays closed, no manual box), and migration 0009
makes the RPC hard-reject any booking with absent or out-of-area coordinates
before a row is written. Refined `service_area_enforced_server_side` to match,
updated the index, and added a `check.py` guard that fails the build if
manual-entry copy returns to the island. The "manual-entry fallback (no dead
end)" recorded earlier in this chapter was a mistake against this rule;
reality wins.

Seventh pass (Step 1 nails-parity, Paul walking the flow one step at a time):
two pieces from the nails Step 1 that apply to Clean but had been dropped. (1)
Returning-client recognition: on phone blur the funnel now asks the new
anon RPC `bath_lookup_subscriber` (migration 0010, applied to dgc-prod) whether
we already know this phone, and greets a known person by first name. The RPC
returns only {found, first_name} (minimal PII), matching the nails posture. (2)
The address autocomplete is now biased toward the service area using a bounding
box derived from `cities.polygon` (maps.js `polygonBounds`), so no coordinates
are hard-coded and the polygon stays in the database. Still parked from the
nails Step 1, as not-yet-applicable-here: per-address allow/deny exceptions over
the polygon, and the "you are on [operator]'s route" personalization (needs the
route-operator data, which Clean does not have wired yet).

Eighth pass (Step 1 carbon-copied to nails, Paul's call to stop iterating
piecemeal): made Clean's Step 1 read as a carbon copy of the nails Step 1.
Eligibility is now nails' physical-fit gate (private home with a driveway, room
to park the truck and trailer); the friendly-dogs callout, ack wording,
returning-client banner, SMS consent, and the button label all match nails; the
two extra address helper lines (the "Selected:" echo and the "start typing"
instruction) were removed. Three things could NOT be carbon-copied without
breaking Clean and are kept as forced exceptions, to be iterated as
clean-specifics: (1) the address box uses the modern PlaceAutocompleteElement,
because Google blocks nails' legacy widget on Clean's newer Cloud project; (2)
the dog card keeps the coat-tier picker, because Clean's bath pricing (Step 2 +
the RPC) requires it and removing it zeroes out pricing; (3) the dog cap stays at
3 (`three_dog_cap`), not nails' 4. This drops the bath-only and three-dogs copy
from Step 1, so check.py now prints two non-blocking warnings (their teeth live
in the RPC and the coat-tier CHECK); the bath-specific eligibility copy gets
re-added in a follow-up.

No new Oracle rules this chapter; two refinements (`maps_js_api_only` and
`service_area_enforced_server_side`, above).
The funnel enforces the existing rule pack. Blocked / handed to Paul: the
Stripe SetupIntent edge function
(needs the Dog Gone Clean TEST keys) to activate the card step, and the
real availability data (per-visit duration, weekly windows) to light up
the slot picker. Both parked in CLEAN_PARKING_LOT.md. Also set up a
permission allowlist (committed settings.json for shareable tools;
gitignored settings.local.json for the environment-specific Supabase MCP
server) so routine work stops prompting; force-push and rm -rf stay denied.

### 2026-05-29 (continued: ship gate made real, booking-flow design + UX hardening)

Same session, after the booking funnel chapter above. Paul opened by bringing
the wreckage of two bad prior sessions and pushing on trust: he wanted the rules
that matter enforced mechanically, not promised. No new Oracle rules came out of
it (refinements and build guards only); the durable outcomes:

Permission allow-list (both repos). The Nails repo's `.claude/settings.json` was
missing the basic file tools (Read/Write/Edit/Glob/Grep), so routine work kept
prompting; brought it in line with Clean's and added a deny-list (force-push,
hard reset, clean -f, rm -rf). Diagnosed that a session rooted at the parent
directory loads neither repo's settings, which is the real cause of the prompt
spam (an environment/launch setting, on Paul's side, not a repo file).

Deploy gate (done-means-live; redesign survival enforced). Paul's rule,
restated and locked: nothing important may be lost in a website redesign, and
"shipped" must mean live on the site, never stranded on a branch. Before this,
`deploy.yml` and `audit.yml` were separate workflows running in parallel on a
push to `main`, so the deploy published to the droplet regardless of whether
`scripts/check.py` passed. Rewired `deploy.yml` so the `deploy` job `needs` an
`audit` job: a push that fails the audit never reaches the rsync. This turns the
tiered audit into a real ship gate (`redesign_survival_is_a_ship_gate`,
`build_gate`), not advisory. Confirmed Nails was already gated this way (its
deploy runs `npm run build`, which chains the guards, before the rsync).

Service-area gate hardened (migration 0009, applied to dgc-prod). Removed the
manual address path entirely (Paul: no manual options; the address
autocompletes, you tap it, in-polygon passes, out-of-polygon fails).
`bath_start_subscription` now hard-rejects a booking with absent or out-of-area
coordinates before any row is written (0009 supersedes 0008's
accept-as-unverified branch). The page offers autocomplete only; when Maps
cannot load it shows an honest "booking opens shortly" notice and the gate stays
closed. A `check.py` guard bans manual-entry copy from the booking island.
Refined `service_area_enforced_server_side` and the index to match.

Returning-client recognition (migration 0010, applied to dgc-prod). On phone
blur the funnel calls the new anon RPC `bath_lookup_subscriber` (returns only
{found, first_name}) and greets a known person by name. Address autocomplete is
biased toward the service area using a bounding box derived from
`cities.polygon` (no hard-coded coordinates). Returning-client lookup is now
DONE (was parked); the portal-claim path is still parked.

Step 1 carbon-copied to the Nails Step 1, then tightened. Per Paul, matched
Clean's Step 1 to the proven Nails Step 1 (physical-fit eligibility: private
home with a driveway, room to park the truck and trailer; friendly-dogs callout;
ack; returning banner; SMS consent; button label). Forced exceptions kept,
because copying them verbatim would break Clean: the modern
PlaceAutocompleteElement (Google blocks Nails' legacy widget on Clean's newer
Cloud project), the coat-tier picker (bath pricing and the RPC require it), and
the 3-dog cap. Note on the cap: it reflects the Villages HOA limit (two dogs,
three grandfathered), not a Dog Gone rule, so it is never stated to customers as
one; the form simply stops at three. Eligibility reads "about 2 standard car
spaces, front to back" with a quiet line: "You don't need to clear your driveway.
We can park on the street when it's safe and legal." Mirrored the front-to-back
wording and that line onto Nails too.

Friendly-dog policy trust line propagated. Added the homepage's "a mobile dog
bath runs on the trust between the dog and the operator" line to the booking
Step 1 callout, and the parallel line ("a mobile nail appointment runs on the
trust between the dog and the specialist") to the Nails homepage card and Nails
Step 1 callout, so both sites' friendly-dog policy carries it.

Booking flow restyled into Neural Expressive, then de-walled. The funnel had
drifted to flat form styling. Brought back the site's look by reusing the
existing vocabulary in `global.css` (no new styles invented): ambient glow haze
behind the funnel, bigger gradient-keyword step headings (`.grad`), more card
lift. Fixed the black autocomplete box (Google's element followed the device
dark-mode default; forced `color-scheme: light` and themed it to `.pt-input`).
Fixed a glow stacking context that trapped the autocomplete dropdown (moved the
glow to a z-index:-1 background layer). Fixed the address box going empty after
toggling the eligibility checkbox (the mount effect had no cleanup and a stale
ref; added teardown so it re-creates on each reveal). Tried a +25% spacing pass
on Step 1 at Paul's request, then reverted it when it made the wall taller, not
smaller; instead re-ranked the friendly callout to lead with the rule and demote
the trust sentence to a small note, keeping all words. Paul confirmed it reads
better and stopped here.

Standing limits, honestly stated: this environment cannot run a browser or load
the referrer-locked Maps key, so interactive autocomplete and the visual restyle
are verified by code, the built bundle, and Paul's eyes on the deployed page,
not by a live click here. The Maps autocomplete still depends on a Google Cloud
console setting on Paul's side before it renders. Still parked: the Stripe
SetupIntent card step (needs the Dog Gone Clean test keys), real availability
data for the slot picker, per-address allow/deny exceptions over the polygon,
the "you are on [operator]'s route" personalization (needs route-operator data),
and the portal-claim path.

### 2026-05-28 (process-page video placement + sound, logo crop, favicon, nav size)

Paul added two clips to the `/process` page (water-pressure, bath-in-action)
and felt they sat too low. They did: fourth section, below the hero, the
intro, the stats, and the six-step list, roughly three mobile scrolls down on
the Pixel target. Moved the whole "See it work" block to second position,
directly under the hero, so the bath is shown in motion right after the hero
promises "here is what happens." Same pattern as the 2026-05-26 homepage swap
(Hurricane Bath section before "why Paul built it"). Build clean, shipped to
`main`.

One new Oracle rule captured: `show_dont_tell` (copy). Proof shows before it is
explained, and feelings are shown not asserted. Seeded by Paul noticing while
filming the water-pressure clip that the trailer is his happy place, and that
it may land better to show that calm and let people conclude it themselves than
to say it out loud. The rule locks both halves (video high on the page; the
trailer's calm shown, never claimed) with the because that a self-reached
conclusion is believed where a direct claim about calm invites the opposite.
A footage shot list (before/after, mud-puddle flush, drying, the calm/peaceful
clip, setup time-lapse, suds-at-skin, the rig) is parked in CLEAN_PARKING_LOT.md
for Paul to capture on the route.

Then Paul asked for the clip audio to behave. Added an `IntersectionObserver`
that mutes a clip once it scrolls mostly out of view and a `visibilitychange`
handler that mutes both clips when the tab is hidden, so sound never plays from
something the visitor cannot see (the classic "where is that noise coming from"
annoyance). Captured as a second new Oracle rule, `video_audio_only_when_visible`
(ux): site video autoplays muted and looping, audio turns on only by a deliberate
tap, one clip at a time, and cuts on scroll-away or tab-hide. The clips keep
playing muted; only audio toggles, and returning never auto-unmutes.

Logo work, same session. The supplied `logo.png` was the artwork (878x313)
floating in a 960x540 canvas with ~112px of dead space top and bottom, so at the
nav's fixed height the mark rendered tiny. Cropped to the artwork with a small
even margin (now 910x345). When Paul reported it still looked uncropped, the
cause was browser cache on the unchanged `/logo.png` URL, fixed by versioning the
nav src to `?v=2`. Added a dedicated square favicon (`public/favicon.png`,
128x128) built from just the dog mark and pointed the favicon links at it; before
this the favicon was the wide lockup squished into a square, an unreadable smear.
Bumped the nav logo render height 48px -> 60px (the bar is 72px) once the real
cropped version was visible and still read small.

Transparency dead-end (recorded so no future session re-attempts it). Paul asked
for a transparent-background logo to park for later. It is not achievable from the
current raster: the dog's body is pure white and open at the bottom where it meets
the ground, so its interior is the same connected region as the background and any
background removal hollows the dog (verified by compositing on dark). The dark
wordmark also vanishes on dark backgrounds. A true drop-anywhere logo needs proper
variants from the source art (a filled-shape dog on transparent, plus a light
wordmark for dark backgrounds), which is a design task, not a raster edit. Parked
the finding in CLEAN_PARKING_LOT.md; Paul said drop transparency for now.

All of the above built clean (`scripts/check.py` plus `astro build`) and shipped
to `main` in logical commits across the session.

### 2026-05-27 (strategy thread + four decisions captured)

A long strategy thread reviewing the project end-to-end before starting the
fork of the DGN multi-page site structure. Paul granted the environment
access to `doggonenails-site` (was blocking the fork; now unblocked) and
directed a thorough read pass of both repos before any code touched disk.
Four decisions came out of the thread and landed in the Oracle as new rules,
one logical commit each:

- `villages_only_in_copy` (Hurricane Bath: copy): the v2.0 surface mentions
  only The Villages in customer-facing copy, no legacy Ocala / no future
  cities / no coming-soon placeholders. Pairs with `villages_only_at_launch`
  (which gates the booking polygon); this rule gates the copy.
- `specialist_named_not_promised` (copy) + `specialist_assigned_per_route`
  (scheduling), paired: name and photo the current operator (today: Paul),
  never lock in "always Paul" and never imply an interchangeable team,
  surface "you are on [Name]'s route" at booking step 1 from the route's
  operator. Pairs with the existing standard-belongs-to-the-process
  language so adding a hire does not break a promise to existing clients.
- `founders_spots_remaining_counter` (ux): port DGN's Villages-page live
  spots counter to the Hurricane Bath launch page, hidden above a
  visibility threshold, auto-updated from the subscription count.

One site-build decision (not a business rule, scoped to this build): the
Hurricane Bath process gets its own dedicated `/process` page mirroring
DGN's, not folded into the homepage. The `/portal/` and `/book/` link
404s parked 2026-05-26 get fixed by adding honest stub pages during the
fork, not by removing the CTAs (the CTAs are part of the money-machine
pattern).

Did NOT touch this session: the existing 24-rule Hurricane Bath pack
(sound), the Field Manual (sound), the `marketing/` showcases (sound),
`legacy/data/` (out of scope for the v2.0 surface), the deploy workflow,
the database, or any code. Active fork build starts next.

Near-miss noted for future-session-Claude: this session almost proposed
inventing a new `BUILD_NOTES.md` and `BRAND_BRIEF.md` before reading the
existing six-doc set. `read_before_redesign` already prevents this in
principle; the concrete example is recorded so the lesson is grounded.
Every "I should make a doc for this" instinct in this repo must first
check whether CLAUDE.md / Scroll / Oracle / Business Rules / Parking Lot
/ Field Manual already has the home for it. The doc set is intentionally
exhaustive; new top-level docs are almost never the right answer.

### 2026-05-26 (recovery from compounded bad sessions)

Paul came in after losing a night of sleep to compounded bad sessions: one had hallucinated
and committed nothing, the next had built a Playwright verify-gate that broke the deploy,
the next had thrashed trying to fix it, and the last had cleaned up the salvage. The
symptom in front of Paul: "Claude says it made the change, but I don't see it on the live
site." This recovery session listened first (no theory before Paul's account), then
verified ground truth from disk and the live site rather than from the prior sessions'
commit messages, and diagnosed: the live homepage was stale by 8 commits (last published
was `f3ed2be` at 6:30 AM Eastern; current `main` was `e408d71`). The verify-gate damage
was already gone from the code, but the GitHub Actions deploy was returning HTTP 403 on
`git clone` for every push after `f3ed2be`, and the Audit workflow was failing the same
way. All repo Actions settings checked out as correct. The cause was a transient GitHub
auth glitch (likely tripped by the morning's commit-storm rate limit on the account); it
cleared instantly when Paul re-ran the latest failed deploy from the Actions UI, and the
queue caught up.

Then bumped `actions/checkout@v4` -> `@v5` and `actions/setup-node@v4` -> `@v5` ahead of
the GitHub Node 20 deprecation (forced upgrade 2026-06-02, removal 2026-09-16); both v5
versions run on Node 24, deprecation warning is cleared, deploy and audit both verified
green on the new versions. Sanity-tested the full pipeline with a homepage section swap
(Hurricane Bath section now precedes "Why Paul built it"), Paul confirmed it landed live.

Two new Oracle rules captured from this recovery: `recovery_from_a_bad_session` (process
for the next session walking into a compounded bad situation: listen first, verify from
disk not from prior-session claims, treat prior-session commit messages as an unreliable
witness, stop on "loop" as Paul's hard-stop word) and `transient_ci_rerun_first`
(engineering: re-run a failing CI workflow once before pushing a fix-commit; pushing onto
a jammed pipeline compounds; the 403 today would have stayed broken for another night if
the response had been another commit instead of a re-run). Both indexed in
CLEAN_BUSINESS_RULES.md. CLAUDE.md updated: the stale "awaiting `DROPLET_SSH_KEY`" build-gate
paragraph replaced with current reality (deploy publishes, `audit.yml` runs `check.py` on
every push); new bullets in "How Paul works" (the loop-stopword recovery protocol) and
"Stack and commands" (the re-run-first rule). Three small live-site bugs found during the
audit and parked in CLEAN_PARKING_LOT.md for the next site-touching session: `/portal/`
links 404 on the homepage CTAs, dead `PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD` env var in
`deploy.yml`, unused CSS classes in `index.astro`.

### 2026-05-26 (workflow-cap follow-up)

A sibling session on `doggonenails-site`, after cleaning up the verify gate, swept the
last 24 hours of changes for "same shape" risks and found three. Checked here:
`audit.yml` had no `timeout-minutes` cap (same shape as the verify-gate hang risk, even
though the audit script runs sub-second); `deploy.yml` was already correct
(`timeout-minutes: 5`, `npm ci --omit=dev`); `.claude/settings.json` was already tighter
than nails (no `Bash(curl *)`, no `Bash(git reset *)`, with `git reset --hard`, `rm -rf`,
and force-push in the deny list). Added the cap to audit.yml and locked the lesson into
the Oracle as `ci_workflows_capped_and_validated` (engineering), indexed in the
business-rules index, so a future workflow can't be added without a cap.

### 2026-05-26 (verify-gate salvage)

The prior 2026-05-26 session shipped a Playwright-based `verify.yml` CI workflow without a
`timeout-minutes` cap and without ever running it end-to-end successfully. Every run hung;
six accumulated and jammed the Actions queue, blocking deploys for the last several
homepage commits. The session flailed through five commits trying to cancel the hung runs
via concurrency groups (which cannot retroactively cancel in-progress runs) and ended with
`verify.yml` deleted but `scripts/verify.mjs` and the npm `verify` script and `playwright`
devDep left in place, and `CLAUDE.md` still pointing future sessions at `npm run verify`
as the required "done means done" gate. Three lessons recorded inline below; salvage in
this session was scoped to what Paul authorized as an outcome: "rules a session reads at
orient match reality."

Removed: `scripts/verify.mjs`, the `verify` npm script, and the `playwright` devDep.
Rewrote the `CLAUDE.md` Stack-and-commands entry and the session-start orient footer to
state the outcome ("verify the specific change you made does what was asked"), not the
broken mechanism. Added Oracle rule `verify_the_change_before_done` (process), indexed in
`CLEAN_BUSINESS_RULES.md`. Did NOT touch: the audit pipeline (`scripts/check.py`,
`audit.yml`, pre-commit hook, SessionStart hook orient logic) which is sound and proven
green every session; `deploy.yml` which has a working `timeout-minutes: 5` cap and the
right `--omit=dev` for Astro. The hung Verify runs in the Actions tab are waiting on
GitHub's ~6h timeout to clear; they cannot be cancelled by tools available to a session.
The next deploy will pick up the latest `main` (homepage commit `72a1f10` plus this
cleanup) once the queue unjams.

Lessons (encoded in the new Oracle rule):
- Reporting "done" on unverified work compounds. A clean build is not verification.
- A CI workflow shipped without being run end-to-end is shipping a guess. Job-level
  `timeout-minutes` is non-negotiable.
- When a remedy is not working, stop adding commits. Flailing leaves more debris than the
  original mistake.

### 2026-05-26 (root-cause fix: GitHub default branch)

Found the actual root cause of the "every session starts on a stale branch" failure
pattern: the GitHub repository default branch was set to `claude/amazing-noether-4Mo5W`,
a two-day-old session snapshot. Every fresh session, every fresh clone, every harness
spin-up was being pointed there by GitHub itself, regardless of what the user picked.
Paul switched the default to `main` in Settings > General, then deleted every `claude/*`
branch from the branch list. The SessionStart hook added earlier stays as a belt-and-
suspenders defense, but this default-branch fix is the cure: the hook was protecting
against the symptom, the default-branch change removes the cause.

### 2026-05-26 (scroll reconciliation)

Discovered the docs had split across two parallel branches: `main` had carried the
2026-05-25/26 work (site scaffolded and deployed, Supabase `dgc-prod` built, journal
absorption, Field Manual, Prime Directive + lenses, Neural Expressive homepage,
"dog grooming" lock, `dates_use_local_eastern`, plus same-day parking-lot adds for
Breed Firewall and shedding-interception copy and the two-tap cancellation idea), while
`claude/inspiring-mayer-ionnB` had branched off the 2026-05-24 base (`f65a096`) and
captured the Hurricane Bath rule pack on a stale view of the world (24 new Oracle rules,
data/ moved to legacy/data/, two-tap cancellation locked as `stop_sign_two_taps`,
hurricanebath.com framed as Dog Gone Clean v2.0). Reconciled both branches into `main`
by union, no decision dropped: kept every Oracle rule from both sides (89 rules total),
folded the parked two-tap idea into a pointer to the locked rule, rewrote
`bills_in_person_today` and `accepted_payment_methods` as surface-scoped (legacy via
Square; Hurricane Bath via Stripe card-on-file per the new rules), refreshed the focus
block to match real state (site live + database seeded + v2.0 rules locked + next step
= build the v2.0 booking surface), kept the 2026-05-26 Hurricane Bath session entry
below. Lesson recorded: every future session must start by reading `main` and refusing
to branch off a stale snapshot; the harness's habit of putting fresh sessions on the
oldest branch is what produced the parallel-reality failure.

### 2026-05-26 (Hurricane Bath rule capture + plan reconciliation)

A prior 2026-05-26 thread did extensive planning for Hurricane Bath (Dog Gone
Clean v2.0) but admitted late that it had hallucinated and committed nothing.
The session's ExitPlanMode body survived in Claude Code's side panel and was
re-pasted into the recovery session. The pasted plan was reconciled against
DGN's canonical skip/reschedule policy (per Paul's "use the dgn policy"
instruction) and against Paul's in-chat correction to the breed list
("exclude any breed that can mat or impact"). The final plan was approved
and the locked rule set was captured into the Oracle one rule per commit,
24 commits, all pushed. Forensic record of the two failed sessions and
recovery procedure was produced inline for Paul to save outside the container. (This session was performed on the stale `f65a096` base, not
on `main`; that branch divergence was reconciled in the 2026-05-26 scroll
reconciliation entry above.)

### 2026-05-24 (foundation session)

Set up the repo and built authoritative client records from the Google Drive contact sheets.
Found and fixed a sourcing error where the handoff doc-ID index pointed at stale or blank
2023-2024 spreadsheet duplicates for six clients (Kevin, Cynthia, Donna DiPasqua, Linda Giza,
Bradley, Mary Beth); re-sourced every standing record from the newest populated doc and
applied Paul's corrections. Built the first route template. Built the doc/handoff system,
then reworked it for the coming website and renamed it to the CLEAN_ prefix. Added
`scripts/check.py` and hardened enforcement. Locked the strategy: the saleability rationale,
the business architecture (one evolving Clean, a fork of the DGN platform), infrastructure,
payment, staging, and the decision-capture workflow. Corrected the live domain to .us.

### 2026-05-24 (continued: the_oracle_journal + foundation + marketing)

Absorbed Paul's original Drive journal (`the_oracle_journal`) into the Oracle and a new
CLEAN_FIELD_MANUAL.md. Laid in the prime directive as the apex of the rulebook, added two
top-level decision lenses (`elons_algorithm`, `dig_the_moat`), and made Claude threads the home
for capturing ideas. Built the Hurricane Bath showcase and a power/drying showcase, kept the
build proprietary, and banked an internal story plus gold lines. Mined the live site (Paul pasted
it, since the environment cannot reach it) into the origin story, brand voice, taglines, doorstep
copy, and four published policies now held as Oracle rules. Resolved the payment list. Rebuilt
this Scroll.

### 2026-05-25 (database setup)

Stood up Clean's own Supabase project and built the client-book database layer. Created
`dgc-prod` (ref `urebdrosrxejhubpbxsa`, us-east-1) in the shared "Mount Olympus" org, the
hard-separation line per `own_infrastructure` (only `dgn-prod` existed before; nothing of
Clean's touches it). Wrote the v1 schema (`public.clients` + `public.dogs`) as a migration
in `supabase/migrations/`, RLS-locked with no policy so only the service role reaches the
data until portal auth is built (the records carry gate codes and door codes). Added
`scripts/gen_seed_sql.py`, which turns `legacy/data/clients.json` (then `data/clients.json`, moved 2026-05-26) into a reproducible
`supabase/seed.sql`, and seeded the project: 47 clients (33 standing, 11 one-off, 2 at-will,
1 banned) and 61 dogs, prices stored in cents, verified with zero orphans and zero standing
records missing required fields. Saved the generated TypeScript types to
`supabase/database.types.ts`. Security advisor shows only the expected INFO
(RLS-enabled-no-policy), which is the intended locked state.

### 2026-05-25 (design direction)

A short thread that set the website's visual direction and surfaced an environment limit. Paul
named the look he wants: Google's "Neural Expressive" design language (the Gemini app redesign
from Google I/O 2026, rolled out 2026-05-19), and rejected an earlier wrong guess of Material 3.
Researched it via web search and captured the concrete tokens (blue gradient washes and glows,
ombre/gradient key words, a simple sans-serif with strong size contrast, editorial hierarchy,
fluid motion; no special typeface needed). Set "restyle, do not reinvent": rebuild the existing
DogGoneClean.us content in the new look. Found that WebFetch is blocked in this remote
environment (403 / egress allowlist) and the live site 403s automated fetches, so the redesign
is blocked pending screenshots from Paul. No code shipped; the direction is recorded in the
Oracle (`neural_expressive_design`), CLAUDE.md, and the decisions log below.

### 2026-05-25 (website rebuild + branch consolidation)

Discovered the work was scattered across unmerged per-session branches with no `main`, the exact
failure the "ship to completion" rule was meant to prevent (the interim "ship = push to working
branch" clause, living in a branched CLAUDE.md, never retired, and no trunk ever established).
Consolidated everything into `main` as the union of the three session branches (build + database
+ deploy, the mined brand content + showcases + field manual, and the docs), resolving the
conflicts by hand with no decision dropped. Fixed the shipping rule (main is the single trunk;
branch from it, merge back to it) and added a `.claude/settings.json` permission allow-list so a
build stops prompting on every tool call. Rebuilt the homepage in the Neural Expressive look
with the master logo and bath-forward content, build-verified, live at hurricanebath.com.
Sharpened the business model after Paul caught that a prior session had flattened it: two
businesses, Clean keeps legacy Ocala full grooming while making a hard pivot to bath only, Ocala
then the Villages. Aligned the homepage (bath-forward, full groom as the legacy service, nails
removed since that is DGN's business). Next session forks the DGN site structure
(`doggonenails-site`) into a multi-page Clean site.

---

## Decisions log (2026-05-24)

Append-only across sessions; grouped for readability, with no decision dropped.

### Data and records
- **Base/home:** 3885 SW 114th Court, Ocala 34481 (rural SW). No separate anchor; the SW /
  On Top of the World cluster is the launch/return zone; Chester Weber (by base, fixed 12pm)
  is the first stop. NE/NW/SE days commute into the city.
- **Active roster:** the past-year set already derived from the calendar in a prior thread
  (47 clients). Do not re-derive it or crawl the full archive.
- **Sourcing:** resolve each client to the newest populated contact-sheet doc; never a blank
  template, an old spreadsheet, or the handoff index.
- **Client corrections (Paul's review):** the full corrected records live in
  `legacy/data/clients.json` (was `data/clients.json` at the time, moved 2026-05-26). Headline fixes: Kevin Cummings is a 7-dog full-groom account at 6wk
  (not a 2-dog nails stop); Mary Beth's Onyx died 6/2025 and Theo is the second dog; Donna
  DiPasqua's dog is Fledge ($100, Monthly); Linda Giza is 3 months; Bradley has one dog;
  Chester lost Windsor; Chloe is Louie only (Boykin Spaniel); Erich is Koby only; Steve and
  Patty are nails-only legacy; plus prices and access details across the book.
- **Cadence conflicts:** Chester 3wk and Greta 6-8wk and Kevin 6wk resolved from the sheets;
  Peter Moran still open (~8wk note vs ~12wk calendar).
- **Lisa Prater service:** depends on visit (full groom some visits, nails between).
- **One-off list:** kept as-is, treated as conversion candidates; parked.
- **From the original brief (baked):** evening/Saturday locks are real client constraints;
  Donna DiPasqua Tuesday; Cynthia Tieche Tuesday 3pm; Nancy Franklin + Lisa Prater + Patty
  Brown Saturday nails cluster; Garret Little at-will; Richard Vieira one-off; Bonnie
  DiGraziano banned, excluded everywhere.

### Doc system and workflow
- **Naming:** the doc set uses the DGN names with a CLEAN_ prefix (chosen over DGC_ because
  DGC and DGN look alike at a glance). CLAUDE.md keeps its exact name.
- **Decision-capture workflow:** on "lock it in" or a clear equivalent, write the decision to
  its live home plus this decisions log and commit/push the same turn; record nothing while
  still musing; the end-of-session rebuild is a polish/reconcile pass, not a rescue. Baked
  into CLAUDE.md, the Oracle (`lock_it_in_capture`), and the header mandate above.
- **Enforcement:** `scripts/check.py` (no deps, no DB) validates `clients.json` and scans
  tracked docs for em dashes; the Oracle's `read_before_redesign` carries a redesign
  checklist (run check.py, walk the index, re-enforce or reject).

### Strategy and architecture
- **Saleability (`clean_stays_saleable`):** Clean must stay sellable as a standalone
  business, never tangled with DGN or dependent on Paul personally. Rationale: saleability is
  a value test, not an exit plan. A business is only buyable if valuable; if no one would buy
  it, it is probably not worth running, and if it is valuable enough to sell, that is the
  reason to keep it. Method: imagine (or ask) why a serious buyer would decline, and treat
  each reason as the improvement backlog.
- **Business architecture (RESOLVED):** two businesses, not three. DGN is the flagship,
  fully separate. Clean is ONE evolving business: existing grooming book + bath-forward new
  acquisition, one portal, one site, one Supabase, morphing toward the profitable mix, can
  expand to the Villages with bath. The separate scalable "new Clean" folds back into Clean.
  (Refined 2026-05-25: Clean keeps legacy Ocala full grooming while making a hard pivot to bath
  only, Ocala then the Villages; DGN is the new nails-only Villages business. See the 2026-05-25
  business-architecture entry.)
- **Clean is a fork of the DGN platform.** v1 replaces the current stack feature-for-feature:
  Squarespace -> Astro site; Acuity + confirmations -> portal + String of Pearls + automated
  notifications; Drive client Docs -> Supabase client book (seeded from `legacy/data/clients.json`);
  Google Voice texting -> SMS; manual location text -> pizza tracker; manual photos ->
  operator-app photo capture and share.
- **String of Pearls from day one** (not deferred for low density); the one adaptation is
  variable grooming durations, not DGN's fixed nail buckets.
- **Forward-parked (not decided):** a possible "Dog Gone" brand family named by service
  (Clean, Walking, Sitting, Training) as forks of the same platform; and whether Paul
  ultimately runs a portfolio he keeps or builds units to sell.

### Infrastructure and build
- **Stack:** reuse the DGN stack (Astro 5 + React 18 islands, Node 20, npm, Supabase,
  DigitalOcean droplet + Caddy, GitHub Actions deploy on push to main), Clean's own instances.
- **Shipping:** ship-to-completion is the git rule (open PR and squash-merge when a branch
  builds clean); it supersedes the earlier "no PR unless asked." Don't offer PR-activity
  subscriptions. (Superseded 2026-05-25: the deploy pipeline exists and `main` is the single
  trunk; every session branches from `main` and merges back into it to count as shipped. See
  CLAUDE.md "Shipping".)
- **Separation:** data (Clean's own Supabase project, never `dgn-prod`) is the hard line. A
  shared droplet (own dir/domain/Caddy block), a shared Supabase/Google account, and shared
  tooling are acceptable to save cost since they are cheap to separate before a sale. API
  keys are each their own and domain-locked (own Google Cloud project for Maps + OAuth).
- **Database guardrail lifted for Clean (greenlit):** build the schema iteratively and
  rebuildably in Clean's own project.
- **Payment:** in person via Square, not Stripe; online payment deferred. SMS via Twilio
  (own number + A2P) is in v1 (replaces Google Voice). n8n deferred. (Accepted-method list
  finalized 2026-05-24, see below.)
- **Pizza tracker:** client-facing live status/ETA view, companion to the operator app,
  replaces the manual "on my way" texts; included in v1 (details from Paul later).
- **Staging:** build and preview on hurricanebath.com (kept private/non-indexed) while
  doggoneclean.us keeps serving the old Squarespace site; flip the domain at launch. Local
  `npm run dev` is the fast loop.

### Facts for the record
- **Domain:** the live site is www.DogGoneClean.us. Paul does NOT own DogGoneClean.com.
  Staging/preview on hurricanebath.com (a domain Paul owns).

## Decisions log (2026-05-25)

### Business architecture (refined)
- **Two businesses, the model sharpened.** The 2026-05-24 lock-in (two businesses not three,
  Clean is one evolving business) was right, and the three-business plan stays retired (it lives
  in history, commits `0c37403` and `9ee4aa3`). What was missing was Clean's precise arc, now
  fixed. (1) DGN is the new nails-only business in the Villages, fully separate. (2) Clean is the
  existing ~20-year full-grooming business in Ocala: legacy full grooming continues for legacy
  Ocala clients, while Clean makes a HARD PIVOT to bath only (no-haircut dogs), because haircuts
  are where cycle time drags and bath is faster and far higher revenue per hour
  (`favor_high_hourly_work`, `core_is_no_haircut_dogs`). The bath pivot starts in Ocala, where
  Paul already works, then migrates from Ocala to the Villages as the legacy book winds down.
  Destination: bath only in the Villages, by morphing the same business. CLAUDE.md and the
  parking lot updated to match.

### Database
- **Clean's Supabase project:** `dgc-prod`, ref `urebdrosrxejhubpbxsa`, region us-east-1, in
  the shared "Mount Olympus" org (org id `rnswdmikyxxukefcikui`). Project URL
  `https://urebdrosrxejhubpbxsa.supabase.co`. This is the hard-separation line
  (`own_infrastructure`): account/org may be shared with DGN, the project never is. Cost is
  $0/month in this org. Keys and DB password live only in the Supabase dashboard and a local
  `.env`, never committed.
- **v1 schema = the client book.** `public.clients` (one table for the whole book, grouped by
  `roster_group`) plus `public.dogs`. Built as a migration (`supabase/migrations/
  0001_init_client_book.sql`). Prices stored in cents (`if_payments_added_handle_money_safely`).
  Scheduling tables (services/subscriptions/appointments) and the `business_rules` table are
  the next layers, deliberately not built yet; the schema is rebuildable while it settles
  (`no_database_until_rules_agreed`, guardrail lifted on greenlight).
- **RLS on, no policy.** Both tables have row-level security enabled with no policy, so only
  the service role reaches the data until portal auth exists. Chosen because the records hold
  real PII and gate/door codes; a permissive policy must not be added without an auth model.
- **Seed is reproducible from the source of truth.** `scripts/gen_seed_sql.py` regenerates
  `supabase/seed.sql` from `legacy/data/clients.json`; re-running it fully refreshes the
  database. `legacy/data/clients.json` stays the authoritative file until the app writes
  back to Supabase.

### Infrastructure handoff (in progress)
- **Supabase secrets:** retrieved and stored in Dashlane; the `dgc-prod` DB password was
  reset to a known value (the MCP-created project never surfaced one). Secrets live only in
  Dashlane and a future local `.env`, never in git.
- **Google Cloud (done 2026-05-25):** Clean's own project `dog-gone-clean` under org
  `nickerson-paul-org` (billing attached, separate from DGN's project per `own_infrastructure`).
  Built: a browser Maps JavaScript API key locked to referrers doggoneclean.us,
  www.doggoneclean.us, hurricanebath.com, localhost:4321 and restricted to the JS API; the
  OAuth consent screen published to production; an OAuth web client with redirect
  `https://urebdrosrxejhubpbxsa.supabase.co/auth/v1/callback`; Google sign-in enabled on
  dgc-prod. Keys and the client secret live in Dashlane, not git. Remaining external deps for
  the build are Twilio (SMS + phone login) and a droplet for hurricanebath.com staging.
- **Two-key Maps architecture (locked 2026-05-25):** Clean uses two Google Maps keys, never
  one. A BROWSER key, restricted by HTTP referrer to Clean's four domains and scoped to the
  Maps JavaScript API, for displaying maps (created and locked now). A SERVER key, restricted
  by IP to the backend and scoped to the routing API (Routes API / Distance Matrix), for the
  scheduler's drive-time math, created later when the droplet's IP exists. A referrer-locked
  key cannot authenticate server calls and a REST key cannot be domain-locked in the browser,
  so the split is what keeps each key both functional and tightly restricted. Full rationale
  lives in the Oracle's `maps_js_api_only`.
- **Deploy host (verified 2026-05-25):** the shared droplet `dog-gone-engine` (DigitalOcean
  NYC1, Ubuntu 24.04, 2 GB / 50 GB, public IP 178.128.144.219) runs Caddy in Docker
  (`engine-caddy-1`, image `caddy:latest`, host ports 80/443, config `/etc/caddy/Caddyfile`)
  under a Compose project named `engine`, alongside an n8n container (`engine-n8n-1`, bound to
  localhost:5678). This is NOT Squarespace. Clean deploys here by adding its own Caddy site
  block (hurricanebath.com for staging, doggoneclean.us at launch) and a served directory,
  reusing the existing Dockerized Caddy rather than installing a second web server. DONE
  2026-05-25: hurricanebath.com staging is live over HTTPS, served from `/srv/doggoneclean`
  via a dedicated Caddy block in `/root/engine/Caddyfile` plus a read-only volume added to the
  engine Compose file (nails untouched, n8n stayed up, caddy recreated in ~1.4s). The DNS A
  record (hurricanebath.com -> 178.128.144.219) is set at GoDaddy. It currently serves a
  placeholder. The GitHub Actions deploy workflow now exists (`.github/workflows/deploy.yml`:
  build Astro, rsync `dist/` to `/srv/doggoneclean` over SSH, triggered on push to main or the
  working branch); it cannot publish until Paul adds the droplet SSH deploy key as the
  `DROPLET_SSH_KEY` GitHub secret and a `cleandeploy` user on the droplet. A minimal Astro
  homepage is scaffolded and builds clean.

### Copy / terminology
- **Always "dog grooming", never bare "grooming" (locked 2026-05-25).** Customer-facing copy
  must qualify the craft as "dog grooming" / "dog groomer"; the unqualified words carry the
  predatory connotation and undercut trust. "Groom" as a verb on a dog and "a full groom" are
  fine. Lives in the Oracle (`grooming_vocab`), CLAUDE.md terminology, and is enforced by
  `scripts/check.py` over `src/`. Homepage copy corrected accordingly.

### Auth / login (Clean)
- **Client login = Google OAuth (decided 2026-05-25).** Clean's client portal uses Google
  sign-in for seamless one-tap access, not an email-only magic-link. The reason is Clean's
  own: most clients already carry a Google account and one tap is the lowest-friction way in.
  (DGN reached the same conclusion, but that precedent is incidental, not the reason.)
- **Phone/email access-code fallback: decided 2026-05-25.** Run a phone-or-email one-time
  access code alongside Google, matching the nails portal's "Continue with Google" plus
  "Phone or email - Send Access Code" layout, so no client is locked out. Google stays the
  default; this is Clean's own portal, consistent UX, not a shared component.
- **Apple Sign In: parked,** not built now (see Parking lot). The `device_profile` no-Apple
  stance governs Paul's own devices and how ops instructions are written; offering Apple
  Sign In to CLIENTS who use iPhones is a separate product question, deferred, not banned.
- **No "owner-only login" decision exists in Clean.** Clean has no auth yet; the database is
  locked to the service role until portal auth and RLS policies are built. That is not a
  decision to keep clients out. Any "only Paul can log in / wait for clients" rule Paul
  recalls is DGN's, recorded in DGN's Oracle, not here, and must not be imported.

### Design and environment
- **Website look = Neural Expressive (decided 2026-05-25).** Clean's site follows Google's
  "Neural Expressive" design language (the Gemini app redesign from Google I/O 2026, rolled out
  2026-05-19), NOT Material 3 (proposed this session and explicitly rejected). Concrete tokens:
  vibrant blue gradient washes and soft glows, ombre/gradient fills on key words, a simple
  sans-serif with strong heading/body size contrast, an editorial hierarchy (key message big
  and bold at the top, lighter detail below), and gentle fluid motion. The expressiveness is
  color/gradient/glow, not a special typeface, so no web-font dependency. Restyle, do not
  reinvent: rebuild the existing DogGoneClean.us content in this look. Lives in the Oracle
  (`neural_expressive_design`) and CLAUDE.md "Design language".
- **Environment limit (noted 2026-05-25).** WebFetch is blocked in this remote/web session
  (403 / egress allowlist), and the live DogGoneClean.us 403s automated fetches, so external
  pages and the live site cannot be loaded here; web search and the Drive/Supabase/GitHub MCP
  tools work. To reference the live site, get screenshots from Paul. Noted in CLAUDE.md "Stack
  and commands".

---

## Decisions log (2026-05-24, continued)

### Foundation: apex and decision lenses
- **Prime directive (LOCKED).** The apex of the whole rulebook: Dog Gone Clean exists to earn
  more every year while asking less, not more, of the people who run it, and to leave everyone it
  touches better off. Seven tests: earn more grind less; runs without Paul (no lapping scheme);
  fun to work on and in; good for body and mind; a unicorn job; clients grateful it exists; the
  world better for it existing. If a rule fights it, the directive wins and the rule gets fixed.
  First section of CLEAN_ORACLE.md, with the apex line and a pointer in CLAUDE.md. Wording approved
  verbatim.
- **`elons_algorithm` (LOCKED).** Run every build/scope call through Musk's five-step order, never
  out of order: (1) make the requirement less dumb (real reason, real person, never "because DGN
  had it"), (2) delete the part or step, (3) simplify, (4) accelerate cycle time, (5) automate
  last. Guards the solo-dev-forking-DGN trap of optimizing or automating what should be deleted.
  Oracle rule + CLAUDE.md "How Paul works" pointer + index row.
- **`dig_the_moat` (LOCKED).** A decision lens on a level with Elon's algorithm, in service of the
  prime directive: does this deepen an advantage a smart AI cannot prompt past, by becoming more
  genuinely valuable (proprietary context, relationships, reputation, local density, grateful
  clients), never by lock-in? As generic business-building commoditizes, value concentrates in the
  un-promptable, so spend effort there and build the commodity layer lean. Absorbed the earlier
  proposed `the_moat_is_proprietary_context`. Oracle + CLAUDE.md pointer + a line in the
  prime-directive section naming both lenses. Tiered as a lens (not folded into the directive) so
  defense never outranks the end it protects.
- **Idea-capture workflow (LOCKED).** Ideas come into a Claude thread now, not the Drive journal.
  Paul describes the idea and the reason; the assistant chooses its home, attaches the because
  (asking one quick question if missing), commits same turn, and reports where it filed. Save
  triggers: "put it where it belongs," "capture this," "lock it in." Hold signal: "just thinking
  out loud." The Drive journal stays only as the offline fallback for mid-route capture. Baked into
  CLAUDE.md ("Recording ideas and decisions") and the Oracle's `lock_it_in_capture`.

### the_oracle_journal absorption
- **Source + split.** Paul's original voice-dictated journal on Drive (file id
  `1ENkpSA6qYPQUcWgcWQGlDI_pE0JfWmr4j3Ft9mLp55I`, entries Feb 12 to Mar 28 2026). Real business
  rules went into the Oracle; hands-on craft and equipment into the new CLEAN_FIELD_MANUAL.md; the
  rest dropped as noise.
- **New Oracle rules.** `persistent_status_update`; `no_doodles`; `income_target_caps_the_day`,
  `heads_up_on_the_way`, `lock_in_timing`, `gated_community_hours`; `cancellation_24h`,
  `favor_high_hourly_work`, `accepted_payment_methods`; `website_is_ground_zero`, `reminder_voice`,
  `appointment_block_not_window`, `language_bank`, `no_trailer_graphics`. All indexed.
- **Conflicts resolved.** Acuity reminder system superseded by the custom scheduler (content kept,
  delivery folded into `lock_in_timing`); the no-Apple rule governs Paul's own tools only, so
  client Apple Pay stays; doodles declined entirely.
- **Dropped as noise.** Doc scaffolding, the "am I writing a training manual" musing, the Gboard
  shortcuts. Aspirational equipment to-dos live in the field manual's open items.

### Hurricane Bath, showcases, and service policy
- **Hurricane Bath showcase.** Drop-in marketing content in `marketing/hurricane_bath_showcase.md`,
  drafted from Paul's account. Moat rule: sell the what, protect the how. The build (dual-pump
  core, command valve, ~10 GPM dialable, clean-water finish, flush-and-rewash) is the canonical
  proprietary record in CLEAN_FIELD_MANUAL.md, kept off the public page. Internal coyote story and
  gold lines banked.
- **`house_shampoo` (LOCKED).** One gentle house shampoo for everyone (privately: TropiClean
  papaya and mango 2-in-1); clients supply any specific, medicated, prescription, or flea product
  and Clean uses it without standing behind the result. Brand and the flea rationale stay private;
  public copy stays positive; any non-guarantee wording lives in intake/terms, not marketing.
- **`dont_knock_competitors` (LOCKED).** Never disparage other systems in client-facing copy; sell
  our own merits (competitor analysis stays private to sharpen our design). Oracle (Copy) + index.
- **Power/drying showcase.** `marketing/power_and_drying_showcase.md`, pairs with the Hurricane
  Bath (clean, then dried fast in a climate-controlled trailer). Two Predator 5000s (~a small
  house of power) feeding strong climate control and high-velocity drying; the dehumidifier-plus-
  dryer one-two punch. Field manual enriched to match.
- **Parked backlog.** Photo-to-gallery toggle (operator app marks an exceptional after-shot on the
  spot); a rotating, curated before/after gallery over a permanent archive; the pizza-tracker
  review flow (click tracking, stop asking after a review, "show someone" nudge). In
  CLEAN_PARKING_LOT.md.

### Live-site mining and payment
- **Captured.** The origin story ("Meet Paul Nickerson... The system came later. The dogs came
  first."), the homepage hero ("Grooming. No Chaos."), the taglines ("Structured. Reliable.
  Personal."), the doorstep/mobile-model copy, and the brand voice into
  `marketing/origin_and_brand.md`. Existing Hurricane Bath lines folded into the showcase language
  bank. (Paul pasted the pages; the environment cannot reach the live site, its host is not on the
  network allowlist.)
- **New Oracle rules from published policies.** `online_only_comms`, `friendly_dogs_only`,
  `core_is_no_haircut_dogs`, `service_area_ocala` (Ocala; no unpaved roads; excludes Silver Springs
  Shores, Summer Glen, Marion Oaks). Pack grooming (one household at a time, no cages) added to the
  field manual.
- **Rebuild cleanups (rules already win).** "Arrival windows" becomes "block"
  (`appointment_block_not_window`); "same-day cancellations 100%" becomes within-24-hours
  (`cancellation_24h`); drop the "they trickle" knock (`dont_knock_competitors`).
- **Payment RESOLVED.** Public list is the journal's: cash plus Visa, Mastercard, Amex, Discover,
  Apple Pay, Google Pay, Samsung Pay, all via Square. No checks. PayPal and Cash App exist but are
  not advertised. `accepted_payment_methods`, `bills_in_person_today`, and CLAUDE.md updated to
  match; the live site's PayPal mention gets dropped on rebuild.

---

## Decisions log (2026-05-26)

### Hurricane Bath v2.0 plan reconciliation (RESOLVED 2026-05-26, reconfirmed during the scroll reconciliation)
- **One business, two URL surfaces.** Dog Gone Clean is the business. Hurricane Bath
  (hurricanebath.com) is the new bath-only, subscription-default v2.0 surface. Legacy
  doggoneclean.us is the existing Squarespace surface for full-grooming clients, sunsetting
  eventually. They converge later; for now they coexist with the String of Pearls scheduler
  shared between them as a service. This supersedes the 2026-05-24 "preview on
  hurricanebath.com until doggoneclean.us flips at launch" framing, per `reality_wins`.
- **Online payment for Hurricane Bath only.** The 2026-05-24 decision "online deferred until
  it earns its place" still applies to legacy doggoneclean.us, which stays on Square.
  Hurricane Bath launches with Stripe card-on-file plus auto-charge at the 24-hour mark, per
  the new `card_on_file_at_signup` and `auto_charge_at_24h` rules. `bills_in_person_today`
  and `accepted_payment_methods` are rewritten as surface-scoped (legacy = Square, v2.0 =
  Stripe), not deleted.
- **DGN's skip and reschedule policy is ported verbatim** for Hurricane Bath per Paul's
  "use the dgn policy" instruction. Source: DGN `SCROLL_OF_HEPHAESTUS.md` sections 6.2 to
  6.8 and DGN `ORACLE.md`. Skip and reschedule are distinct curves: a paid skip jumps in
  one step to the single-visit rate, while a reschedule beyond grace steps up weekly.
- **Subscription-default, one-off allowed** (locked during the 2026-05-26 reconciliation).
  Hurricane Bath sells recurring (4wk default, 2wk freshness upgrade at the same price); a
  single one-off bath is allowed at +$20 above the recurring first-dog rate per tier
  (`single_oneoff_higher`).
- **data/ moved to legacy/data/.** These records are the legacy Ocala client book and
  belong to the legacy doggoneclean.us surface; the v2.0 surface gets its own subscriber
  data in Supabase. `scripts/check.py`, `scripts/gen_seed_sql.py`, and CLAUDE.md updated
  to point at the new path.

### Rules captured into the Oracle (24, one commit each, originally on `claude/inspiring-mayer-ionnB`, folded into main during reconciliation)
- Product scope: `bath_only_no_mats`, `villages_only_at_launch`, `three_dog_cap`,
  `premium_inclusive_no_addons`.
- Pricing: `breed_tier_pricing`, `cadence_4wk_or_2wk_same_price`, `single_oneoff_higher`,
  `tiered_founders_rate`.
- Money flow: `card_on_file_at_signup`, `auto_charge_at_24h`, `card_expiry_60_30_7`,
  `within_24h_non_refundable`, `no_show_pause_at_two`.
- Skip and reschedule (ported from DGN canon): `one_free_skip_per_52w`,
  `free_skip_keeps_maintenance_rate`, `paid_skip_resets_next_visit_to_single_rate`,
  `five_week_grace_returns_to_maintenance`, `reschedule_step_up_weekly`,
  `reschedule_two_paths_for_recurring`.
- UX: `no_reason_field_ever`, `stop_sign_two_taps`, `octane_selector_cadence_picker`,
  `calendar_shows_price_per_date`.
- Engineering: `string_of_pearls_is_a_service`.

### Parking-lot adds (earlier on 2026-05-26, on `main`)
- Breed Firewall coat-eligibility classification (draft) for who the bath-only model
  accepts; needs work before intake/copy/code use.
- Two-tap cancellation idea: locked the same day as `stop_sign_two_taps`; the parking-lot
  entry now points to the locked rule.
- Marketing copy kernel: shedding interception via the two-week routine. Holds until the
  copy pass.

### Open decisions (captured in CLEAN_PARKING_LOT.md)
- Cycle time per appointment (1hr placeholder; Paul measures in Villages).
- Tier slug names (smoothcoat / doublecoat recommended; Paul may rename).
- Breed list refinement (first attempt seeded for Phase 4; Paul iterates).

### Paul-actions deferred from these sessions
- Grant this environment access to the `doggonenails-site` repo so a future session can
  fork the DGN structure.
- Create the new Dog Gone Clean Stripe account and hand over the publishable + secret keys.
- Twilio account, number, and A2P registration (SMS + phone login).
- Already done (do NOT re-do): `dgc-prod` Supabase project exists; Google Maps key
  domain-locked to hurricanebath.com and the Clean domains; Google sign-in enabled; GitHub
  default branch is `main`; stale `claude/*` branches deleted; CI/deploy on Node 24
  action versions ahead of the 2026-09-16 Node 20 removal.

### Recovery from compounded bad sessions (afternoon)
- **The "Claude says it changed, I don't see it" symptom traced to a transient GitHub 403
  on `git clone`.** Cause was outside the code (all repo Actions settings correct, all
  prior workflow file changes correct), resolved by a single Re-run of the latest failed
  deploy from the Actions UI. Eight commits caught up at once when the queue cleared.
- **Two new Oracle rules locked:** `recovery_from_a_bad_session` (process: the next
  session walking into prior-session damage listens first, verifies from disk not from
  prior-session claims, treats prior commit messages as unreliable witness, stops on
  Paul's "loop" stopword) and `transient_ci_rerun_first` (engineering: re-run a failing
  pipeline once before pushing a fix-commit; pushing compounds). Both indexed.
- **Node 20 action deprecation cleared.** `actions/checkout@v4` -> `@v5` and
  `actions/setup-node@v4` -> `@v5` in `deploy.yml` and `audit.yml`; both v5 versions run
  on Node 24. Verified green end-to-end on the new versions. Cleared well ahead of the
  2026-06-02 forced upgrade and the 2026-09-16 removal.
- **Pipeline sanity-tested with a homepage section swap.** Hurricane Bath section now
  precedes "Why Paul built it" instead of following it. Edit -> commit -> deploy -> live
  loop confirmed working.
- **CLAUDE.md updated** to fix the stale "awaiting `DROPLET_SSH_KEY`" build-gate paragraph
  (deploy publishes; `audit.yml` runs `check.py` in CI) and to reference the two new rules
  in "How Paul works" and "Stack and commands".
- **Three small live-site bugs parked** for the next site-touching session: `/portal/`
  links 404 on the homepage CTAs (Client sign in + Book a visit); dead
  `PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD` env var in `deploy.yml`; unused CSS classes
  (`.chips`, `.chips li`, `.services`) in `index.astro`.

## Decisions log (2026-06-07)

### Endless-load on /portal traced to a paused project, plus a permanent guard
- **Root cause: `dgc-prod` was paused (free-tier auto-pause).** A returning visitor
  with a stored session triggers a token refresh on load; against a paused project that
  call hangs, so `onAuthStateChange` never fired and the portal sat on its checking
  spinner forever. Restored the project. Added a `withTimeout` reachability guard
  (`supabase.js`) and a watchdog in `PortalApp` so an unreachable backend now shows a
  retry card instead of an infinite spinner. Paul will move to Supabase Pro before the
  first real client; until then the free tier keeps auto-pausing and the portal goes dark
  when it does.

### Client portal built out to full self-service (migrations 0011-0016)
- The portal went from an auth shell + placeholder to a real account surface: Home
  dashboard (next visit, plan, pack, details, history); pause / restart / cancel
  (`0011`); reschedule + skip a visit against live open slots (`0012`); change cadence
  4wk<->2wk at the same price (`0013`); pack management with the cap as a trigger
  (`0014`, later lifted); edit contact details + a tightened subscriber-update path
  that closed a broad self-update RLS hole (`0015`); and a verified service-address
  change reusing the booking in-area gate (`0016`). Every action's teeth live in a
  SECURITY DEFINER RPC or trigger scoped to `auth.uid()`, anon revoked. A test
  subscriber (`is_test`) on Paul's login exercises every screen.
- **Two real inputs still gate launch:** The Villages needs a published visit duration
  (`hb_slot_minutes`) + availability windows before the reschedule picker and booking
  funnel can offer slots; Stripe (card-on-file, payments) stays parked per Paul.

### three_dog_cap lifted (decision, migration 0017)
- **Decision (Paul, 2026-06-07): drop the hard 3-dog cap on the bath surface.** The 3
  was the Villages residency limit borrowed as a default, never a Dog Gone rule. The
  bath pivot starts in Ocala, where it does not apply, and real clients exceed it (one
  with 5 dogs, one with 4, most one or two). Lifted in the three durable places: the
  pack trigger (dropped), the `bath_appointments.dog_count` CHECK (now `>= 1`), and the
  `bath_start_subscription` guard (now `>= 1`), plus the booking counter and portal Add
  control. Pricing already computes per dog (each additional at the prior rate minus the
  $20 decrement) and scales with no change. The real limit is visit time / route
  capacity, which belongs in scheduling, not a count constraint. Oracle `three_dog_cap`
  and the index rewritten; key kept for sync. The legacy Ocala book (`clients`/`dogs`)
  was never capped and is untouched.

### Squarespace + Acuity retired; legacy folds into Clean v2 (decision, 2026-06-07)
- **Decision (Paul, 2026-06-07): kill the legacy doggoneclean.us Squarespace site and the
  Acuity scheduler within days; legacy full-grooming clients become first-class clients
  inside the one Clean app.** Same login, same self-scheduling and account management a bath
  subscriber has, not a separate portal and not a reduced mode. doggoneclean.us redirects into
  the app. Recorded as Oracle `legacy_folds_into_v2`; supersedes the 2026-05-26 "two URL
  surfaces, legacy rebuilt later" framing per reality_wins.
- **The unlock: per-client block time is known.** Paul has years of appointment data showing
  the real cycle time for every client, so the scheduler can block each grooming client's
  actual duration instead of a fixed bath slot. That is what lets full-groom clients
  self-schedule in the same engine. Source of that data still to be wired (Calendar / Drive /
  Acuity export); it is the gating input for grooming scheduling.
- **Payment decoupled from the cutover.** Acuity's death is not Square's death. Legacy keeps
  paying in person via Square through the cutover; card-on-file for legacy is a deferred,
  separate decision. So the days-deadline scope is scheduling + self-management + reminders +
  the website fold, not payment.
- **Reminders are load-bearing and net-new.** Acuity sends the legacy appointment reminders
  today, so reminders must exist in the app before Acuity is cancelled or clients no-show.
  n8n on the shared droplet is the planned reminder host.
- **Cutover safety: export before cancel.** Acuity holds the live forward schedule and any
  intake data; that vanishes on cancellation. Pull the appointment-history / future-bookings
  export before pulling the plug. The client roster itself is already reconstructed in
  `legacy/data/clients.json`, so the gap is the forward schedule and durations, not the names.
- **Planned model (to verify against the data):** one generalized recurring-service relation
  with a service type (bath or full groom), a per-visit block duration, a cadence, and a
  payment method; bath = Stripe card-on-file + fixed duration, grooming = in-person Square +
  historical per-client duration. Next steps: generalize the subscription/appointment schema,
  load the legacy book + durations, build the reminder job, fold the site and redirect the
  domain.
- **Model refinements (Paul, 2026-06-07), folded into `legacy_folds_into_v2`:** (1) service
  type is full groom / bath / **nails**, not just bath/groom; the short-cycle legacy entries
  (Lisa Prater, Nancy Franklin, Patty Brown, Steve Crandall, Garret Little) are nails clients
  and their short blocks are correct. (2) **Recurring-versus-not is a real recorded per-client
  attribute, never inferred from visit counts** (standing = recurring; one-off / at-will =
  not). This corrects the prior session's lean that grooming clients are all recurring. (3)
  Block time is on-site time (median cycle); the route engine calculates actual inbound drive
  time per stop separately. (4) Every legacy client is kept and carried in; none dropped.
- **Data-model fork resolved (Paul chose Option 1, 2026-06-07): generalize the live engine.**
  The DB has two table families: the working bath_* operational stack (account/auth,
  subscriptions, appointments, scheduler, portal RPCs, React islands) and the richer but
  non-operational legacy `clients`/`dogs` book (already encodes roster_group = recurrence and a
  service_type that lists groom/bath/nails, but empty in prod, no login or appointments). Paul
  chose to widen the bath_* stack in place rather than rebuild on `clients`, because the
  scheduler/portal machinery already works and the days deadline makes reuse the right call;
  the bath_ table names are kept and a rename is a deferred cosmetic (teeth live in columns).
  **Migration 0018 applied to dgc-prod and committed:** bath_subscriptions and bath_appointments
  now carry service_type (full_groom/bath/nails), payment_method (stripe_card/square_in_person),
  per-visit block minutes, cadence_days, and is_recurring; bath_subscribers gains client_id (FK
  to the legacy CRM record) and is_legacy. Additive and non-destructive: the one live bath
  subscription and its appointments back-filled to bath / stripe_card / recurring with cadence
  preserved, so the booking flow is unaffected. get_advisors after the DDL showed no new issues.
  Next: generalize bath_start_subscription and the slot engine for per-client duration + nails/
  groom, load the legacy book + cycle-time durations, build the n8n reminder job, fold the site
  and redirect the domain.
- **Legacy book loaded into prod + Ocala added as a city (2026-06-07).** Ran the seed from
  `legacy/data/clients.json` into the empty `clients`/`dogs` tables: 47 authoritative records
  (33 standing, 11 one-off, 2 at-will, 1 banned-with-exclude) + 61 dogs, verified by count. The
  cycle-time sheet (51 names) reconciled cleanly against all 46 active roster records (banned
  Bonnie correctly absent), surfacing 5 names in the sheet but not the roster: Shane Smith, Jane
  Henrich, Amanda Posner, Billye Mallory, Edely Abreu. Asked Paul before reconciling (his
  standing instruction); he said add all 5, so they went in as `one_off` records carrying their
  cycle-time facts (visits, last visit, on-site block, avg charged) with explicit `data_gaps`
  for service address / dogs / service type / cadence / one-off-vs-standing, since their contact
  details are unverified. Roster now 52. Also established (data-confirmed) that the entire book
  is Ocala and nearby Marion County, and added **Ocala** to `cities` (slug 'ocala', center set,
  hb_active false until its polygon/pricing/slot exist). Two new rules: `ocala_is_a_served_city`
  (pivot-origin city, updates `villages_only_at_launch`) and `new_ocala_clients_are_v2_only`
  (new Ocala signups are bath-only; legacy groom/nails grandfathered, book closed to new
  entries). The consumer-copy rule `villages_only_in_copy` (check.py bans "Ocala" on the
  marketing pages) is left untouched, pending Paul's call on how Ocala is marketed. Still
  pending for the 5 added names and for scheduling: pull their contact sheets to fill the gaps,
  and attach per-client block times once a `visit_minutes` home is added.
- **Per-client block times attached (2026-06-07, migration 0019).** Added
  `clients.visit_minutes` + `visit_minutes_confidence`, seeded from the new
  `legacy/data/block_times.json` (median on-site cycle per client, derived from
  `cycle_times.md`; akas resolved, confidence by visit count, banned client null).
  `gen_seed_sql.py` now emits both columns so a fresh load carries them. Prod updated:
  51 of 52 clients have a block time (11 to 395 min), only banned Bonnie null. This is the
  scheduling unlock from `legacy_folds_into_v2`: the engine can now reserve each client's real
  minutes. Lisa Prater (11 min, mixed groom/nails) flagged low-confidence; her groom visits
  need a per-visit override.
- **Open idea, pending Paul's decision (raised 2026-06-07): gate new Ocala clients by drive-time
  to an anchor instead of a polygon.** A new Ocala address qualifies if it is within a 15-minute
  drive of an existing legacy anchor stop, excluding the exception clients Paul serves as favors
  (Tonya Hunt in Williston, Greta Custer's Dunnellon outlier). This deletes the polygon data-gap
  so Ocala can open now, and makes the service area a living function of route density that
  auto-contracts as the book shifts to the Villages. Open decision before building: do new bath
  clients also become anchors (organic growth, with each anchor toggleable, plus a manual
  force-approve) or stay pinned to the legacy seed set? Recommended the former. Not yet captured
  as a rule; build once Paul decides the anchor-growth question.

### Ocala drive-time service-area gate built (2026-06-07, migration 0025 + edge function)
- Goal Paul restated firmly: keep serving legacy AND take new bath clients in Ocala, but only when
  they are within 15 minutes' DRIVE of an existing client, so a new stop fits a day he is already
  nearby. First attempt used straight-line (crow-flies) distance: wrong metric, it ignores roads
  and his schedule. Reverted (the haversine + crow-flies function are dropped; `ocala_service_area_by_anchor`
  in the Oracle already specified drive time, so the Oracle was right and the code was the drift).
- Built the real gate as the `ocala-service-area` Supabase edge function: real Google Distance
  Matrix drive time, server-side so anchor homes never leak, driving duration to the nearest
  anchor, returns only { within, minutes }. Added `clients.geo_lat/geo_lng/is_anchor`; anchors are
  the recurring backbone (standing + at-will), with the favor/outlier clients (Tonya Hunt, Greta
  Custer) flagged out so they do not stretch the area: 33 anchors.
- Implementation simplified after testing: the function feeds the 33 anchor ADDRESSES straight to
  Distance Matrix (Google geocodes them internally), so only the Distance Matrix API is needed, NOT
  Geocoding. Paul made a Distance-Matrix-restricted server key; since this environment has no tool
  to set a function env secret, the key is stored in `public.app_secrets` (RLS on, no policy, only
  the service role reads it) and the function reads it there. Verified live end to end the same day:
  "Ocala, FL" gives within=true (0 min), "Miami, FL" gives within=false (266 min), all 33 anchors
  resolved. Gate is LIVE and callable. Still parked before Ocala actually opens: the containment
  perimeter polygon (so edge anchors cannot breadcrumb the area outward) ANDed with the gate, wiring
  the booking funnel + bath_start_subscription, then flipping Ocala hb_active on.
- 2026-06-07 (later, no-workarounds pass): Paul enabled the Geocoding API and we did it the clean
  way. Geocoded the 33 anchors once and cached their real coordinates on `clients.geo_lat/geo_lng`,
  so the function now routes on coordinates (it already preferred coords over addresses); all 33
  resolved. Re-verified: "Ocala, FL" within=true (0 min), "Belleview, FL" within=true (10 min),
  "Miami, FL" within=false (266 min). Addresses stay the fallback if coords are ever missing, so a
  fresh DB rebuild still works before any re-geocode. Also enabled Places API (New) for the future
  booking-form autocomplete.
- 2026-06-07 (perimeter added): Paul named the breadcrumb hole in the anchor model: an edge client
  becoming an anchor would let the 15-minute gate walk the area outward forever. Fix is a frozen
  containment perimeter ANDed with the drive-time gate. Paul hand-drew the fence on geojson.io
  around his outermost clients (I handed him a GeoJSON of all 33 as pins to draw around). 3 clients
  were clipped by his southern edge, so the south line was nudged down about 1 mile to take them in
  plus a cushion; all 33 now inside. Stored in `public.service_perimeters` (slug 'ocala', GeoJSON,
  migration 0027, public-readable). The `ocala-service-area` function now geocodes the address,
  refuses anything outside the fence, then runs the drive-time check. Verified: Ocala center and the
  southern pocket accepted; Belleview REFUSED (10-minute drive but outside the fence, the proof the
  cap works); Gainesville refused. Oracle `ocala_service_area_by_anchor` corrected from
  drive-time-only to the drive-time + perimeter hybrid (reality wins over the old "no polygon" line).
- 2026-06-07 (Acuity/Squarespace teardown scoped): Squarespace's job is already done better by the
  app, so the live question is Acuity. Acuity's jobs are: hold the recurring schedule, let clients
  self-manage (the portal already does reschedule/skip/cancel/cadence), email confirmations and
  reminders, and Google Calendar sync. Grounded check: the portal management engine and the
  recurring-service schema (`bath_subscriptions` / `bath_appointments` carry `service_type` +
  `payment_method`) are built, but 0 legacy clients exist as subscriptions (only the bath test
  account), no notification function exists, and no calendar sync exists. Decisions: reminders are
  EMAIL only to match Acuity (which only emails); SMS/Twilio deferred and NOT on the teardown path
  (do not keep raising it). Build list + Paul-action checklist parked under "Acuity + Squarespace
  teardown"; the immediate Paul action is verifying `service@doggoneclean.us` as a Resend sender.
- 2026-06-07 (legacy email templates drafted + saved): worked the legacy full-grooming
  notification emails from their real source, not from scratch. Found DGN's built
  `send-notification` (the canonical template set) and started from Paul's actual Acuity copy
  rather than inventing. Saved to `legacy/notifications/email_templates.md` (DRAFT): booking
  confirmation, 72h / 26h / 6h reminders, cancellation, reschedule. Standards locked: in-person
  payment, `cancellation_24h` "billed in full" (NOT the bath "non-refundable"), the time is a
  "block" (`appointment_block_not_window`) expressed as a real `{start_time} to {end_time}` span
  now that the system stores `scheduled_end`, a "the block is when the work gets done, not a
  wait-around arrival window" clarifier on every block mention, and the old Acuity breathing-room
  line dropped. Open and flagged in the file: whether `lock_in_timing` (bath rule) lets the
  legacy 26h reminder keep the cancellation line; second-person vs canon third-person tail; and
  an on-my-way/ETA and a review-ask message still to come from Paul. Nothing sends until
  `service@doggoneclean.us` is a verified Resend sender.
- 2026-06-07 (client reminder preferences, migration 0034 + portal UI, Paul's idea): a portal screen
  where a client picks which reminders they want and on which channel. Three layers, all shipped:
  (1) `notification_preferences` table + two SECURITY DEFINER RPCs (`bath_get/set_notification_prefs`,
  scoped to the caller via auth.uid(), whitelisting the three reminder keys); (2) the dispatcher
  (send-notification v2) now resolves channels from prefs (reminders follow the toggles, default email
  on; confirmations/cancellations/reschedules always email), with the SMS channel logging
  twilio_not_configured until Twilio; (3) a Reminders card in the portal home (PortalViews
  `NotificationsSection`) with Email/Text checkboxes per reminder (3 days before, the day before, day
  of), saved on each toggle. Verified: RPC merge/whitelist logic, dispatcher resolves the email
  default and returns the per-channel result, and the site builds with /portal compiling. SMS is
  captured but dormant. The full logged-in render still wants an in-browser check.
- 2026-06-07 (notification dispatcher built + verified, migration 0033): the Acuity reminder
  replacement. Ported DGN's `send-notification` to Clean: retargeted to the `bath_*` tables,
  email-only, in-person (no card/charge language), rendering the legacy templates (booking
  confirmation, 3-day / 26-hour / day-of reminders, cancellation, reschedule) with the block as a
  start-to-end span and the "not a wait-around arrival window" clarifier. 0033 added
  `notification_log` (idempotency: partial unique index on dedup_key where status=sent, so a double
  send is impossible). Secrets (`notifications_secret`, `resend_api_key`) live in `app_secrets` since
  this env cannot set function env vars. Fail-closed: with no Resend key it logs
  "skipped: resend_not_configured" and sends nothing, so it stays dormant until cutover and cannot
  double-send against Acuity. Verified live against Barbara Lape's real Fri 6/12 4-6pm appointment:
  rendered the full legacy confirmation correctly and skipped the send. Remaining notification work:
  the hourly cron watcher (mirror DGN `notifications-cron`, but for Clean's 3d/26h/6h timings) to
  trigger reminders, wiring confirmations to the booking/reschedule/cancel paths, and Paul's Resend
  sender + key (`service@doggoneclean.us`) to switch sending on.
- 2026-06-07 (first calendar backfill, migrations 0031 + 0032): proved the calendar-to-app import on
  real data. 0031 added `bath_appointments.source` + `external_id` with a partial unique index, so an
  imported appointment is keyed by its upstream id (Acuity id, or the gcal event id for Paul's manual
  recurring entries) and re-imports never duplicate. The import then hit `bath_appointments_no_overlap`,
  a global no-overlap exclusion (a bath-model assumption) that rejected Ginger Fink 5-7pm overlapping
  Michelle Reiners 6-9pm, real padded blocks. 0032 scoped that guard to app-native bookings only
  (`source is null`); imported legacy blocks are exempt because their overlap is real and the app
  mirrors it (`schedule_mirrors_real_bookings`). Backfilled this week's 13 standing-client appointments
  from Paul's Google Calendar, matched by name to clients, prices pulled from each client's real
  per-dog book (Lisa Irwin 2 dogs $180, etc.), service types correct, both overlapping NE-evening
  appointments preserved. Follows: extend to the full 28-day horizon, add the one-off clients (their
  client rows exist, need subscriber rows), capture per-visit service_type from the calendar title
  (Lisa Prater's nails-vs-groom visit), and build the durable automated sync, which needs Paul's
  one-time Google Calendar connection (OAuth or calendar-share-with-service-account).
- 2026-06-07 (scheduling model + terminology locked, per Paul): two Oracle rules added.
  `schedule_mirrors_real_bookings`: the app shows the REAL booked appointments imported from Paul's
  calendar (keyed by Acuity ID), never appointments synthesized from cadence; `cadence_days` is only
  a due/overdue signal that assists the next rolling booking. Because auto-booking everyone by
  frequency manufactures the collisions Paul avoids by booking one ahead and only far out when it
  fits. Confirmed by reading his Google Calendar: it carries every real booking with Acuity IDs,
  times, dogs, and prices, plus one-offs and his own manual recurring entries; so "generate
  appointments" becomes "import from the calendar" and merges with the Google Calendar sync (calendar
  is the source before cutover, the app writes back after). `clients_not_subscribers`: legacy clients
  are clients with a recurring schedule, not subscribers (they pay in person, subscribe to nothing);
  the `bath_*` table names are a DGN-fork artifact pending rename; never surface "subscriber" in copy
  or UI.
- 2026-06-07 (Ocala availability loaded): first build move of the Acuity teardown, done with no
  input needed. Loaded the real working grid into `bath_availability_windows` for Ocala: Tue-Sat,
  noon to 8pm (weekday 2-6, 12:00-20:00), days addable, migration 0028, verified 5 rows. Grounding
  the book migration surfaced that it needs a small SCHEMA change first, not just a data load:
  `bath_subscriptions.cadence` only allows 4wk/2wk/oneoff while the book runs q14-q98 (so the real
  value must live in `cadence_days`), and the base-price-plus-decrement model cannot hold legacy
  per-dog full-groom prices (`bath_dogs` has no price column). Plan: make cadence nullable with
  cadence_days authoritative, add `bath_dogs.price_cents` for per-dog legacy prices, then migrate
  the standing/at-will book from `clients.json` (cadence, per-dog price, service_type, dogs,
  payment_method=square_in_person), flagging the ~5 clients the route template marks pending.
- 2026-06-07 (legacy book loaded into the app): the move that makes Acuity droppable. Migration 0029
  fit the schema (cadence nullable so `cadence_days` is authoritative; added `bath_dogs.price_cents`
  for legacy per-dog prices). Migration 0030 loaded all 33 standing clients straight from
  `public.clients`/`public.dogs` (real client_id links, no name-matching): one `bath_subscribers`
  row each (unclaimed, so the 0024 claim flow ADOPTS it on login), one active recurring
  `bath_subscriptions` with real `cadence_days`, in-person payment, and per-visit price, plus 61
  `bath_dogs` with per-dog prices. Verified: 33 subscribers, 33 subscriptions, 61 dogs, none priced
  at $0; service split full_groom 29 / nails 3 (Steve, Nancy, Patty) / bath 1 (Debra); Lisa Prater's
  mixed mapped to full_groom; Steve ($65 for four) and Patty ($45 for two) set as bundle totals.
  at_will (Karen, Garret) and one_offs intentionally left out (not the recurring book). Next: generate
  upcoming appointments on the Tue-Sat grid so a logged-in client sees real visits.
- Paul: "go for number 1" (legacy login). Legacy clients live in `clients`, not `bath_subscribers`,
  so a sign-in dead-ended at the empty portal. Built `bath_claim_legacy_account()`: matches the
  verified sign-in identity (phone last ten digits from the JWT, or email) to a clients row and
  creates or adopts a linked `bath_subscribers` row (client_id + auth_user_id), copying name,
  address, and Ocala city. An already-claimed record is never handed over; a repeat claim is a
  no-op. Wired into `getPortalData` (supabase.js): a first sign-in with no subscriber row attempts
  the claim, then re-reads. Added `clients.phone_e164` + `clients.email` as the match targets.
  Verified end-to-end in a rolled-back transaction (seeded client + fake auth user + simulated
  JWT): phone match returned claimed with the linked row carrying the client's name, address, and
  Ocala; a second call returned already_linked.
- Step 2 backfill done (2026-06-07): pulled contact info from the Acuity calendar feed and matched
  by name to the clients book. A first pass (Jun to Aug 2026) covered 27, then a wider pass (Jan
  2025 to Dec 2026, searched per name) brought it to 44 of 51 active clients now login-ready (phone
  or email on file). Also corrected two names the book had typo'd against the calendar and filled
  their real contact: Colleen Smith (book had "Coleen") and Garret Little (book had "Garrett"; his
  Acuity bookings and email garretllittle@gmail.com confirm one T, fixed in the DB, clients.json,
  seed.sql, the legacy data/source files, and the one mis-titled Google Calendar event). The 7
  clients with no contact on file (Brooksley Sheehe, Chester Weber, Cynthia Tieche, Ligia Amyotte,
  Lisa Irwin, Mary Jane Hunt, Tonya Hunt) are blank BY PAUL'S INTENT, not a gap: per
  contact_omitted_is_intentional he left their phone/email off so the system never auto-messages
  them, since they run on his standing schedule and do not need the portal; Edely Abreu and Eric
  Shannon have email but no phone. Phone stored as +1 E164, email lowercased, both filled only
  where empty so nothing was overwritten. Kristin Nickerson was a test row (Paul's wife), ignored.
- Ocala availability (number 2) captured, not yet built: every other week Tue-Sat anchored on the
  week of Monday June 8, 2026, plus manual extra days and brief off-week trips
  (`ocala_availability_every_other_week`). Confirmed against Paul's calendar: the week of June 8 is
  a packed Ocala week (about 15 stops Tue-Sat), the next week drops to a couple (the Cummings
  off-week trip). The recurring windows + every-other-week generator are the next build.

### schedule_by_client_history implemented on Clean (2026-06-07, migration 0023)
- Paul: "schedule based on guess for a new client, then historical duration for the exact client
  in the future. go." Built `clean_effective_duration_minutes(subscriber_id)`: returns the linked
  legacy client's `visit_minutes` when present (the exact client's history), else the coat-tier
  bath default (smoothcoat 30 / doublecoat 60), floored by the city minimum stop (30). Wired into
  `bath_reschedule_appointment` (a known client re-books at their real length) and into
  `bath_start_subscription` (a new client's first appointment uses the guess; the appointment now
  also stamps service_type, payment_method, duration_minutes). This also repaired booking, which
  had broken when durations moved from the single `hb_slot_minutes` to per-tier minutes (the old
  RPCs keyed off the now-null `hb_slot_minutes`). Verified in a rolled-back transaction: a new
  (unlinked) subscriber returns 60 (its doublecoat guess), linked to Kevin Cummings returns 395,
  linked to Steve Crandall returns 53 - the exact per-client history. DGN side next.
- **Ocala anchor decided + foundation built; notification path corrected (2026-06-07).** Paul:
  do the Ocala anchor, new clients become anchors. Locked as Oracle `ocala_service_area_by_anchor`
  (15-min drive to an anchor; new bath clients anchor by default, toggleable, plus manual
  force-approve; exception clients flagged out), replacing the polygon requirement for Ocala
  only. Migration 0020 added `clients.geo_lat/geo_lng/is_anchor` + `bath_subscribers.is_anchor`;
  designated 31 legacy anchors (33 standing minus Tonya Hunt and Greta Custer, both carrying
  "anchor": false in clients.json so a reseed preserves it); gen_seed emits is_anchor. Verified
  in prod (31 anchors). Paul also corrected the notification path: confirmations and reminders
  run from Clean's own Supabase (scheduled edge function on pg_cron, mirroring DGN
  send-notification), NOT n8n (n8n is later automation) - captured as
  `confirmations_and_reminders_via_supabase` and folded into `legacy_folds_into_v2`. Remaining
  to make the gate live (verify-blocked here, needs the key): enable Distance Matrix on Clean's
  existing Maps Cloud project (MAPS_BROWSER_KEY in maps.js), run a one-time geocode of the 31
  anchors into geo_lat/geo_lng, then wire the client-side drive-time check into the Ocala booking
  gate and verify in dev. Also still needed to open Ocala: bath pricing + slot minutes.
- **Slot engine made duration-aware (2026-06-07, migration 0021).** bath_open_slots gained a 4th
  arg p_duration_minutes: it reserves the requested per-client block on a 15-minute start grid,
  falling back to the city bath slot when omitted (so the bath funnel's 3-arg call is unchanged).
  Because block lengths now vary, the unique-on-start index was replaced with a gist no-overlap
  exclusion constraint over live appointment time ranges (btree_gist). Verified against a
  throwaway active city: a 45-min request returns 45-min blocks (90 slots), 179-min returns
  179-min blocks (63 slots), no-duration returns the city 60-min slot (87 slots). The bath flow
  is unaffected (Villages has no slot minutes or windows set, so it offered nothing before or
  after). Next slice to make legacy clients bookable: generalize bath_start_subscription to take
  service_type, payment_method, and the per-client duration (from clients.visit_minutes) so a
  groom or nails appointment is created with its real length and in-person payment.
- **Bath prices/durations, min stop block, nails durations clarified (2026-06-07).** Confirmed
  to Paul that all rules this session live in durable layers (DB columns, CHECK + exclusion
  constraints, SECURITY DEFINER RPCs, seeded data files), not page code, so they survive a
  website redesign; the Oracle is the rulebook and the index maps each rule to its DB home.
  Paul's bath inputs, set durably (migration 0022 + city data): bath starting durations 30 min
  smoothcoat / 60 doublecoat (`bath_starting_durations`), a 30-min minimum stop block
  (`minimum_stop_block`, floors Lisa Prater's 11-min median), and Ocala bath prices copied from
  The Villages (`ocala_prices_match_villages`). Nails stop durations answered from the cycle
  data: Franklin 35 (1 dog), Prater 11 (1 dog, floored to 30), Little 64 (2 dogs), Crandall 53
  (4 dogs); the data does not scale with dog count, so per-client history beats a dog-count
  formula. Garret Little's 2-dog count recorded (names/breeds still a gap). Ocala stays
  hb_active false until the anchor gate is wired; prices and durations are no longer gaps.
- **Scheduling philosophy locked on Clean (2026-06-07): schedule by client history.** Verified
  the nails dispute against Paul's source sheet (Time is Money, full CSV, 1,214 rows): Lisa
  Prater is cleanly bimodal (two full grooms at 45/59 min $75, nine nails at 5-11 min $30), and
  Crandall (37 visits all $65, median 41) and Little (median 33) are pristine. My earlier
  "implausible / data artifact" framing was wrong: I trusted a blended median over the source.
  Pulled two more nails clients for spread (Diana Boos 2 dogs median 26; Suzette LaVallee 2 dogs
  median 25). Derived nails starting average ~15 one dog / ~25 two-three / ~40 four, which
  matches DGN's existing service_duration_table and the real data. Locked Oracle
  `schedule_by_client_history`: schedule each client for their own historical on-site time
  (clients.visit_minutes), falling back to the derived average only for a client with no track
  record yet. CONFLICT FLAGGED FOR PAUL on the nails (DGN) side: DGN's service_duration_table
  says service time is fixed by dog count and "never adjusts... fixed times keep both sides out
  of the loop" (anti-shaming) - the per-client override reverses that, so it is not yet written
  into DGN pending Paul's decision on whether to supersede it and how to keep the anti-shaming
  intent (e.g. route on real time without surfacing it as a judgment in the operator app).
