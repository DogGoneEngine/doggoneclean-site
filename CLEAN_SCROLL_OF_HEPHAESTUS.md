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
- Keep the "Current focus / next action" block at the top current, so a session that ends
  abruptly still orients the next one fast.

To resume cold: read CLAUDE.md, then this Scroll, then CLEAN_ORACLE.md.

---

## Current focus / next action

- **Direction:** Clean is ONE evolving business with TWO URL surfaces during the
  transition. Hurricane Bath at hurricanebath.com is Dog Gone Clean v2.0: a
  subscription-only, bath-only operation in The Villages with online card-on-file
  payment. Legacy doggoneclean.us continues serving Ocala full-grooming clients
  on Squarespace + Square + Acuity until its own rebuild. Both surfaces carry
  the Dog Gone Clean brand; eventually they converge. Two businesses total in
  Paul's portfolio: DGN (flagship, fully separate) and Clean (this repo).
- **State:** client records clean (33 standing, seed-ready); route template drafted; doc and
  handoff system built; strategy, infrastructure, and workflow decisions locked;
  `scripts/check.py` enforces what can be enforced today. Clean is greenlit to build.
  Hurricane Bath rule set captured into the Oracle on 2026-05-26 (24 new rules,
  one commit each, all pushed). `pre-hurricane-snapshot` git tag created locally
  on commit `f65a096`; push to remote blocked by the harness proxy and is a
  Paul-action.
- **Next chapter:** Build step 2 of the approved 2026-05-26 plan: scaffold the
  Astro app plus the bath-forward marketing skeleton. Plan file at
  `/root/.claude/plans/in-a-different-thread-vivid-spindle.md`. Per
  `string_of_pearls_is_a_service`, the scheduler is pulled forward of the
  legacy site rebuild so Acuity can be dropped early.
- **Needs Paul to unblock the live pieces:** create Clean's own Supabase project and hand
  over URL + keys; create a Google Cloud project with a domain-locked Maps key and OAuth
  client; point hurricanebath.com at the droplet for staging. (If a literal fork of the DGN
  code is wanted, bring that source over; this repo cannot reach the DGN repo.)
- **Open questions:** Peter Moran cadence (~8 vs ~12wk); Lisa Irwin current home vs office
  address; Terri McDonnell works-from-home; Mary Beth's Theo breed; Patty Brown availability;
  Chester bearing from base; whether Paul's FL/GA travel constrains the Clean route.

---

## Phase map

- **Phase 1 - Authoritative client records.** DONE. 33 standing + 11 one-off + 2 at-will + 1
  banned in `data/clients.json`, verified against the current contact sheets.
- **Phase 2 - First zone-day route template.** DRAFTED (`data/route_template.md`). Pending
  the last cadence lock and a rebalance against corrected stop sizes.
- **Phase 3 - Doc / handoff system.** DONE. CLAUDE.md + this Scroll + CLEAN_ORACLE.md +
  CLEAN_BUSINESS_RULES.md + CLEAN_PARKING_LOT.md + `scripts/check.py`.
- **Phase 4 - Clean website + ops app (fork of the DGN platform).** STARTED 2026-05-26.
  Rule capture complete (24 Hurricane Bath rules committed to the Oracle, one
  per commit). Next: Astro scaffold + bath-forward marketing skeleton. Build
  per the approved 2026-05-26 plan: Hurricane Bath at hurricanebath.com is the
  subscription bath-only surface with online card-on-file payment, premium-
  inclusive pricing, and the String of Pearls scheduler exposed as a service
  consumable from the legacy doggoneclean.us Squarespace site so Acuity can be
  dropped before the legacy rebuild. Operator app + pizza tracker + SMS
  notifications + Resend email all forked from DGN. Clean's own Supabase
  project (`dgc-prod`); new Stripe account for Dog Gone Clean. Legacy
  doggoneclean.us continues on Squarespace + Square + Acuity (with the
  scheduler swapped out) until its own rebuild later.
- **Phase 5 - Later.** Villages bath expansion; route automation and true drive-time as
  density grows; multi-specialist routing (apprentice Jake).

---

## Session history

### 2026-05-26 (Hurricane Bath rule capture + plan reconciliation)

