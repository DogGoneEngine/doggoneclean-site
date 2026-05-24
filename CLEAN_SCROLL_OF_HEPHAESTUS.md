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

- **Direction:** Clean is ONE evolving business and a fork of the DGN platform. Two
  businesses total: DGN (flagship, fully separate) and Clean (this repo). Clean keeps its
  existing full-grooming clients while the marketing leans into higher-profit bath work, one
  portal serves both, and it can expand to the Villages with bath.
- **State:** client records clean (33 standing, seed-ready); route template drafted; doc and
  handoff system built; strategy, infrastructure, and workflow decisions locked;
  `scripts/check.py` enforces what can be enforced today. Clean is greenlit to build.
- **Next chapter (best done in a fresh thread):** scaffold the Clean Astro app + bath-forward
  marketing skeleton (needs no credentials), then the schema as migration files + seed from
  `data/clients.json`, then the portal shell. Recommended first move: scaffold the Astro app
  plus marketing skeleton.
- **Needs Paul to unblock the live pieces:** create Clean's own Supabase project and hand
  over URL + keys; create a Google Cloud project with a domain-locked Maps key and OAuth
  client; point hurricanebath.com at the droplet for staging. (If a literal fork of the DGN
  code is wanted, bring that source over; this repo cannot reach the DGN repo.)
- **Hurricane Bath showcase (in progress):** drafting the bath-forward hero content in
  `marketing/hurricane_bath_showcase.md` ahead of scaffold so it drops into the site later; the
  proprietary build is captured in CLEAN_FIELD_MANUAL.md ("The Hurricane Bath") and kept off the
  public page (`dig_the_moat`: sell the what, protect the how). Open: real benefit facts/numbers,
  origin story, photos/video, and the reveal-level confirmation.
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
  CLEAN_BUSINESS_RULES.md + CLEAN_PARKING_LOT.md + CLEAN_FIELD_MANUAL.md + `scripts/check.py`.
- **Phase 4 - Clean website + ops app (fork of the DGN platform).** GREENLIT, starting.
  Astro marketing site (bath-forward) + client portal (existing + new clients) + String of
  Pearls scheduling + operator app with photos + pizza tracker + SMS notifications, on
  Clean's own Supabase project, seeded from `data/clients.json`. In-person payment (Square).
  Preview on hurricanebath.com until doggoneclean.us flips at launch.
- **Phase 5 - Later.** Villages bath expansion; route automation and true drive-time as
  density grows; multi-specialist routing (apprentice Jake).

---

## Session history

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

### Oracle journal absorption (from `the_oracle_journal` on Drive)
- **Source:** Paul's original voice-dictated business journal on Google Drive (file id
  `1ENkpSA6qYPQUcWgcWQGlDI_pE0JfWmr4j3Ft9mLp55I`), entries Feb 12 to Mar 28 2026. Studied and
  split: real business rules into the Oracle, hands-on craft/equipment into a new manual, the
  rest dropped as noise.
- **New Oracle rules absorbed:** `persistent_status_update`; `no_doodles`;
  `income_target_caps_the_day`, `heads_up_on_the_way`, `lock_in_timing`, `gated_community_hours`;
  `cancellation_24h`, `favor_high_hourly_work`, `accepted_payment_methods`;
  `website_is_ground_zero`, `reminder_voice`, `appointment_block_not_window`, `language_bank`,
  `no_trailer_graphics`. All indexed in CLEAN_BUSINESS_RULES.md.
- **New doc:** CLEAN_FIELD_MANUAL.md holds the grooming craft and trailer/equipment SOPs (a
  saleability asset), kept out of the Oracle because they are how the job is done, not business
  rules.
- **Conflicts resolved with Paul:** (1) the journal's Acuity reminder system is superseded by
  the custom String of Pearls scheduler; Acuity is cut as soon as the new system works (the
  reminder content/standards were kept, the Acuity delivery detail folded into `lock_in_timing`).
  (2) The no-Apple rule (`device_profile`) governs Paul's own tools only; accepting Apple Pay
  from clients is fine, so the full wallet list stays in `accepted_payment_methods`. (3) Doodles
  are declined entirely for now (`no_doodles`), not just full-groom doodles.
