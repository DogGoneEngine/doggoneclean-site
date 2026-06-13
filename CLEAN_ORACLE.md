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

## Prime directive

Dog Gone Clean exists to earn more every year while asking less, not more, of the people who
run it, and to leave everyone it touches better off than it found them. Every rule in this book
serves this. If a rule ever fights the prime directive, the directive wins and the rule gets
fixed.

1. **Earn more, grind less.** Profit should grow over time without Paul, or anyone, working
harder to keep up. Growth comes from better systems, pricing, and leverage, never from just
piling on hours. Because a business that only grows on the owner's sweat has a low ceiling and
a hard cliff. Test: does this decision raise profit per hour, or just add hours?

2. **It runs without Paul (no lapping scheme).** Paul can step away and everything keeps
working. He takes real time off and nothing falls apart. The business must never lean on his
daily presence to paper over gaps, the way a check-lapping scheme collapses the moment the
bookkeeper stops. Because a business that needs the owner every day is a job, not an asset, and
it is one bad week from breaking. Test: if Paul disappeared for two weeks, what breaks, and can
we design that out now?

3. **Fun to work on and in.** Building the business and doing the grooming should both be
genuinely enjoyable, not a grind endured for a paycheck. Because staying power comes from work
that is fun, and a business that bores or drains its people slowly rots.

4. **Good for the body and the mind.** The work should leave the people who do it healthier, not
used up. Because mobile grooming is physical, and a business that wears down its bodies is
borrowing against its own future. Test: does this make the day easier on the body and mind, or
harder?

5. **A unicorn job.** If Paul hires, the job is good enough that a long line of people want it.
Because great people make the great service, and you only keep great people by being the place
everyone wants to work. It is also how the business comes to run without Paul.

6. **Clients grateful it exists.** The service is good enough that clients feel lucky it is
available to them, not like they are doing Paul a favor by booking. Because gratitude is the
only moat that lasts: grateful clients stay for years, refer their friends, and forgive the rare
off day.

7. **The world is better because it exists.** Clients, dogs, workers, and the community are all
left better off. Because a business that only takes gets pushed out eventually, and one that
genuinely adds is one people protect.

Two decision lenses serve this directive and are run against every build or scope call:
`elons_algorithm` (build it lean, in the right order) and `dig_the_moat` (does this deepen an
advantage a smart AI cannot prompt past?).

---

## Process

`redesign_survival_is_a_ship_gate` (process):
Nothing ships until it would survive a major website redesign. This is a LOOP, run before every
ship, on the assistant's own initiative and without involving Paul:
  1. About to ship something (a rule, business logic, a decision, copy, a feature, a schema
     change)? Ask: if the whole website were torn down and rebuilt tomorrow, would this still
     hold?
  2. If no, because its only enforcement is a string or markup a redesign would rewrite away,
     fix it right then: move the rule's teeth into a durable layer (a database constraint, a
     server RPC, a data file, or a build-time guard).
  3. Ask the question again on the fixed version.
  4. Repeat 2 and 3 until the answer is yes, then ship.
The two outcomes this rule exists to forbid are both real and both wrong: shipping something that
will not survive a redesign, AND leaving something unshipped because it failed the question. The
answer to a failure is never "do not ship" and never "ship anyway"; it is "fix it and ask again."
A change only stops moving when it passes, and then it ships.
The assistant is what runs this loop; a script can DETECT that something will not survive but
cannot invent the fix, so the tiered build audit (`scripts/check.py`) is the safety net that
catches a skipped loop, not the thing that does the fixing. In that audit a missing durable layer
BLOCKS the build and a missing page-copy reminder only WARNS, under one invariant: a check may be
WARN-only just when the rule's teeth already live in a durable non-page layer, so dropping the copy
does not lose the rule. A decision whose only home is the page is split: the STRUCTURE that carries
it (an element, a URL, a set of options) is a BLOCK so a redesign cannot ship without it, and only
the exact WORDING warns. A copy-only decision is never left as warn-only.
Because the May 2026 DGN portal redesign silently deleted business logic that lived only in
component code, and Clean is a fork of that same platform carrying the same risk; durability is
what makes a rule real, and a gate that depends on Paul remembering to ask fails exactly when a
session is moving fast. Pairs with `read_before_redesign` (the human discipline) and the four-layer
map in `CLEAN_BUSINESS_RULES.md` (the mechanism).

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

`elons_algorithm` (process):
Run any build or scope decision through the five-step order, never out of order: (1) make the
requirement less dumb (every requirement traces to a real reason and a real person who wants it,
never "because DGN had it"; requirements from smart people are the most dangerous because they
go unquestioned); (2) delete the part or step (if you are not adding some of it back later, you
deleted too little); (3) simplify what survives (only now, since optimizing a thing that should
not exist is the trap); (4) accelerate the cycle time; (5) automate, last. Because the expensive
mistake is optimizing, speeding up, or automating something that should have been deleted, and
the solo-dev-forking-DGN risk is porting features Clean does not need. Named for Musk's design
algorithm. Pairs with `clean_stays_saleable` and `no_mockups`.

`dig_the_moat` (decision lens):
Hold every build or scope decision against one question, the way Bezos asks "does this improve
the customer experience" and Musk asks "does this get us to Mars": does this deepen an advantage
a smart AI cannot prompt past? It counts as yes only if the moat is dug by becoming more
genuinely valuable and harder to replace (deeper proprietary context, stronger relationships,
better reputation, tighter local density, more grateful clients), never by trapping people or
raising switching costs, which would violate the prime directive. As AI makes generic
business-building cheap, value drains out of the scaffolding (tech stack, platform code, generic
features, the "business in a box") and concentrates in what a prompt cannot conjure, so spend the
effort there: capture tacit knowledge relentlessly into these docs, keep the corpus proprietary
and portable (it is the asset a buyer pays for), and build the commodity layer lean rather than
hand-crafting what the models will soon generate for free. Because once "make me a dog grooming
business" is one prompt, any effort that does not deepen an un-promptable advantage is spent on
what a competitor can conjure for free, and the smart AI is not the moat (every competitor will
have it); the moat is that ours is pointed at twenty years of context no one else has. A peer of
`elons_algorithm` in service of the prime directive; pairs with `clean_stays_saleable`.

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

`no_unilateral_deviation` (process):
Never change anything Paul has already decided on your own: locked copy, locked timing, settled
scope, a standing business rule. If a decision that is already made looks wrong or improvable,
stop and bring it to Paul first with the exact change and your reason, and do nothing until he
says yes. Building new work where nothing was decided yet is yours; reversing or quietly drifting
from a standing decision is not, and "it reads better my way" is never license to change a settled
choice without asking. Because Paul has years of deliberate decisions baked into this business
that can look arbitrary out of context but are not (the 26-hour reminder's wording, for one, is
tuned to warn a client fairly without encouraging a cancellation), and a silent deviation can
undo a careful choice before anyone notices, after it has already cost real money or trust.

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

`verify_the_change_before_done` (process):
Before reporting a task as done, verify that the specific change just made does what was
asked. Targeted on the change, not a generic "nothing broken" sweep: for a UI change, load
the affected page and confirm the thing you changed renders the way you intended; for a
data or config change, re-read the affected record and confirm the value; for a rule
change, run `python3 scripts/check.py` and confirm the rule is in force. Because a clean
build is not verification: a build can pass and the change can still not do what was asked,
and saying "done" on unverified work compounds (errors aren't caught until later, and trust
in past sessions' "done" claims is destroyed, which is what blew up the afternoon of
2026-05-26).

`recovery_from_a_bad_session` (process):
When a prior session has hallucinated, gaslit, or looped and Paul is bringing the wreckage
into a fresh session, the new session does five things, in order: (1) listen first and let
Paul describe what is wrong before forming any theory; (2) verify ground truth from the
file system, live systems, and Paul's account, never from prior-session commit messages or
Scroll claims; (3) name disagreements between Paul's account and the docs out loud, because
reality wins (`reality_wins`); (4) propose one verified change at a time, each with a clear
reversal path; (5) if Paul says "loop" mid-conversation, stop immediately, re-ground from
disk, and do not defend the prior turn's claims. Because a prior session's commit messages
and Scroll entries are CLAIMS by an unreliable witness, not ground truth; treating them as
fact lets the next session re-confirm the hallucination. The cost of pausing to verify is
low; the cost of compounding a bad session's errors is what Paul walked into on 2026-05-26
after losing a night of sleep to it.

`ci_workflows_capped_and_validated` (engineering):
Every GitHub Actions job in `.github/workflows/` must declare `timeout-minutes:` on the
job, and any new workflow must have been run end-to-end successfully at least once before
the file is merged to `main`. Because a workflow without a cap can hang for ~6 hours
before GitHub kills it, accumulating runs that jam the Actions queue and block all
deploys (this is exactly what `verify.yml` did on 2026-05-26), and a workflow shipped
without ever running is shipping a guess. No exceptions for "low-risk" workflows: the cap
costs one line, the failure mode costs a day.

`transient_ci_rerun_first` (engineering):
When a GitHub Actions workflow fails with a transient-looking signal (HTTP 403 or 429 from
GitHub itself, a network timeout, "unable to access" during checkout on a public repo, an
intermittent service error), the first response is to re-run the workflow once from the
Actions UI, not to push a fix-commit. Only push when the diagnosis points at the code, the
workflow file, or repo state that the runner actually sees. Because pushing commits onto a
failing pipeline compounds the mess: each new commit fires another run that fails the same
way, and the queue of failed runs jams the deploy chain so even after the transient cause
clears, queued commits sit unpublished. On 2026-05-26 a transient GitHub 403 on `git
clone` looked persistent across eight homepage commits, blocked the live site for hours,
and resolved instantly on a single Re-run of the latest deploy from the Actions UI. A
one-tap re-run is the cheapest possible diagnostic for "transient versus persistent" and
costs nothing when the cause turns out to be real.

`no_merge_across_repos` (process):
Never share, symlink, or merge these docs or infrastructure between the DGN and DGC repos.
Because merged history and shared infrastructure mis-apply rules across products.

`persistent_status_update` (process):
On any status request, do not report only what is top of mind; also surface important
unfinished work that has gone quiet (weak spots, neglected systems, loose ends, underbuilt
assets) until it is done enough to stop needing attention. Because important work should not
vanish just because Paul has not mentioned it lately.

`dates_use_local_eastern` (process):
Stamp every date (the decisions log, commits, and doc dates) in Paul's local time, US Eastern, not
the container's UTC clock. Because the container runs on UTC, which rolls to the next day in the
evening Eastern, so trusting it near midnight stamps work a day ahead; that happened once and had
to be reverted. When the date matters and is uncertain, ask Paul.

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

`toes_over_the_precipice` (roster):
A client who treats the operator as a suspect ends as a client. The
trigger is not the request the client makes; it is the accusation
underneath it. A client asking to sit in the trailer because their dog
is anxious, asking the operator to call before arrival, asking for a
shorter trim, asking the operator to use their own shampoo, asking to
reschedule, asking to skip the ears because they are sore: these are
normal customer-service requests and are not this rule. The precipice
is a no-cause accusation against the operator (or anyone present at the
appointment) of harming a dog, or a demand for supervised-only or
restricted-presence conditions inside the trailer that flows from such
an accusation. The distinguishing test: is the client treating the
operator as a service provider with a request (fine, accommodate
within reason), or as a suspect with a condition (this rule fires).
Do not try to win them back, and do not accept the conditions, because
both legitimize an accusation that should simply end the relationship.
The trust required to be alone with someone's dog cannot be partially
restored. Once the suspicion is held it never leaves: every future
off-day for the dog becomes the operator's fault with no possible
defense, because you cannot disprove something that never happened.
And the discipline this rule asks for is exactly because the client
was profitable. A first-time, troublesome, or unprofitable client
making the same accusation is easy to cut loose; a five-year, very
profitable client making it is the actual test of this rule. The
comfort of established revenue creates the urge to negotiate, to
accept the conditions, to keep the income flowing. That urge is the
booby trap. A long-time profitable client who has crossed the trust
boundary is not a profitable client anymore; they are a future
scenario in which a real or imagined off-day becomes a legal or
reputational incident, and the revenue does not begin to cover that
downside risk. The harder the choice feels, the more this rule is
exactly the rule that should make it. A client standing with their
toes over the edge of that precipice is a liability on every visit no
matter how much they pay. Recorded from the 2026-04-24 incident with a
5-year client; the full text exchange is preserved in the 2026-05-27
decisions log entry in CLEAN_SCROLL_OF_HEPHAESTUS.md. Pairs with
`banned_excluded` (which is the data-side rule once a relationship has
been ended; this rule is the strategic rule for when to end it).

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

`specialist_assigned_per_route` (scheduling):
Each service address belongs to a route, and each route is staffed by one named
operator. At booking step 1, when a visitor enters their address and it passes
the polygon check, the response shows "you are on [Operator Name]'s route" with
the operator's name and photo, so the visitor knows who is physically coming
before they put a card on file. The assignment lives on the route (not on the
individual appointment), so handing a route to a new operator updates every
client on that route at once with no per-appointment edit. Because visitors
deserve to know who is coming to their driveway as part of the decision to
sign up (`stop_sign_two_taps` plus card-on-file is a trust commitment, and
the operator is a real part of what they are committing to), and the
route-as-the-unit model is how the operator layer scales when Paul hires
(`runs without Paul` from the prime directive) without the system needing a
per-appointment human in the loop. Pairs with `specialist_named_not_promised`
on the marketing side and `use_the_smart_scheduler_from_day_one` on the
engine side.

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

`schedule_mirrors_real_bookings` (scheduling):
The app's schedule is the real booked appointments, imported from the calendar (keyed by the
Acuity appointment ID so re-imports never duplicate), never appointments synthesized from a
client's cadence. `cadence_days` is a due/overdue signal that helps place the next booking, not
an instruction to auto-create future appointments. After cutover the app becomes the source and
writes bookings back to the calendar; before cutover it reads from the calendar, AND (2026-06-10,
migration 0149) Paul can also book in-app from the client sheet: app-booked rows carry source
null, which the sync and its prune never touch (they own only gcal_sync rows), and the booking
panel offers a one-tap "Add to Google Calendar" link so the working calendar stays in the loop
until the flip makes the write-back automatic. Because blindly
booking every client out by frequency manufactures collisions, which is exactly why Paul books
one ahead and only books far out when it genuinely fits; the app assists that judgment, it does
not replace it. Pairs with `clients_not_subscribers`.

`clients_not_subscribers` (data model):
Legacy full-grooming people are clients with a recurring schedule, not "subscribers": they pay in
person and subscribe to nothing. The `bath_subscribers` / `bath_subscriptions` tables are a
DGN-fork naming artifact (the bath product genuinely is a subscription with a card on file),
pending rename now that they also hold grooming, nails, and legacy clients; for a legacy client
the "subscription" row carries only the recurring cadence and per-visit price, no billing and no
auto-charge. Never surface "subscriber" or "subscription" in any client-facing or Paul-facing copy
or UI; say "client" and "recurring schedule." Because the word misrepresents the relationship, and
Paul flagged it directly.

