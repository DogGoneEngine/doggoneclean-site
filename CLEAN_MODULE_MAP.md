# CLEAN_MODULE_MAP.md - what each module does, and what a redesign must not break

This is the redesign safety net. Every recurring break this session (the tracker
not advancing on the before photo, the photo share options vanishing) happened
because a module was redesigned without a written list of what it must still do.
This file is that list.

How to use it (see `module_contract_before_redesign` in CLEAN_ORACLE.md):
1. Before you touch a module, read its contract here.
2. After you change it, go down its "Must not break" list and confirm each item
   still works, on real data, before you ship.
3. If you add a capability, add a bullet here in the same commit. If a contract is
   missing or thin for a module you are about to redesign, audit the live module
   and fill it in FIRST. A contract that is not kept current is how the net fails.

Each entry: Purpose, the source file(s), Must-not-break (the checklist), and where
the teeth live (the durable layer that survives a page rewrite).

---

## VisitPhotos - photos on a visit
- **File:** `src/components/admin/VisitPhotos.jsx`. Data: `admin_get_client` (photo
  fields), `admin_add_visit_photo`, `admin_set_photo_*` RPCs, `visit-photos` bucket.
- **Purpose:** add before / after / with-operator / extra photos to a visit and
  decide, per photo, where each one goes.
- **Must not break:**
  - Add a photo by each kind: Before, After, With <operator>, and Extras (Extras
    accepts multiple at once).
  - Per photo, set every destination: **share with the client**, **Team gallery**,
    **suggest for the website**, and **mark as the answer to their request**. These
    must be reachable and obvious, not hidden (the 2026-06-18 break: they were moved
    into a tap-to-open editor with no hint, so they looked gone).
  - Tag which dog a photo shows (multi-dog), and the photo picker is scoped to the
    dogs on the appointment.
  - Flag a photo: "Show the client" (worth-a-look, the client gets a heads-up) or
    "Just for me" (private), each with a note, and an UNMISTAKABLE saved/on state
    (a clear banner that appears instantly) so there is never doubt it took.
  - Remove a photo. Thumbnails show small dots for where each photo is shared.
  - Taking the first **before** photo is the signal the tracker uses to flip to
    underway (see Tracker) - the photo's `kind='before'` must be preserved.
- **Teeth:** the destination/flag state is columns on `visit_photos`
  (`client_visible`, `team_visible`, `website_state`, `answers_request`,
  `worth_a_look`, `field_flag`) set by RPCs; the layout is page-only.

## ClientSheet - the client record
- **File:** `src/components/admin/ClientsView.jsx` (ClientSheet + its sub-cards).
- **Purpose:** one client's contact sheet: who they are, their dogs, today's work,
  and history, laid out so the current appointment needs no scrolling.
- **Must not break:**
  - Today's appointment floats to the top as the working card the moment there is an
    appointment today (no "underway" gate); photos and notes are right there.
  - The must-knows banner rides above everything: this visit's special request, each
    dog's standing instructions, door handling (carry/leash), HEADS UP warnings, and
    the verify-before-turn-loose ASK note.
  - "Dogs on this appointment" picker: drop dogs not being done (re-prices to the
    dogs kept); "+ a dog who's back" adds a moved/former dog to this one appointment.
  - Past & archived dogs are findable (collapsed, names shown) but off the everyday
    roster and the tracker.
  - Tap-to-edit fields; alternate address; access notes; who's on site; aliases;
    people to notify; book a visit; log a visit; the growing visit history.
  - Type & status (recurring/on-demand + lifecycle) is editable and separate from
    the ban control (which sits at the bottom, clearly labelled).
- **Teeth:** all values are columns/RPCs on `clients` / `dogs` / `bath_appointments`;
  the sheet only renders them.

