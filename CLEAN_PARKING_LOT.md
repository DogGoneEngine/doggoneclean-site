# CLEAN_PARKING_LOT - Dog Gone Clean

Deferred work and forward-looking ideas, parked so they survive a context reset. Nothing
here is committed work; it is the backlog. Move an item into CLEAN_SCROLL_OF_HEPHAESTUS.md's focus block
when it becomes active.

## Cutover follow-ons - legacy fold (2026-06-07)

The legacy-fold cutover (legacy_folds_into_v2) is mid-build. Open threads, parked so they
survive a reset:

- **Reminders + confirmations on Supabase.** Net-new and load-bearing: Acuity sends the legacy
  reminders today, so a Supabase scheduled edge function (pg_cron + SMS/email, mirroring DGN
  send-notification) must exist before Acuity is cancelled or clients no-show
  (confirmations_and_reminders_via_supabase). n8n is deferred.
- **Legacy client login: done for who needs it; the rest are intentional.** Mechanism built +
  verified (`bath_claim_legacy_account`, migration 0024). Calendar backfill (2026-06-07) brought
  44 of 51 active clients to login-ready. The remaining no-contact clients are NOT a backfill TODO:
  per `contact_omitted_is_intentional`, Paul left their phone/email off on purpose so the system
  never auto-messages them; they run on his standing schedule and do not need the portal. Add a
  client's contact only when a real need appears (they ask for the portal or go irregular). Edely
  Abreu is going inactive; Eric Shannon gets a phone later only if needed. On-demand only: reconcile
  the active Acuity roster (a few current clients are not in the book) if one needs to self-serve.
- **Enter Ocala availability + every-other-week generator.** Spec captured
  (`ocala_availability_every_other_week`): every other week Tue-Sat anchored on the week of
  2026-06-08, plus manual extra days and brief off-week trips. Build the recurring window generator
  plus a manual day add/remove control, so the slot engine offers only days Paul is in Ocala.
- **Open Ocala for new bath signups.** Needs the anchor drive-time gate live
  (ocala_service_area_by_anchor): enable Distance Matrix + Geocoding on Clean's Maps Cloud
  project, geocode the 31 anchors into clients.geo_lat/geo_lng, wire the client-side drive-time
  check into the booking gate, then flip Ocala hb_active on. Prices and durations already set.
- **Anchor-growth decision still open:** do new bath clients become anchors (toggleable) or stay
  pinned to the legacy seed set? Recommended the former; build on Paul's call.
- **Lisa Prater per-visit override.** Her visit_minutes (11) is nails-weighted; her record is
  bimodal (full grooms 45-59 min at $75, nails 5-11 min at $30, per Time is Money). Mixed
  groom/nails clients need a per-visit service type and duration, not one blended block.
- **The 5 added one-off names.** Shane Smith, Jane Henrich, Amanda Posner, Billye Mallory, Edely
  Abreu were added from cycle-time data with contact details as gaps; pull their contact sheets
  for service address, dogs, service type, cadence, and one-off-vs-standing.
- **Website fold + domain redirect.** Fold the doggoneclean.us content into the app and redirect
  the domain; retire Squarespace.
- **bath_ table rename.** Cosmetic: the bath_* tables now hold grooming and nails too; rename to a
  neutral client/subscription/appointment model once the cutover is stable (teeth are in columns,
  so deferrable).
- **Recurring next-appointment generator.** When built, it must size each appointment via
  clean_effective_duration_minutes (schedule_by_client_history), the way reschedule now does.
- **Refine bath durations.** bath_starting_durations (30/60) are estimates; replace with real
  bath cycle data once it exists.

## Website build

The site is live at hurricanebath.com (staging), built and deployed from `main` via
`.github/workflows/deploy.yml`. The multi-page fork DONE 2026-05-27: eight routes
live (`/`, `/the-villages`, `/process`, `/book`, `/portal`, `/privacy`, `/terms`,
`/sms`), Neural Expressive look consistent across all of them, zero DGN aesthetic
imported. See the 2026-05-27 "fork shipped" entry in the Scroll for the slice list.

**Booking flow chapter (IN PROGRESS, 2026-05-29).** Decision: a real slot
picker now, backed by a lean availability layer, NOT the drive-time route
optimizer (deferred). Slices shipped to `main`:
- ~~Slice 1: availability layer + signup RPC~~ DONE (migration 0003).
  City booking config (slot length, buffer, horizon, timezone),
  `bath_availability_windows` + `bath_availability_exceptions`,
  `bath_open_slots()` (free slots, no PII, anon-callable), and
  `bath_start_subscription()` enforcing the rule pack atomically.
