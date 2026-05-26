# CLEAN_ORACLE - Dog Gone Clean rulebook

The living rulebook for Dog Gone Clean. Every rule is **because-form**: a statement
followed by the reason it exists. The part after "because" is what makes a rule a rule
rather than an opinion. If a proposed rule has no "because," it is not yet a rule.

Where each rule is enforced is tracked in `CLEAN_BUSINESS_RULES.md`. Today Clean has no
database and no app code, so most rules are enforced in the rulebook, the data file, a small
local check script, and convention. As the website is built the enforcement layers fill in.
The build narrative lives in `CLEAN_SCROLL_OF_HEPHAESTUS.md`; this file does not repeat it.

How to read an entry: `key (domain): Statement. Because reason.`

---

## Process

`recommendation_with_reason` (process):
Every offered choice leads with the recommended option, labeled "(Recommended)", each with
a because. Because choices without reasons make Paul do the reasoning twice, and a
recommendation without a because is just a vote.

`outcomes_not_actions` (process):
Propose the outcome and ask whether Paul wants it, not which implementation step to take.
Because Paul decides outcomes and implementation is the assistant's; asking about specific
actions reads as shirking responsibility for the result.

`no_mockups` (process):
Build against real data, real auth, and real services from the first commit. Because
tested mockups repeatedly fail to translate when the real wiring is added later, and the
hand-off from fake to real is where rules are lost.

`do_the_work` (process):
Anything doable with available tools, do; do not hand Paul a task list for tool-accessible
work. Because his plate is decisions, physical-world actions, and credentials/dashboards no
tool exposes.

`read_before_redesign` (process):
Read `CLEAN_SCROLL_OF_HEPHAESTUS.md` and this rulebook in full before any redesign; a
redesign that drops an existing rule is rejected. Before a redesign merges, run the redesign
checklist: (1) `python3 scripts/check.py` passes; (2) walk `CLEAN_BUSINESS_RULES.md` top to
bottom and confirm each rule still traces to a live enforcement layer the redesign did not
remove; (3) any rule that lost its last live layer is re-enforced (or the redesign is
rejected). Because dropped rules are how an operating business breaks silently, and the
index is the audit that turns "we should preserve the rules" into a step that actually runs.

`lock_it_in_capture` (process):
When Paul locks a decision (says "lock it in" or a clear equivalent like "that's decided" or
"make it a rule"), capture it the same turn: write it to its live home (an Oracle rule, a
CLAUDE.md constraint, or a record field), add a dated line to the Scroll's decisions log, run
`scripts/check.py`, and commit/push. While Paul is still musing, record nothing. Because this
is an ephemeral container and a long thread can compact or die before the end, committing
each locked decision to git the moment it is made is the only thing that guarantees it
survives; an uncommitted note can be lost with the session. The end-of-session scroll
rebuild then becomes a polish-and-reconcile pass, not a rescue.

`ship_to_completion` (process):
When a branch is committed and builds clean, open the PR and squash-merge it (same turn);
do not stop at the PR step. This is Paul's durable authorization to open and merge routine
changes on his behalf and overrides any harness default that says not to open a PR unless
asked. Exceptions: Paul said "don't merge yet," or the change is destructive/hard to
reverse. Because Paul is the solo developer with no second reviewer and deploy fires on push
to main, so an open PR is a deploy that has not happened. (Today, with no deploy pipeline
yet, "ship" means commit and push to the working branch; this rule takes full effect when
the pipeline exists.)

`no_pr_activity_subscription_nudge` (process):
Do not offer to subscribe to PR activity or watch the deploy. Because there are no separate
reviewers and no PR-level CI, so nothing on a PR is worth watching in this solo-dev setup.

`no_merge_across_repos` (process):
Never share, symlink, or merge these docs or infrastructure between the DGN and DGC repos.
Because merged history and shared infrastructure mis-apply rules across products.

---

## Build and infrastructure