A prior 2026-05-26 thread did extensive planning for Hurricane Bath (Dog Gone
Clean v2.0) but admitted late that it had hallucinated and committed nothing.
The session's ExitPlanMode body survived in Claude Code's side panel and was
re-pasted into the recovery session. The pasted plan was reconciled against
DGN's canonical skip/reschedule policy (per Paul's "use the dgn policy"
instruction) and against Paul's in-chat correction to the breed list
("exclude any breed that can mat or impact"). The final plan was approved
and the locked rule set was captured into the Oracle one rule per commit,
24 commits, all pushed. The `pre-hurricane-snapshot` git tag was created
locally at `f65a096`; pushing it to the remote was blocked by the harness
proxy with HTTP 403 and is a Paul-action. Forensic record of the two failed
sessions and recovery procedure was produced inline for Paul to save outside
the container.

### 2026-05-24 (one long session)

Set up the repo and built authoritative client records from the Google Drive contact sheets.
Found and fixed a sourcing error where the handoff doc-ID index pointed at stale or blank
2023-2024 spreadsheet duplicates for six clients (Kevin, Cynthia, Donna DiPasqua, Linda Giza,
Bradley, Mary Beth); re-sourced every standing record from the newest populated doc and
applied Paul's corrections. Built the first route template. Built the doc/handoff system,
then reworked it for the coming website and renamed it to the CLEAN_ prefix. Added
`scripts/check.py` and hardened enforcement. Locked the strategy: the saleability rationale,
the business architecture (one evolving Clean, a fork of the DGN platform), infrastructure,
payment, staging, and the decision-capture workflow. Corrected the live domain to .us. Ended
by rebuilding this Scroll and recommending a fresh thread for the build phase.

---

## Decisions log (2026-05-24)

Append-only across sessions; grouped here for readability, with no decision dropped. Future
sessions add their own dated section below.

### Data and records
- **Base/home:** 3885 SW 114th Court, Ocala 34481 (rural SW). No separate anchor; the SW /
  On Top of the World cluster is the launch/return zone; Chester Weber (by base, fixed 12pm)
  is the first stop. NE/NW/SE days commute into the city.
- **Active roster:** the past-year set already derived from the calendar in a prior thread
  (47 clients). Do not re-derive it or crawl the full archive.
- **Sourcing:** resolve each client to the newest populated contact-sheet doc; never a blank
  template, an old spreadsheet, or the handoff index.
