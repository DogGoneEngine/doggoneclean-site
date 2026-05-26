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
  locked in the Oracle but no code behind it yet. `scripts/check.py` green.
- **Marketing content (in `marketing/`):** the Hurricane Bath hero showcase, the
  power-and-fast-drying showcase, and the origin/brand source (story, taglines, doorstep
  copy). The live site's old "Grooming. No Chaos." hero is recorded there but was rejected.
  Waiting on Paul's real photos and video. Build details stay in CLEAN_FIELD_MANUAL.md, off
  the public page.
- **Next chapter:** build the Hurricane Bath v2.0 booking surface against the locked rule
  pack. That means: a real signup flow (Stripe SetupIntent at booking per
  `card_on_file_at_signup`), the octane cadence picker, three-dog cap selector,
  breed-tier-priced single bath, the two-tap stop sign in the portal, the calendar that
  shows price per date. Parallel track: fork the DGN site structure
  (`doggonenails-site`) into a multi-page shell that holds both surfaces and the marketing
  pages, then a real copy pass on the placeholder hero. Then the portal shell with auth
  (first RLS policies land with auth), scheduling tables forked from DGN's String of
  Pearls, and the `business_rules` table mirroring the Oracle.
- **Needs Paul to unblock the remaining pieces:** (1) grant this environment access to
  the `doggonenails-site` repo so the next session can fork the DGN structure; (2) create
  the Dog Gone Clean Stripe account (separate from any DGN/personal account per
  `own_infrastructure`) and hand over the publishable + secret keys; (3) Clean's own
  Twilio account, number, and A2P registration (SMS + phone login). DONE: `dgc-prod` keys
  + DB password; Google Cloud Maps key + Google sign-in; the deploy publishes to
  hurricanebath.com (confirmed live). Also supplies only Paul can give: real photos/video
  for the showcases, and starting the review-gathering. Repo housekeeping is DONE: GitHub
  default branch is `main`, all stale `claude/*` branches deleted (2026-05-26).
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
- **Phase 4 - Clean website + ops app (fork of the DGN platform).** IN PROGRESS. The
  database foundation is DONE (`dgc-prod` live, client book seeded, RLS-locked). Branches
  reconciled into `main`. The homepage placeholder is DONE: rebuilt in the Neural
  Expressive look with the master logo and bath-forward content, live at hurricanebath.com.
  The Hurricane Bath v2.0 rule pack is locked in the Oracle (24 rules covering pricing,
  skip, reschedule, UX, money). Next: build the v2.0 booking surface against those rules
  (Stripe SetupIntent signup, octane cadence picker, three-dog cap selector, two-tap stop
  sign, calendar-shows-price-per-date), then fork the DGN site structure
  (`doggonenails-site`) into a multi-page shell, then a real copy pass, then the client
  portal + String of Pearls scheduling + operator app with photos + pizza tracker + SMS +
  Resend email. Surface-scoped payments: Hurricane Bath uses Stripe card-on-file (new Dog
  Gone Clean Stripe account); legacy doggoneclean.us continues in person via Square. The
  scheduler is built as a service callable from both the new Astro app and the legacy
  Squarespace site (per `string_of_pearls_is_a_service`) so Acuity can be dropped before
  the legacy rebuild. Build details stay in CLEAN_FIELD_MANUAL.md and off the public page.
- **Phase 5 - Later.** Villages bath expansion; route automation and true drive-time as
  density grows; multi-specialist routing (apprentice Jake).

---

## Session history

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
  Brown Saturday nails cluster; Garrett Little at-will; Richard Vieira one-off; Bonnie
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
- Flip the GitHub default branch to `main` (Settings > Branches) if it is not already.
- Grant this environment access to the `doggonenails-site` repo so a future session can
  fork the DGN structure.
- Create the new Dog Gone Clean Stripe account and hand over the publishable + secret keys.
- Twilio account, number, and A2P registration (SMS + phone login).
- Already done (do NOT re-do): `dgc-prod` Supabase project exists; Google Maps key
  domain-locked to hurricanebath.com and the Clean domains; Google sign-in enabled.
- Repo housekeeping (delete stale `claude/*` branches) is parked as very low priority
  in CLEAN_PARKING_LOT.md; safe to defer indefinitely.
