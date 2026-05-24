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
When Paul locks a decision or hands over a raw idea to keep (says "lock it in," "put it where it
belongs," "capture this," or a clear equivalent), capture it the same turn: choose its live home
(an Oracle rule, a CLAUDE.md constraint, the parking lot, the field manual, or a record field),
add a dated line to the Scroll's decisions log if it is a decision, run `scripts/check.py`, and
commit/push, then tell Paul where you filed it. While Paul is still musing ("just thinking out
loud"), record nothing. If an idea is becoming a rule and Paul did not give a reason, ask one
quick question for the because rather than saving a reasonless rule. Ideas now arrive in a
Claude thread rather than the Drive journal (`the_oracle_journal`), which stays only as the
offline fallback for mid-route voice capture, batch-absorbed later. Because this is an ephemeral
container and a long thread can compact or die before the end, committing each captured idea or
decision to git the moment it lands is the only thing that guarantees it survives; an
uncommitted note can be lost with the session. The end-of-session scroll rebuild then becomes a
polish-and-reconcile pass, not a rescue.

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

`persistent_status_update` (process):
On any status request, do not report only what is top of mind; also surface important
unfinished work that has gone quiet (weak spots, neglected systems, loose ends, underbuilt
assets) until it is done enough to stop needing attention. Because important work should not
vanish just because Paul has not mentioned it lately.

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

`no_doodles` (roster):
Decline doodles. Because a doodle's coat takes so long that its revenue-per-hour falls far
below what the same time earns on other dogs (Paul could finish several short-coat dogs in the
time one doodle takes), and it is hard to make a doodle profitable under any circumstances.
Current policy as of 2026-05-24; revisit only if Paul changes it.

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

`income_target_caps_the_day` (scheduling):
Decide the target income for a day and schedule as close to that as possible; do not stack
extra appointments onto an already-lucrative day. Because energy depletes by how hard the day
earned, not by clock hours, so a high-revenue partial day drains Paul as much as a full one;
this sharpens `protect_the_operator` from a time cap into a revenue-and-energy cap.

`heads_up_on_the_way` (scheduling):
Always send the client a heads-up when Dog Gone Clean is on the way, with a live Google Maps
link to track progress. Because no one wants to sit watching the window, and a heads-up lets
the client go about their day until Clean is close. In v1 the pizza tracker is this rule's
home, replacing the manual "on my way" text.

`lock_in_timing` (scheduling):
Send the tomorrow reminder about 26 hours out, reading like a normal reminder and never like a
countdown or "last chance." Because the small buffer carries the client past the 24-hour
cancellation line feeling fair rather than blindsided, while a countdown-styled message would
manufacture cancellations that otherwise would not happen. The buffer is never mentioned in the
message itself.

`gated_community_hours` (routing):
Some gated communities restrict the hours service vehicles may enter (for example no service
entry after 5pm); treat those windows as real access constraints when sequencing a day.
Because a stop Paul cannot enter at the planned time is a hole in the route, the same class of
constraint as a client's HARD window.

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

`cancellation_24h` (money):
Appointments canceled or rescheduled within 24 hours are billed in full; once inside 24 hours
the slot is reserved for that client. Use this exact wording everywhere it appears. Because a
route is built around held slots so a late cancel is unrecoverable revenue, and one standard
sentence keeps the policy from drifting weaker as it gets reused. Pairs with `lock_in_timing`.

`favor_high_hourly_work` (money):
Steer the book toward the highest revenue-per-hour work (nail-only and bath) and away from
labor-intensive low-margin work; price each breed to what its market bears, not by a flat rate.
Because Paul tracks pay-per-job against time and nail-only and bath clear far more per hour than
a long full groom, and this economics is the engine under Clean's bath-forward repositioning,
not a separate idea. Pairs with `no_doodles`.

`accepted_payment_methods` (money):
State the full accepted-payment list consistently everywhere it appears: cash, Visa,
Mastercard, American Express, Discover, Apple Pay, Google Pay, Samsung Pay. The Apple, Google,
and Samsung wallets are methods clients pay with and do not conflict with `device_profile`,
which governs Paul's own tools, not what clients use. Because a clear list stops clients
wondering whether they need cash or an ATM stop, and naming the wallets removes a friction
point at the trailer.

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
uses no Apple devices, ever. This governs the tools Paul is told to use, not what clients pay
with; accepting Apple Pay from clients is fine (see `accepted_payment_methods`).

`website_is_ground_zero` (copy):
The website holds the strongest version of every core message; every other channel (texts,
email, social, reviews, in person) pulls from it, and any strong line discovered in use is
promoted onto the website so it becomes official. Verify this consistency, never assume it.
Because scattered wording drifts and waters down, and a single source of truth is what keeps
the business sounding like one business everywhere.

`reminder_voice` (copy):
Client messages must each earn their place (reassure, clarify, strengthen the brand, reduce
uncertainty, or add movement), carry forward energy ("Dog Gone Clean is rolling your way"),
age well over hundreds of sends, and never read like automation. Extends `no_jargon` with a
banned-phrase list: "friendly reminder," "just a reminder," "reaching out," "please be
advised," "arrival window," "last chance," "make changes now." Because these messages are
part of the brand, not admin exhaust, and a long-time client may receive them a hundred times.

`appointment_block_not_window` (copy):
Call the appointment time a block, not a window; explain once that the work is completed within
the block and the opening minute is not a guaranteed arrival time, then stop re-explaining.
Never use cable-company "arrival window" language. Because a block sets an honest expectation
that leaves room for a mobile day's twists without promising a to-the-minute arrival.

`language_bank` (copy):
Keep a brand language bank of reassurance lines and promote them to the website. Two locked
entries: the trailer as a familiar escape (for a dog who knows the service the trailer is calm,
known ground when the house is chaotic with storms, guests, holidays, or noise) and the thunder
reframe (thunder at home and thunder in the trailer are two different things; inside, the dog
has enough going on that the weather stops being the story). Each also needs a short, natural
spoken version for the doorstep. Because these answer the client's biggest unasked doubts
before they ask, and a line strong enough to reassure in a text deserves to be official
website language.

`no_trailer_graphics` (copy):
Keep the trailer unmarked: no business name or graphics on it. Because a marked trailer draws
hagglers at gas stations and in traffic and attracts the wrong sort of inquiry, and the trade
is a few missed casual leads for far less noise. Revisit only if a gated community requires a
marked service vehicle for entry, as some once did.

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