`no_unpaved_roads` (routing):
Dog Gone Clean does not drive on unpaved roads; an unpaved driveway is fine. The rule is
CITY-SCOPED in where it is stated: it appears in the location requirements only for
cities that actually have unpaved roads (Ocala and Marion County today, where it sits on
the Ocala page's new-client note), and it is deliberately omitted from The Villages
surfaces because to Paul's knowledge The Villages has no unpaved roads, so stating it
there is pure noise in the funnel (corrected 2026-06-10 after a first pass put it on the
Villages checklist). The operating limit itself is company-wide; the copy placement is
not. Carried forward from the legacy `service_area_ocala` operating limits, revived
because Paul decided to revitalize Dog Gone Clean in Ocala rather than leave it behind.
Because the truck-and-trailer rig does not belong on washboard dirt roads (the equipment
takes the beating and the schedule takes the slowdown), while a driveway is short and
slow so its surface does not matter; saying both up front where it applies prevents a
doomed booking and a doorstep decline, and saying it where it cannot apply just adds
friction to the slide.

`mat_removal_out_of_scope` (service):
Mat removal is not part of the v2.0 service, ever, in any city. The service cannot be
delivered properly on a matted coat (shampoo and water cannot move through a mat, and
drying a mat traps moisture against the skin), so a matted dog is not serviceable as
"just give it a bath." The defense is layered: eligibility already excludes coats that
can mat (`bath_only_no_mats`, `excluded_breeds_are_slide_holes`), the eligibility copy
now says mat removal is outside this service, and if an accepted dog still arrives
matted, the visit is declined or rescheduled rather than improvising mat removal at the
door. Because someone will eventually bring a haircut-coat dog and ask for "just a
bath," and a bath on a matted coat is either a bad job (against everything the brand
promises) or unpaid out-of-scope coat work (against `premium_inclusive_no_addons` and
`favor_high_hourly_work`); naming the line up front keeps the doorstep conversation
short and kind. Captured from Paul's 2026-06-10 thinking-out-loud; he flagged it might
only matter rarely, so the enforcement stays copy-plus-doorstep until reality shows it
needs more teeth.

`gated_community_hours` (routing):
Some gated communities restrict the hours service vehicles may enter (for example no service
entry after 5pm); treat those windows as real access constraints when sequencing a day.
Because a stop Paul cannot enter at the planned time is a hole in the route, the same class of
constraint as a client's HARD window.

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
(Key name historical; the eligibility half of this rule stands, the "bath only"
service framing it once implied is corrected by `v2_full_grooming_no_haircuts`.)
The v2.0 service accepts only short-haired and double-coated breeds that do not
require haircuts and have low mat risk. The service delivered to an accepted dog
is the full no-haircut dog grooming visit, not a reduced bath. Because cycle
time depends on no mat surprise, and the premium-inclusive promise breaks if the
operator has to charge for unexpected work or skip a booked dog at the door.

`v2_full_grooming_no_haircuts` (product):
The v2.0 service is a complete dog grooming visit for dogs that do not need
haircuts, NOT a bath-only service. One visit includes everything the dog needs
except a haircut it does not need: the Hurricane Bath, climate-controlled
high-velocity drying, deshedding and undercoat work, nail care included, and
foot-pad hair shaved. Teeth brushing is the one thing deliberately not offered.
There are no add-ons because nothing was held back to upsell
(`premium_inclusive_no_addons`): it is the full job, only on quick dogs. The
"we only give baths" framing that shipped on the site was a misunderstanding
and is corrected everywhere it appears. Because Paul does the full job on
no-haircut dogs (a boxer or a pit bull gets everything it needs except teeth
brushing), "bath only" undersold the service and misdescribed the business,
and the pivot's economics are about declining slow haircut and bog-down dogs
(`favor_high_hourly_work`), never about doing less for the dogs we take.
Corrected by Paul 2026-06-10.

`two_dog_kinds_service_choice` (ux):
The service choice is presented as exactly two kinds of dogs a client instantly
understands, defined clearly enough that no back-and-forth is ever needed, and
the client self-classifies, mixed breeds included. The easy kind: smooth or
short single coats (pit bull, boxer, Lab) that wash and dry fast. The more
complicated kind: full double coats (German Shepherd, Australian Shepherd) that
take longer, are more work, and cost more. These are the existing smoothcoat
and doublecoat tiers (DB slugs and pricing unchanged); this rule governs how
they are explained at the decision moment. A mixed dog picks by its coat, and
the funnel says so explicitly. Because Dog Gone Nails sells one product that is
the same for every dog while Clean has two, the difference was not being
explained, and a category a visitor cannot confidently place their own dog in
stalls the funnel exactly where it should accelerate. Paul, 2026-06-10.

`breed_pick_sets_tier` (Hurricane Bath: product):
In the booking funnel the breed list is the authority, per dog: each dog card
carries a breed dropdown (`src/components/portal/breeds.js`), and picking a
listed breed SETS that dog's coat tier itself, shown as a locked confirmation
("A Golden Retriever books as Doublecoat"), never offered as a choice the
client can downgrade. The dropdown leads with the breeds common around here
(Labs, Goldens, doodles, Shepherds, Cavaliers, the small companions) and puts
everything else under "All breeds A to Z", so the common case never scrolls
past ninety rare breeds; "Mixed breed" and "Other / not listed" make the list
effectively all-inclusive without being two hundred rows long. The tier is
about the WORK, not the textbook (Paul, 2026-06-11): a Labrador is technically
double-coated but grooms like a smoothcoat, so it books smoothcoat. Picking an
excluded breed shows the kind decline, with the reason named, the moment it is
picked. Mixed breeds answer the resemblance question (which coat does their
mix most resemble, described by real coat traits with example breeds) plus an
optional what's-in-the-mix note; rare breeds use "Other / not listed" with
free text, still gated by the exclusion check here and server-side. Because a
household can have one smoothcoat and one doublecoat dog (the tier was always
per dog and stays so), because "is your dog the easy kind?" invites honest
confusion and dishonest discounts, and because a Siberian Husky owner rushing
the form should learn at the breed pick, kindly, that we are not built for
that coat, not slip through by clicking the cheaper card.

`excluded_breeds_are_slide_holes` (product):
The funnel is a slide with person-shaped holes: right-fit visitors are pulled
down into signup, and wrong-fit dogs fall out gracefully and early, declined
kindly and directed away, never booked and never told no at the door. The hard
breed exclusions for new v2 clients: any doodle (any breed name starting or
ending with "doodle") and poodles or poodle crosses, Siberian Huskies, Great
Pyrenees, Great Danes, and any coat or size that bogs the day down for 2 to 3
hours. These sit alongside the standing holes: haircut and matting coats
(`bath_only_no_mats`), aggression (`friendly_dogs_only`), and out-of-area
addresses (the service-area gates). Legacy clients are grandfathered (the
existing husky and Pyrenees households stay served). Enforced server-side in
`bath_start_subscription` (breed reject before any row is written) and
client-side as an early graceful decline in the funnel. Because one 2-to-3-hour
dog ruins a route day and the pivot's economics (`favor_high_hourly_work`,
`no_doodles`), the exclusions also shape what a future hire has to handle (a
unicorn job needs a curated book), and a graceful early no preserves goodwill
where a doorstep no destroys it. Paul, 2026-06-10. Extended 2026-06-11 (Paul):
the "any coat or size that bogs the day down" catch-all is now spelled out as
three named families, each with its own kind decline: haircut-level coats
(doodles and poodles, Shih Tzus, Yorkies, Maltese, Bichons, Schnauzers,
Cockers, Pomeranians and friends; dogs that need haircut-type grooming are not
a fit for a quick-bath business), excessive double coats (Siberian Husky,
Alaskan Malamute, Samoyed, Chow Chow, Akita, Keeshond, Great Pyrenees), and
excessively large dogs (Great Dane, Saint Bernard, Newfoundland, Mastiffs,
Irish Wolfhound, Leonberger, Anatolian, Bernese; the business gets in and
out). The shared teeth live in `_breed_excluded()` (0158), used by
`bath_start_subscription`, mirrored in the funnel's breed list and free-text
regex. Legacy grandfathering unchanged.

`villages_only_at_launch` (product):
Hurricane Bath's service area at launch is The Villages, FL, with the address
polygon enforced at booking step 1. The schema keeps the zone abstraction so
later cities can be added without rework. Because launching one zone densely
beats spreading thin across Florida, and a Villages-shaped route is the operator
load model the pricing is calibrated against. Updated 2026-06-07: Ocala is now
also a served city, the origin of the bath pivot (see `ocala_is_a_served_city`
and `new_ocala_clients_are_v2_only`); The Villages remains the destination, but
the service area is no longer Villages-only. RESOLVED 2026-06-08: Paul directed
that Ocala be presented as a location, so `villages_only_in_copy` now means
served-cities-only (The Villages and Ocala) and Ocala has its own `/ocala` page;
new Ocala clients are bath-only, legacy full-groom clients are grandfathered.

`ocala_is_a_served_city` (service area):
Ocala and nearby Marion County (Williston, Dunnellon, Anthony) is a served Clean
location, present in the cities model as slug 'ocala'. It is the home of the
entire legacy book (every legacy client's service address is there) and the first
city of the bath pivot, which deliberately starts in Ocala where Paul already
works before migrating to The Villages. Ocala is added but not yet open for
new-client v2 booking (hb_active false): opening it needs the anchor drive-time
gate live (`ocala_service_area_by_anchor`: Distance Matrix on Clean's Maps key
plus a one-time anchor geocode), then hb_active flipped on. Bath prices and
starting durations are already set, equal to The Villages
(`ocala_prices_match_villages`, `bath_starting_durations`). Ocala needs no drawn polygon. Because the
legacy clients are all in Ocala and need a city to belong to, and the pivot
begins where Paul works; but a city is not bookable for new clients until its real
area and prices exist, so the row exists without going live.

`new_ocala_clients_are_v2_only` (product):
New clients acquired in Ocala may only become v2 clients (bath,
subscription-default, Stripe card-on-file). Clean does not take new full-groom or
nails clients in Ocala. The legacy full-groom and nails clients are grandfathered:
kept, served, and carried into the app, but that book is closed to new entries.
Enforced by the public booking funnel offering only bath and the booking RPC
defaulting service_type to 'bath'; the legacy groom and nails service types are
set only by the admin legacy load, never by public self-signup. Because the whole
business motion is the pivot off labor-intensive low-hourly full grooming toward
fast high-hourly bath work (`favor_high_hourly_work`, `core_is_no_haircut_dogs`),
and taking new full-groom clients would regrow the exact book Clean is winding
down.

`ocala_service_area_by_anchor` (service area):
Ocala's service area for new clients is two gates ANDed together: a new service address qualifies
only if it is (1) INSIDE a frozen containment perimeter Paul drew by hand around his outermost
existing clients, AND (2) within a 15-minute drive of an existing anchor stop (a real client Paul
already serves), measured by Google Distance Matrix on Clean's own Maps key. The drive-time gate
keeps each new stop efficient (no isolated runs); the perimeter is the hard cap that stops an edge
client, once it becomes an anchor, from breadcrumbing the area outward one stop at a time. Anchors
are the routed legacy standing clients plus active bath clients; favor/outlier clients (Tonya Hunt
in Williston, Greta Custer's Dunnellon outlier) are flagged out (`clients.is_anchor` /
`bath_subscribers.is_anchor`) so they neither anchor a new stop nor extend the area. New bath
clients become anchors by default, each individually toggleable, with a manual force-approve for an
address Paul chooses to take outside the gate; because the perimeter is frozen (never recomputed
from new clients), new anchors only densify coverage inside the fence, they never push it out. The
perimeter lives in `public.service_perimeters` (slug `ocala`, GeoJSON, public-readable so the
booking form can pre-check); the anchor coordinates and drive math stay server-side in the
`ocala-service-area` edge function. Because proximity-to-anchor alone makes the area a living
function of where Paul already profitably drives and auto-contracts as the book shifts to The
Villages, but on its own a single edge signup turning into an anchor would let the area walk outward
forever; the frozen perimeter caps that, the drive-time gate keeps efficiency, and the two together
are stricter than either alone (a stop can be a 10-minute drive yet still outside the fence, for
example Belleview, and is then refused). Drawn and decided 2026-06-07 (Paul hand-drew the fence on
geojson.io, southern edge nudged about 1 mile to take in three clipped clients; new clients become
anchors, per Paul). The Villages keeps its own polygon (`villages_only_at_launch`).

`bath_starting_durations` (scheduling):
To start, a bath visit is 30 minutes for a smoothcoat dog (quick) and 60 minutes for a
doublecoat (longer), stored per city in `cities.hb_smoothcoat_minutes` and
`hb_doublecoat_minutes`. These are starting estimates, not measured: refine them once real
bath-only cycle data exists. A multi-dog bath takes the longer tier's minutes among the dogs
for now. Because Paul has no reliable bath-only cycle times yet (the legacy book is grooming
and nails), and a smoothcoat washes and dries faster than a doublecoat, so these blocks are
sane starting points mapped to the coat tiers the pricing already uses.

`minimum_stop_block` (scheduling):
No scheduled stop reserves less than the city's minimum stop block (30 minutes,
`cities.hb_min_stop_minutes`), even when a client's historical median is lower. The duration
reserved is `greatest(the client or tier minutes, hb_min_stop_minutes)`; for example Lisa
Prater's 11-minute mixed-nails median is floored to 30. Because a mobile stop has irreducible
drive-up, setup, and teardown overhead, so a sub-30 block underbooks the route, and 30 is
Paul's quick-stop baseline.

`ocala_prices_match_villages` (pricing):
Ocala's bath prices equal The Villages' bath prices: the smoothcoat and doublecoat recurring
and single rates, the additional-dog decrement, and the founders rates and cap are all copied
across. Because it is the same bath product and Paul set them equal to start; adjust a city's
prices only if its economics later diverge.

`schedule_by_client_history` (scheduling):
An appointment is scheduled for the length that exact client has historically taken: their own
on-site time averaged from recent visits, stored per client as `clients.visit_minutes` (grooms
and nails split where a client gets both, per `time_is_money` source data). The derived service
average is only the cold-start default, used until a client has a track record. The nails
starting average is about 15 minutes for the first dog, 25 for two or three, 40 for four (the
real Time is Money spread validates this: roughly 13 one dog, 26 two, 41 four); the bath
starting average is 30 minutes smoothcoat / 60 doublecoat (`bath_starting_durations`); every
stop is floored by `minimum_stop_block`. Because Paul has years of per-visit history and the
real per-client time beats any average: a chatty household or a slow dog is a permanent,
plannable fact of that stop, not noise to average away. The average exists only so a brand-new
client can still be booked before they have a history of their own.

`adaptive_visit_blocks` (scheduling):
The block an appointment reserves adapts to reality on its own: when a client has at least 3
completed visits with recorded on-site minutes, the block is the median of their last 5 (per
service) plus the city's breathing buffer (`cities.hb_buffer_minutes`, default 15), rounded up
to a 5-minute grid; the static `visit_minutes` snapshot is only the fallback for thin history
(`clean_effective_duration_minutes`, 0153). The buffer stays until the route engine reserves
drive time per stop explicitly; today the slot grid does not know which stop precedes a slot,
so the buffer is what absorbs the drive. Because Paul asked for exactly this on 2026-06-11: a
3-hour block that reality shows only needs 2 hours should shrink on its own, and a tight
90-minute block should grow, with every completed visit feeding the next booking's length
instead of a one-time snapshot going stale.

`fill_the_near_gap` (scheduling):
An unfilled slot in the very near future relaxes the routing rules completely: if it is
mathematically possible to drive to that appointment between the neighboring stops, it is
offered and filled, regardless of zone-day, cadence fit, or any routing preference. Because an
empty near-term slot earns nothing, and filling it is better than letting it go empty; the
routing rules exist to protect future efficiency, which an already-dying slot no longer has.
(Paul, 2026-06-11. Teeth land in the String of Pearls route engine when it is built; until
then the drive-time annotations in the suggestion panel are the manual version of this test.)