- **Dropped as noise:** doc scaffolding, the "am I writing a training manual" musing, and the
  Gboard text-expansion shortcuts. Aspirational equipment to-dos (three rotary setups, charging
  bucket cleanup, tire/bearing interval) live in CLEAN_FIELD_MANUAL.md open items.

### Prime directive (LOCKED)
- **The apex of the whole rulebook.** Dog Gone Clean exists to earn more every year while asking
  less, not more, of the people who run it, and to leave everyone it touches better off. Seven
  tests: earn more grind less; runs without Paul (no lapping scheme); fun to work on and in; good
  for body and mind; a unicorn job; clients grateful it exists; the world better for it existing.
  Every rule serves it, and if a rule fights it the directive wins and the rule gets fixed. Lives
  as the first section of CLEAN_ORACLE.md, with the apex line and a pointer in CLAUDE.md "What
  this repo is". Paul approved the wording verbatim.

### Shampoo policy (LOCKED)
- **`house_shampoo`:** one gentle house shampoo for everyone (privately: TropiClean papaya and
  mango 2-in-1, the one product years of use produced no complaints about); clients supply any
  specific, medicated, prescription, or flea product and Clean uses it without standing behind the
  result (cannot stock or vouch for every medicated formula, and a flea bath cannot fix an
  environmental flea problem). Brand kept in the private record, not public copy. Lives in the
  Oracle (Service) + index, with the full policy in CLEAN_FIELD_MANUAL.md. Public copy stays
  positive, brand-free, and skips the flea lecture; any non-guarantee wording lives in the
  intake/terms, not marketing. The coyote anecdote stays off the public page (internal only).

### Brand voice: don't knock competitors (LOCKED)
- **`dont_knock_competitors`:** never disparage other systems, products, or groomers in
  client-facing copy; sell why ours is great on its own merits (competitor weaknesses may be noted
  privately to sharpen our design, never in public copy). Paul's call while drafting the Hurricane
  Bath showcase, where the origin story was rewritten to drop all comparisons. Lives in the Oracle
  (Copy) with an index row.

### Dig the moat (LOCKED)
- **`dig_the_moat`, a decision lens on a level with Elon's algorithm, in service of the prime
  directive.** One recurring question for every build/scope call, the way Bezos asks "does this
  improve the customer experience" and Musk asks "does this get us to Mars": does this deepen an
  advantage a smart AI cannot prompt past? Counts as yes only when the moat is dug by genuine
  value (proprietary context, relationships, reputation, local density, grateful clients), never
  by lock-in (which would violate the directive). Rationale: as AI makes generic
  business-building a single prompt, the scaffolding commoditizes and value concentrates in the
  un-promptable, so spend effort there and build the commodity layer lean. Absorbed the earlier
  proposed `the_moat_is_proprietary_context` (never committed). Lives in the Oracle, with a
  pointer in CLAUDE.md "How Paul works" beside Elon's algorithm and a line in the prime-directive
  section naming both lenses. Paul chose the decision-lens tier (not folded into the directive)
  to keep defense from outranking the end it protects.

### Elon's algorithm (LOCKED)
- **`elons_algorithm`:** run every build/scope decision through Musk's five-step order, never out
  of order: (1) make the requirement less dumb (tie each to a real reason and person, never
  "because DGN had it"), (2) delete the part or step, (3) simplify what survives, (4) accelerate
  cycle time, (5) automate last. Guards against the solo-dev-forking-DGN trap of optimizing or
  automating features Clean does not need. Lives in the Oracle (`elons_algorithm`), with a
  pointer in CLAUDE.md "How Paul works" and a row in the enforcement index.

### Idea-capture workflow (LOCKED)
- **Ideas come into a Claude thread now, not the Drive journal.** Paul describes the idea and
  the reason; the assistant chooses its home (Oracle rule, CLAUDE.md constraint, parking lot,
  field manual, or record field), attaches the because (asking one quick question if missing),
  commits same turn, and reports where it filed. Save triggers: "put it where it belongs,"
  "capture this," "lock it in." Hold signal: "just thinking out loud." The Drive journal stays
  only as the offline fallback for mid-route voice capture, batch-absorbed later. Baked into
  CLAUDE.md ("Recording ideas and decisions") and the Oracle's `lock_it_in_capture`.