- ~~Slice 2: the funnel UI~~ DONE, restructured for low friction, then
  rebuilt as a FAITHFUL PORT of the nails booking flow (2026-05-29) after
  Paul's call that nails is the proven baseline. `/book` is `BookingApp.jsx`,
  four steps mirroring nails: (1) friendly-dogs callout + eligibility
  checklist + ack, then address + gate code, then contact + dogs (coat
  tier, optional DOB + age badge), optional Google prefill; (2) plan cards
  4wk/2wk/single + live total; (3) next-available or specific-month, real
  slots with a "Best fit" badge, card-on-file trust framing + charge
  policy; (4) review + recurring preview ("your first 4 visits").
  NO ACCOUNT to book (migration 0007 reworked `bath_start_subscription` to
  run anonymously, keyed on phone; auth_user_id NULL until the portal is
  claimed). Bath-only divergences from nails: coat-tier pricing per dog
  (fixed in 0005: each dog its own tier, stacking discount), 2-week
  cadence, three-dog cap, and NO add-ons (nails' silk-finish upsell omitted
  per premium_inclusive_no_addons). State persists to sessionStorage across
  the Google-prefill redirect. Honors ?plan=single.
- ~~Slice 3: founders counter feed~~ DONE (migration 0004).
  `bath_founders_remaining(slug)` feeds the hidden `#launch-spot-count`
  on `/the-villages` (reveals below the visibility threshold).

**Still ahead on booking (blocked or next):**
- ~~Address autocomplete + service-area verification~~ DONE (2026-05-29).
  `src/components/portal/maps.js`: a SINGLE service-address box using the
  modern `PlaceAutocompleteElement` (Places API New) -> on select, fetch
  fields -> lat/lng -> ray-cast point-in-polygon against `cities.polygon`
  (real 308-point Villages boundary). In-area reveals the rest of the
  funnel; out-of-area routes to the waitlist and blocks. If the Maps script
  fails, the fallback is one plain text box (never a multi-field form).
  Uses the modern element, NOT the legacy `google.maps.places.Autocomplete`
  widget: Google blocked the legacy widget for Cloud projects created after
  March 2025, and Clean's project is new (the legacy widget throws
  LegacyApiNotActivatedMapError; nails works only because its project is
  older). Verified vs an independent SQL ray-cast; interactive click NOT
  verifiable from the build environment (no headless browser + referrer-
  locked key), so final confirm is Paul on the deployed page. The Maps
  BROWSER key is a source constant (ships in the page like the Supabase
  publishable key); Paul keeps it HTTP-referrer locked to hurricanebath.com
  and the project needs the Places API (New) enabled (its own Clean Google
  Cloud project per `clean_stays_saleable`). NOT YET done: per-address
  allow/deny exceptions (override the polygon for edge lots); add when a
  real case appears. Open polish: theme the element to match the form
  (limited to its CSS hooks).
- **Slice 4: Stripe SetupIntent edge function** + activate the card step.
  BLOCKED on Paul creating the Dog Gone Clean Stripe account and providing
  TEST keys. The funnel's final "Confirm booking" button is disabled until
  this lands; `bath_start_subscription` is built and verified end-to-end.
  Port the nails `create-setup-intent` edge function + `StripeCardSetup.jsx`.
- **Portal claim path** (since booking no longer creates an account): when
  a client signs into `/portal` by phone OTP / Google, match their phone or
  email to an unclaimed `bath_subscribers` row and set `auth_user_id`. A
  small SECURITY DEFINER claim RPC. Until then a booked client has no portal.
- ~~**Returning-client recognition** (nails parity): phone-blur lookup that
  shows "Welcome back, X"~~ DONE 2026-05-29: anon RPC `bath_lookup_subscriber`
  (migration 0010, applied to dgc-prod) returns only {found, first_name}; the
  Step 1 phone field calls it on blur and greets a known person. No subscribers
  exist yet, so nothing triggers it until real bookings land.
- **Paul inputs to light up the slot picker** (real_data_only; the picker
  shows an honest empty state until these exist): per-visit duration
  (`cities.hb_slot_minutes`, currently NULL), the weekly open windows
  (`bath_availability_windows`), booking horizon, buffer between stops.