`drive_time_in_suggestions` (scheduling):
Every suggested booking slot shows the real drive minutes from the stop before it and to the
stop after it (suggest-drive edge function annotating `admin_suggest_slots`), and only when the
slot is actually ADJACENT to that stop (within about 100 minutes of idle): a stop hours earlier
is not "15 minutes away" in any useful sense, so it shows nothing (field correction,
2026-06-11, after every chip on a day read the same 15 minutes from one distant stop). Within
each day the slots are ordered tightest fit first (least added drive) with the best one
flagged, the first slice of String of Pearls thinking in the booking panel. Drive seconds
between two clients' homes are computed once via Distance Matrix and cached forever in
`drive_cache`, since homes do not move; missing coordinates geocode from the client's plus
code first (some address fields are placeholders that all geocoded to one city centroid) and
persist back. Because Paul picks the slot that fits tightest into the route, and the panel can
only earn that choice by showing real, honest drives, not one stale number repeated.

`appointment_dogs_explicit` (scheduling):
An appointment can carry an explicit list of which dogs are going (`bath_appointments.dog_ids`);
null means the whole regular roster, the historical default. The booking panel offers the
choice whenever a household has more than one dog, and the tracker shows only the assigned
dogs. Because households like Emily Walker's groom different dogs on different rhythms (the
two Cavaliers together, the Golden on her own schedule), and assuming every dog in the house
rides on every appointment records the wrong thing.

`ocala_availability_every_other_week` (scheduling):
Paul works the Ocala route every other week, Tuesday through Saturday, anchored on the week of
Monday June 8, 2026 (the Ocala weeks are June 8, June 22, July 6, and every second Monday after).
On top of that recurring block he can manually open extra days, or add a brief return trip to
Ocala on an off week, and the schedule offers slots only on days he is actually there. Because his
real Ocala presence alternates by week, so the booking engine must never offer a day he is in The
Villages, and his route still throws off ad-hoc Ocala trips that need room (for example the
multi-dog Cummings job that landed on an off week in his calendar). Teeth landed 2026-06-10
(migration 0143): `cities.hb_week_parity_anchor` (Ocala = 2026-06-08) makes `bath_open_slots`
open recurring windows only on on-weeks, and a manual open exception bypasses the parity, which
is exactly the extra-day / off-week-trip path this rule reserves. The same migration fixed the
engine refusing hb_active-false cities, which had silently broken every legacy portal
reschedule (hb_active means "open to NEW public booking" and is enforced in
`bath_start_subscription`, not in the slot grid).

`legacy_login_by_claim` (auth):
A legacy client signs in with phone (SMS OTP), email (magic link), or Google, and the portal links
them to their existing clients record by matching the verified identity (phone last ten digits or
email) through `bath_claim_legacy_account()`, which creates or adopts a `bath_subscribers` row
carrying `client_id`. A clients record already claimed by another auth user is never handed over,
and a repeat claim by the same user is a no-op. Because legacy clients live in the clients book,
not in `bath_subscribers`, so sign-in has to bridge the two by verified identity; the match targets
`clients.phone_e164` and `clients.email` are backfilled from the Acuity calendar feed, which
carries each client's phone and email.

`contact_omitted_is_intentional` (messaging):
For an established legacy client on a fixed recurring schedule, a blank phone and email on the
clients record is intentional, not a data gap. Paul has shown up on a standing cadence these
clients have relied on for years; they neither need the portal nor want automated messages, so
their contact was left off on purpose to keep the system from texting or emailing them. Treat
absence of contact as do-not-auto-contact and portal-optional, and add a client's phone or email
only when a real need appears (they ask for the portal, want to self-serve, or their schedule goes
irregular). Because automated reminders and confirmations must reach only clients who have contact
on file and want them; messaging or chasing contact for someone who runs on a standing schedule
would bother a person who never asked and add work for no gain (prime directive: earn more, grind
less).

`extra_notification_people` (messaging):
A client's appointment messages can go to more people than the account holder: a standing
co-recipient (a spouse who also wants the texts) or a temporary stand-in (Jane Henrich's dog
sitter while she travels), each either IN ADDITION TO or INSTEAD OF the client, with an optional
end date after which the person silently drops out (nobody has to remember to turn the sitter
off). Rows live in `notify_people`; the dispatcher resolves the effective recipient set through
`_notify_recipients` (the client unless an active instead-person covers today, plus every active
in-addition person), so what the Clients-floor panel shows is exactly who gets the messages.
Riker files these by voice ("Jane sent me her sitter's number, text Maria instead until July").
When Twilio lands, the FIRST message to a new person opens with "[Client] asked us to keep you
up to speed on [dog]'s visits" and carries opt-out: that one line is the courtesy that makes an
unexpected text welcome AND the consent posture A2P expects; `opt_in_sent_at` tracks it. Because
real households have two owners and real clients hand the reins to a sitter mid-trip, and the
alternative is Paul keeping a side list in his head of who asked to be texted this month, which
is exactly the kind of unwritten knowledge this system exists to absorb (Paul, 2026-06-10, from
the Jane Henrich case). Pairs with `contact_omitted_is_intentional` (absence of contact stays
deliberate) and `no_fly_list` (an excluded person is never added as a recipient).