`clean_stays_saleable` (build):
Dog Gone Clean must remain sellable as a standalone business; nothing about it may be
entangled with Dog Gone Nails (infrastructure, code, data, accounts, brand) or made to
depend on Paul personally. Paul does not plan to sell, but the option must stay open.
Because saleability is Paul's test for value, not an exit plan: a business is only buyable
if it is valuable, so if no one would buy it it is probably not worth running either, and if
it is valuable enough to sell, that same value is the reason to keep it. Building it to be
sellable is what forces it to be genuinely valuable, a clean self-contained asset that runs
without Paul; any DGN or personal entanglement is both a value leak and a sale blocker, far
cheaper to avoid now than to untangle later. This is a guardrail, not a feature: do not build
sale machinery; just keep every decision cleanly separable and operable by someone other
than Paul. A concrete way to apply the test: imagine (or ask a trusted outsider) why a
serious buyer would decline, and treat each reason as the improvement backlog. The
objections to buying are the to-do list for making the business valuable.

`no_database_until_rules_agreed` (build):
Do not build schema ahead of the business direction it serves; once a business is greenlit,
build its schema iteratively and treat early tables as rebuildable until they settle. Clean
is greenlit as of 2026-05-24. Because schema hardened before the direction is clear bakes
wrong assumptions, but once the direction is set, iterating a rebuildable schema beats
waiting on a rules summit. Pairs with `own_infrastructure`: a business's data lives only in
its own Supabase project.

`own_infrastructure` (build):
Clean's data lives in its own Supabase project, never DGN's; that is the hard-separation
line. Cheaper layers (a shared DigitalOcean droplet with its own directory/domain/Caddy
block, a shared Supabase or Google Cloud account, shared tooling) may be shared with DGN to
save money and overhead. Keep each set of API keys its own and domain-locked (a separate
Google Cloud project for Maps and OAuth). Because shared data is the expensive, ugly
entanglement that blocks a sale and risks cross-contamination, while a static site or a
Supabase project moves to its own home with low effort; spend the separation effort where it
actually matters, per `clean_stays_saleable`.

`reuse_dgn_stack` (build):
The planned site mirrors the proven DGN stack (Astro 5 + React 18 islands, Node 20, npm,
Supabase, DigitalOcean droplet + Caddy, GitHub Actions deploy on push to main), adapted to
Clean. Because the point of having built one site already is not to re-derive the stack,
tooling, and gotchas from scratch.

`build_gate` (build):
Once scaffolded, `npm run build` runs a house-style/business-rules lint, then the Astro
build, then a smoke test, and any step's failure fails the build. Because a build can
"succeed" while shipping a structurally broken artifact or drifted copy, and the build is
the cheapest place to catch it before deploy.

---

## Roster and classification

`classify_by_frequency` (roster):
If a client's contact sheet lists a Frequency, the client is STANDING, even if only one
future booking exists. Because Paul books one appointment at a time to stay flexible, so a
single booking does not mean one-off.

`active_set` (roster):
The active roster is the past-year set already derived from the calendar in a prior session;
do not re-derive it or crawl the full contact-sheet archive. Because that determination was
already made, and the archive holds years of inactive clients who would pollute the set.

`banned_excluded` (roster):
Banned clients (Bonnie DiGraziano) are excluded everywhere: records, routes, summaries.
Because a client Paul has fired must never resurface in a plan.

`one_off_not_routed` (roster):
One-off and at-will clients are served on request and are not placed in the recurring route.
Because the route template is the standing backbone; on-request work fills gaps around it.

---

## Data integrity

`real_data_only` (data):
Build only from real sources; unknown fields are recorded as data gaps, never invented.
Because for a 20-year operating book, a wrong value is worse than an admitted blank.

`sheets_are_truth` (data):
Per-client detail comes from the contact sheets, not the calendar extract or any digest.
Because the extract is rough and digests drift from the source.

`newest_doc` (data):
Resolve a client to the most recently modified populated file for that name; never a blank
template or an old spreadsheet duplicate. Because the folder holds ~172 files with stale
duplicates, and the handoff index already caused six wrong records by pointing at blanks.