- **Open pricing policy (flagged in migration 0003):** multi-dog mixed-coat
  visits price off the HIGHER coat tier. Confirm or change.

**Active next step (after booking):** Portal Phase 2 (data views). The
read-side views from DGN's `PortalViews.jsx`: Dashboard (next-appointment
card, card-expiry banners), Appointments list + detail, Pack view. Now
has real rows to render once booking starts writing them.

**Phase 3 (mutating views):** Stripe card management, Plan section with
the two-tap stop sign, Reschedule with per-date pricing, Skip flow,
Notifications. Each requires its own SECURITY DEFINER RPC plus the UI.

**Resolved 2026-05-27 (kept for history):**
- ~~Fork the DGN site structure into Clean (multi-page)~~ DONE. Shipped in six
  thin slices, all merged to `main`. Build-time decisions locked the same day:
  `villages_only_in_copy`, `specialist_named_not_promised` +
  `specialist_assigned_per_route`, `founders_spots_remaining_counter`, dedicated
  `/process` page, honest stubs at `/book` and `/portal`.
- ~~`/portal/` and `/book/` links 404~~ FIXED 2026-05-27. Both routes now serve
  honest "coming soon" stub pages.
- ~~Dead `PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD` env var in `deploy.yml`~~ REMOVED
  2026-05-27.
- ~~Unused CSS classes `.chips`, `.chips li`, `.services` in `src/pages/index.astro`~~
  AUTO-RESOLVED 2026-05-27: the rewritten homepage dropped those classes.
- ~~Supabase Auth Site URL on dgc-prod defaulted to `http://localhost:3000`~~
  FIXED 2026-05-27 by Paul in the Supabase dashboard (Authentication >
  URL Configuration). Site URL is now `https://hurricanebath.com`;
  Additional Redirect URLs include `https://hurricanebath.com/portal/`
  + `**` wildcard, plus `http://localhost:4321/portal/` + `**` for
  local dev. Diagnostic: if Google sign-in lands a Pixel on
  `localhost:3000/#access_token=...` (the OAuth callback hash with an
  unreachable host), this is the cause every time. Configuration lives
  in the dashboard, not the Supabase MCP, so a future session cannot
  diagnose-and-fix in one move; surface to Paul.
- ~~Tier prices and founders cap hardcoded as literals on `/the-villages`~~
  FIXED 2026-05-27. New `src/lib/cities.js` does a build-time fetch of
  the city row; the page hydrates from there. Change a price column in
  the `cities` table and the next build picks it up.
- ~~Customer-facing rules survive a major website redesign only because
  the only thing standing between a redesigner and dropping them was my
  copy~~ FIXED 2026-05-27. 25 rules (every Clean rule with a site-or-portal
  expression) now have `scripts/check.py` patterns that fail the build
  if their expression goes missing. The one rule still deferred is
  `cancellation_24h`, whose exact wording applies to the legacy
  doggoneclean.us surface that has not been rebuilt. Going-forward
  expectation hardened in the Oracle's "How to add a rule" section:
  lint enforcement lands the same commit as the rule by default.

**Still open for Paul (mechanical, container cannot do):**
- **Copy pass (real work still needed in some places).** The eight-page site uses
  bath-forward copy throughout, but a final copy review by Paul will sharpen
  voice and catch anything that does not sound like the business. Service area
  is Villages-only (`villages_only_in_copy`). No "brush out" or brush wording:
  the Hurricane Bath and high-velocity dryer do that work, Paul owns no brush.
- **Photo of Paul for the city page specialist section.** The `/the-villages`
  page currently uses a placeholder "P" gradient avatar; drop a real photo in
  `public/` and update the `<img src="...">` in `the-villages.astro`.
- ~~**Logo check.** Confirm the logo renders cleanly on the light page (may need a
  transparent-background version).~~ DONE 2026-05-28. The supplied `logo.png` had
  ~112px of dead space top and bottom; cropped to the artwork (960x540 -> 910x345),
  nav render height raised 48px -> 60px, and a dedicated square favicon
  (`public/favicon.png`, from the dog mark) replaced the squished wide lockup in
  the browser tab. **Transparent-background version is NOT feasible from the current
  raster** and should not be re-attempted: the dog's body is pure white and open at
  the bottom, so its interior is the same region as the background, and removing the
  background hollows the dog (verified on a dark composite); the dark wordmark also
  vanishes on dark backgrounds. A drop-anywhere logo needs proper variants from the
  source art (filled-shape dog on transparent + a light wordmark for dark
  backgrounds), a design task for whenever the original vector/layered file is
  available. Paul dropped transparency for now (2026-05-28).