`operator_override_with_confirm` (scheduling):
Scheduling rules bind CLIENTS hard and bind PAUL softly: where a client-facing path refuses
outright (a slot that does not fit their constraint window, a duration that overflows a hard
window like Mary Jane's Thursday 12 to 3), an operator-facing scheduling surface shows Paul the
conflict and asks "are you sure?", one tap yes or no, and yes proceeds. First live surface
(2026-06-10, migration 0149): the client sheet's Book-next-visit panel over
`admin_book_appointment`, where a refused time names its conflict and one tap books it anyway
with p_override; the one thing override never crosses is the no-overlap exclusion constraint,
because two stops in the same minutes is physics, not policy. Paul's Google Calendar remains an
ungated path the sync imports.
Because the rules encode his policies, not his physics: he holds knowledge the engine lacks (he
knows he can get in and out of Mary Jane's window in time), and a system that hard-blocks its
owner teaches the owner to route around it, which is worse, because the workaround leaves no
record and the system stops reflecting reality (Paul, 2026-06-10).

`orbit_roles_operator_masked` (Clean: engineering):
Orbit has roles: 'owner' (Paul, everything) and 'operator' (a Hurricane Bath Operator running a
route). An operator signs in with their own Google account (onboarding: insert an `admins` row
with their email and role; their first sign-in binds it via admin_self's adopt-by-email), sees
only the floors the route needs (Today, Calendar, Clients), and the MASKING IS SERVER-SIDE
where a redesign cannot drop it: admin_get_client and admin_today_appointments strip contact
details and money for the operator role and hand back a click-to-text link instead of a phone
number. Honest limit until Twilio: an sms: link necessarily carries the number inside the href
(not displayed, but inspectable by a technical person); true number-hiding is the Twilio relay,
which slots in without changing the UI. Jake is the intended first test operator. Because the
console is being built emperor-mode for Paul but the business is built to run without him
(prime directive), more people are coming, and an operator needs the day's work without holding
every client's personal contact and the business's money numbers; masking in the RPC instead of
the page means no future floor can accidentally leak what the role should not see. Paul,
2026-06-10. Foundation shipped in migration 0150.

`villages_only_in_copy` (Hurricane Bath: copy):
(Name kept for continuity; the rule now means served-cities-only.) The Hurricane
Bath surface names only Clean's served cities, The Villages and Ocala, in
customer-facing copy: no cities Clean does not serve (those are Dog Gone Nails
territory), no speculative future locations. Updated 2026-06-08 on Paul's
direction to fold the legacy Ocala surface in and present Ocala as a location:
The Villages is the live booking surface; Ocala has its own `/ocala` page and is
surfaced in the nav, footer, and homepage service area, marketed bath-only for
new clients (`new_ocala_clients_are_v2_only`) with legacy full-groom clients
grandfathered, and with new-client booking shown as opening soon until Ocala's
anchor drive-time gate is wired and `hb_active` is flipped (`ocala_is_a_served_city`).
Because the surface stays focused on the bath product in the places Clean
actually serves, and naming a city Clean cannot serve invites support questions
you would have to say no to. Pairs with `villages_only_at_launch` (the booking
polygon). When a third zone is added, update this rule and the copy together.

`three_dog_cap` (product):
No hard cap on the number of dogs per visit or per household. The key name is
historical: 3 was the Villages residency limit (2 dogs, 3 grandfathered)
borrowed as a convenient default, never a Dog Gone rule, and it was lifted on
2026-06-07. The only count rule now is at least one dog (DB CHECK
`dog_count >= 1` and the booking RPC guard); there is no upper wall in the
database, the booking form, or the portal. Pricing is per dog and scales to any
count: each additional dog is priced at the prior dog's rate minus the $20
decrement, within the tier. Because the bath pivot starts in Ocala, where the
Villages limit does not apply, and real clients exceed three (one with 5 dogs,
one with 4, most one or two); a borrowed number that blocks a paying client is
worse than no number, the count was never ours to enforce, and the per-dog
decrement already prices each extra dog. The real limit is visit time and route
capacity, which belongs in scheduling (slot length scaling with dog count), not
in a count constraint.

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

`within_24h_non_refundable` (money):
Once an appointment enters the 24-hour window before its scheduled start, the
card has been (or is about to be) charged and that payment is non-refundable.
The portal hides the cancel and skip buttons in this window. The visit is
removed from the operator's day if the client cancels, but the captured payment
stays. A within-24h cancellation does NOT consume the free skip allowance.
Because the 24-hour mark is the operator's commitment point (route locked,
capacity allocated), and asymmetric refund policy past that point would
re-introduce no-show losses that the auto-charge rule exists to eliminate.

`no_show_pause_at_two` (money):
Two no-shows on a recurring subscription auto-pause the subscription via a
counter on the subscription row. The client self-reactivates from the portal
and selects a new slot from current availability. A no-show does NOT consume
the free skip allowance. Because two real no-shows is enough signal that the
client and the slot need a reset, and auto-pausing protects route stability
without requiring the operator to make a judgment call mid-day.

### Skip and reschedule

The skip and reschedule rules below are ported from DGN's canonical policy
(DGN SCROLL_OF_HEPHAESTUS.md sections 6.2-6.8 and DGN ORACLE.md), locked
identical for Hurricane Bath on 2026-05-26. Skip pricing and reschedule
pricing are distinct curves, not the same curve: a paid skip jumps in one
step to the single-visit rate, while a reschedule beyond grace steps up
weekly toward it.

`one_free_skip_per_52w` (skip):
Each subscription includes one free skip per rolling 12-month window.
Unadvertised. The clock starts on the skip date and resets exactly 12 months
later. A within-24-hour cancellation does NOT consume the free skip (the
visit is already paid for per `within_24h_non_refundable`). Because clients
need a release valve to keep a subscription emotionally easy to keep, but
unlimited skips destroy route stability and the operator's working-capital
model.

`free_skip_keeps_maintenance_rate` (skip):
When a free skip is available and used, the next appointment after the skip
is charged at the normal recurring (Maintenance) rate. No change, no penalty.
Portal copy on skip: "This is your free skip. Your next appointment will be
at your regular rate." Because the free skip is a quiet trust-builder, not a
fee event; charging extra on the next visit would convert a goodwill
mechanism into a hidden surcharge clients would resent on discovery.

`paid_skip_resets_next_visit_to_single_rate` (skip):
After the free skip in a 12-month window has been used, a subsequent skip in
the same window prices the very next appointment at the single-visit (Reset)
rate, in one step. NOT a weekly step-up curve. After that single-rate
appointment, if the following visit falls within 4 weeks (5 with grace per
`five_week_grace_returns_to_maintenance`), Maintenance resumes automatically.
Tracked via `subscriptions.last_skip_at` and `last_skip_priced_at`. Portal
copy on the paid skip: "Your next appointment will be at the single-visit
rate. That is because coat maintenance costs more when nails or coat have
grown longer between visits. After that, you will go back to your regular
rate." Because coat maintenance labor really does go up when intervals
stretch, and the one-step jump matches that labor reality without inventing
a fee-stacking curve that would feel punitive.

`five_week_grace_returns_to_maintenance` (skip):
Unadvertised. If the gap between a skipped appointment and the next
appointment is 5 weeks or less, the Maintenance rate applies even without a
free skip remaining. Quiet business decision; never advertised, never
explained. Because at 5 weeks the coat has not grown significantly more than
the normal 4-week cadence, so charging the higher rate would not match labor
reality. Quiet because surfacing it would invite negotiation and turn a
goodwill rule into a haggling tool.

`reschedule_step_up_weekly` (reschedule):
When a client reschedules an appointment, the price for the rescheduled
appointment is calculated based on distance from the ORIGINAL scheduled
date, not from today. Curve:
- 0 to 7 days from original (grace, unadvertised): Maintenance rate
- 8 to 14 days from original: Maintenance + 1/3 of (Reset minus Maintenance)
- 15 to 21 days from original: Maintenance + 2/3 of (Reset minus Maintenance)
- 22 or more days from original: full Reset rate
After the rescheduled appointment, if the next visit falls within 5-week
grace, Maintenance resumes. Because aligning client incentive with route
stability requires the cost of late changes to be visible at the decision
moment; calculating from the original date (not today) is what makes the
curve a real incentive rather than a way to game the picker.

`reschedule_two_paths_for_recurring` (reschedule):
Recurring clients see two reschedule buttons. "Just this visit" reschedules
the one appointment, leaves the subscription cadence unchanged, and applies
the step-up to this visit only. "Change my regular schedule" reschedules this
appointment AND updates the subscription cadence going forward, applying the
step-up to this visit and pricing future appointments at the new cadence's
rate. Because clients reschedule for two different reasons (one-off conflict
versus an ongoing rhythm change) and conflating them either over-charges
casual reschedulers or under-charges true cadence changes.

### UX and copy

`no_reason_field_ever` (ux):
The portal never asks a client why they are skipping, rescheduling, or
canceling. No textbox, no dropdown, no "tell us why" prompt. The client picks
the action (or the new slot) and confirms. Because reason-collection is
friction theater that signals the client owes an explanation; it erodes the
stop-sign promise of frictionless exit and turns a routine action into a
small negotiation. The data that matters (when, what, gap) is already on the
row.

`stop_sign_two_taps` (ux):
The cancel-subscription control in the portal is two taps from portal home,
with a clear consequence preview between them: tap "Stop my subscription",
see a screen that lists what cascades (future not-within-24h appointments
removed; any appointment inside the 24-hour window still charges per
`within_24h_non_refundable`), tap "Confirm cancel". The two-tap promise is
marketed on four surfaces: the homepage block, booking step 2 cadence-picker
tagline, booking step 4 card-entry reassurance, and the portal control
itself. Homepage copy: "Cancel in two taps. No phone calls, no scripts, no
guilt." Booking step 2 tagline: "Try it. If it is not for you, cancel in two
taps." Booking step 4 reassurance: "Cancel anytime in two taps from your
portal. No questions asked." The portal cancel screen carries no reason
field per `no_reason_field_ever`. Refined 2026-06-10 (Paul): the portal
control is DRAMATIC, a literal red stop-sign octagon labeled STOP with "Two
taps and it is done. We stop charging. We stop coming." (the brag made
physical), and the confirm screen states the slot consequence elegantly:
"Stopping frees your visit times for another family on the route. The door
stays open: come back whenever you like and pick from the times that are
open then." That phrasing carries subject-to-availability honestly without
legal chill: the freed slot is presented as generosity to the route, and
re-entry as an open door whose times are whatever is open then. Placement
refined again later the same day (Paul, superseding the morning's Account >
Your plan call): the stop sign lives ON THE PORTAL HOME SCREEN, at the
bottom under the care content, and also in Account > Your plan where someone
managing a plan would look, because the literal two-tap count only holds if
the first tap is available where the client lands (tucked one tab away it
was really three taps), and an exit control you have to hunt for undercuts
the brag exactly where a client goes to check it. Because frictionless exit
is a marketing feature that drives signups, and the visible cancel
commitment is what makes a card-on-file subscription emotionally signable;
hard-to-cancel is what gives subscriptions their bad name.

`octane_selector_cadence_picker` (ux):
Booking step 2 presents three cadence options as three buttons laid out left
to right: "Every 4 weeks" (default, highlighted), "Every 2 weeks", and
"One-off". Above the buttons sits a horizontal arrow pointing left to right
with the copy: "Want your dog fresher?" The visual metaphor is a racetrack
octane selector: same product, increasing freshness as you move up the row.
The upgrade path is freshness, not savings, per
`cadence_4wk_or_2wk_same_price`. Because the visual metaphor makes the
freshness-to-cadence mapping legible at the decision moment, and a clearly
defaulted 4-week with an obvious "more freshness" path positions the 2-week
option as upgrade rather than penalty.

`calendar_shows_price_per_date` (ux):
The portal reschedule date picker displays the price for each candidate date
on the date itself, hotel/airline style: a cheap Maintenance date and a more
expensive Reset date look different at a glance. The skip-then-new-pick flow
uses the same display. Because the reschedule step-up curve is the rule's
enforcement at the moment of choice; surfacing the price on each candidate
date is what makes the curve a real decision input rather than a surprise on
the next invoice.

`founders_spots_remaining_counter` (ux):
The launch/pricing area on the Hurricane Bath surface shows a live
"spots remaining at this rate" counter under the founders pricing, hidden
until remaining drops below a visibility threshold (10 by default), updating
automatically from the active subscription count (no manual maintenance).
Port of DGN's Villages-page pattern: see `doggonenails-site/src/pages/
the-villages.astro`, the `#launch-spot-count` element fed by a public
read on a counted Supabase resource. Because real scarcity is the
conversion tool that gets indecisive visitors to decide today instead of
next month, the auto-update pattern adds zero ongoing work for Paul, and
hiding the count above the threshold avoids the "97 spots left" anti-signal
that tells visitors the offer has no real urgency. Pairs with
`tiered_founders_rate` (which defines the rate and cap the counter draws
from) and `founders_cap_statement_always_visible` (which carries the
scarcity framing when the counter itself is hidden).

`founders_cap_statement_always_visible` (ux):
The founders rate page must state the founders cap (e.g., "first 25
households") prominently in always-visible copy, separate from the
counter element that surfaces only when remaining drops below the
visibility threshold. The cap belongs in the launch card eyebrow,
headline, or subhead, and is reinforced in a terms tile so it cannot
be missed by a scanning reader. Because scarcity expressed only through
a counter-when-low produces a page that does not read like a special
offer when the counter is hidden (the failure mode caught on
2026-05-27, where the first cut of `/the-villages` buried the cap and
read as just another price). The cap is the always-true fact that
makes the offer feel time-limited even before the count is meaningful;
the counter is the urgency signal that fires when supply runs low. Two
distinct surfaces, both required. Pairs with
`founders_spots_remaining_counter` and `tiered_founders_rate`.

`video_audio_only_when_visible` (ux):
Site video autoplays muted and looping; audio turns on only by a deliberate tap,
only one clip at a time, and cuts automatically when the clip scrolls mostly out
of view or the browser tab is hidden. Clips keep playing muted (only the audio
toggles), and returning to the tab or scrolling back never auto-unmutes. First
applied to the `/process` "See it work" clips (muted-autoplay markup plus an
IntersectionObserver and a visibilitychange handler). Because autoplaying sound a
visitor did not ask for is hostile, and sound from a clip that has scrolled off or
a tab that is hidden is the classic "where is that noise coming from" annoyance,
while a muted loop still carries the proof; audio should be a choice the visitor
makes on purpose and should never outlive the moment they can see what is making
it. Pairs with `show_dont_tell` (the clips are the proof shown before it is
explained) and `neural_expressive_design` (gentle, controlled motion).

`single_visit_as_own_path` (ux):
On the city page and in the booking flow, the single-visit option is
presented as its own findable path with its own price block and CTA,
not as a secondary row inside a recurring pricing card. On the city
page that means a dedicated section or card sitting alongside the
recurring options, not a "single visit" line buried under a "recurring"
header. In the booking flow that means a top-level plan choice the
visitor sees before card entry, not an option discovered late. Because
the single-visit price is the on-ramp many new customers need before
committing to a recurring subscription, and most "try us once"
customers convert to recurring after the first visit; burying the
trial path makes it read as an afterthought and starves the recurring
funnel of its main feeder. The failure mode this rule prevents was
caught on 2026-05-27, where the first cut of `/the-villages` showed
the single-visit price only as a row inside the tier pricing card,
which Paul correctly read as "you can't actually try us once." Pairs
with `single_oneoff_higher` (which defines the price spread).

`portal_amazement` (ux):
The portal's overriding goal is that clients are AMAZED at how awesome it is,
amazed enough to tell other people about it. The main road to amazement is
ease: everything a client could possibly want to do with Dog Gone Clean should
be doable in the portal, and every one of those things should be really, really
easy. The standing test for any portal change: does this make a client's want
easier, and would a client mention it to a friend? The portal is the product
surface clients actually live in after signup (the marketing site converts, the
portal serves), so the amazement bar applies to every screen, every flow, every
word in it. The running inventory of client wants to build toward lives in
CLEAN_PARKING_LOT.md ("Portal amazement"). Because word of mouth is the
business's strongest channel and the portal is the thing clients touch most;
a portal that feels effortless converts routine service into the story a
client tells at dinner, and that is the moat (`dig_the_moat`). Paul,
2026-06-10: "let's make this portal something that people tell other people
about. Because it is just that. Awesome."

`gravity_slide_funnel` (ux):
The website's job is to take a right-fit visitor and pull them with the force
of gravity down a slide that ends with a booked appointment and a card on
file, excited. The selling pulls real emotional strings (the dog's wellbeing,
the clean home, the relief of a chore permanently handled, the pride in a dog
that looks and smells great) and is never sleazy: every promise made on the
slide is one the service actually delivers, and the trust mechanics (the
two-tap stop, the day-before charge, the founders cap) are bragged about
openly because they are real. Wrong-fit visitors fall out of the slide through
the person-shaped holes (`excluded_breeds_are_slide_holes`) gracefully, early,
and pointed somewhere useful. Because excitement plus zero friction is what
converts, a visitor who signs up excited and then gets exactly what was
promised becomes the grateful client the prime directive requires, and
overselling converts a signup into a churn and a bad review. Paul, 2026-06-10.

`pizza_tracker_client_loop` (ux):
The client-facing name is THE DOG GONE TRACKER (working name, Paul 2026-06-10;
"pizza tracker" is the internal inspiration shorthand, never client-facing).
The tracker loop runs per appointment, replacing every manual
text: (1) when Paul leaves for the stop, one button push sends the client a
heads-up with a live progress link to their house (the home of
`heads_up_on_the_way`); (2) progress updates flow to the client's tracker view
as the visit advances through SIX stages (refined by Paul 2026-06-10):
scheduled; rolling your way; we're here (the "I'm here" tap: "setting up in
your driveway, with you shortly"); underway, which advances when the BEFORE
PHOTO lands on the visit, never on a timer (refined by Paul 2026-06-10 after
the first field run: a 10-minute timer could say "in the trailer" while he is
still talking in the client's living room, and the before photo is the one
signal true by construction, taken in the trailer right before the work; no
photo just means the stage waits for the next tap); coming back to your
door (a DELIBERATELY MANUAL one-tap stage, because only Paul knows the moment
the dogs are headed back and that is exactly when the client should watch the
door); done. While rolling, the tracker shows a PROMINENT live drive ETA and
the truck on a map (operator location from the Today sheet's geolocation
watch, ETA via Google server-side, both token-scoped and broadcast only until
arrival; honest limit: Chrome only delivers fixes while Orbit is on screen,
so the client sees the last fix with its age, never a guess, and the true
background fix is a small Android companion app, parked); status changes can
chime and vibrate, gentle and short (a doorbell for the driveway, a bright
run for the door), DEFAULT OFF and opt-in via one tap on the tracker because
browsers require a gesture before sound, remembered per device, and a chime
fires ONLY for a change observed live (page visible, last poll under a
minute old): a backgrounded tab catches up silently, so nobody gets a
doorbell an hour after the truck arrived and left; (3) photos taken
through the visit (before, after, extras including skin or health observations
worth flagging) attach to the visit and surface in the client's portal record
as their dog's history; (4) after Paul drives away, a professional follow-up:
an extra-tip ask only when appropriate (new clients and known lovers of the
service, never blanket), and a feedback-plus-Google-review ask for everyone
EXCEPT anyone already asked or who already left one. The review ask is tracked
per client (record the ask, track the click, stop forever once a review
exists) and stays active only for a limited window after the visit, so the ask
is timed, never nagging. A tracker link answers for the visit plus 7 days
after the scheduled end, then reports expired and points at the portal:
long enough for the "show someone" photo moment, short enough that an old
text never stays a live window into the household's schedule; tokens stay on
the row (history is never deleted), only the public answer goes quiet.
Because the tracker is the experience clients tell
their friends about and the un-promptable moat (`dig_the_moat`); review volume
is throughput-limited near full capacity, so the system optimizes the timing
of one well-placed ask instead of manufacturing volume; and a tip ask aimed
only where it is welcome reads as confidence while a blanket ask reads as a
shakedown. Spec locked by Paul 2026-06-10; sends gate on Twilio and online
tips gate on Stripe, build order in CLEAN_PARKING_LOT.md.

### Engineering

`string_of_pearls_is_a_service` (engineering):
The String of Pearls scheduler is built as a backend service from day one,
callable both from the Hurricane Bath Astro app (direct Supabase RPC) and
from the legacy doggoneclean.us Squarespace site (CORS-locked Supabase edge
functions plus an embeddable `/schedule-widget` iframe route). Edge functions
are service-type aware: `?service=bath` carries Hurricane Bath durations and
rules, `?service=full-groom` carries the legacy variable durations. Keys are
domain-locked per `own_infrastructure`. Because the doggoneclean.us rebuild
is sequenced after Hurricane Bath, but dropping Acuity should not wait that
long; building the scheduler as a service from day one lets the legacy site
adopt it via embed while the new site uses it natively.

---

## Money

`bills_in_person_today` (money):
Surface-scoped. Legacy Ocala full-grooming (served from doggoneclean.us until its own
rebuild) bills in person at the appointment: cash and card via Square (reader plus
invoices), no checks. Stripe is not used on this surface. The Hurricane Bath v2.0 surface
(hurricanebath.com) is the exception and is governed by `card_on_file_at_signup` +
`auto_charge_at_24h` (Stripe SetupIntent at booking, charged at the 24-hour mark). Because
the two surfaces have different operating models: legacy is pay-after-service for known
clients on a held route, while Hurricane Bath sells a subscription-default product to new
clients where a card on file is what makes the 24-hour commitment loop work; one payment
rule cannot serve both without breaking one of them.

`legacy_folds_into_v2` (architecture):
Legacy Ocala full-grooming clients are first-class clients inside the one Clean app, not a
separate portal and not a reduced mode. They sign in, self-schedule, reschedule, skip, and
manage their account exactly as a bath subscriber does. The doggoneclean.us domain redirects
into the app; the Squarespace site and the Acuity scheduler are retired (target: within days
of 2026-06-07). One generalized recurring-service model carries both surfaces: a service
relationship has a service type (full groom, bath, or nails), whether it recurs or does not, a
per-visit block duration, and a payment method. Recurring-versus-not is a real per-client
attribute, recorded and never assumed from visit counts: a client either holds a standing
recurring slot on a cadence or books on demand (one-off or at-will), and the app models both
distinctly. Bath is Stripe card-on-file plus a fixed bath duration; grooming and nails are
in-person Square plus the client's real block time, seeded per client from years of appointment
cycle-time history, so the scheduler blocks each client's actual time with no guesswork. Block
time is on-site time (arrive to depart, the client's median cycle); the route engine calculates
the actual inbound drive time to each stop separately and does not fold it into the client's
block. Every existing legacy client is carried into the app; none are dropped in the migration. Legacy keeps paying in person via Square through the cutover; moving legacy
to card-on-file is a deferred, separate decision and is not part of this work. Acuity's
reminders are load-bearing, so reminders must exist in the app before Acuity is cancelled or
clients no-show; those reminders and confirmations are sent from Clean's own Supabase as a
scheduled edge function (see `confirmations_and_reminders_via_supabase`), not n8n, which is
reserved for later automation. Because killing Squarespace
and Acuity removes legacy's only operational home, so legacy needs that home in the app now,
not at a later rebuild; one app with one login preserves the client relationship and full
history through the Ocala-to-Villages, grooming-to-bath migration that is the core business
motion, where a second portal would fracture that relationship and is also the slowest path to
build under a deadline; and Acuity's death is not Square's death, so in-person payment keeps
working and stays out of the cutover's critical path. This supersedes the 2026-05-26 "two URL
surfaces, legacy rebuilt later" framing per reality_wins: the legacy rebuild is this, folded
into the app.

`confirmations_and_reminders_via_supabase` (architecture):
Appointment confirmations and reminders are sent from Clean's own Supabase: a scheduled edge
function on a pg_cron trigger calls the SMS and email providers, mirroring DGN's
`send-notification` edge function but with Clean's own instances and keys (never shared, per
`clean_stays_saleable`). n8n on the shared droplet is reserved for later, non-core automation
and is not the confirmation or reminder path. Because Acuity's reminders are load-bearing and
must be rebuilt before Acuity is cancelled (`legacy_folds_into_v2`); the notification path
belongs in the same Supabase that owns the appointments, on the same scheduled-function
pattern DGN already proved, rather than in a separate automation tool that would split the
system and complicate a future sale.

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
Legacy surface only (doggoneclean.us). State the accepted-payment list consistently
everywhere it appears on the legacy surface: cash, Visa, Mastercard, American Express,
Discover, Apple Pay, Google Pay, and Samsung Pay, all run through Square (the in-person
processor). No checks. PayPal and Cash App can be taken if a client insists, but are
deliberately not advertised, because they are an extra hassle and usually a fumble at the
trailer. The Apple, Google, and Samsung wallets are methods clients pay with and do not
conflict with `device_profile`, which governs Paul's own tools, not what clients use. The
Hurricane Bath v2.0 surface does not use this list; it is card-on-file Stripe per
`card_on_file_at_signup`. Because a clear list stops clients wondering whether they need
cash or an ATM stop, and naming the wallets removes a friction point at the trailer.

`house_shampoo` (service):
Clean washes everyone with one gentle, well-tolerated house shampoo; a client who wants a
specific, medicated, prescription, or flea product provides it, Clean runs it through the
Hurricane Bath system at no extra charge, and the bottle goes right back to the client. Because
at scale one reliably inoffensive shampoo avoids the steady stream of complaints any single
product attracts (twenty years of auditions; this is the one no one has ever complained about),
Clean cannot stock every medicated formula or know which one treats a given dog, and a single
flea bath cannot fix an environmental flea problem the dog will just be re-exposed to. The
specific house brand stays in the private record, not public copy (`dont_knock_competitors` and
brand-neutral copy); privately it is TropiClean Papaya & Coconut Luxury 2-in-1 Shampoo and
Conditioner (brand name corrected 2026-06-10 from "papaya and mango"; mango is only in the
botanical blend). Public copy may hype the verifiable product facts without the name: gentle,
soap free, paraben and dye free, naturally derived ingredients, light tropical scent, and
soap-free cleaning that does not wash away vet-applied topical treatments. The
bring-your-own offer is marketed as a service ("hand us the bottle, it comes right back, no
extra charge"); it stays free unless it ever becomes a real hassle, which is Paul's call to
revisit. Any non-guarantee wording (Clean does not promise a client-supplied medicated or flea
product will work) lives in the intake or terms, never the marketing copy, which stays positive
and skips the flea lecture (`reminder_voice`).

---

## Service and operating policies

`online_only_comms` (process):
All client communication (scheduling, updates, questions) runs through the online system; Clean
does not take or return phone calls. Because Paul is hands-on with dogs all day and cannot step
away for calls, and an online record keeps every booking and change documented and clear. The
outbound heads-up text still goes out (`heads_up_on_the_way`); this rule is about inbound calls.

`friendly_dogs_only` (safety):
Clean grooms friendly dogs; a dog must be handleable without aggression. Snapping, biting
attempts, or aggression ends the appointment immediately, and resistance that prevents safe,
efficient work can mean service is declined. Clients disclose behavior concerns before booking.
Because a dog-bite injury can put the groomer out of work and the whole business runs on Paul's
hands; it is a safety boundary, not personal. Serves `protect_the_operator` and the prime
directive's good-for-the-body test.

`core_is_no_haircut_dogs` (roster):
Clean's core focus is dogs that do not need haircuts: short coats, double coats, heavy shedders,
working breeds. Haircut breeds are still served but are not the focus, and doodles are declined
outright (`no_doodles`). Because no-haircut natural-coat grooming is the fast,
high-revenue-per-hour bath work the business is repositioning toward (`favor_high_hourly_work`),
while haircut-heavy coats are slow and low-margin; this is the market position already on the live
site.

`service_area_ocala` (routing):
The service area is Ocala, Florida (most Ocala mailing addresses). Hard exclusions: no unpaved
roads, and no service to Silver Springs Shores, Summer Glen, or Marion Oaks. Because these are the
real operating limits the route and intake must honor; a booking outside them is declined up
front, not routed. Pairs with `base_is_home_sw`.

---

## Copy and terminology

`grooming_vocab` (copy):
In customer-facing copy always write "dog grooming" and "dog groomer", never the bare words
"grooming" or "groomer". The craft itself is correct for Clean (unlike DGN), but the
unqualified terms read as the predatory sense of the word and undercut trust on sight, so the
"dog" qualifier is mandatory. "Groom" as a verb with a dog object ("we groom your dog") and
"a full groom" as a noun are fine; it is the bare "grooming"/"groomer" that is banned. Because
the brand voice has to read unambiguously as pet care. Enforced by `scripts/check.py` over
`src/` (the website copy).

`specialist_named_not_promised` (copy):
The current operator of a Hurricane Bath route is named and photographed in the
marketing copy (today: Paul). The copy never promises "you will always see Paul"
and never implies an interchangeable Tom-or-Dick-or-Harry. It pairs with the
existing "the standard does not belong to a person, it belongs to the process"
language, so a new operator joining the team does not break a promise made to
existing clients. Each operator who joins the team gets their own name and
photo in the copy when they start, in the same section, on equal footing.
Because Paul is the trailblazer today but the business is being built so it can
add operators later (the prime directive's "runs without Paul" and "a unicorn
job" tests), and copy that locks in "always Paul" makes every future hire read
as a downgrade, while copy that hides the operator entirely makes the brand
feel faceless. Named-but-not-promised is the version that serves both the
"clients grateful it exists" test (you know who is coming) and the
runs-without-Paul test (the brand survives a hire) at the same time.

`hurricane_bath_operator_title` (copy):
The client-facing title of the person who does the work is HURRICANE BATH OPERATOR, capitalized
as a title; Paul's full styling is "Owner and Hurricane Bath Operator". Use it everywhere the
worker is named or described in customer-facing copy (the tracker, the city-page specialist
card, the trust lines, the team copy); never a bare "operator" or "the operator" in client-facing
prose. Internal usage (Oracle rules, code, DB roles, the route data model) keeps plain "operator"
since the role name and the display title are different things, same as the String of Pearls
pattern at DGN. Locked by Paul 2026-06-10 ("in Clean overall the name of the worker is Hurricane
Bath Operator, make it so"). Because the bare word is generic filler while the title carries the
brand's signature system in the worker's own name, so every mention of who is coming restates
what makes the service different; Paul chose it on sound ("Owner and Hurricane Bath Operator
sounds better"). Pairs with `specialist_named_not_promised`: the title scales to every future
hire without re-writing the promise.

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

`post_appointment_show_someone_nudge` (copy):
Every post-appointment client text follows this exact two-line format, identical at Dog Gone
Clean and Dog Gone Nails:

```
[Dog's name] before and after.
Show someone.
```

Photos are attached as MMS. "Show someone." is the literal second line, two words, no variations.
The nudge is deliberately bare: no brand handle, no @-mention, no "tag us" line, no
platform-specific share call, no pre-filled social caption. The client is treated as already
proud of the photo, and the nudge only removes friction if they decide to share. Anything that
flows back to the business is downstream of the client's choice and carries the weight of
being unprompted.

Hard line that does not move: the text never contains a pre-filled brand handle, an embedded
"@doggoneclean" caption, or a "tag us" appendage. A later companion share page on
doggoneclean.us (or hurricanebath.com on the v2.0 surface) is allowed once Clean's Supabase
booking pipeline writes per-appointment photo records: it uses the Web Share API to one-tap
the photos into the client's native share sheet, presents an optional generic caption, and
stays under the same constraint (no pre-filled brand handles, no embedded "@doggoneclean"
caption, no "tag us" prompt). Platform choice, caption, and tagging always stay with the
client; the helper only removes the steps of saving to camera roll and opening another app.
The share page is parked in CLEAN_PARKING_LOT.md until the photo pipeline lands.

Because the nudge's strategic value lives entirely in being unprompted. Pre-filling brand
handles or appending "tag us" copy converts organic enthusiasm into a recognizable marketing
channel, which simultaneously destroys the unprompted-word-of-mouth dynamic and crosses the
line from making sharing easy into using the client as a promotion channel. The honest
position is that we want clients to share these photos and we want to make that easy, and
if it sometimes comes back to the business that is fine because it arrived without an ask;
embedding the ask in the message itself converts kindness into an ask and collapses the
value. Effective immediately on Paul's existing post-appointment send (Google Voice today,
Twilio MMS once A2P 10DLC clears).

`dont_knock_competitors` (copy):
Never disparage other systems, products, or groomers in client-facing copy; make the case for
why ours is great on its own merits. Because putting others down makes the brand look insecure
and invites argument, a confident positive case ages better, and it fits the prime directive's
bar of leaving everyone better off. Competitor weaknesses can still be noted privately in the
corpus to sharpen our own design, never in public copy.

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

`show_dont_tell` (copy):
Show the proof and let the visitor reach the conclusion; do not assert the feeling in words.
Two applications are locked. First, the strongest proof (video of the bath working) sits high
on the page, above the explanation, so a visitor sees the bath in motion before reading why it
works: the `/process` page leads with the "See it work" clips directly under the hero, the
same pattern as the homepage where the Hurricane Bath section precedes "why Paul built it."
Second, the trailer's calm is shown, never claimed: footage of an unbothered dog, steady
hands, and the quiet of the climate-controlled interior carries "this is a peaceful place"
without the page ever saying so. Because a conclusion a viewer reaches on their own is
believed, while a direct claim about calm invites the opposite reaction (a nervous owner reads
reassurance as papering over stress), and proof shown before it is described persuades harder
than the same point made in prose. Paul's own words, 2026-05-28: the trailer is his happy
place, and it may make more sense to show that and let people come to that conclusion by
themselves than to say it out loud. Pairs with `language_bank` (the spoken and text
reassurance lines) and `neural_expressive_design` (key message and proof big at the top,
detail below).

---

## Design

`neural_expressive_design` (design):
Clean's website visual design follows Google's "Neural Expressive" language, the Gemini app
redesign unveiled at Google I/O 2026 and rolled out 2026-05-19, NOT Material 3 (which was
proposed this session and explicitly rejected). Translate its hallmarks to a marketing site:
vibrant blue gradient washes and soft "illuminated" glows (Neural Expressive's signature, and
a fit for DGC's brand blues), ombre/gradient fills on key words, a simple sans-serif with
strong size contrast between headings and body, an editorial hierarchy that puts the key
message big and bold at the top with lighter detail below, and gentle fluid motion. The
expressiveness comes from color, gradient, and glow, not a special typeface, so no web-font
dependency is needed. Restyle, do not reinvent: rebuild the existing DogGoneClean.us content
and structure in this look rather than inventing new copy (pairs with `real_data_only` and
`no_mockups`). Because Paul chose this look by name and rejected Material 3, and recording the
exact reference plus its concrete tokens stops a future session from re-guessing the style or
sliding back to the wrong system.

---

## Engineering constraints that protect outcomes (apply when the relevant tech exists)

These are carried from DGN's hard-won lessons. They are not active yet because Clean has no
app, but they are recorded here so they are not re-learned the hard way during the build.

`maps_js_api_only` (engineering):
Google Maps usage from the browser is via the JS API, never a REST API; the routing and
drive-time REST calls (Routes API, formerly Distance Matrix) run server-side. This means two
separate keys, never one: a BROWSER key restricted by HTTP referrer to Clean's domains and
scoped to the Maps JavaScript API (for displaying maps), and a SERVER key restricted by IP to
the backend and scoped to the routing API (for the scheduler's drive-time math). Because the
REST API has CORS issues in the browser and cannot be domain-locked there, while a
referrer-locked browser key cannot authenticate a server call (no referrer is sent), so
splitting the keys is the only way each one is both functional and tightly restricted. Make a
key only when its lock target exists: the browser key now (the domains are known), the server
key once the droplet exists and its IP is known. Directly relevant since Clean is a routing
business. The browser key must ALSO have the Places API (New) enabled, not just Maps
JavaScript: the booking funnel's address field uses `PlaceAutocompleteElement` (Places API
New) for address entry + the in-area service-area check, which bills as Places but is still a
browser JS call (sends a referrer, stays referrer-locked, NOT a REST call). Do not strip Places
off the browser key thinking it violates this rule; the rule bans browser REST calls, not the
JS Places library. Use the NEW element, not the legacy `google.maps.places.Autocomplete` widget:
Google blocked the legacy widget for Cloud projects created after March 2025 (Clean's project is
new, so the legacy `Autocomplete` errors with LegacyApiNotActivatedMapError; nails' legacy widget
works only because nails' project predates the cutoff). Wired 2026-05-29 in
`src/components/portal/maps.js`: classic `libraries=places&v=weekly` loader (the
form Clean's project loads cleanly), then `google.maps.places.PlaceAutocompleteElement`
used directly off the namespace. The address field is a single box, never a
multi-field form (the fallback if Maps fails is one plain text input, not a form).

`service_area_enforced_server_side` (engineering):
The service-area (in-polygon) check is authoritative in the signup RPC
(`bath_start_subscription` calling `_bath_point_in_area` over `cities.polygon`), not in the
browser. There is NO manual address path. A booking must carry coordinates that fall inside the
polygon or it is rejected before any row is written: coordinates absent (autocomplete bypassed or
unavailable, or a crafted request) is a hard reject; coordinates outside the polygon is a hard
reject; coordinates inside proceed with `bath_subscribers.address_verified = true` (migration
0009, which supersedes 0008's accept-as-unverified branch). The Google Places autocomplete in the
booking island is the only way to enter an address and is a convenience for capturing it, not the
gate; when it cannot load, the funnel shows an honest "booking opens shortly" notice and the gate
stays closed. Because the only area check used to live in the browser (`maps.js`) and ran only
when autocomplete returned coordinates, so a dead autocomplete box, a manual-entry fallback, or
any crafted request could place an out-of-area signup. A location gate a redesign or a dead widget
can bypass is not a gate (see `redesign_survival_is_a_ship_gate`), and a manual "confirm it later"
path is precisely the unverified hole this rule forbids: address either autocompletes and is
in-area, or it cannot book. The `address_verified` column stays (always true on a successful
booking now) as a belt-and-suspenders guard the future charge job still honors.

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

`rpc_grants_explicit` (engineering):
Every SECURITY DEFINER function declares its audience with explicit grants, and PUBLIC
never holds EXECUTE. The tiers: the deliberately-anonymous booking RPCs
(bath_start_subscription, bath_open_slots, bath_lookup_subscriber,
bath_founders_remaining) are granted to anon; admin_* and the authenticated portal
bath_* RPCs are granted to authenticated only (their in-function auth gate, _is_admin
or auth.uid(), still applies on top); everything else (internal _ helpers, agent scans,
cron dispatchers, edge-function data feeds) is service_role only. Default privileges in
the public schema revoke EXECUTE from PUBLIC, so a new function is born locked and must
be granted to its audience deliberately (migration 0135). Because Postgres grants
EXECUTE to PUBLIC on function creation, which silently made about 110 functions
anon-callable over a month of fast building, including ungated internal write helpers;
a default that fails open cannot be outrun by remembering, so the default itself was
flipped. Locked 2026-06-10. Refinement (same day, the photos-into-the-void lesson): a
helper referenced by an RLS POLICY runs as the INVOKER, not as a definer, so it must
keep an explicit grant to every role whose queries that policy can gate; the 0135
lockdown silently broke every visit-photo upload and signed-URL read because the
storage policies call `_is_admin()` as the authenticated user. Fixed by migration 0142
(grant `_is_admin` to authenticated + anon; it only reads auth.uid() against admins and
returns a boolean). When locking grants down, list the functions used inside
`pg_policy` expressions first; those are the ones the lockdown must exempt.
Round two (0147, same day): 0135's default-privileges fix only revoked PUBLIC, but
Supabase projects ship per-role defaults (pg_default_acl grants EXECUTE to anon,
authenticated, service_role on every new public function), so everything created after
0135 was born anon-callable again and per-migration "REVOKE FROM PUBLIC" never touched
those explicit grants. 0147 drops anon + authenticated from postgres's function
defaults and re-runs the tier sweep over all public app functions (extension functions
are supabase_admin-owned and unaffected). The durable lesson: after any grant lockdown,
verify with pg_default_acl and has_function_privilege, not with the migration text.

`offline_first_field_app` (engineering):
If a Clean field/operator app is built, it renders today's full state from a local store
instantly with or without signal; the server is a sync target, not a query source, and
write-queue state never gates a read or a render. Because a field app that fails to render
because of a client-side sync condition is the failure mode that broke DGN's first field
tests in a no-signal trailer.

---

## How to add a rule

1. Write the entry here with a real because.
2. **In the same commit (or at most the next one), add its enforcement
   layer.** If the rule expresses itself in customer-facing copy or in
   structural markup, add a `scripts/check.py` pattern that fails the
   build if the expression is dropped. If the rule lives in code, add
   the constant/function (today: `scripts/check.py`; later:
   `src/business/`). The previous practice of "land the rule now,
   defer the lint to later" repeatedly produced rules-in-name-only:
   the Oracle said one thing and the only thing standing between a
   redesigner and dropping it was a comment. A rule that can be
   silently dropped at the next refactor is not a rule.
3. Update `CLEAN_BUSINESS_RULES.md`: the "Enforced today" column names
   the live layer (Oracle + check.py + DB + ...), the deferred column
   names what else this rule will gain when a downstream piece lands.
4. (Deferred until the rules are agreed and a business_rules table
   exists: add a row in a migration. Not built yet per
   `no_database_until_rules_agreed`.)

A rule that lives in only one place is a rule waiting to be lost. The
target is the four-layer pattern in `CLEAN_BUSINESS_RULES.md`: Oracle
(rationale), `business_rules` DB row (data), code mirror (`src/`),
lint pattern (`scripts/check.py`). New rules close as many of those
layers as they can the day they land.

---

## Finance

`expense_ledger_clean_start` (Clean: finance):
The expense ledger is a clean go-forward start, not a historical backfill. Paul
begins uploading business-account statements from the current month onward, and
net profit begins at that cutover. Because the revenue side already carries the
proprietary multi-year trend that is the moat, the old full-groom cost structure
has little forward value, a clean cutover is proper bookkeeping, and prior years
already live with the accountant, so duplicating closed periods here would only
create a second source of truth. Decided 2026-06-08.

`books_complement_not_replace` (Clean: finance):
The console money-in and money-out ledger is a management cockpit, not a
tax-accounting system. It stays clean enough to drive the CFO and to export for
the accountant, but it does not build double-entry, tax forms, payroll, or penny
reconciliation. Because tax-grade accounting is the commodity layer that an AI
can prompt past and a buyer can simply purchase, while the un-promptable moat is
the operational intelligence tied to this specific business (revenue per hour,
route economics, where the money leaks). QuickBooks or a bookkeeper stays the
system of record for taxes, and this console feeds it. Decided 2026-06-08.

`per_business_books` (Clean: finance):
Each business keeps its books only in its own Supabase project. Clean's expenses,
recurring costs, CFO, and bookkeeping live in dgc-prod; Nails' live in dgn-prod;
and each new business gets its own, with one bank account per business feeding
its own ledger and never crossing. The top level (Mount Olympus) shows a
read-only consolidated view across businesses (total in, total out, net), but it
never stores a shared ledger: the cross-business picture is computed from each
project at view time, not held in a store that spans them. Shared costs that
serve more than one business are paid by each from its own account where
possible, or tagged and split when one account pays for several. Because
clean_stays_saleable: a business's books must leave cleanly with it if it is ever
sold, so they can never be commingled. Decided 2026-06-08.

---

## AI agents

`agent_costs_logged` (Clean: finance):
Every LLM-backed agent (Riker, the message drafter, the Archivist, the weekly
review, the CFO brief, and whatever joins them) logs its token usage to
`agent_costs` on every call, and the HR floor shows what each agent has cost
historically and the projected month ahead, priced from the published per-token
rates. Agents that run as plain database jobs (the availability watcher, the
charge cron, the calendar sync) cost effectively nothing and log nothing.
Because Paul asked to see what his AI staff costs, and `agent_when_value_beats_cost`
is only checkable when the cost side is a number on a screen instead of a guess.

`infra_usage_watched` (Clean: operations):
The infrastructure under the business is watched like everything else: a daily
scan snapshots database and storage usage into `infra_metrics` and cards Today
when either passes 70% of the plan limit, and the Operations floor shows the
live numbers. Plan limits live in `app_secrets` (`infra_db_limit_mb`,
`infra_storage_limit_mb`, defaulting to the Supabase free-tier 500 MB / 1 GB)
so a plan upgrade is one row, not a deploy. The DigitalOcean droplet (50 GB
disk serving the static site) is named honestly as not yet instrumented; its
risk is low because the deployed site is a few MB. Because Paul asked to know
about server limits and storage space before they bite, and a surprise
full-disk or full-database is exactly the kind of 2 a.m. problem this app
exists to prevent.

`calendar_sync_moves_orbit` (Clean: calendar):
The Google Calendar sync is two-way in effect for every appointment it knows:
moving an event in the calendar moves the appointment in Orbit (the sync
updates times by external_id), and an app-booked appointment that Paul added
to the calendar gets ADOPTED on the next sync (the overlapping event stamps
its external_id onto the existing row instead of inserting a duplicate), so
from then on calendar moves carry it too. Adopted rows keep source null, so
the prune (which only deletes source='gcal_sync' rows) can never remove an
app booking even if the calendar event is deleted. The sync window is 366
days, covering Paul's year-ahead pencils, and a single overlap collision
skips that one event instead of aborting the whole run. Because during the
bridge period the calendar is still Paul's working surface, and a sync that
duplicated his own bookings back at him, or died whole on one collision,
would make the bridge worse than no sync.

`today_feed_by_value` (Clean: operations):
The Today feed is ordered by value, never by arrival time: severity first (an
alert outranks counsel), then by how asymmetric the card's payoff usually is.
Revenue actions lead (capacity, win-back, pricing, retention: each is a
one-tap action worth a whole visit), money counsel reads next (CFO, chief of
staff, bookkeeper), housekeeping waits politely (compliance, infrastructure,
maintenance, reorders). Within the info tier the day-before route brief leads
because Paul acts on it every single evening. Because Paul asked for the
highest-value, smallest-effort-biggest-win things on top, and a feed sorted
by timestamp buries a win-back under a filter reminder.

`day_before_brief` (Clean: operations):
Every evening an agent writes ONE card with tomorrow's route in stop order:
time, client, the dogs going, how to get in (access notes), standing
instructions per dog, and open follow-ups; penciled stops are included and
labeled. It supersedes its own previous card so the feed never stacks stale
briefs, and it costs nothing (pure SQL). Because the brief turns Paul's
morning prep into zero minutes: everything he used to assemble from memory
and contact sheets is already on one card the night before.

`sms_consent_unchecked` (Clean: compliance):
The SMS consent checkbox in the booking funnel starts UNCHECKED, always, and
booking proceeds fine without it (email carries the notifications). Because
consent that was pre-checked is not consent: A2P registration expects opt-in,
and a client who never noticed the box did not agree to anything.

`preview_before_live` (Clean: engineering):
Two release modes, switched by whether real clients are using the surface.
Pre-traffic (today): ship straight to main, fast and bold, because there is
nobody to break. Once a surface carries real client traffic, user-facing
changes go out for a look first: push the candidate to the `preview` branch,
which publishes the whole site to preview.hurricanebath.com (same audit gate,
separate directory), Paul clicks through it, says ship, and only then does it
merge to main and reach clients. Database migrations are the exception that
stays careful in BOTH modes, because schema has no preview copy. The flip to
preview-first happens per surface on Paul's word, not on a date. Because
recklessness is free before launch and expensive after it, and Paul wants to
see a change with his own eyes before clients do.

`one_visit_per_day_per_client` (Clean: clients):
A client has ONE visit record per Eastern day, no matter how many paths feed
it: the stop flow's arrival stamps create it, and anything Paul tells Riker
about that day MERGES into it (filling empty fields, appending notes, adding
scores) instead of inserting a second row. Bare dates are interpreted at noon
Eastern, never midnight UTC, so a backdated visit can never display as the
previous evening. Because the duplicate-visit glitch (Eric Shannon, found
live 2026-06-11) came from two writers each making their own row, and a
doubled visit corrupts everything downstream: cycle medians, adaptive blocks,
revenue, and the suggestion engine's due dates.

`business_value_in_sight` (Clean: finance):
The Finance floor leads with a continuously updated what-would-it-sell-for
range (`admin_business_value`). While the expense ledger is thin it uses an
annual-revenue multiple adjusted by what we genuinely measure (recurring
revenue share, year-over-year growth); the moment recorded business costs
reach 5% of revenue it switches automatically to seller's discretionary
earnings times the standard 2.0 to 2.8 owner-operated route multiple, same
adjustments. All inputs and multiples display so the number shows its work,
and every assumption lives in one migration for Paul to retune. Because Paul
wants the big picture in sight through the daily hustle: he does not plan to
sell, but a business valuable enough that someone would want to buy it is the
truest single gauge that everything is going well, and it keeps
clean_stays_saleable honest.

`family_window_into_the_business` (Clean: operations):
Kristin has her own Orbit login (role 'viewer') that opens onto ONE floor, the
Family window: what the business is worth and its two health levers, the last
30 days of money and visits, the earned-per-hour rate, and where Paul is right
now with each stop's plain-words status. No cards to act on, no settings,
nothing that needs tending; signal only. The viewer role sees no other floors.
Because Kristin is very much a stakeholder in something that is becoming a big
part of their lives without being in the day-to-day, and the page that earns a
voluntary glance over coffee is the one that asks nothing and tells the truth.
Paul, 2026-06-12.

`operator_identity_on_the_tracker` (Clean: operations):
Each operator's profile photo and bio live on their admins row (photo_path,
bio), set from the HR floor, and the tracker serves whichever operator is
assigned to the appointment: name, title, bio line, header photo, all of it.
Because the who's-coming block is a trust feature, and Jake's first solo visit
showed Paul's face over Jake's name; a new operator's identity must reach
clients with zero code changes.

`photo_inbox_for_claude` (Clean: process):
Orbit carries a Library floor, the asset library: every photo and video Paul
hands the business lands in the private bucket with a row in site_inbox,
carrying an editable note and a status (new, shelf, used, dropped). A great
shot goes on the shelf even with no use for it yet. A media file with no note
is held, never guessed at. Claude reads the library each session, acts on the
notes, and updates statuses. Files over the storage plan's 50MB cap go to
Google Drive instead, where Claude reads them with the Drive tools. Because
getting a file from Paul's phone to Claude was a standing friction point,
good photos were getting lost in the Google Photos stream with nowhere to
put them, and the first real use proved a note typed after the file pick was
silently lost; a description that goes into the void teaches Paul to stop
writing descriptions.

`schedule_adherence_is_a_main_metric` (Clean: operations):
Schedule adherence, the gap in minutes between an appointment's planned start
and the actual arrival the tracker stamps, is tracked as a first-class metric
alongside cycle time: signed delta per stop (late positive), on-time rates,
and drift across the stops of a day, derived live from bath_appointments
.scheduled_start and visits.arrived_at by admin_schedule_adherence and shown
on the Reports floor. Historical ground truth (1,158 stops, 2023 to 2026,
median 78 minutes behind) lives in schedule_adherence_history, seeded from
legacy/data/adherence_history.json (the Time is Money sheet matched against
the calendar), and the RPC returns it as a separate baseline block beside
the live series: the history is the benchmark to beat, never blended with
the tracker-era numbers, because the two come from different instruments.
Because Paul plans the day on the calendar and reality keeps diverging from
the plan, and a divergence you do not measure quietly becomes the schedule:
honest scheduled times, realistic day plans, and client trust all hang on
knowing this number. Paul, 2026-06-12.

`living_prospectus` (Clean: finance):
Orbit carries a Prospectus floor: the standing pitch to a buyer who does not
exist yet, written as if Dog Gone Clean were for sale today. Every claim
carries a receipt and every number is computed live from the operating
tables by admin_prospectus on each load; nothing is typed in by hand and
nothing is invented. Because Paul wants to see, always current and always
true, why someone would want to buy this business: it keeps the
clean_stays_saleable guardrail visible instead of theoretical, and a pitch
that only reads stronger when the business actually gets stronger is a
compass, while a stale or padded one is a lie waiting to be discovered.
Paul, 2026-06-12.

`know_your_limits` (Clean: operations):
Everything the business pays for that has a ceiling lives as a row in
infra_limits (service, what is limited, the limit, and a note on where to
check it), and admin_infra_status attaches live usage to every limit the app
can measure (database, storage, auth accounts, emails sent, Anthropic spend)
and says "dashboard only" for the rest, all shown on the Operations floor
under the infrastructure panel. When a plan changes, the row changes.
Because a limit you are not tracking is discovered by hitting it, in
production, on a route day; the Supabase watcher proved the pattern and the
rest of the stack (droplet disk, Resend's 100-a-day, the 50MB upload cap)
deserves the same eyes. Paul, 2026-06-12.

`tracker_undo_is_deliberate` (Clean: operations):
Every forward tap on the Today stop card (On my way, I'm here, Bringing them
back, All done) can be rolled back exactly one step by admin_tracker_undo,
which reverts the appointment status and clears the matching time stamp so
the button, the client's tracker page, and the clocks agree again. The
control is deliberately quiet (a small "undo step" text link) and
deliberately two-stage (tap, then confirm with the step named), the opposite
of the big forward button. Because fast fingers happen mid-route and a wrong
stage lies to the client watching the tracker, but an undo that is itself
fat-fingerable would just move the problem. Paul, 2026-06-12.

`tasks_with_receipts` (Clean: operations):
Work gets assigned, not remembered: the owner assigns a task to any operator
from the Tasks panel on Today, the assignee sees it on their own Today, and
marking it Done can require a photo receipt (the finished filter, the
cleaned intake) that the owner sees beside the done-stamp in the same panel.
Owner assigns and drops; assignee or owner completes; proof is enforced
server-side (admin_complete_task rejects a proof-required task without a
photo). Because delegation only works when "done" is observable: Paul needs
to see that Jake did it, when, and to what standard, without standing next
to him. Paul, 2026-06-12.

`delegation_closes_the_loop` (Clean: operations):
Handing work down can never become a new void. The owner can hand any agent
card on Today to whoever works for Clean ("Hand to"): it becomes that person's
task, the card flips to delegated and leaves the active feed but stays visible
as an in-flight task in the panel, and it resolves itself with a done note the
moment the assignee finishes. Four things keep a delegated card from rotting:
it stays visible while out, it stamps a receipt when done (a photo, or for an
hours-ask card the number itself), it flags overdue and resurfaces if it sits
open past three days, and the watcher agent re-raises the underlying condition
on its own once its dedupe window passes, so reality and not a reminder is the
backstop. An action card carries its action: a delegated "Update hours" card
lets the assignee enter the reading from their own task, which lands the number
and closes the card; an operator writes equipment hours only through a task
handed to them, never as a general power (direct admin_set_equipment_hours_by_name
is owner-only). The owner also sweeps finished tasks off the board (clear one,
or clear all), cleared not deleted so the audit trail survives. Because Paul
wants to route work instead of doing all of it, and a handoff that disappears is
worse than no handoff: it has to come back if it is not done. Paul, 2026-06-13.

`cards_resolve_or_stay` (Clean: operations):
Every agent card on Today is a question, and every way to answer it makes the
card go away; nothing else does. The answers are four: Handle it (I am taking
care of it), Hand off (it becomes someone's task and resolves when they finish),
Leave it alone (on purpose, the agent stops flagging it for good), and Dismiss
(clear it, the agent may raise it again if it still matters). A note to the agent
is optional and rides along with whichever answer is chosen; a note alone never
resolves a card, so the only reason a card still sits there is that it has not
been answered yet. Every answer is reversible: the card collapses to a one-line
outcome with an Undo that reopens it (back to read, disposition cleared, the
handed-off task dropped) until the next refresh, except a hand-off whose task is
already finished, because then the work happened and there is nothing to take
back. Because the old card had buttons that looked like answers but left the card
sitting there (Reply, Mark read) and two that cleared it but looked identical
(intentional vs dismiss), so Paul could not tell what any button would do, and a
card you cannot confidently clear is a card that piles up. Being tried before a
final call (Paul, 2026-06-13).

`access_map_reads_the_truth` (Clean: engineering):
Orbit has one emperor-only Access page that shows, per role (Emperor, Employee,
Stakeholder), exactly what that person sees: their menu, and what is hidden
inside the floors they can open, plus a Preview-as that walks their menu live. It
is built so it can never drift from reality. The menu half is generated from the
one role-to-floors definition the live nav also gates on (roles.js), so there are
not two lists to keep in sync, only one. The masking half is read live by
admin_access_probe, which calls the real masking RPCs once as the owner and once
as a representative of each other role and reports the fields that disappear, so
the page shows what the server actually strips, not a hand-written note that can
go stale; an unknown stripped field still shows by its raw name so nothing can
hide. Because access creep is silent: permissions get added one at a time and a
year later no one can say who sees what, and a map you cannot trust is worse than
no map. A description drifts; a generated map cannot. Paul, 2026-06-13.

`stop_closes_the_loop` (Clean: clients):
When a client taps the portal stop sign, three things happen in one
transaction: every future appointment is cancelled including pencilled
(tentative) ones, a Plan-stopped alert cards the owner's Today feed
naming the client and the count of cancelled visits, and the client gets
the promised cancellation notice by email for their next upcoming
appointment. Reminders are the only opt-out-able messages; account
notices (confirmations, cancellations) always send. Because the stop sign
brags that stopping is two taps with no phone call, and a stop nobody
notices is how a client quietly disappears and a route day silently gains
a hole; the easy exit must still inform the house. Paul, 2026-06-12.

`riker_parses_on_the_record` (Clean: engineering):
Every Riker parse is logged (riker_log: utterance, client, full plan), so a
"Riker would not cooperate" report is diagnosed from the actual parses, not
from memory. Because the Becky's-husband failure could only be guessed at
after the fact; the next miss will be a query.

`reminders_one_gateway` (Clean: operations):
A time-based commitment ("contact her in 2 weeks", "follow up after the
holidays") goes in through Riker like everything else and lands in `reminders`
with a due date; it surfaces on the Today floor when due (and stays until
marked done), instead of living in Paul's head or a separate to-do app.
Because Paul is consolidating the whole business behind one gate he goes
through, where things he must remember are intelligently surfaced when they
become important, not stored where he has to remember to look.

`agent_when_value_beats_cost` (Clean: engineering):
Add an AI department-head or watcher agent wherever its value clearly offsets its
small cost, and surface each candidate to Paul rather than building it silently.
The agent pattern is cheap (a daily Sonnet briefing over pre-computed numbers
runs a few cents a month), so the bar is not "can we afford it" but "does it
provide real recurring value," and Paul wants a say on each because even a small
ongoing cost should be spent deliberately. Because the value of the strong
candidates (catching a lapsing recurring client before it churns, nudging an
underpriced client up toward the target revenue per hour, or keeping the books
clean and the net accurate) dwarfs the token cost, while naming the candidate
first keeps the spend intentional and the agent roster legible. The live pattern
is the `agents` registry plus a cheap edge-function or SQL agent that reads
scoped real data, writes a briefing (recommend, never act), and a human approves.
Decided 2026-06-08.

`capacity_watchdog_agent` (Clean: operations):
The Availability watcher answers one question daily: if a client came looking for an
appointment today, how long until they could actually get one, measured against THEIR real
constraints (hard windows, not-days, their own visit length, their city's open days), plus the
same for a hypothetical new client per city. When anyone's wait would exceed the threshold (10
days, Paul's number) it cards Today once (one summary card, never one per client; it re-cards
only after the last card is closed). Slots come from `bath_open_slots`, the same engine every
booking path uses, so the watcher and the booking surface can never disagree; per-client
constraints come from `availability_not_days` (exact) and `availability_hard` (free text,
parsed for the patterns that exist in the book; anything unreadable is treated as unconstrained
and flagged on the card, honest about its own blind spots). suppress_winback clients are
INCLUDED because this is an internal capacity signal, never outreach. The release valve it
points at is opening capacity (an extra day, an off-week exception), and when there is no room
for someone, that is surfaced rather than silently absorbed. Because Paul should learn the
calendar is too tight from a card, days before a client learns it from a failed booking
attempt: a quietly squeezed-out client is lost revenue and eroded trust, and capacity pressure
is invisible until someone hits the wall. Asked for by Paul 2026-06-10; threshold and the
new-client half are his spec. Lives as `_capacity_scan()` + the daily cron + the `capacity`
agent row (migration 0144).

`talk_back_with_because` (Clean: knowledge):
Briefings are a two-way conversation, and every time Paul talks back to an agent
the reply should carry a "because" and is recorded as durable knowledge, not just
used to silence one alert. His talk-backs are wisdom about the business (why a
client is priced the way she is, why a cadence is what it is), and the reason is
the most valuable thing to keep. Replies and "this is intentional" resolutions
land in the `wisdom` inbox, scoped to the client or the department, and a one-tap
quick-capture (the speed dial, a floating button on every Orbit floor, text or
voice) lets Paul drop any idea into the same inbox to be absorbed into the Oracle
or a client record. These notes are internal only: `briefing_notes` and `wisdom`
are RLS-locked admin surfaces, never shown to a client (so a blunt private note
like a fixed-income exception never reaches the client it is about). Because a
reason captured once stops the same question being asked forever and compounds
into the un-promptable moat, while an answer used and discarded has to be
re-derived; and the friction between having a thought and capturing it is what
loses it. Decided 2026-06-08.

---

## Growth

`winback_is_cadence_and_calendar_aware` (Clean: growth):
The win-back nudge (re-engaging a lapsed client) is timed off the client's own
cadence and flexed by the calendar, never a rigid arbitrary clock. A client with
a recorded cadence becomes a win-back candidate at their cadence plus about two
weeks; a one-off client with no captured cadence at about ninety days since the
last visit. Neither threshold is rigid: it can slide a little earlier or later
than the two-week or ninety-day mark based on how the calendar looks. The agent
surfaces win-backs when there is actually room to take the client, because trying
to win people back while the calendar is jammed is wasted effort and risks
overbooking. But if it IS time to win a client back and there is no room, that
itself is surfaced to Paul, so he can choose to make room or add capacity rather
than silently lose the window. Because re-engagement timed to the client's own
rhythm and to real available capacity converts, while an arbitrary ninety-day
blast into a full calendar does not, and a quietly missed win-back window is lost
revenue. Decided 2026-06-08.

`winback_contact_email_opt_in` (Clean: growth):
Win-back contact goes to the client by email, never SMS, and is a first-class
registered communication type, not an ad-hoc send. It is sent through Resend
(email; Twilio and SMS stay reserved for time-sensitive transactional messages
like reminders and confirmations), logged like any official notification in
`notification_log`, and governed by per-category preferences the client controls
in the portal: for this category the choices are email or off, so a
re-engagement nudge can never arrive as an intrusive text. It is presented to the
client as an opt-in care feature, not a sales blast: framed around the dog's
wellbeing first (a dog that goes too long between baths sheds and mats more and
gets itchy skin), with the cleaner-home benefit second, and an easy unsubscribe.
Because re-engagement by SMS reads as spam and pulls Clean into stricter
SMS-marketing consent rules, while a defined email category earns deliverability
(SPF/DKIM/DMARC through Resend) and a clean consent and opt-out story; and a
retention mechanism framed as genuine care for the dog serves the prime directive
(leave everyone better off) and the moat, where a "we want you back" blast erodes
both. Exact selling copy still to finalize with Paul. Decided 2026-06-08.

`tentative_marker_is_private` (Clean: growth):
Paul has two private pencil markers in Google Calendar and both mean the same
thing: a trailing "?" on the title, and the banana event color. The banana
pencils are his year-ahead strategy (explained 2026-06-11): when a client gets
groomed he pencils their next visits at their normal cadence for up to a year
ahead, in banana, in his own calendar only, never in the booking system the
client sees; as the date approaches he resolves collisions and only then makes
it official to the client. Many clients carry these. Neither marker is ever
client-facing and neither is stored literally: the sync strips the "?" for
client matching, the Apps Script flags banana-colored events, and both
translate to an internal `status = 'tentative'` on `bath_appointments`
(distinct from `'confirmed'`). A tentative appointment is a
SOFT booking, not a confirmed one. It is treated as real planned time
everywhere internal: it excludes the client from win-back (a "?" client is by
definition not forgotten) and counts toward the win-back calendar-capacity check,
exactly like a confirmed appointment. But it is operator-only: in Paul's own
Calendar floor it reads as "pencilled," and it must never surface on any
client-facing surface (win-back or care email, portal, SMS) nor ever be presented
to a client as a confirmed booking. The sync only owns the tentative/confirmed
distinction; once an appointment has moved past that (on_the_way through completed,
or cancelled) the sync does not downgrade it. Because the "?" is Paul's note to
himself and exposing it, or treating a pencilled slot as a firm commitment to the
client, would both break trust; while still honoring it as planned time keeps the
calendar and win-back honest. Decided 2026-06-09; banana color and the year-ahead
penciling strategy folded in 2026-06-11 (Apps Script color flag + `_sync_appointments`
tentative field, 0152; Orbit's booking panel labels a tentative next booking
"penciled, not client-official").

---

## Clients

`no_fly_list` (Clean: clients):
Clients on the no-fly list (`clients.nofly = true`, which also sets
`exclude_from_everything` and `roster_group = 'banned'`, with a `nofly_reason`)
receive no outreach of any kind and are excluded from every agent and every comms
category. Paul manages the list himself from the Clients floor: a per-client "Put
on no-fly list" control with a reason, plus a No-fly list panel to review and
remove. It is kept distinct from `exclude_from_everything` alone, which also
covers merged-alias records that should not surface but are not bans (a former
name like Lisa Midgett -> Lisa Irwin, or a household duplicate like Chris Votos
under Donna Rodriquez's account). Because some clients must never be contacted or
served, and with outbound win-back email now in play a single missed exclusion
could send an unwanted message to someone Paul has cut off; keeping the
human-managed ban (with its reason) separate from data-hygiene exclusions keeps
both correct, and putting the control in Paul's hands means he never has to ask
to get someone off the list. The opt-in email send, when built, must also honor
`exclude_from_everything`. Decided 2026-06-08.

`households_search_by_any_name` (Clean: clients):
A household is one client record that can carry any number of alternate names, and
searching any of them opens the same household. The names come from spouses, former
names (divorce), spelling variants, and other household members; they live in the
`client_aliases` table, and the Clients-floor search matches the name, the aka, and
every alias. Paul manages them on the client sheet ("Also known as / household
names"). Because real households go by many names over the years (a maiden and a
married name, a husband who books, a misspelled surname), and Paul must be able to
type any one of them and land on the same record rather than create or chase a
duplicate; a household split into two records is how visit history, cadence, and
win-back timing all go wrong, which is exactly what happened with Chris Votos /
Donna Rodriquez and Lisa Midgett / Lisa Irwin. Decided 2026-06-08.

`client_archive_after_a_year` (Clean: clients):
A client whose newest visit is older than a year, with no upcoming appointment, is
archived (`clients.archived_at` set), not deleted. Archived clients keep their full
record and history; they are hidden from the default Clients book, the win-back
agent, and the calendar-capacity count, so three-plus years of history does not
clog the active view. Archiving is reversible and self-healing: an `after insert`
trigger on `bath_appointments` and on `visits` clears `archived_at` the moment any
new appointment or visit lands for that client, so anyone who comes back is
restored automatically no matter the write path (calendar sync, manual log,
booking funnel); Paul can also bring one back by hand from the Archived panel on
the Clients floor (`admin_unarchive_client`). A never-visited client is never
auto-archived (it could be a freshly added record). The sweep
(`_archive_stale_clients`, default 365 days) runs on a monthly cron and via
`admin_archive_stale_clients`. Because the book spans years and Paul only works the
people he is actually still seeing, a stale record is clutter, not a deletion
decision; archiving keeps the active view honest while losing no history and
auto-restoring the moment a client returns. Decided 2026-06-09.

`calendar_flip_order` (Clean: calendar):
Until a deliberate cutover, Paul's single Google calendar (his default calendar) stays the
working source of truth he books and works out of; the Orbit admin Calendar floor is a
read-only mirror he uses to test the sync against that calendar, never a replacement, and
Acuity stays the system that actually sends client reminders until our own reminder send is
built and verified. The cutover to a dedicated "Dog Gone Clean" calendar now runs as a
PARALLEL BRIDGE first (Paul's amendment, 2026-06-10): the Apps Script reads BOTH the default
calendar AND a calendar named "Dog Gone Clean" (deduped), so the moment Paul creates that
calendar he can start booking new appointments into it while the old ones stay on the default,
and the app sees everything throughout. The original all-at-once failure this rule guarded
against (a repointed script with no events, or a calendar the script cannot see) cannot occur
under the bridge, because nothing is ever unread. The FINAL flip, on Paul's go once he trusts
it: (1) move any remaining upcoming client events onto the Dog Gone Clean calendar; (2) drop
the default calendar from the script's read list. Acuity keeps sending reminders until our
Resend send is live, unchanged. After the flip two pieces unlock: per-business calendars give perfect Nails/Clean
separation (each business's script reads only its own calendar, personal stays unread), and
two-way enrichment can stamp each appointment's service address and gate code back into the
calendar event for the field. No step starts until Paul says go. Because the calendar is Paul's
live working tool and a half-done switch would silently drop appointments out of his view, and
the calendar is also the durable Nails/Clean separation boundary that serves
`clean_stays_saleable`. Full procedure parked in CLEAN_PARKING_LOT.md. Decided 2026-06-09.

`client_dispositions_are_migrations` (Clean: clients):
Operational client dispositions (no-fly bans, household merges, deceased / moved-away / test-account
exclusions, archive, win-back suppression) are encoded as replayable migrations keyed by the
client name, never left as manual one-off edits to the live database. The first such migration is
`0077_client_cleanup.sql`. Because a prior round of exactly this cleanup (current-roster trimming
and household merges) was done as manual database edits and was lost, almost certainly wiped when
the database was reseeded from `legacy/data/clients.json`; migrations run after any seed, so a
disposition written as a migration survives a reseed, a rebuild, and a context reset, while a
manual edit does not. Keying by name (stable across reseeds) rather than id makes the migration
re-apply correctly even when ids are regenerated. Decided 2026-06-09.

`client_no_winback_flag` (Clean: clients):
`clients.suppress_winback` leaves a client in the active book but out of the win-back agent, the
lever for an active client who self-manages: a seasonal regular who rebooks on their own, a VIP, a
client who is away part of the year. It is distinct from `exclude_from_everything` (which hides the
record entirely) and from `archived_at` (dormant, auto-restored). `_winback_due_view` excludes
suppressed clients. Mary Jane Hunt is the first: she is away roughly half the year and books her
own block starting in October, so she should never be auto win-backed; once her future appointments
are on the books the existing future-appointment guard also suppresses win-back on its own, but the
flag holds regardless of how far out those appointments are or whether they have synced yet. Because
nudging a client who manages their own cadence is noise that erodes the relationship, and the right
control is a quiet per-client suppression, not a ban and not removal from the book. Decided 2026-06-09.

`visit_notes_are_observations_only` (Clean: clients):
The `visits.visit_notes` field holds behavior and condition observations only, never payment status.
The Acuity / calendar import had dumped the online-payment label ("paid: Invoice" and similar) into
visit_notes on hundreds of visits, which read as "paid by invoice" for clients regardless of how they
actually paid. It was scrubbed (`0078`), and the real method stays in `visits.payment_method`. Because
mislabeled imported data presented as fact violates `real_data_only` and made the contact sheet lie
about how people paid. Decided 2026-06-09.

`vibe_score` (Clean: clients):
Paul scores every dog at every appointment 1 to 5, the "vibe score", recorded per dog per visit in
`visit_dog_ratings.score` and captured in the Log-a-visit form (and, once built, by the voice-capture
agent). The scale is behavioral, about how the dog was to work with, not about looks or coat:
  1 = the dog showed aggression (Paul has zero tolerance) or was so uncooperative it could not be
      groomed safely (it could injure itself or Paul). A 1 means the dog is NOT eligible for future
      service. Paul may at his own discretion keep working with a 1 conditionally when he believes it
      can improve over the next couple of appointments, but a dog that stays a 1 is not worth the risk
      and is done.
  2 = like a 1 but with no aggression; Paul will conditionally serve again on the condition the dog
      improves to a 3.
  3 = average; neither excessively good nor bad.
  4 = the dog goes out of its way to cooperate and tries to anticipate what Paul will do next.
  5 = a 4 taken to the next level; the dog brings joy to the day, reads his cues, shifts its weight and
      offers the next foot before he reaches for it, and learns his tool-and-task patterns (when a
      certain blade goes on, it anticipates the body parts that follow in his fixed order).
Because the vibe is real, safety-relevant signal Paul already tracks by hand: a 1 is an eligibility
decision (an unsafe dog is a no), a 2 is a conditional warning that sets an improvement target, and the
trend over time tells him which dogs are a joy and which are a grind, which feeds scheduling, pricing,
and whether the work is worth doing. These definitions are Paul's working version and may be refined.
Decided 2026-06-09.

`riker_capture_agent` (Clean: clients):
Riker is the speak-it-and-it-gets-entered clerk. Paul dictates a short note about an appointment he
just finished (his phone's voice-to-text fills the box) and it is filed into the right place on the
contact sheet instead of typed by hand: the replacement for the per-client Google Doc sheets. The
split follows the house pattern, an AI proposes and a click writes: the `riker` edge function has
Claude PARSE the utterance into a structured plan (proposes, never writes), and `admin_riker_apply`
writes it under the admin gate; `admin_riker_context` feeds the parser only the client and dogs it may
touch and doubles as the auth check. Supported writes: a visit (service, minutes, amount, payment,
work done, visit notes) with per-dog vibe scores, a household note appended to `clients.note`,
per-dog notes appended to `dogs.notes`, dog roster status changes ("Windsor moved away, archive
him" sets roster_status, reversible, never a delete; 0149), notify people ("text the sitter
instead until July"; 0148), and a WISDOM FALLBACK (0150): anything that is not about one
client's record (an idea, a rule, a decision) lands in the wisdom inbox for the Archivist, with
no client required; every dog reference is validated to belong to the client. THE ONE GATEWAY
(Paul, 2026-06-10): the floating + on every Orbit floor now sends everything through Riker,
who routes it; there is no separate Oracle-capture or per-purpose entry point, because one
habit (hit +, say it) beats remembering which button files what, and the wisdom fallback means
nothing said can fall on the floor. The living user manual is the "What can I tell Riker?"
list rendered wherever Riker takes input (RikerManual in RikerCapture.jsx), updated in the
same commit as each new power so it cannot drift from reality.
Nothing is written until Paul taps Confirm once (one-tap confirm), so a misheard word never lands. It
is on Today (Riker resolves the client name Paul says) and on each client sheet (the client is fixed).
Because the moat is the proprietary per-client knowledge Paul carries, and the way to keep it is to
make capturing it as cheap as talking: the goal is that Paul interacts with the contact sheet the way
he interacts with his GitHub, constantly but through an agent, never by hand. The voice-to-text is the
phone's job; Riker takes no audio. The name is provisional. Decided 2026-06-09.
Note: the `riker` edge function runs with verify_jwt off and handles CORS itself (the browser preflight
fails under verify_jwt); auth is still enforced inside via `admin_riker_context` (raises for non-admins)
and the apply RPC is independently admin-gated, so security is unchanged.

`visit_photos_capture` (Clean: clients):
Photos attach to a visit: a before, an after, a with-the-dog shot, and any extras. They are picked
straight from Paul's phone (the Android picker reaches Google Photos; the input is `accept="image/*"`
with no `capture`, so the gallery is offered, not just the camera) and uploaded to a PRIVATE Supabase
Storage bucket `visit-photos`, recorded in `visit_photos` (visit_id, kind, storage_path), and viewed
through short-lived signed URLs. Read and write are admin-only via storage RLS keyed on `_is_admin()`
plus admin-gated RPCs (`admin_add_visit_photo`, `admin_delete_visit_photo`); `admin_get_client` returns
each visit's photo rows and the client signs them. Labeled thumbnails show on each visit in the history.
Because the photos are client property and a real part of the record Paul keeps, and the bucket must
stay private and inside Clean's own project so the business stays sellable (`clean_stays_saleable`); the
simplest intake that works on his Pixel (direct pick-and-upload) beats a Google Photos integration that
would add a dependency to untangle at sale. Per-dog tagging shipped 2026-06-10 (Paul: the upload
assumed a one-dog household): `visit_photos.dog_id`, an "Of:" dog chip at upload for multi-dog
clients, tap-the-label retro-tagging, and the dog's name on the Orbit, portal, and tracker photo
labels; untagged stays legitimate (a whole-pack shot is real). Default visibility refined the
same day (0149, the Michelle case): the standard kinds (before, after, with-operator) are SHARED
the moment they upload, because appearing on the client's live tracker is the whole point of
taking them mid-visit; 'extra' stays private until deliberately shared, since an extra can hold a
skin observation Paul wants to deliver with words first; the per-photo toggle still un-shares
anything. Uploads are also resized client-side (max 1600px JPEG) and queue in the background so
Paul never waits between the after shot and the with-him shot. The Riker "add the photos?" handoff
is the remaining later pass. Decided 2026-06-09.

`dog_standing_instructions` (Clean: clients):
Every dog carries standing instructions: the semi-permanent "how to handle this dog every time"
(muzzle the back feet, start at the rear, do nails first, hates the dryer), sourced from Paul's Drive
contact sheets. They live in `dogs.standing_instructions`, separate from the freeform visit-condition
notes (`dogs.notes` and `visits.visit_notes`), and are shown and editable per dog on the contact sheet
(`admin_set_dog_standing`). Because this per-dog handling knowledge is exactly the proprietary,
un-promptable context that is the moat (`dig_the_moat`): a buyer or a fill-in specialist can run the
business well only if it is written down, so it gets a durable home of its own rather than living in
Paul's head or buried in visit notes. The first populated pass is the cross-reference of active clients
against their newest Drive contact sheet. Per dog the source is the explicit "Standing Instructions"
field on the sheet, transcribed as written; the dated visit history is not folded INTO the standing
instructions (that would be interpretive), but the history itself is migrated separately as visit
records, see `visit_history_migration`. Decided 2026-06-09.

`time_is_money_is_source_of_truth` (Clean: clients):
For DATES, TIMES, and DOLLAR AMOUNTS, the `time_is_money` import is the absolute source of truth, ranked
above every other source (Google Calendar, the contact sheets, Acuity). On any conflict about when a
visit happened or what was charged/paid, time_is_money wins. The contact sheets remain authoritative
only for content time_is_money never captured: the per-dog vibe scores and Paul's per-visit notes. So
the visit-history migration ENRICHES the existing time_is_money visits (keeping their dates and amounts)
with the sheet's scores and notes; it never overwrites a date or an amount from a sheet, and when a
sheet entry's date does not line up it is reconciled toward the time_is_money record rather than
trusted over it. Because time_is_money is the system Paul actually ran the money and the schedule on, so
it is the ledger of record; the sheets are his field notebook, trustworthy for observations, looser on
exact dates and figures. Decided 2026-06-09.

`visit_history_migration` (Clean: clients):
The old contact-sheet visit history is MIGRATED into the new system, not abandoned. Paul's whole
purpose in switching systems was to carry his data forward, and an earlier import had captured only the
visit dates and dollar amounts and silently dropped the real content: the per-dog 1-to-5 vibe score and
Paul's per-visit note ("skin irritated", "took over 4 hours", "bit my arm"). That content is migrated
into `visit_dog_ratings`, which now carries a per-dog `note` and a NULLABLE `score` (the pre-1-to-5-era
entries recorded a word like "Ok" or "good dog"; those migrate faithfully as a note with no number
rather than a fabricated one). The contact sheet is the authoritative source: each dated entry's
per-dog score and note attaches to the matching existing visit by date, or a visit is created where
none exists. It shows per visit in the contact-sheet history (the score dot plus the note). Distinct
from `dog_standing_instructions` (the semi-permanent how-to-groom field): the history is the running
ledger, the standing instructions are the header. The cross-reference pass migrates both per client,
and the eight clients already done for standing instructions still need their history migrated. LOSE
NOTHING is the governing rule of this migration (Paul, 2026-06-09: "let's not throw any data away"):
a dog named in the history but missing from the roster is the client's real dog and gets ADDED to
`dogs` and migrated (Chloe's deceased Whiskey and Skout; Tonya's Andy, Scrappy, Pebbles), with a
deceased or last-seen marker in `dogs.notes` where known; a visiting or relative's dog that is not the
client's own is preserved in that visit's `visits.visit_notes` (Tonya's guest dogs Charlie, Dash,
Eula) rather than given a false dog record; a genuinely sparse nail-only record (Steve, Nancy) migrates
the few scores it has and leaves the rest an honest gap, never an invented number. Because
abandoning years of real per-dog observations would gut the proprietary record that is the moat
(`dig_the_moat`), which is exactly what the prior import quietly did. Decided 2026-06-09.

`client_access_notes` (Clean: clients):
Client-level "how to get in" notes (gate, door, and lock codes, where to park, how to reach the dog),
transcribed from the contact sheets into `clients.access_notes` (a dedicated human-readable field,
separate from the jsonb `access` and the general `note`), shown and editable on the contact sheet under
"How to get in". Because this is exactly what Paul needs on his phone at the stop, it lives on the
sheets, and writing it down where the app surfaces it serves the runs-without-Paul directive (a
fill-in specialist can get in). Captured in the same Drive cross-reference pass as the standing
instructions. Decided 2026-06-09.

`client_onsite_people` (Clean: clients):
Every client record carries a "who's on site" note: the people Paul might meet at the appointment
(housekeeper, family, staff, who lets him in, who to ask for), transcribed from the contact sheets into
`clients.onsite_people`, shown and editable on the sheet. Because walking up to a stop and knowing that
the man with the beard is Isaiah or that Gloria is the housekeeper is real situational knowledge that
makes the work smoother and is exactly the proprietary context a fill-in specialist would need.
Captured in the same Drive cross-reference pass. Decided 2026-06-09.

`block_banned_from_booking` (Clean: clients):
A hard-banned client cannot book. A `before insert or update` trigger on `bath_subscribers` (the first
row the booking funnel writes) rejects any contact whose email or phone matches a client with
`nofly_level = 'banned'`, aborting the booking with a soft, non-provoking message ("Sorry, we are not
taking new clients in your area right now.") that reads like a service-area decline, never a personal
rejection, so it does not provoke. Only the hard ban blocks; a shadow-banned client who books on their
own is still served. The teeth live in the database trigger so no booking path can bypass them and a
redesign cannot drop them. Limitation: it can only match a banned person Paul has an email or phone on
file for; a banned person booking under brand-new contact details would get through, and Paul bans
those too. The live funnel's Confirm button is currently disabled pending Stripe, so this is the
waiting gate; mapping the message into a friendly funnel panel and an early in-funnel check are parked
with the Stripe launch step. Decided 2026-06-09.

`dog_followup_lifecycle` (Clean: clients):
A dog's "ask / check next time" follow-up is an OPEN LOOP, not a permanent field. Paul's point: it
cannot just live there forever; he sees it at the next visit, asks, records the answer, and it closes
into history. So it is a per-dog record in `dog_followups` (body, status open|resolved, resolution,
created_at, resolved_at), not a text column (the earlier `dogs.follow_up` field from 0086 was migrated
into open records and dropped in 0088). Open follow-ups show highlighted on the dog and surface on the
Today stop (`admin_today_appointments` returns them) so he is reminded before he walks up; resolving one
(`admin_resolve_dog_followup`, with what he found) moves it to the dog's collapsible past-follow-up
history and off the open list. RPCs: `admin_add_dog_followup`, `admin_resolve_dog_followup`,
`admin_drop_dog_followup`, `admin_list_dog_followups`. It is kept SEPARATE from `standing_instructions`
(a permanent grooming instruction vs a transient reminder; Donna's Fledge "ask about her belly" was
moved out of the instructions into a follow-up). Because a reminder with no resolution loop either nags
forever or gets ignored, and the answer belongs in the history once he has it. Supersedes the
field-only `dog_follow_up`. Decided 2026-06-09.

`dog_birthday` (Clean: clients):
Each dog has a birthday (`dogs.birth_date`) with an exact-or-estimated flag (`dogs.dob_approximate`),
since many ages are a guess (rescues, strays) and saying so honestly matters (`real_data_only`).
`admin_set_dog_birthday`; shown and editable per dog (date + an "estimated" checkbox; displays "(exact)"
or "(estimated)"). Decided 2026-06-09.

`client_address_maps_link` (Clean: clients):
The client's location on the contact sheet is a tappable Google Maps link, and it prefers the editable
plus code (`clients.location_plus`, set via `admin_set_client_plus`) over the street address. Because
some street addresses route to the wrong place (e.g. Heather Albinson), and the plus code is the
reliable locator; the maps URL uses plus code, then address, then lat/lng. Decided 2026-06-09.

`client_message_draft` (Clean: clients):
Paul has a free stream-of-consciousness field per client (`clients.message_thoughts`) where he says
whatever he is thinking about the dog or the visit, and a draft agent (the `message-draft` edge
function, Claude) turns it into a short, warm, personal message he could send the client, pulling out
what is worth saying and never inventing sentiment. TEST ONLY for now: it shows Paul a draft and never
sends; the brain dump is saved so he can keep adding. Later it feeds an automatic post-appointment send
(through the Resend notification path, opt-in, per `winback_contact_email_opt_in`). Because the warmth
and specific memory of each dog is the un-promptable moat (`dig_the_moat`), and lowering the cost of
turning Paul's real thoughts into a genuine client touch deepens the relationship without faking it.
Decided 2026-06-09.

`nofly_two_tiers` (Clean: clients):
The no-fly list has two tiers, not one. BANNED is a hard ban (the falling-out, the genuine "do not
serve": `nofly = true`, `nofly_level = 'banned'`, `exclude_from_everything`, `roster_group = 'banned'`,
hidden and never contacted). SHADOW is a shadow ban: the client stays in the book and is still served
if they come, but is never solicited (excluded from win-back and outreach via `nofly_level = 'shadow'`,
which the win-back due view excludes; `exclude_from_everything` stays false so they remain a real
client). `clients.nofly_level` carries the tier; `admin_set_client_status(client, level, reason)` sets
it. The set-status control is collapsed at the BOTTOM of the contact sheet, never a prominent header
button, and the hard ban asks for confirmation, because banning is a rare, deliberate, roughly
once-a-year action and a fat-fingered ban from the header is a real risk. The header shows only a quiet
read-only badge when a status is set. Shadow is distinct from `suppress_winback` (the neutral
"self-manages their own cadence" flag, e.g. Mary Jane): both stop win-back, but shadow is a negative
disposition and lands on the no-fly list, while suppress_winback is neutral and does not. Supersedes
the single-tier framing in `no_fly_list`. Decided 2026-06-09.