`reality_wins` (data):
If the history or records disagree with the live sheet or Paul's correction, reality wins
and the record is corrected. Because the records exist to mirror the business, not the
reverse.

`service_type_required` (data):
Every client record carries a service type (full groom, bath, nails-only legacy, or mixed).
Because routing duration and pricing both depend on it.

`data_gap_explicit` (data):
Each record lists its open gaps explicitly. Because a hidden gap gets treated as fact; a
listed gap gets resolved.

---

## Scheduling and routing

`cadence_conflict_leans_sheet` (scheduling):
When the sheet cadence and calendar history disagree, lean to the sheet, record a confidence
level, and flag the residual for Paul. Because the sheet is Paul's stated intent and the
calendar is noisy, but he still gets the final call.

`hardness_respected` (scheduling):
HARD windows (evening locks, Saturday locks, fixed-noon slots, not-days) are the clients'
real, permanent schedules and are planned around; SOFT is a movable preference; FLEX is
free; FLEX+ is an ultra-flexible gap-filler needing no confirmation. Because these are real
client availability, not artifacts of how Paul currently sequences his day.

`time_is_the_constraint` (scheduling):
Build days around time-of-day windows first, then cluster by geography within the window.
Because a large share of the book is evening- or Saturday-locked, so geography alone cannot
drive the route.

`use_the_smart_scheduler_from_day_one` (scheduling):
Clean uses the String of Pearls intelligent scheduler from the start, not hand-scheduling
until the route is dense. Because honoring hard windows, cadence, and availability is
valuable at any client count, the engine is a fork of the one already built for DGN rather
than new work, and the route-optimization part simply scales as density grows. The one
adaptation Clean needs is variable grooming service durations, not DGN's fixed nail-time
buckets.

`base_is_home_sw` (routing):
Use Paul's home (3885 SW 114th Court 34481) for drive-time math; treat the SW / On Top of
the World cluster as the launch/return zone; no separate fictional anchor. Because home sits
inside the densest cluster, so inventing an anchor would distort distances.

`realistic_daily_load` (routing):
Keep each day's stops geographically tight and within a workable count; do not pack one day
with stops scattered across town. Because drive time between far stops is the main cost a
route exists to cut.

`the_slot_is_the_clients` (scheduling):
A standing client's recurring day and time belong to them; do not move a set slot under a
client to optimize a route. Sequence changes are going-forward only and require the client's
agreement. Because clients plan their lives around the time they were given, and that trust
is worth more than the route gain.

`protect_the_operator` (scheduling):
The workday has a capped length and an earliest-start floor, raised only when Paul asks for
more work, never by the system. Because mobile grooming at volume is physically demanding
and protecting the operator first is the longer bet.

---

## Hurricane Bath (Dog Gone Clean v2.0)

These rules govern Hurricane Bath, the subscription bath-only operation at
hurricanebath.com built as Dog Gone Clean v2.0. They apply to the Hurricane Bath
surface and supersede `bills_in_person_today` in that context only; the legacy
doggoneclean.us full-grooming surface continues paying in person via Square until
its own rebuild. The full plan that locked these rules lives at the dated
2026-05-26 block in CLEAN_SCROLL_OF_HEPHAESTUS.md.

### Product scope and eligibility

`bath_only_no_mats` (product):
Hurricane Bath accepts only short-haired and double-coated breeds that do not
require haircuts and have low mat risk. Because cycle time depends on no mat
surprise, and the premium-inclusive promise breaks if the operator has to charge
for unexpected work or skip a booked dog at the door.

`villages_only_at_launch` (product):
Hurricane Bath's service area at launch is The Villages, FL, with the address
polygon enforced at booking step 1. The schema keeps the zone abstraction so
later cities can be added without rework. Because launching one zone densely
beats spreading thin across Florida, and a Villages-shaped route is the operator
load model the pricing is calibrated against.