## TodayView - the day / the stop flow
- **File:** `src/components/admin/TodayView.jsx`.
- **Purpose:** Paul's live day: the ordered stops and the one-tap stop flow.
- **Must not break:**
  - The stop flow, one tap each: On my way -> I'm here -> Bringing them back ->
    All done; each tap stamps the time and drives the client tracker stage.
  - "I'm here" creates/stamps the visit (arrival); the feed orders by value
    (severity first), not arrival time; the screen wake lock holds while sharing
    location.
  - Fix-times (inbound / arrived / departed) editable per stop.
  - A rolled-out (completed/departed) stop drops off Today the instant it is
    wrapped, and stays gone across refreshes; the list only shows what is still
    ahead. The finished visit is never lost (it lives in the client's history).
    Paul chose the clean screen over parking done stops here all day (2026-06-23).
    A redesign must not bring back all-day-visible finished stops.
- **Teeth:** `admin_arrived` / `admin_returning` / `admin_depart` /
  `admin_stamp_appointment_time` on `bath_appointments` + `visits`. The drop-off is a
  TodayView display choice (filter completed out of the stop list + remove on wrap),
  reversible by design; the appointment row itself is untouched.

## Tracker - the client-facing "pizza tracker"
- **File:** `/track` page + `public.tracker_status(token)` (DB function). Client name:
  the Dog Gone Tracker.
- **Must not break:**
  - Stage progression: scheduled -> on_the_way -> arrived -> **underway** ->
    returning -> done. **Underway is triggered by the first before photo**, NOT a
    timer (0148; a timer lies while Paul is still on the client's couch). This broke
    on 2026-06-18 when tracker_status was rebuilt from a stale migration file.
  - Only the dogs actually on the appointment show (appointment `dog_ids`, else the
    ACTIVE funnel dogs, else the legacy regular/occasional roster). A gone dog never
    shows unless explicitly added to the stop.
  - The heard-and-delivered loop: `special_request` shown, then the answer photos
    (`answer_photo_ids`).
  - "Worth a look" photos: a flagged photo flips from a plain Moment to a worth-a-look
    card WITH Paul's comment AND the tagged dog's name (so a close-up reads for the
    right dog in a multi-dog household). Rides `tracker_status` as the `worth_a_look`
    array (`[{id, note, by}]`); the dog name comes from the matched photo's `dog_name`
    in the photos feed; the page reads `data.worth_a_look`.
  - Operator name/bio; client-visible photo credits.
- **`tracker_status` must return every field the /track page reads:** found, stage,
  scheduled_start, scheduled_end, first_name, dogs, special_request,
  request_delivered, **answer_photo_ids**, **worth_a_look**, operator, photo_credits.
  Dropping any one silently breaks the page (the 2026-06-18 breaks: stage's
  before-photo trigger, then worth_a_look + answer_photo_ids, were each dropped when
  the function was rebuilt from an old migration file).
- **Teeth:** entirely in `tracker_status` (anon RPC) - this is the redesign-proof
  layer; the /track page is a thin renderer. CHANGE IT BY DUMPING THE LIVE FUNCTION
  FIRST, never by rebuilding from an old migration file; then diff the returned keys
  against the `data.<field>` reads in `src/pages/track.astro`.

## RikerCapture - Clio, the voice scribe
- **File:** `src/components/admin/RikerCapture.jsx` + `riker` edge function +
  `admin_riker_apply` / `admin_riker_context`.
- **Must not break:** one-tap voice capture; the confirm step shows the parsed
  FIELDS (not a prose summary) before applying; household-name -> alias; one person
  goes in one place; reuse a known phone; nothing is written until Paul confirms.
  A dog price change reprices that client's already-booked upcoming appointments in
  the same write, via `reprice_upcoming_appointments_for_client`, so the calendar
  never keeps a straggler at the old price; an appointment whose total cannot be known
  for certain (a dogless multi-dog appointment, or a listed dog with no price on file)
  is left alone and reported as "needs a look" instead of guessed at. Any future
  path that changes a dog's price must call that repricer too.

## Client Portal - the whole client-facing account (`/portal`)
- **Files:** `src/components/portal/PortalApp.jsx` (shell + auth), `PortalViews.jsx`
  (all views), `portal/supabase.js` (every client RPC), `portal.css`. Data: one read
  RPC `getPortalData`; writes are SECURITY DEFINER RPCs (the rule lives in the DB, not
  the page). Supabase client uses `persistSession: true`.
- **Purpose:** where a client lives after signup: see their plan and visits, and run
  the self-service actions, without calling Paul.
- **Must not break (the complete client-facing surface):**
  - **Sign in** three ways: Google OAuth, SMS one-time code, and magic link; a legacy
    client can claim their account by phone (`lookupSubscriberByPhone`). Session
    persists. The booking Supabase client stays `persistSession: false`; the portal's
    stays `true` - do not cross them.
  - **See:** the next visit (city wall-clock time, never UTC), the plan/subscription
    and its state, the pack (dogs), the profile + service address, the visit history,
    and their visit photos (own shared photos via `myVisitPhotos` / signed URLs).
  - **Plan actions:** pause, resume, cancel, and change cadence (`pauseSubscription`,
    `resumeSubscription`, `cancelSubscription`, `changeCadence`).
  - **Visit actions:** skip the upcoming visit, and reschedule it to an open slot
    (`skipAppointment`, `rescheduleAppointment` + `getOpenSlots`); a visit can become
    not-skippable / not-reschedulable and must say so, not error blankly.
  - **Pack:** add a dog (pick coat tier), edit a dog (coat tier read-only on edit, the
    in-person assessment owns price), remove a dog (soft delete), and bring back a past
    dog; archived/inactive dogs are hidden from the active pack but listed under "Past
    dogs"; changes sync to the legacy `dogs.roster_status` via trigger so the operator
    and client records never drift.
  - **Profile:** edit profile, edit service address (not mailing address), confirm
    profile; manage notification preferences (`getNotificationPrefs` /
    `setNotificationPrefs`).
  - **Payment framing:** the v2 (Hurricane Bath) plan is Stripe card-on-file at signup,
    auto-charged at the 24-hour mark; never charge earlier. Legacy bills in person.
- **Teeth:** every write is a SECURITY DEFINER RPC with the rule inside it; the page is
  a renderer. A redesign keeps the actions and their guards, not just the screens.

## Booking funnel - new-client signup (`/book`, `BookingApp.jsx`)
- **Purpose:** convert a new client: pick city, enter dogs + coat tiers (live price),
  service address inside the service-area gate, card on file, start the subscription.
- **Must not break:** the service-area gate (`ocala-service-area` drive-time +
  perimeter) blocks out-of-area before payment; per-dog coat-tier pricing shows a live
  total; a hard-banned contact cannot create a subscriber (`_block_banned_subscriber`);
  card-on-file via Stripe with the 24-hour auto-charge rule. City prices are stored in
  cents. The booking Supabase client is `persistSession: false`.

## Ban / no-fly - client status
- **Files:** ClientStatusControl (ClientsView) + `admin_set_client_status` +
  `_block_banned_subscriber` trigger.
- **Must not break:** hard ban removes the client everywhere (`exclude_from_everything`
  filters ~30 queries) and blocks booking; shadow ban keeps serving them but stops
  the chase (win-back, retention, capacity all skip `nofly_level='shadow'`); both
  reversible; the control explains itself and is reachable but hard to fat-finger.

## Ban / no-fly - client status
- **Files:** ClientStatusControl (ClientsView) + `admin_set_client_status` +
  `_block_banned_subscriber` trigger.
- **Must not break:** hard ban removes the client everywhere (`exclude_from_everything`
  filters ~30 queries) and blocks booking; shadow ban keeps serving them but stops
  the chase (win-back, retention, capacity all skip `nofly_level='shadow'`); both
  reversible; the control explains itself and is reachable but hard to fat-finger.

---

## Modules to fill in before their next redesign
The CLIENT-FACING surface is fully contracted above: the Tracker, the Client Portal,
and the Booking funnel. These remaining OPERATOR-side modules run today but do not yet
have a full contract here. Audit the live module and write its Must-not-break list
before redesigning it:
CalendarView, FinanceView, RecurringCosts, HRView, FamilyView, GeographyView,
AuditView, ProspectusView, the Library (assets / team gallery / website queue), and the
AdminApp shell/nav.
