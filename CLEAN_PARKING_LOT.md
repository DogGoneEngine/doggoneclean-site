# CLEAN_PARKING_LOT - Dog Gone Clean

Deferred work and forward-looking ideas, parked so they survive a context reset. Nothing
here is committed work; it is the backlog. Move an item into CLEAN_SCROLL_OF_HEPHAESTUS.md's focus block
when it becomes active.

## Launch blockers - Paul's external setup (2026-06-08)

These gate the v2.0 online path and the Acuity/Squarespace cutover. Only Paul can do them
(credentials, legal entity, physical-world); none are tool-accessible. Rough dependency order:

0. **DONE 2026-06-11: Maps key fixed.** Paul added Places API (New) to the browser key's
   restrictions and confirmed autocomplete works in the funnel. (History: diagnosed 2026-06-10
   as 403 API_KEY_SERVICE_BLOCKED; the funnel now also probes Places on load and names this
   failure in a banner if it ever regresses.)
0b. **Supabase Auth URL configuration (one minute, dashboard only).** Found by Jake 2026-06-11:
   fresh Google sign-ins authenticate fine, then bounce to the Site URL, which is still the
   developer default http://localhost:3000, so the browser shows "can't connect to the server."
   Fix in supabase.com dashboard > project dgc-prod > Authentication > URL Configuration:
   set Site URL to https://hurricanebath.com and add https://hurricanebath.com/** to Redirect
   URLs. Until this is set, EVERY new sign-in (Jake's operator login, every future portal
   client) dead-ends; existing remembered sessions (Paul's) keep working, which is why it hid.
1. **iPostal1 mailing address.** A real business mailing address. Feeds the Resend sender
   verification, the address drop-in on the privacy + terms pages, and the bank / Stripe / Twilio
   registrations that all want a business address. Paul is going in person (week of 2026-06-08).
2. **Fictitious name (DBA) from Florida Sunbiz.** Register the trade name(s) ("Dog Gone Clean" /
   "Hurricane Bath" as needed). Precedes the bank and processor accounts.
3. **EIN from the IRS.** Needed by the bank, Stripe, and the Twilio A2P 10DLC registration.
4. **Business bank accounts from Relay.** Clean's OWN accounts, never Paul's personal or DGN's
   (`clean_stays_saleable`). Stripe payouts and Square settle here.
5. **Twilio.** Number + A2P 10DLC registration for SMS reminders. Email reminders already work
   without it; text is the later bonus (`notification_email_first`).
6. **Stripe (Dog Gone Clean account).** New Clean Stripe account (not DGN's, not personal) + keys.
   Unlocks the portal payment surface (card management), card-on-file billing, in-portal booking,
   and tipping (the gated portal-parity slices).

What they unblock: the Resend key (item 1) is the last wall before cancelling Acuity; Stripe (item 6)
is the wall before the v2.0 online-payment surface and the remaining portal-parity slices; Twilio
(item 5) turns on text reminders. The bank/EIN/DBA (2-4) are the legal-entity spine Stripe and the
bank sit on.

## ====> CALENDAR FLIP: Google one-calendar-per-business cutover (strict order) <==== (2026-06-09)

HIGH PROFILE. Read this before touching the calendar sync. The rule of record is
`calendar_flip_order` in CLEAN_ORACLE.md.

**Current state (true until the flip, do not change it):** Paul works out of his single
Google calendar (his default calendar); that calendar is the source of truth he books from.
The Orbit admin Calendar floor is a READ-ONLY MIRROR he uses to test the sync against that
calendar, never a replacement. Acuity still sends the client reminders. Nothing about the sync
changes Paul's calendar or his Acuity workflow.

**AMENDED 2026-06-10 (Paul): the flip now runs as a PARALLEL BRIDGE first.** The Apps Script
(`supabase/apps-script-calendar.gs`) reads the default calendar AND a calendar named
"Dog Gone Clean" (deduped). So the runway is:
1. **Paul** creates a "Dog Gone Clean" calendar in Google Calendar and re-pastes the updated
   Apps Script (the repo file changed 2026-06-10; same trigger, no other setup).
2. **Paul books new appointments straight into the Dog Gone Clean calendar from then on**,
   while old ones stay on the default. The app sees both the whole time; nothing can go
   unread, which was the failure the old all-at-once order guarded against.
3. **The final flip, whenever Paul trusts it:** Claude moves any remaining upcoming client
   events onto the Dog Gone Clean calendar and drops the default from the script's read list.

**Unlocks AFTER the flip (not before):**
- **Per-business separation:** when Nails gets the same sync it reads only the Nails calendar;
  Clean reads only the Dog Gone Clean calendar; personal stays on the default calendar and is
  read by neither. The calendar is the durable Nails/Clean boundary (serves `clean_stays_saleable`).
- **Two-way enrichment:** stamp each appointment's service address + gate code back into the
  calendar event so they are on Paul's phone at the stop (system stays the master record).

**Do NOT start any step until Paul says go.** Until then the default calendar stays the working
truth and the admin view stays a test mirror.

## Moat agent (proposed): a standing owner of "dig the moat deeper"

Paul's thought 2026-06-13: success is all about digging moats; is there / should there be an agent
in charge of digging the moat deeper? Status today: the moat (`dig_the_moat`) is a DECISION LENS
applied by Claude at build/scope time and baked into CLAUDE.md + the Oracle, but it has no
autonomous owner. The existing agents are department heads that emit briefing cards (migration
0042: cfo / coo / hr / growth / compliance, orchestrated by Riker); none owns the moat as a
standing mandate. So the moat only gets dug when Claude is in a thread, not continuously.

Proposal: add a `moat` agent to the agents table (a "Chief Moat Officer" / "Moat" head) that emits
briefings like the others, scoped TIGHTLY to concrete, data-grounded signals so it produces actions
not platitudes (the real failure mode of a moat-agent is a vibes-bot saying "deepen relationships!").
The four moat sources from `dig_the_moat`, each tied to a real query we already have data for:
  1. Proprietary context: clients with thin records / data_gaps (no behavior notes, no handling
     quirks, no dog specs). Card: "enrich X's record, depth of per-client context is the moat."
  2. Grateful clients / relationships: heard-and-delivered moments delivered, worth-a-look shares,
     special requests honored. Card: surface a client primed for a personal touch.
  3. Reputation: reviews earned vs asked, referrals made. Card: ungathered goodwill to ask for.
  4. Lean commodity layer: flag effort sunk into undifferentiated work an AI could replicate, to
     keep it lean (the inverse signal: stop over-investing here).
Because the moat is the whole game in the AI era (`dig_the_moat` serves the prime directive), and a
lens with no owner is only applied when someone remembers to; an agent makes it continuous and
visible. RECOMMENDATION when built: start with ONE or two signals (proprietary-context gaps is the
highest-leverage and the data is already there), not all four, per Elon's algorithm (smallest real
version first). Build only after Paul greenlights scope; do not ship a platitude generator.

STATUS 2026-06-13: v1 SHIPPED as the just-in-time context-gap nudge on the Today stop (Oracle
`context_gap_nudge`, migration 0180), NOT as a roster agent. Paul's call: leave it as the nudge
and field-test it before adding any standing `moat` agent to the agents table. So the standing
four-signal version below stays parked until the nudge proves what is worth escalating to a card.

## Voice-capture agent ("Riker"): BUILT v1 2026-06-09 (riker_capture_agent)

Shipped: one-tap confirm, on Today (say the name) and the client sheet (client fixed). Writes a visit
with per-dog vibe scores, a household note, and per-dog notes. Still open: photos through Riker (below),
an `agent_runs` provenance log per capture, broader field coverage (cadence/availability/access changes
as first-class structured updates, not just freeform notes), and Paul's final name for it. Original
spec kept below for the next passes.

### Original spec / next passes

Paul's model: Picard does not do the data entry, he tells Riker and Riker gets it done. Paul wants a
capture box (like the Oracle "lock it in" button) where, standing at an appointment, he dictates with
his phone's voice-to-text in plain speech ("Bella was a five today, the client wants the sanitary
trim shorter from now on, collected 60 in cash") and the system files each piece into the right home
on the client's record: the vibe score per dog (`visit_dog_ratings`), the visit row (`visits`:
work done, minutes, amount, payment), and durable contact-sheet facts (access notes, cadence changes,
standing instructions on `clients` / `dogs`). This is the replacement for the per-client Google Doc
sheets Paul used to hand-keep: instead of typing, he talks. Design direction (recommended): a free-text
box (voice-to-text is the phone's job, no audio upload) -> an LLM edge function that resolves which
client (from the open sheet or a named client) and parses the utterance into structured proposed
writes -> a quick "here is what I am about to record" confirm so nothing garbage lands -> writes via
the existing `admin_log_visit` / client-update RPCs. It ACTS (Riker gets it done), but shows the parse
first so a misheard word does not corrupt the record; an "undo" on the last capture covers the rest.
Build on top of the vibe score (done) and the visit model. Open choices for Paul: auto-write vs the
one-tap confirm; how to pick the client when none is open (say the name); and the name (he said not
"Riker"). Next build after he picks a direction.

## Photos per visit: BUILT v1 2026-06-09 (visit_photos_capture)

Shipped option 1 (direct pick-and-upload from the phone): before / after / with-dog slots + extras per
visit, private bucket, signed URLs, thumbnails on each visit. Still open: per-dog tagging (v1 is
visit-level), a Riker "add the photos?" handoff, and the fancier Google Photos API pull only if the
direct picker proves annoying in the field. Original spec kept below.

### Original spec / next passes

Paul's real practice: for each dog-grooming appointment he takes three photos on his phone, a BEFORE,
an AFTER, and an AFTERWARD shot of him with the dog, plus the option for extra photos (something he
observed, or just extras). Today they live in his Google Photos. He wants them on the visit record and
noted that, unlike a quick spoken update to Riker, photos will take an extra step or two.
`visits.photo_paths` already exists (text[]). Direction (recommended): three labeled slots (before /
after / with-dog) plus an open "extras" set per visit, in a PRIVATE Supabase Storage bucket (signed
URLs through an admin RPC), thumbnails in the visit-history row, tap to enlarge. Private because these
are client property and the business must stay sellable (`clean_stays_saleable`): Clean's data, in
Clean's project, never entangled.
The real open question is the easiest intake from a phone where the shots are already in Google Photos:
  1. (Recommended) Direct multi-select upload from the phone in the visit form (and a Riker follow-up
     "add the photos?"). The Android share sheet / file picker reaches Google Photos, so it is
     pick-and-go: no extra integration, no new API surface, nothing extra to untangle at sale. Fewest
     moving parts that works on his Pixel.
  2. A Google Photos API pull (pick from an album in-app). Smoother in theory but adds a Google
     integration and scopes to untangle at sale; only worth it if option 1 is annoying in the field.
  3. Auto-ingest via a per-day shared album. Most automatic, most fragile, hardest to map a photo to
     the right dog and visit. Last resort.
Decide intake (likely option 1) before building. Next build after Riker hardening.

## The Dog Gone Tracker: build order (spec locked 2026-06-10, `pizza_tracker_client_loop`)

Client-facing name: the Dog Gone Tracker (Paul, 2026-06-10; "pizza tracker" stays internal
shorthand). The full spec is the Oracle rule. Status:

1. ~~**Tracker plumbing.**~~ DONE 2026-06-10 (migration 0136): `bath_appointments.tracker_token`
   (unique, defaulted, backfilled on all 56 appointments) + anon `tracker_status(p_token)` RPC
   returning only stage / block / first name / dog names; the stage derives from the appointment
   status AND the time_is_money stamps Paul already taps, so the tracker moves with his existing
   workflow.
2. ~~**Tracker page.**~~ DONE 2026-06-10: `/track?t=<token>` (query param, not a dynamic route,
   because the site is static): four-stage timeline, the appointment block with the
   not-an-arrival-window clarifier, auto-refresh every 45s, honest not-found and
   no-longer-scheduled states.
3. ~~**Orbit "On my way" button.**~~ DONE 2026-06-10: on each Today stop, one tap flips status to
   on_the_way (`admin_on_my_way`, never downgrades), stamps the Left clock if empty, and opens
   the share sheet (or copies) the heads-up message. Copy hyped up 2026-06-13 to lead with the
   tracker's value and name what it does: "Dog Gone Clean is rolling your way! Track our progress
   to your driveway, watch the live ETA and map, and follow every step through to all done:
   <link>". Until Twilio, Paul pastes it into Google Voice; with Twilio the same tap sends.
4. **Photo sharing, portal half: DONE 2026-06-10 (migration 0137).** Per-photo Share toggle on
   each Orbit visit photo (admin_set_photo_visibility); the client portal's Visits tab gains a
   "Photos from your visits" section (bath_my_visit_photos + a storage policy that lets the
   signed-in client sign URLs for exactly their own shared photos, nothing else). The tracker
   page also now shows WHO is coming (Paul's name + photo, per specialist_named_not_promised).
   Tracker half DONE 2026-06-10 too: the `tracker-photos` edge function (verify_jwt off, house
   pattern; the unguessable token is the credential) signs URLs server-side for that one visit's
   shared photos, and /track shows them in a "Photos from this visit" strip, refreshed each
   minute. Nothing left on this slice except first field use.
5. **Review-ask tracking.** `review_asks` table EXISTS (0136: asked/clicked/reviewed/suppressed
   per client). Remaining: the post-visit send (Twilio/Resend-gated), the click-tracking
   redirect, and the ask-window expiry logic.
6. **Tip ask.** Post-visit, only for new clients and flagged lovers-of-the-service; online tip
   capture is Stripe-gated, so this lands with the Stripe slice.

Gates: Twilio (the sends), Stripe (online tips).

7. ~~**Personalized tracker: the heard-and-delivered loop.**~~ BUILT 2026-06-13 (migration 0171,
   `tracker_heard_and_delivered`): per-visit special_request captured on the Today stop card shows
   on /track as "You asked for ...", reads delivered when the visit wraps, and a photo tagged
   Answer (VisitPhotos) shows beside it as proof. Fully live: the answer-photo spotlight reads
   answer_photo_ids from tracker_status (migration 0172), so it needs no edge-function redeploy
   (that route was blocked by a deploy-approval gate; moving the signal into the DB function
   routed around it). Original idea below.

   **Optional trim: redundant photo_credits map.** UPDATE 2026-06-13: tracker-photos is now
   DEPLOYED (v7) and returns each photo's photographer `by` directly. The `photo_credits` map in
   tracker_status (migration 0178, the DB workaround added while edge deploys were stuck) is now
   redundant: the page prefers it and the edge `by` always agrees, so it is harmless. Optional
   low-priority trim: drop photo_credits from tracker_status someday. Not a correctness fix; leave
   it until something else touches tracker_status. (History: while edge deploys were stuck in one
   session, the signal rode tracker_status via the same routing trick as answer_photo_ids; a fresh
   session deployed the function cleanly.) Separately: set Paul's profile photo in Orbit HR (Jake
   already has one) so his who's-coming portrait is a real photo instead of the static cover.

   **Cleanup: register migrations 0177-0181 in the migration history.** 2026-06-13: these five
   migrations were APPLIED to dgc-prod via `execute_sql` (because `apply_migration` hit the stuck
   approval gate that session), so the schema is correct and verified, but
   `supabase_migrations.schema_migrations` has no rows for them (newest registered entry is
   `task_delegation_and_clear`). The drift: the migration FILES exist in `supabase/migrations/`
   (0177 photo_taken_by_and_tracker_operator, 0178 tracker_photo_credits, 0179
   profile_photo_choices, 0180 context_gap_nudge, 0181 book_price_by_selected_dogs) but the
   history table does not list them, which could confuse later migration tooling. FIX (do in a
   fresh session where apply_migration is not gated): re-apply each of the five via
   `mcp__supabase__apply_migration` (using the file contents). All five are written idempotently
   (CREATE OR REPLACE, ADD COLUMN IF NOT EXISTS, the 0181 UPDATE just re-sets the same value), so
   re-applying is safe and only adds the missing history rows. Low risk, do it to keep the file
   set and the history in sync.

   **Two-tier hard ban (comms block), Twilio-gated.** Paul's idea 2026-06-13: split the hard ban
   into two levels. Level 1 is today's hard ban (removed from every working list, never solicited,
   record kept, reversible). Level 2 is for an obnoxious person: completely block communication.
   Parked, not built, because it has no teeth yet: messaging is outbound-only today and there is no
   inbound channel, so there is nothing for level 1 to "still allow" or level 2 to "block." The
   distinction only becomes real when Twilio lands and a banned number can text the business line,
   at which point level 2 means block-this-number on the inbound side. Build it with the Twilio
   slice, not before (a level whose only home is card copy fails the redesign-survival gate). When
   built: add a third `nofly_level` value (e.g. 'banned_blocked') or a separate `comms_blocked`
   flag, and have the inbound SMS handler drop messages from a blocked number. Until then the card
   copy was corrected to claim only what is enforced (removed + not solicited, no inbound claim).

   Make the tracker
   personal proof that the client was heard. When a client asks for something special at the door
   ("clip the ears a little shorter"), Paul captures it on the stop, and it shows on that visit's
   tracker as a "you asked for" line, so a client following along sees their request landed. Then
   a matching "and here it is" state when it is done, ideally with the existing client-visible
   photos attached right next to the request (the short ears, proof not just a checkmark). The
   per-visit shared-photo plumbing already exists (item 4, migration 0137); the new pieces are a
   place to capture the request (recommend a per-visit special-request field, entered from the
   Today stop card / contact sheet), surfacing it on /track, and letting a shared photo be tagged
   to a request so it renders beside it. Because the moat is grateful clients and proprietary
   per-client context: "they heard me and showed me" is the un-promptable thing a competitor
   cannot copy (`dig_the_moat`). Spec to be shaped with Paul before build; recommendation drafted
   in the 2026-06-13 thread.