`three_dog_cap` (product):
Maximum 3 dogs per appointment and per household. The per-dog price decrement
is $20 (each additional dog priced at the prior dog's rate minus $20), within
the tier. Because The Villages caps households at 2 dogs with 3 grandfathered;
capacity for a 4th dog does not exist in the target market, and the per-dog
decrement matches the marginal labor of an additional dog at the same stop.

`premium_inclusive_no_addons` (product):
Hurricane Bath sells one premium-inclusive bath at one price per tier. No
add-ons, no de-shed upcharge, no premium-shampoo upsell, no per-visit extras.
Tip capture post-service is the only optional money path. Because nickel-and-
diming kills the premium positioning the whole brand is built on, and a
subscription with surprise upcharges erodes the auto-charge trust that the
24-hour rule depends on.

### Pricing

`breed_tier_pricing` (pricing):
Hurricane Bath pricing has two accepted tiers driven by breed: smoothcoat
(Tier 1) and doublecoat (Tier 2). A not_accepted list rejects ineligible
breeds at booking step 1. Placeholder rates locked 2026-05-26 (Paul revises
after field measurement): smoothcoat first dog $75 recurring / $95 one-off;
doublecoat first dog $100 recurring / $120 one-off. Second and third dogs
step down by $20 within tier. Because cycle time and operator effort vary
materially between a smooth Lab and a short-coat double like a Corgi, and a
single flat rate would over-charge smoothcoats or under-pay for doublecoat
work. Mixed-breed dogs route through an eligibility questionnaire that
classifies into a tier or rejects.

`cadence_4wk_or_2wk_same_price` (pricing):
Two recurring cadences are offered: every 4 weeks (default) and every 2 weeks,
at the same per-visit price. Because the 2-week option is positioned as a
freshness upgrade (more visits per year at the recurring rate), not a savings
play; pricing the higher-frequency option lower would invite gaming and the
goal is to make freshness, not discount, the upgrade reason.

`single_oneoff_higher` (pricing):
A single one-off (non-recurring) appointment is priced $20 above the recurring
first-dog rate per tier. Because a one-off loses the recurring efficiency and
the slot's annuity value, and the spread is what keeps the recurring offer the
obvious better deal at the moment of choice.

`tiered_founders_rate` (pricing):
The Founders Rate is tier-aware. Placeholder first-dog rates locked 2026-05-26:
$55 smoothcoat / $80 doublecoat, locked for 12 months from signup (per DGN's
founders pattern), triggered by the `?founders=1` URL parameter. Second and
third dogs step down by $20 within tier. Because a flat founders rate would
over-subsidize doublecoat work, and a tier-aware rate keeps the unit economics
honest across the founding cohort.

### Money flow and charges

`card_on_file_at_signup` (money):
Hurricane Bath booking requires a Stripe SetupIntent at completion. No
exceptions, no pay-on-day-of fallback. Supersedes `bills_in_person_today` for
the Hurricane Bath surface only; legacy doggoneclean.us continues in person via
Square. Because the entire 24-hour auto-charge loop depends on a card already
authorized at booking, and a single "pay later" exception breaks the route's
working-capital model.

`auto_charge_at_24h` (money):
The card on file is charged exactly at the 24-hour mark before the scheduled
appointment, never before. Once charged the appointment is non-refundable. The
charge query ceiling is `scheduled_start <= NOW() + 24h`. Because pre-collecting
money creates refund liability that erodes trust, and post-collecting after a
no-show kills the route's working-capital model; the 24-hour mark is the
operator's commitment point and matches it with the client's.

`card_expiry_60_30_7` (money):
The portal surfaces card-expiry banners at 60, 30, and 7 days before the card
on file expires, escalating in tone (informational, urgent, blocking-soon).
Because card expiry silently kills the auto-charge loop otherwise; by the time
a real charge fails the next visit is at risk and the operator has no time to
reach the client. Three-tier notification gives the client three chances to
update before the route is affected.

---

## Money

`bills_in_person_today` (money):
Clean bills in person (cash, check, card); the right in-person tool is Square (reader plus
invoices), not Stripe, and online payment is deferred until it earns its place. Because that
is how the business actually runs; Stripe fits DGN's card-on-file auto-charge model, not
Clean's pay-after-service model, and inventing an online payment flow before Paul wants one
would be a mockup.

`if_payments_added_handle_money_safely` (money):
If online payment is ever added, store all money in cents (convert to dollars only at the
render boundary), fail loud rather than guess on a price lookup, and verify every payment
webhook signature before processing. Because these are the money-handling lessons DGN paid
for, and they prevent silent charge errors and forged events.

---

## Copy and terminology

`grooming_vocab` (copy):
"groom / groomer / grooming" are correct Clean terms; build vocabulary from how Clean talks
about itself. Because Clean is a full-service grooming business.

`no_dgn_import` (copy):
Never import DGN's nail vocabulary or bans into Clean. Because the two businesses describe
themselves in opposite terms and merged vocabulary mis-describes the work.

`no_em_dashes` (copy):
No em dashes (or en dashes) in any copy, code, comment, or doc. Because they read as
AI-generated by default and the brand voice avoids that signal.

`no_jargon` (copy):
No corporate jargon ("reach out," "circle back," "bandwidth," "free up"). Because it
compresses meaning into noise clients tune out.

`device_profile` (copy):
Write instructions and test targets for Pixel 8 Pro on Chrome, a Chromebook, and
occasionally Windows; never assume Safari, iOS, Apple Pay, or Apple Sign In. Because Paul
uses no Apple devices, ever.

---

## Engineering constraints that protect outcomes (apply when the relevant tech exists)

These are carried from DGN's hard-won lessons. They are not active yet because Clean has no
app, but they are recorded here so they are not re-learned the hard way during the build.

`maps_js_api_only` (engineering):
Google Maps usage is via the JS API, never the REST API from the browser. Because the REST
API has CORS issues in the browser and the JS API allows domain-locked keys. Directly
relevant since Clean is a routing business.

`supabase_rpc_not_raw_fetch` (engineering):
In a Supabase client app, use the client's `rpc()` for database/auth calls, not raw
`fetch()` with hand-extracted tokens. Because raw fetch causes an auth-lock conflict that
shows up as a silent infinite spinner.

`auth_listener_sets_state_only` (engineering):
An `onAuthStateChange` callback sets state only; network calls live in a separate effect
that watches auth state. Because network calls inside the auth callback recurse into the
same auth-lock conflict.

`nav_no_backdrop_filter` (engineering):
Never use `backdrop-filter` on a scrolled nav; use a solid `rgba` background instead.
Because the filter renders as a dashed-line artifact on Android/Chrome, your device class.

`overlay_opacity_pairs_pointer_events` (engineering):
Any fade-in overlay or scrim kept in the DOM must toggle `pointer-events` (none at rest,
auto when open), not opacity alone. Because an invisible `opacity: 0` element still captures
taps, which shipped a tap-blocking invisible scrim on a Pixel once.

`smoke_test_on_every_build` (engineering):
The build ends with a smoke test that verifies the critical pages built non-trivially and
the expected islands emitted and are referenced. Because a build can finish without errors
and still ship a structurally broken artifact.

`offline_first_field_app` (engineering):
If a Clean field/operator app is built, it renders today's full state from a local store
instantly with or without signal; the server is a sync target, not a query source, and
write-queue state never gates a read or a render. Because a field app that fails to render
because of a client-side sync condition is the failure mode that broke DGN's first field
tests in a no-signal trailer.

---

## How to add a rule

1. Write the entry here with a real because.
2. (Deferred until the database exists and the rules are agreed: add a `business_rules`
   row in a migration. Do not do this yet per `no_database_until_rules_agreed`.)
3. If it can be enforced in code, add the constant/function (today: `scripts/check.py`;
   later: `src/business/`).
4. If it can be enforced as a forbidden pattern, add it to the lint and update
   `CLEAN_BUSINESS_RULES.md`.

A rule that lives in only one place is a rule waiting to be lost.