- **Client corrections (Paul's review):** the full corrected records live in
  `data/clients.json`. Headline fixes: Kevin Cummings is a 7-dog full-groom account at 6wk
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
- **Clean is a fork of the DGN platform.** v1 replaces the current stack feature-for-feature:
  Squarespace -> Astro site; Acuity + confirmations -> portal + String of Pearls + automated
  notifications; Drive client Docs -> Supabase client book (seeded from `data/clients.json`);
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
  subscriptions. Until the deploy pipeline exists, "ship" means commit and push to the branch.
- **Separation:** data (Clean's own Supabase project, never `dgn-prod`) is the hard line. A
  shared droplet (own dir/domain/Caddy block), a shared Supabase/Google account, and shared
  tooling are acceptable to save cost since they are cheap to separate before a sale. API
  keys are each their own and domain-locked (own Google Cloud project for Maps + OAuth).
- **Database guardrail lifted for Clean (greenlit):** build the schema iteratively and
  rebuildably in Clean's own project.
- **Payment:** in person via Square, not Stripe; online payment deferred. SMS via Twilio
  (own number + A2P) is in v1 (replaces Google Voice). n8n deferred.
- **Pizza tracker:** client-facing live status/ETA view, companion to the operator app,
  replaces the manual "on my way" texts; included in v1 (details from Paul later).
- **Staging:** build and preview on hurricanebath.com (kept private/non-indexed) while
  doggoneclean.us keeps serving the old Squarespace site; flip the domain at launch. Local
  `npm run dev` is the fast loop.

### Facts for the record
- **Domain:** the live site is www.DogGoneClean.us. Paul does NOT own DogGoneClean.com.
  Staging/preview on hurricanebath.com (a domain Paul owns).

---

## Decisions log (2026-05-26)

### Hurricane Bath plan reconciliation (RESOLVED)
- **One business, two URL surfaces.** Dog Gone Clean is the business. Hurricane
  Bath (hurricanebath.com) is the new subscription bath-only surface. Legacy
  doggoneclean.us is the existing Squarespace surface for full-grooming clients,
  sunsetting eventually. They converge later; for now they coexist with the
  String of Pearls scheduler shared between them as a service. This supersedes
  the 2026-05-24 "preview on hurricanebath.com until doggoneclean.us flips at
  launch" framing, per `reality_wins`.
- **Online payment for Hurricane Bath only.** The 2026-05-24 decision "online
  deferred until it earns its place" still applies to legacy doggoneclean.us,
  which stays on Square. Hurricane Bath launches with Stripe card-on-file plus
  auto-charge at the 24-hour mark, per the new `card_on_file_at_signup` and
  `auto_charge_at_24h` rules. `bills_in_person_today` is explicitly scoped to
  the legacy surface only by the new rules' becauses; it is not deleted.
- **DGN's skip and reschedule policy is ported verbatim** for Hurricane Bath
  per Paul's "use the dgn policy" instruction. Source: DGN
  `SCROLL_OF_HEPHAESTUS.md` sections 6.2 to 6.8 and DGN `ORACLE.md`. Skip and
  reschedule are distinct curves: a paid skip jumps in one step to the
  single-visit rate, while a reschedule beyond grace steps up weekly.
  Reverses the 2026-05-24 parking-lot line "The DGN payment/skip/reschedule/
  card layer is not ported now" for the Hurricane Bath surface only.

### Rules captured into the Oracle (24, one commit each)
- Product scope: `bath_only_no_mats`, `villages_only_at_launch`, `three_dog_cap`,
  `premium_inclusive_no_addons`.
- Pricing: `breed_tier_pricing`, `cadence_4wk_or_2wk_same_price`,
  `single_oneoff_higher`, `tiered_founders_rate`.
- Money flow: `card_on_file_at_signup`, `auto_charge_at_24h`,
  `card_expiry_60_30_7`, `within_24h_non_refundable`, `no_show_pause_at_two`.
- Skip and reschedule (ported from DGN canon): `one_free_skip_per_52w`,
  `free_skip_keeps_maintenance_rate`,
  `paid_skip_resets_next_visit_to_single_rate`,
  `five_week_grace_returns_to_maintenance`, `reschedule_step_up_weekly`,
  `reschedule_two_paths_for_recurring`.
- UX: `no_reason_field_ever`, `stop_sign_two_taps`,
  `octane_selector_cadence_picker`, `calendar_shows_price_per_date`.
- Engineering: `string_of_pearls_is_a_service`.

### Meta-Rule on every-decision-survives-a-redesign
The four defense layers are: Oracle (rationale, locked today) ->
`business_rules` DB row (deferred until DB lands per
`no_database_until_rules_agreed`) -> code mirror in `src/business/`
(deferred until Phase 4 scaffold) -> lint pattern in
`scripts/lint-business-rules.mjs` (deferred until scaffold). Every new
Hurricane Bath rule lands in the Oracle today and in the right-hand columns
as Phase 4 scaffolds; CLEAN_BUSINESS_RULES.md tracks the migration.

### Open decisions (captured in CLEAN_PARKING_LOT.md)
- Cycle time per appointment (1hr placeholder; Paul measures in Villages).
- Tier slug names (smoothcoat / doublecoat recommended; Paul may rename).
- Breed list refinement (first attempt seeded for Phase 4; Paul iterates).

### Paul-actions deferred from this session
- Push the `pre-hurricane-snapshot` git tag (the harness proxy returns 403 on
  tag pushes; the tag exists locally at `f65a096`).
- Create the private archive repo `doggoneclean-legacy-data` (the harness
  scope is limited to the existing repos). The plan calls for moving the
  current `data/` contents there eventually; for now they are held under
  `legacy/data/` in this repo.
- Create the Hurricane Bath Supabase project (`dgc-prod`) and hand over URL +
  keys.
- Create the new Stripe account for Dog Gone Clean.
- Domain-lock the Google Maps and OAuth keys for hurricanebath.com.
