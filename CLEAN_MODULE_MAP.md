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
  - Flag a photo (worth-a-look to the client / for the owner) with a note.
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
- **Teeth:** `admin_arrived` / `admin_returning` / `admin_depart` /
  `admin_stamp_appointment_time` on `bath_appointments` + `visits`.

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
  - The heard-and-delivered loop (special request shown, then the answer photo).
  - Operator name/bio; client-visible photo credits.
- **Teeth:** entirely in `tracker_status` (anon RPC) - this is the redesign-proof
  layer; the /track page is a thin renderer. CHANGE IT BY DUMPING THE LIVE FUNCTION
  FIRST, never by rebuilding from an old migration file.

## RikerCapture - Clio, the voice scribe
- **File:** `src/components/admin/RikerCapture.jsx` + `riker` edge function +
  `admin_riker_apply` / `admin_riker_context`.
- **Must not break:** one-tap voice capture; the confirm step shows the parsed
  FIELDS (not a prose summary) before applying; household-name -> alias; one person
  goes in one place; reuse a known phone; nothing is written until Paul confirms.

## Portal pack - the client's own dogs
- **File:** `src/components/portal/PortalViews.jsx` (PackSection) + portal supabase.
- **Must not break:** a client can add a dog, edit it, remove it (soft delete), and
  bring back a past dog; archived dogs are hidden from the active pack; changes sync
  to the legacy `dogs.roster_status` via trigger. Inactive dogs never show as active.

## Ban / no-fly - client status
- **Files:** ClientStatusControl (ClientsView) + `admin_set_client_status` +
  `_block_banned_subscriber` trigger.
- **Must not break:** hard ban removes the client everywhere (`exclude_from_everything`
  filters ~30 queries) and blocks booking; shadow ban keeps serving them but stops
  the chase (win-back, retention, capacity all skip `nofly_level='shadow'`); both
  reversible; the control explains itself and is reachable but hard to fat-finger.

---

## Modules to fill in before their next redesign
These run today but do not yet have a full contract here. Audit the live module and
write its Must-not-break list before redesigning it:
CalendarView, FinanceView, RecurringCosts, HRView, FamilyView, GeographyView,
AuditView, ProspectusView, the Library (assets / team gallery / website queue), the
AdminApp shell/nav, and the booking funnel (`booking/` + portal BookingApp).