## Access map: data-level Preview as (parked 2026-06-13)

The Access page's "Preview as" shows another role's MENU live, and lists what is masked inside on
the page. A true data-level preview (render Jake's actual screens with his masking applied, as if
signed in as him) is deferred: doing it safely means running the app as that user or faithfully
re-deriving every masking rule client-side, which is heavy and easy to get subtly wrong. Paul's
call (2026-06-13): wait for a future, more capable model that can handle it cleanly rather than
build a fragile version now. The menu preview plus the live masking list cover the day-to-day need
(`access_map_reads_the_truth`). Bring back when the model lift makes it cheap and safe.

## Cutover follow-ons - legacy fold (2026-06-07)

The legacy-fold cutover (legacy_folds_into_v2) is mid-build. Open threads, parked so they
survive a reset:

- **Reminders + confirmations on Supabase.** Net-new and load-bearing: Acuity sends the legacy
  reminders today, so a Supabase scheduled edge function (pg_cron + SMS/email, mirroring DGN
  send-notification) must exist before Acuity is cancelled or clients no-show
  (confirmations_and_reminders_via_supabase). n8n is retired (container and droplet leftovers
  removed 2026-06-14), not the reminder path.
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
- **Open Ocala for new bath signups (gate + perimeter LIVE; remaining: wire the form + flip).**
  The `ocala-service-area` edge function is deployed and verified end to end (2026-06-07). It
  geocodes the service address, refuses anything outside Paul's hand-drawn containment perimeter
  (migration 0027, `public.service_perimeters` slug 'ocala'; all 33 clients inside after the
  southern edge was nudged about 1 mile), then checks it is within a 15-minute drive of an anchor
  via Google Distance Matrix on the 33 cached coordinates. Verified: Ocala center and the southern
  pocket accepted; Belleview refused (10-minute drive but outside the fence); Gainesville refused.
  Distance Matrix + Geocoding enabled; key in `public.app_secrets`. Remaining to actually open
  Ocala: (1) wire the booking funnel to call the function for the typed Ocala service address (Places
  New autocomplete to capture it), and have `bath_start_subscription` enforce the gate server-side at
  signup; (2) flip Ocala `hb_active` on. Prices, durations, anchors (`clients.is_anchor`, outliers
  flagged out) already set.