## Video / footage to capture (Paul, mechanical)

The `/process` page now leads with two clips (water-pressure, bath-in-action) directly under
the hero per `show_dont_tell` (Oracle). Footage is the page's strongest proof, so a small shot
list is parked here for Paul to capture on the route. Ranked by persuasive punch:

1. **Before / after the same dog.** Dirty or matted, then clean and fluffy. The single most
   persuasive clip a pet owner can see.
2. **The "flush if filthy" mud puddle.** Wash water going brown, the system flushing and
   refilling clean, then washing again. Proves a capability words cannot ("the wash water turns
   to a mud puddle").
3. **Drying in the trailer.** High-velocity dryer with the coat blowing dry, ideally a shot of
   the humidity gauge near 30 percent. Proves "walks out dry, not damp" and sells the
   climate-controlled trailer.
4. **A calm dog mid-bath (the peaceful trailer).** Relaxed dog, loose tail, steady hands, the
   quiet of the interior. This is the `show_dont_tell` calm clip: show the happy place, never
   say it. Answers the unspoken "will my dog hate this?"
5. **Setup / pulling into the driveway** (short time-lapse). Leveling the trailer, AC and lights
   coming up. Sells the mobile "without leaving home" promise the copy only states.
6. **Coat parted to show suds at the skin.** Close-up proof of "suds that get all the way down."
7. **The rig itself / recirculation system.** A few seconds of the custom machine Paul built.
   This is the moat ("none of the systems Paul could buy did everything"); seeing it makes it
   real.

If only two get shot next: before/after and the mud-puddle flush. Note when shooting the calm
clip that the trailer reads as peaceful to Paul because he built it; frame it so the calm is
visible to someone who has never seen inside.

## Marketing copy ideas (parked, not ready to use)

Kernels for the site copy, captured so they are not lost. Not approved and not for publish yet.

- **Shedding interception (the two-week routine).** Paul's kernel, 2026-05-25, verbatim:
  > We can't change your dog's natural shedding cycle, but by getting on a strict two-week
  > routine, we can intercept a massive amount of that dead undercoat in our van before it ever
  > has a chance to land on your rugs, your furniture, or your clothes.

  Angle: sells the recurring two-week bath cadence as shedding control. Ties straight to the
  bath-forward pivot and to recurring standing visits. Hold until the copy pass.

## Portal and subscription ideas (parked, not ready to use)

- **Two-tap cancellation.** LOCKED 2026-05-26 as `stop_sign_two_taps` (see Oracle). The parked
  idea from 2026-05-25 became the rule the same week; kept here only as a pointer so future
  sessions do not re-park it.

- **"Show someone." share page (Web Share API).** Companion to the post-appointment SMS
  nudge locked in the Oracle as `post_appointment_show_someone_nudge`. The bare two-line
  MMS ("[Dog's name] before and after. / Show someone.") with photos attached is effective
  immediately on Paul's existing send. This entry is the next phase: a small share page on
  doggoneclean.us (or hurricanebath.com on the v2.0 surface) at a per-appointment URL that
  lets the client one-tap the photos into their native share sheet via `navigator.share()`,
  with an optional generic caption (e.g. "fresh paws") they can edit or delete. Hard
  constraints carried from the rule do NOT relax: no pre-filled brand handles, no embedded
  "@doggoneclean" caption, no "tag us" prompt, no platform-specific deep-link. Platform
  choice and tagging stay with the client; the page only removes the steps of saving to
  camera roll and opening another app. Falls back to a download link plus
  copy-to-clipboard on browsers without `share()`. Parked because it needs per-appointment
  photo records in Clean's Supabase with stable signed URLs plus a tokenized fetch path
  that does not require auth (an SMS recipient is not necessarily logged into the portal).
  The booking pipeline plus operator-app photo storage have to be solid first. Sizing:
  ~2 to 3 units once photo records exist (one Astro route, one React island, one edge
  function for the tokenized photo fetch).

## Service eligibility ideas (parked, needs work before use)

- **The Breed Firewall classification (draft).** Paul's idea, 2026-05-25. A coat-type rule for
  who the bath-only model accepts, aligning intake with `core_is_no_haircut_dogs`. Still needs
  work before it goes into intake, copy, or code.
  - **Excluded category:** any coat type that requires a haircut or styling, or that can knot,
    mat, or pack loose undercoat against the skin.
  - **Approved, smooth category:** single, short-haired coats that do not trap water and dry
    within minutes.
  - **Approved, dense category:** short or medium double-coats that shed heavily but do not mat,
    needing a standard undercoat blowout within the route time limit.

## Conversion candidates (one-off -> standing)

Leave the one-off list as-is and treat it as people to try to convert to standing where
applicable. These are NOT contact-sheet-verified (calendar-derived + Paul's notes only) and
are not routed until converted. Verify against the real sheet at conversion time.

- **Richard Vieira** (SE, ~5wk, no sheet) - most likely to convert; watch first.
- Eric Shannon (NE, was standing; money issues) - has a sheet.
- Emily Walker / Russ Walker account (SE) - has a sheet.
- Brooksley Sheehe (Anthony; moved to Miami, occasional) - has a sheet; low priority.
- Sally O'Laughlin (NW; moving to Lake Wales ~90 min S) - likely leaving service area.
- Arlene Calbo, Becky Swinford, Coleen Smith, Elijah Weber, Maria Arvanitis, Martica Ewers
  - calendar-only, no sheet; convert only if cadence reappears.

## Open data questions (need Paul)

- Peter Moran cadence: ~8wk (his note) vs ~12wk (calendar).
- Lisa Irwin: current home vs office address and the every-other-Tuesday alternation.
- Terri McDonnell: confirm works-from-home (affects daytime availability).
- Mary Beth Anderson: Theo's breed.
- Patty Brown: real availability beyond the Saturday assumption (no contact sheet).
- Chester Weber: exact bearing/zone from base (minor).

## Route work (after cadences lock)

- Rebalance the template against corrected stop sizes: Kevin is now a half-day 7-dog stop;
  Steve and Patty are quick nails; Chester is shorter without Windsor.
- Confirm the Thursday NE evening trio (Ginger, Michelle, Chloe) overflow plan to Saturday.

## Bigger questions for Paul (decide before the build needs them)

- **Business architecture (RESOLVED 2026-05-24, refined 2026-05-25 and 2026-05-26).** Two
  businesses in Paul's portfolio: DGN (Dog Gone Nails, new, nails only in the Villages, fully
  separate) and Clean (this repo, one evolving business, a fork of the DGN platform). Clean
  has TWO URL surfaces during the transition. **Legacy** (doggoneclean.us) keeps serving
  legacy Ocala full-grooming clients on Squarespace + Square + Acuity until its own rebuild.
  **Hurricane Bath v2.0** (hurricanebath.com) is Clean's new bath-only, subscription-default
  surface: launches in The Villages with Stripe card-on-file at signup, the locked v2.0 rule
  pack (founders rate, breed tiers, three-dog cap, free-skip allowance, no-show pause,
  reschedule step-up, two-tap cancel, etc.). Destination: bath only in the Villages by
  morphing the same business; the surfaces eventually converge. Still parked as
  forward-looking, not decided: a possible "Dog Gone" brand family named by service (Clean,
  Walking, Sitting, Training) built as forks of the same platform, each its own instance; and
  whether Paul ultimately runs a portfolio he keeps or builds units to sell.
- **Online payment:** DECIDED 2026-05-24 (legacy only), UPDATED 2026-05-26 (Hurricane Bath
  is online). Surface-scoped: legacy doggoneclean.us continues in person via Square (see
  `bills_in_person_today` + `accepted_payment_methods`). Hurricane Bath launches with Stripe
  card-on-file at signup plus auto-charge at the 24-hour mark, per the new Oracle rules
  `card_on_file_at_signup` and `auto_charge_at_24h`. DGN's payment/skip/reschedule/card
  layer IS ported to the Hurricane Bath surface (see the 2026-05-26 decisions log in the
  Scroll for the 24 captured rules); it is NOT ported to the legacy surface.
- **Field/operator app:** DECIDED 2026-05-24. Yes, operator app plus pizza tracker in Clean
  v1, forked from DGN. (Pizza-tracker details to come from Paul.)
- **Paul's FL/GA travel:** still open. Does the biweekly Florida/Georgia travel that shapes
  DGN's Villages schedule also constrain the Clean route, or is it DGN-only? Clean data today
  only has client seasonality (Mary Jane away Jun-Nov), not Paul's own travel.

## Hurricane Bath open decisions (parked from the 2026-05-26 plan)

These do not gate the build but should be resolved as Phase 4 progresses.

- **Cycle time per appointment.** 1 hour placeholder including drive + work; Paul
  measures real cycle times in The Villages once routes start running. Capacity
  planning gut estimate also parked: 65% one-dog, 30% two-dog, 5% three-dog.
  Updates `breed_tier_pricing` and operator-app capacity math.
- **Tier slug names.** Recommended `smoothcoat` and `doublecoat` per the plan;
  Paul may rename (candidates considered: `tier_1` / `tier_2`, `quick` /
  `extended`, `standard` / `extended`, `express` / `full`). Descriptive beats
  hierarchical because the categories are coat-type differences, not levels.
- **Breed list refinement.** First attempt at `src/data/breeds.json` lives in
  Appendix A of the approved plan, with smoothcoat (~52 breeds), doublecoat
  (~11 breeds, small after Paul's mat/impact exclusion), and a long
  not_accepted list including all poodles/crosses, Goldens/Aussies/Border
  Collies (per Paul's call-outs), feathered retrievers/setters, spaniels, toy
  grooming breeds, long-coat herders, wirehairs, corded/heavy-coat, and the
  excluded Nordic/spitz/heavy-undercoat group. Mixed-breed dogs route through
  an eligibility questionnaire. Paul iterates.

## Paul-actions still open

Mechanical work the container cannot do itself.

- **New Stripe account for Dog Gone Clean.** Separate from DGN's account and Paul's
  personal account per `own_infrastructure`. Hand over publishable + secret keys for the
  Hurricane Bath v2.0 surface (gates `card_on_file_at_signup`).
- **Twilio account, number, and A2P registration.** For SMS notifications and phone-login
  fallback. Clean's own account, not DGN's.
- **Grant the remote environment access to `doggonenails-site`** so a future session can
  read its multi-page structure and fork it into Clean.
- **Create the private archive repo `doggoneclean-legacy-data` (eventually, not urgent).**
  The harness scope is limited to `doggoneclean-site` and `doggonenails-site`. For now the
  records live under `legacy/data/` in this repo, which is fine; move them out only if and
  when the legacy book moves into Supabase and the static files become true archive.

## Repo housekeeping

- **Default branch + stale `claude/*` branches: DONE 2026-05-26.** Repo default branch was
  pointing at a stale `claude/amazing-noether-4Mo5W` snapshot, which is why every new
  session kept opening on stale state regardless of which branch was picked: GitHub itself
  was telling them that was the trunk. Switched the default to `main` (Settings > General),
  deleted every `claude/*` branch. The SessionStart hook in `.claude/hooks/session-start.sh`
  is now the belt-and-suspenders defense; the default-branch fix is the root cause cure.

## Saleability (keep the door open)

Constraint (Oracle `clean_stays_saleable`): Clean must stay sellable as a standalone
business, never tangled with DGN or dependent on Paul personally. Probably never sold, but
the option stays open. Implications to honor as the build proceeds:

- Separate from DGN where it counts: the Supabase project (data) is the hard line, never
  shared. A shared droplet, account, or tooling is acceptable to save cost since those are
  cheap to separate before a sale. Keep API keys their own and domain-locked. No shared data
  or imports.
- Operate without Paul: routes, rules, and the client book live in the system and the docs,
  not in his head. No DGN-style dynastic/bloodline ownership; ownership and operator roles
  must be transferable.
- Keep Clean's docs self-contained: DGN references should be incidental, not load-bearing,
  so a buyer can read the Oracle and records without needing DGN context.

Pre-sale cleanup (not urgent, but would block a sale if left):
- Authoritative client data currently lives in Paul's personal Google Drive. For a real
  transfer, the source of truth should move into Clean's own infrastructure (its Supabase
  project) so the asset is self-contained.
- Brand/trademark: a buyer gets "Dog Gone Clean"; Paul keeps "Dog Gone Nails." Confirm what
  rights to the shared "Dog Gone" name transfer. Real-world task for Paul, not a build task.

## Website build, when the rules are locked (the DB guardrail lifts first)

**Marketing showcase content lives in `marketing/`.** When building the marketing page, pull from
there: the Hurricane Bath hero (`marketing/hurricane_bath_showcase.md`) and differentiator
showcases like power and fast drying (`marketing/power_and_drying_showcase.md`), with their copy,
FAQ, and banked gold lines. Keep build details (CLEAN_FIELD_MANUAL.md) and the shampoo brand off
the public page.

**Marketing-site features (forward-looking):**
- **Photo-to-gallery toggle.** In the operator app, when Paul takes an after photo that looks
  exceptional, a toggle marks it for the website gallery on the spot. Because the best moment to
  curate is while looking at the shot, and it feeds the rotating gallery with no later sorting
  chore.
- **Before/after gallery.** A curated, rotating display (recent and best work, out with the old as
  new comes in) backed by a permanent, growing archive of every shot. Show a fresh subset, keep
  everything. Because rotation signals an active, in-demand business, lets quality stay high,
  keeps pages fast, and the archive stays an owned asset that compounds. Needs client permission
  to display, and curate so no shot reveals the Hurricane Bath build.
- **Reviews built into the pizza tracker (recovered plan, was getting lost).** Track whether a
  client clicked the Google review link; once they have left one, stop asking; never pester a
  long-standing client who reviewed years ago; add a light "show someone" nudge to the
  after-photo drop. Review volume is throughput-limited (near full capacity, few new clients a
  week), so the system optimizes and times the ask, it does not manufacture volume.

Tooling to port from DGN at scaffold time (adapted, never shared): `package.json`,
`astro.config.mjs`, `scripts/lint-business-rules.mjs` (rewrite patterns for Clean; keep
em_dash and the generic ones, drop/invert the nail-terminology patterns),
`scripts/smoke-build.mjs`, the GitHub Actions deploy workflow, the stop-hook. Plus the
`business_rules` table + `src/business/` module pattern once the DB exists.

Architecture to clone, not reinvent:
- **Scheduling / recurring engine.** DGN's "book once, the slot is yours, materialize the
  recurring chain, route around it" (subscriptions + horizon + cascade + get_available_slots)
  is literally Clean's standing-client-on-a-cadence operation. `route_template.md` is the
  manual version. Re-derive grooming durations (Clean times run 17 to 367 minutes, not
  DGN's fixed 15/25/40), the Ocala service-area polygon, and Clean's own cascade numbers.
- **Offline-first field app** lessons (cache is the render source, writes never block render,
  advance controls always visible, manual time corrections, persistent End Day) if a Clean
  field app is built.

## Website redesign (Neural Expressive) - blocked on screenshots

The marketing site's visual direction is Google's "Neural Expressive" language (decided
2026-05-25; full rule `neural_expressive_design` in the Oracle): blue gradient washes and
glows, ombre/gradient key words, a simple sans-serif with strong size contrast, editorial
hierarchy, gentle motion; expressiveness from color, not a special typeface. Approach is
restyle-not-reinvent: rebuild the existing DogGoneClean.us content in the new look, replacing
the current placeholder green palette (`src/pages/index.astro`) with the brand blues. BLOCKED
pending Paul's screenshots of the current DogGoneClean.us pages: the live site 403s automated
fetches and WebFetch is blocked in this remote environment, so the existing content cannot be
pulled here.

## Session ergonomics (parked, not urgent)

- **End-of-session documents-touched summary (parked 2026-05-26).** Paul wants, at the
  end of every session, a summary of which documents the session updated. Don't work
  out the mechanism now; decide later. Likely options when picked up: a Stop hook that
  runs `git log --name-only` against the session's commit range and prints the changed
  paths; or a session-end skill; or a footer the assistant prints from memory.

## Future / bigger ideas

- **Apple Sign In for clients (parked 2026-05-25).** Add Apple sign-in as an extra client
  login provider once Google login is live. Deferred to keep the first auth pass simple. This
  is a client-facing option for iPhone owners and does NOT change `device_profile`: that rule
  is about Paul's own environment (he uses no Apple devices) and how instructions are written,
  not which login providers clients are offered.
- Geocode the plus codes to compute true drive-time clusters instead of NE/NW/SE/SW buckets.
- Multi-specialist routing: apprentice Jake can take solo dogs (e.g. Spero at Heather's).
- Route-generation automation that reads `clients.json` + the template and honors every
  HARD window, plus a check that banned/one-off clients never appear in a generated route.