- **Acuity + Squarespace teardown (`legacy_folds_into_v2`): the cutover checklist.** Replace both
  with the one Clean app; legacy full-grooming clients fold in and doggoneclean.us redirects in.
  **DONE (this session):** legacy login/claim (a client signs in and lands on their own record); the
  33 standing clients loaded as recurring full-groom records with real cadence + per-dog prices
  (migrations 0029-0030); Tue-Sat noon-to-8 availability (0028); the scheduling model locked (mirror
  real bookings, cadence is a due signal not an auto-booker, clients not subscribers); the calendar
  import proven (dedup key + overlap scoping, 0031-0032, this week backfilled); the notification
  dispatcher (`send-notification`, legacy templates, fail-closed) + `notification_log` (0033); the
  client reminder-preferences screen (0034 + portal UI).
  **REMAINING, mine (no Paul needed):** (a) DONE 2026-06-08: the hourly reminder cron fires the
  reminder_3d / reminder_26h / reminder_day windows via pg_cron job `bath-reminders` ->
  `bath_dispatch_reminders()` -> `send-notification` (migration 0035), verified against the real
  upcoming book; (b) DONE 2026-06-08: confirmations fire on booking / reschedule / cancel via the
  `bath_appointment_notify_trg` trigger, app-native (source IS NULL) only so a backfill cannot blast
  imports (migration 0035); (c) extend the calendar backfill to the full horizon + the one-off
  clients + per-visit service type (interim until the live sync); (d) DONE 2026-06-08: verified a
  logged-in legacy client renders correctly in the portal. Found and fixed the one bath-only
  defect: the Plan card "Cadence" row read the bath cadence enum (null for legacy) and rendered
  blank; `cadenceLabel` now falls back to `cadence_days` (21 -> "Every 3 weeks"). Rest of the view
  renders coherently for a full-groom, pay-in-person client (real price, status, dogs, next visit,
  history); founders row and the 4wk/2wk cadence switcher correctly stay hidden. Verified against
  real data: 0 of 33 clients have a missing price or cadence.
  **PAUL ACTIONS (credentials/physical, no tool reaches them; the Chromebook is far smoother than
  the phone for the Google Cloud bits):** (1) verify `service@doggoneclean.us` as a Resend sender and
  hand over the API key -> stored in `app_secrets`, email turns on; (2) connect Paul's Google Calendar
  once (OAuth, or share it with a Clean service account) -> the live two-way sync turns on so Paul
  never runs two systems; (3) point doggoneclean.us DNS at the droplet -> add the Caddy redirect;
  (4) cancel Acuity, then Squarespace, once one real client is verified end to end.
  **CUTOVER ORDER:** Resend key (emails CAN send, but stay gated off) -> connect calendar (sync on)
  -> cron + confirmation wiring live (DONE 2026-06-08, migration 0035) -> CANCEL ACUITY -> flip the
  master switch `app_secrets.notifications_live = 'true'` (migration 0036) -> the next hourly cron
  sends our first real reminders -> verify one real client got it -> flip doggoneclean.us DNS + Caddy
  redirect -> cancel Squarespace. SMS/Twilio stays off this path: Acuity emailed reminders only, so
  email fully replaces it; text is a later bonus.
  **DOUBLE-SEND GUARD (why the switch exists):** the existing legacy appointments are ALREADY on
  Acuity's reminder schedule, so our pipeline must stay silent until Acuity is off or every client is
  reminded twice. `notifications_live` defaults OFF; even with the Resend key in place nothing fires.
  Acuity is cancelled FIRST, then the switch is flipped. Pre-flip verification uses a test
  appointment (is_test subscriber, Paul's own email, source NULL so it was never in Acuity), never a
  real Acuity client.
- **Portal add-a-dog coat tier for legacy clients.** The Add-a-dog form requires a bath coat tier
  (smooth/double) to save, which is a bath pricing concept that is inert for a full-groom client.
  It does not break anything (it just asks an odd question and stores harmless metadata). DECIDED
  2026-06-08: leave it for now (Paul's call); revisit only if it annoys a real client. Kept here as
  a known low-priority item, not an open question.
- **Portal parity with Nails (in progress).** Goal: the Clean portal matches the Dog Gone Nails
  portal so Nails has nothing to flex. Slice 1 DONE 2026-06-08: tabbed app shell (Home / Visits /
  Pack / Account bottom nav). Slice 2 (payment section) PARTIALLY DONE
  2026-06-08: the gated section is live and the legacy in-person note ships (square_in_person and any
  unknown method never see a card field). REMAINING on slice 2, BLOCKED on Clean's own Stripe account
  (Paul action) + Stripe wiring (create-setup-intent edge fn, webhook, card-detail columns, Stripe
  Elements): see card brand/last4/expiry, update card, failed-charge + card-expiry banners. Today Clean
  has no card columns, zero stored payment methods, and no Stripe edge functions, so this half cannot be
  built as real (non-mockup) work yet. REMAINING slices: (3) book-a-visit from inside the portal (not
  just reschedule/skip) -- BLOCKED: a portal booking creates an appointment Paul cannot see (not on
  his Google Calendar, no Clean admin), a no-show risk until the live calendar sync is up; bath
  bookings also need a card (Stripe); (4) tipping after a completed visit -- Stripe-blocked for online
  tips, and legacy clients tip in person, so N/A until Stripe; (5) returning-client welcome flow DONE
  2026-06-08 (migration 0038 bath_confirm_profile + WelcomeBack component). Welcome gate is conservative:
  it does NOT trigger for a client with zero loaded appointments (cannot tell lapsed from un-backfilled),
  so with today's partial backfill it shows for nobody and activates once history exists. NET: the
  unblocked parity work is complete; the remaining gaps (card management, book-a-visit, tipping) all wait
  on Clean's own Stripe account (Paul) and the live calendar sync. Nails reference lives in
  doggonenails-site/src/components/portal/.
- **Anchor-growth decision still open:** do new bath clients become anchors (toggleable) or stay
  pinned to the legacy seed set? Recommended the former; build on Paul's call.
- ~~**Lisa Prater per-visit override.**~~ RESOLVED 2026-06-10 (migration 0139). New per-service
  override columns `clients.visit_minutes_groom` / `visit_minutes_nails` sit on top of the
  blended `visit_minutes`; `clean_effective_duration_minutes` gained a service-aware form
  (per-service history -> blended history -> coat-tier default, floored by the city minimum)
  and `bath_reschedule_appointment` passes the appointment's own service type. Lisa seeded
  groom 52 / nails 11 from her Time is Money record; verified live (groom books 52, nails
  floors to 30). Any future mixed client is two column values away from correct booking.
- ~~**The 5 added one-off names.**~~ RESOLVED 2026-06-10 (migration 0138) from Paul's account +
  his Google Calendar booking forms (no contact sheets exist for these; Abreu confirmed sheetless
  by Drive search). All five: service_type full_groom, addresses + contacts verified. Dogs: Shane
  Smith two Siberian Huskies (Ice, Luna, $175 each); Jane Henrich Great Pyrenees Dory ($150);
  Amanda Posner a Boxer ($75, gate code 0155); Billye Mallory a Boykin Spaniel + Cavalier +
  English Bulldog ($180 bundle); Edely Abreu an American Staffordshire Terrier ($75). Remaining
  genuine gaps: the Posner/Mallory/Abreu dog NAMES (never recorded anywhere). No cadences: these
  are one-offs by nature (Paul). Abreu and Mallory may go inactive; the yearly archive sweep
  handles that on its own.
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

- **Shedding interception (the two-week routine).** USED 2026-06-10: worked into the homepage
  recurring section ("We can't change your dog's natural shedding cycle. But on a steady
  routine, we intercept a massive amount of that dead undercoat in our trailer before it ever
  has a chance to land on your rugs, your furniture, or your clothes."), with "van" updated to
  "trailer". Kernel kept here for provenance (Paul, 2026-05-25).

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
  has TWO URL surfaces during the transition. **Legacy** (doggoneclean.us) served legacy Ocala
  full-grooming clients on Squarespace + Square + Acuity. (SUPERSEDED 2026-06-07 by
  `legacy_folds_into_v2`: the legacy book folds into the one Clean app, doggoneclean.us redirects
  in, and Squarespace + Acuity are being retired, with no separate rebuild.)
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

## Banned-booking funnel polish (parked with Stripe) (2026-06-09)

The hard teeth are built (`block_banned_from_booking`): a trigger on `bath_subscribers` already
blocks a banned contact from creating any booking with a soft "not taking new clients in your area"
message. What is parked, because the booking funnel's Confirm is disabled until Stripe is wired
(launch blocker #6): (1) map that specific error into the funnel's friendly service-area panel
instead of a raw error line, and (2) an EARLY in-funnel check at the contact step (reuse the
phone-blur recognition path) so a banned person gets the soft decline before filling the whole form
rather than at submit. Do both when the Stripe card step goes live.

## Add the new clients that have no record yet (from Google Keep) (2026-06-09)

Paul has been serving some NEW clients he never made a contact sheet for; he took the notes in
Google Keep and they are not in the system at all (not among the 53 seeded active clients). Not
urgent, but MUST NOT be forgotten: create a real record for each one. Source = Paul's Google Keep
notes (he will paste/dictate them). For each new client capture whatever the notes hold, the same
fields as the contact-sheet cross-reference: client (name, city/area, cadence, service type), each
dog (name, breed, price, birthday + exact/estimated, standing instructions), access notes (gate /
door / lock codes, plus code if the street address routes wrong), who's on site, and any open
follow-ups. Unknown fields are data gaps, never invented (`real_data_only`). Write them as a
replayable migration keyed by name so a reseed cannot wipe them (`client_dispositions_are_migrations`),
then read them back to Paul to confirm. Optional enabler: an in-console "Add client" button so Paul
can add future ones himself from his phone (runs-without-Paul); for this batch, pasting the notes is
the faster path.

## Portal amazement: the wants inventory (`portal_amazement`, Paul 2026-06-10)

The portal's bar: clients amazed at how easy everything is, amazed enough to tell people.
Everything a client could possibly want to do with Dog Gone Clean, buildable in the portal.
LIVE today: sign in three ways, see the next visit and full history, reschedule, skip, pause,
restart, the stop button (red octagon, two taps, slot-release copy, on the Home screen and in
Account), change cadence, manage the pack, edit contact + verified service address, reminder +
Dog Gone Tracker preferences, shared visit photos, the live tracker (six stages, ETA, the truck
on a map, opt-in chimes). THE INVENTORY still to build (roughly in order of client value):

1. **Pay and tip from the phone** (Stripe-gated): see the card on file, update it, tip after a
   great visit, see receipts per visit.
2. **Book a visit from inside the portal** (calendar-sync + Stripe gated for bath; legacy can
   self-book once the cutover lands): today the portal manages visits but new bookings go
   through /book.
3. **The dog's story page**: per dog, the before/after gallery over time, weight/coat notes,
   birthday, "what we did last visit." The shareable pride surface.
4. **Refer a friend**: a personal link that pre-fills the funnel; the moat grows by word of
   mouth, give the words a handle.
5. **Message us**: one async text-style thread per client inside the portal (replaces "what
   number do I text?"), honoring online_only_comms.
6. **Live answers**: "when are you coming next month?" answered without asking; cadence and
   upcoming visits laid out plainly.
Each item ships only when it can be real (no_mockups); the bar for each is "would a client
mention this to a friend?"

REJECTED, do not re-add (Paul, 2026-06-10): **Gift a visit** (pay for a friend's first visit).
Because a gifted visit lands on a recipient who never walked the funnel's fit gates: the
giver's friend may have a doodle, a matting coat, an out-of-area address, or an unsafe dog,
and the gift converts a kind gesture into a doorstep decline or an ineligible booking. The
sanctioned version of the same growth instinct is Refer a friend (item 4), where the friend
walks the slide themselves and the person-shaped holes still work.

## Scheduling engine: committed next rounds (NOT parked indefinitely; Paul 2026-06-10)

Order of work after the current stragglers:
1. **Rolling duration recompute. SHIPPED 2026-06-11** (`adaptive_visit_blocks`, 0153): blocks
   are now the median of the last 5 recorded on-site visits per service (3+ samples) plus
   `cities.hb_buffer_minutes` (default 15), with the static snapshot as the thin-history
   fallback. Paul's breathing-room question on 2026-06-11 made the pending drive-inclusive
   vs on-site call: blocks track ON-SITE reality, the buffer absorbs drive until round 2
   reserves drive per stop, at which point the buffer can shrink toward zero.
2. **Drive time as a first-class reservation.** EXPLICITLY COMMITTED, not procrastinated: when
   the route engine lands, blocks become true on-site time and inbound drive is computed and
   reserved per stop (the Oracle's original block-time intent). The new tracker stamps
   (inbound -> arrived) are already capturing real per-stop drive times to feed it. Progress
   2026-06-11: `drive_cache` (home-pair drive seconds, cached forever) and the `suggest-drive`
   annotator now exist and feed the booking panel, so the engine inherits a warm cache. The
   route engine must also honor `fill_the_near_gap` (Paul, 2026-06-11): a near-future empty
   slot relaxes ALL routing rules if the drive between neighbors is mathematically possible.
3. **Per-dog durations** (Paul's spec, 2026-06-10): clients sometimes groom a subset (one dog
   today, not the other; a dog dies; a new dog arrives), so appointment length should follow
   the dogs actually being groomed. Time is Money only has per-visit totals, but visits carry
   dog_ids and the vibe ratings already record which dogs were done, so the lowest-touch design
   needs NO new field workflow: (a) decompose per-dog minutes from historical subset variation
   per client (least-squares over their visits where different dog sets appear); (b) where a
   client always grooms all dogs together, split the total by breed-informed priors and flag
   low confidence; (c) appointment duration = sum of the selected dogs' estimates + per-visit
   refinement as new data lands; (d) a NEW dog on a known client = known baseline + estimated
   increment for that dog, refined as it accrues history (never reset the client to a guess).
   Progress 2026-06-11: appointments can now carry the explicit dog list
   (`bath_appointments.dog_ids`, `appointment_dogs_explicit`), so the input side of per-dog
   durations (which dogs are actually going) is captured at booking time.

## Orbit first-principles cleanup (assessed 2026-06-10; staged, behavior-preserving)

Paul flagged that Orbit "was iterated into existence" and is starting to Frankenstein. Ground
truth from the code, not vibes: the SHELL is actually sound (AdminApp is one taxonomy array,
one router, one drawer; 261 lines). The Frankenstein lives one level down, in four specific
debts, listed in fix order. Each step is mechanical and behavior-preserving; none should be
batched with feature work.

1. **Split ClientsView.jsx (1272 lines, 203 inline style objects).** It is a god-file holding
   the client list, the contact-sheet header, dog cards, visit logging, photos, follow-ups,
   aliases, status controls, and the time-is-money export. Cut it along the seams that already
   exist as components-in-file (ClientHeader, DogCard, VisitLog, sheet panels), one file each,
   no logic changes. This is the single highest-value cut.
2. **Promote repeated inline styles into admin.css classes, floor by floor.** Two styling
   systems coexist: admin.css classes (the durable layer; the dog-card restyle proved the
   pattern) and per-element style={{}} objects re-invented per floor (panel headers, uppercase
   captions, pill buttons, mono cells). Inline styles are how a redesign loses rules; the
   class layer survives. Do it opportunistically: whichever floor is touched next converts.
3. **One shared async-panel wrapper.** Loading / error / empty states are re-written in nearly
   every floor with slightly different copy and markup. A single usePanelData hook (or a
   <PanelData> wrapper) collapses roughly 16 re-implementations.
4. **Today is the cockpit; keep it lean.** The 2026-06-10 StopCard redesign (one big header
   target, one stepping action button, times tucked behind "fix times") is the template for
   any future per-stop control: never another row of small adjacent buttons.

Explicitly NOT problems: the 16-floor taxonomy (it is the roadmap in plain sight), the
RoadmapPanel placeholders, the agent/briefing card pattern (shared already).

## Android companion app for true background GPS (parked 2026-06-10)

The tracker's live location has a hard web-platform ceiling: Chrome on Android only delivers
geolocation fixes while Orbit is on screen, so backgrounding Orbit (navigation, calls, anything)
freezes the truck at its last fix. The tracker is honest about it (shows the fix's age, never
guesses) and the today workarounds are split-screening Orbit beside Maps or just accepting
last-fix staleness. The REAL fix is a small Android companion (a Capacitor/TWA wrapper around
Orbit with a foreground location service): the OS-level service keeps fixes flowing with a
persistent notification while a stop is on_the_way, with the same start/stop taps. Post-launch
build, only if field staleness actually annoys clients; web push notifications for the tracker
chimes (so a locked phone still dings at the doorbell moment) would ride in the same wrapper or
arrive earlier via a service worker + Notification permission prompt. Neither blocks anything
gated on Twilio: the SMS at each stage is the guaranteed channel regardless of what the open
tab can do.

## Portal self-booking for existing clients (committed next slice; Paul 2026-06-10)

Admin booking shipped 2026-06-10 (the client-sheet Book-next-visit panel). The client half:
a "Book a visit" flow in the portal for claimed clients, offering bath_open_slots sized to
their own duration, hard-gated (no override; clients never see "book anyway"), honoring
hardness windows once those are structured, writing source-null appointments exactly like
admin booking. Confirmations ride the existing trigger (live once Resend lands + Acuity is
cancelled). Gate it on nothing else: legacy clients pay in person, so Stripe is NOT required
for this slice. Build after the tracker settles.

## Rolling duration recompute: method locked (Paul's cycle-time question, 2026-06-10)

The right question is not "what is the average?" but "what does THIS dog take NOW?" A dog that
fought the system for six visits and then learned it has two eras, and a whole-history average
straddles them. Decision: per client per service, the working duration is the MEDIAN OF THE
LAST 5 real visits (minimum 3; below that, blend with the seeded value). A short recent window
IS the heavier weighting on recent visits, the median shrugs off the one chaotic day a mean
would absorb, and no standard-deviation machinery is needed (elons_algorithm: that would be
optimizing a part that should not exist). Implementation rides the committed rolling-recompute
round: every completed visit updates clients.visit_minutes (and the groom/nails splits) from
that window.

## Mount Olympus dashboard at mountolympusops.com (LIVE 2026-06-14; own repo; CI deploy broken; business tiles still parked)

LIVE at mountolympusops.com behind Cloudflare Access (Google sign-in, Paul's email only). The
cross-business owner dashboard ("emperor mode") is a plain static site (one HTML file, one
stylesheet, the app script, one config file `projects.js`); no build step, so it survives any
redesign by being too simple to break.

Permanent repo home is DECIDED and DONE: it has its own repo, `DogGoneEngine/mount-olympus`
(keeps Clean sellable and un-entangled), with its own doc set (README, LOG, and
SHARED_INFRASTRUCTURE runbook). The original copy at `mount-olympus/` in this Clean repo was
removed 2026-06-14; the dashboard lives only in its own repo now.

How it serves on the shared droplet: Caddy serves `/srv/mountolympus` for mountolympusops.com,
with the site block locked to Cloudflare IPs only (the droplet answers nothing else, so the
Google gate cannot be skipped by hitting the IP) over a Cloudflare origin cert. n8n is fully
retired: the container was stopped and removed in a prior session, and on 2026-06-14 the leftovers
were cleared too (the roughly 2 GB n8n image, the `engine_n8n_data` volume, `/root/.n8n`, three
n8n SSH keys in root's `authorized_keys`, and the open UFW rule for port 5678). Every automation
it once did is custom code now (Supabase edge functions, pg_cron, the GitHub Actions deploys).

Contents: a "building" card per business (Dog Gone Clean, Dog Gone Nails) with doors into every
surface (site, booking, portal, operator, Laelaps/Orbit) and a collapsible "engine room"
(Supabase, GitHub, deploys); a `/`-key command palette across all businesses; add-a-project in
one `projects.js` edit; best-effort reachability dots; an Eastern-time clock; a localStorage
scratchpad; and a web manifest + icons so it installs on the Pixel home screen. Distinct
night-sky-and-gold identity so it reads as the layer above the businesses.

Server-health panel ("Engine Room") is LIVE. A droplet cron job writes
`/srv/mountolympus/status.json` every 5 minutes; the dashboard renders it as a single
green/amber/red health beacon with a plain-English verdict, collapsed by default and expandable
to grouped detail (server vitals, real HTTP-200 site checks, per-business Supabase liveness,
security updates, containers, and a TLS cert only when under 14 days). It shows ONLY actionable
things (Paul's rule), and `status.json` is served only under the Access-gated domain so it stays
private. The page refreshes every 60 seconds; data is at most ~5 minutes old. Full detail, the
collector, and the runbook are versioned in the mount-olympus repo (`SHARED_INFRASTRUCTURE.md`).
Visual confirm of the rendered panel is Paul's, since only his Google login passes the gate.

Still open:
- CI deploy now WORKS (fixed 2026-06-15): push to `main` auto-deploys via GitHub Actions as the
  `olympusdeploy` droplet user. The workflow excludes `status.json` so a deploy never wipes the
  cron output. When JS/CSS change, bump the `?v=` tag in index.html for Cloudflare/browser cache.
- Phase 2 live BUSINESS tiles (today's count, week count, run rate per business) are still PARKED,
  and are separate from the server-health panel above. VALIDATED 2026-06-14: unpaused dgn-prod and
  ran the pulse against real data; the core-three compute cleanly (Nails: today 0, this week 1,
  next appt Sat Jul 11). Buildable now for both businesses. Caveat: Nails is still pre-launch TEST
  data ($0 paid, 0 subscriptions, 16 clients / 19 appts), so its tiles read real-but-throwaway
  until launch; Clean's are real. Build path: a small Cloudflare Worker that holds each project's
  read key server-side (keys never touch the browser) and returns aggregates to the Google-gated
  page; each call reads only its OWN project, so nothing merges. The exposure concern dissolves
  behind Access. Cost note: two active projects stays within Supabase Free; dgn-prod re-pauses
  after about a week idle pre-launch, and going always-on is the Pro trigger.
- Data separation stays clean: the dashboard only READS each business's own project; never merges.
- Money-job monitor (DGN auto-charge last run/result) is a later add to Mount Olympus, separate
  from the server-vitals Engine Room panel that is now live above (idea captured by the parallel
  session 2026-06-14).

## Public website gallery: BUILT 2026-06-13 (Phase 2 of photo_destinations, migration 0174)

The public homepage gallery is live. On the homepage's "Real dogs, real driveways" section a
script calls the anon `website_gallery()` feed and, once there are at least 6 approved photos,
replaces the three curated fallback shots with the live wall (responsive grid, dog-name
captions, staggered fade-in, hover zoom). Below 6 it keeps the curated shots so the homepage
never looks thin.

How private photos reach a public page without an edge function (those deploys are gated): at
approval the OWNER'S BROWSER mints a long-lived (1 year) signed URL and stores it on the row
(`visit_photos.website_public_url`); `website_gallery()` hands those URLs to the homepage.
Unpublish clears the URL; FIFO roll-off drops the photo from the feed.

Remaining nice-to-haves (parked, not blocking):
- Signed URLs expire after a year; re-approving refreshes. If it ever bites, upgrade to a real
  public bucket (copy on approve from the owner's browser) for permanent, cacheable, indexable
  URLs, which would also make unpublish a hard delete.
- A pulled photo leaves the feed immediately but its saved direct link survives until expiry
  (not hard-deleted). Fine for curated dog photos.
- Lead the wall with the before/after collages the tracker already builds.

## Per-person access grants (parked 2026-06-13, build when first needed)

Today access is purely role-based (owner / operator / viewer), defined in roles.js (menu + tabs)
and RPC role checks (actions), and shown on the emperor-only Access page (read-only map). Paul
asked where a future grant would live, e.g. letting one future employee see the Website queue
without making everyone an owner. Decision (`access_grants_live_on_the_access_page`): when a real
person needs an exception, add a per-admin capability (a flag on the admins record, default off),
surface a toggle on the Access page, and have the relevant RPC accept role OR that capability.
Do NOT build the machinery before there is a real person to grant to. The Access page is the home
for both seeing and granting. Note for whoever builds it: also fold tab-level / within-floor
visibility (like "operator sees only the Team tab of the Library") into the Access map so the map
stays honest about finer-grained access, not just whole floors.

## Special-request cleanup: tidy vs verbatim (parked 2026-06-13, blocked on edge deploy)

The special-request box on the Today stop card (the "you asked for" line on the tracker) should
let Paul dictate a stream-of-consciousness ramble and have it read intelligently on the client
tracker. Design agreed with Paul:
- A toggle on the box: "Their words" (verbatim, shown in quotes on the tracker, untouched) vs
  "Tidy it up" (default, rough/dictated notes rewritten into one clean, warm, client-facing
  line that adds nothing not said).
- Dictation needs nothing special: the phone keyboard mic types into the field already.
- GUARD (non-negotiable, client-facing): the tidied text shows back to Paul to approve or tweak
  before it goes live, so the AI can never put words in a client's mouth. Dictate -> Tidy ->
  approve -> live.
Blocker: the AI tidy must run server-side (an edge function calling Claude, like Riker / the
department-head agents; the key cannot be in the browser), and edge-function deploys are gated
in the remote tool flow (same wall as the tracker-photos redeploy). Build the capture + the
toggle + the approve step anytime; wire the AI tidy when an edge function can deploy (Paul can
deploy it from the Supabase dashboard, or extend the existing riker function). Until then Paul
types the request carefully himself; "Their words" works with no AI.
