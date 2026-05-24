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
  durability already happened at each lock. Never rewrite it mid-session.
- **If history and reality disagree, reality wins** and this file is corrected.
- Keep the "Current focus / next action" block at the top current, so a session that ends
  abruptly still orients the next one fast.

---

## Current focus / next action

- **Direction (locked 2026-05-24):** Clean is ONE evolving business and a fork of the DGN
  platform, replacing the current Squarespace + Acuity + Drive-docs + Google-Voice +
  manual-location/photos stack. Two businesses total: DGN (flagship) and Clean.
- **Data:** 33 standing records clean; they are the Supabase seed for Clean's client book.
- **Next action:** stand up Clean's own Supabase project (greenlit; build schema
  rebuildably), then build the bath-forward marketing site + client portal + String of Pearls
  scheduling + operator app (photos) + pizza tracker + SMS notifications, forked from DGN and
  adapted (variable grooming durations, Square/in-person payment). Preview on
  hurricanebath.com (kept private) while doggoneclean.us stays on the old site until launch.
- **Open:** Peter Moran cadence; route rebalance against corrected stop sizes.
- **Parked:** one-off list as conversion candidates; see CLEAN_PARKING_LOT.md.

---

## Phase map

- **Phase 1 - Authoritative client records.** DONE (corrected 2026-05-24). 33 standing +
  11 one-off + 2 at-will + 1 banned in `data/clients.json`.
- **Phase 2 - First zone-day route template.** DRAFTED (`data/route_template.md`). Pending
  final cadences and any load rebalancing.
- **Phase 3 - Doc/handoff system + website foundation.** DONE (2026-05-24): CLAUDE.md +
  this file + CLEAN_ORACLE.md + CLEAN_BUSINESS_RULES.md + CLEAN_PARKING_LOT.md, renamed to
  the CLEAN_ prefix, reworked for the coming website, with the carried DGN rules folded in
  and `scripts/check.py` enforcing what can be enforced today.
- **Phase 4 - Clean website + ops app (fork of the DGN platform).** GREENLIT 2026-05-24,
  starting. Astro marketing site (bath-forward) + client portal (serves existing grooming
  clients and new bath clients) + String of Pearls scheduling + operator app with photos +
  pizza tracker + SMS notifications, forked from DGN onto Clean's own Supabase project, seeded
  from `data/clients.json`. In-person payment (Square). Preview on hurricanebath.com until
  doggoneclean.us flips at launch.
- **Phase 5 - Later.** Villages bath expansion; route automation and true drive-time as
  density grows; multi-specialist routing (apprentice Jake).

---

## Session history

### 2026-05-24 - Repo setup, records, route, corrections

- Set up repo from scratch on the DGC feature branch. Read the five handoff files from
  Drive ("Dog Gone Nails - Scheduling Handoff" folder, contents are DGC): HANDOFF doc,
  dgc_roster_final, dgc_active_enriched, dgc_availability.json, dgc_overrides.json.
- Built `data/clients.json`, `data/sources.md`, `data/README.md` from the contact sheets.
- Built first `data/route_template.md` (zone-day skeleton).
- **Error found and fixed:** the handoff doc-ID index pointed at stale/blank 2023-2024
  spreadsheet duplicates for six clients (Kevin, Cynthia, Donna DiPasqua, Linda Giza,
  Bradley, Mary Beth). Re-sourced every standing record from the newest populated doc per
  name (verified by listing the folder) and applied Paul's corrections. Fixed sources.md.
- Set up this doc/handoff system (Phase 3).

### 2026-05-24 - Website-foundation rework

- Reframed the repo as the future DGC website, not a permanent data repo.
- Evaluated DGN's CLAUDE.md, ORACLE.md, and BUSINESS_RULES.md for relevance and sorted
  them into carry / adapt / drop for Clean.
- Renamed the doc set to the CLEAN_ prefix (keeping the nails names) so DGC and DGN do not
  blur at a glance: CLEAN_SCROLL_OF_HEPHAESTUS, CLEAN_ORACLE, CLEAN_BUSINESS_RULES,
  CLEAN_PARKING_LOT; CLAUDE.md keeps its name.
- Reworked CLAUDE.md and the Oracle for the coming-website reality (stack, ship-to-
  completion, build gate, engineering constraints carried from DGN), and rebuilt the
  Business_rules index on the four-layer model (thin now).
- Added `scripts/check.py` (no deps, no DB): validates clients.json and scans tracked docs
  for em dashes, making a few enforcement cells real.

### 2026-05-24 - Enforcement hardening + records audit

- Broadened `scripts/check.py`: also validates cadence_confidence and hardness tags and that
  no one-off, at-will, or banned client appears in `route_template.md` (guards 14 names).
- Added a redesign checklist to `read_before_redesign` in the Oracle (run check.py, walk the
  index confirming each rule still has a live layer, re-enforce or reject).
- Audited `clients.json` for completeness: all 33 standing records have address, zone, dogs,
  and service type; the records are the durable distillation of the contact sheets, which
  remain the authoritative raw source in Drive. Empty `access` objects are genuine (those
  clients have no gate/codes; parking notes live in `location.geo_notes`), not omissions.
- Note on separation: DGN-site hardening that came up this session is tracked in the nails
  thread, not here, per the no-merge rule.

---

## Decisions log (record every Q&A answer here)

### 2026-05-24

- **Base/home:** 3885 SW 114th Court, Ocala 34481 (rural SW Marion). No separate fictional
  anchor; home sits adjacent to the SW / On Top of the World cluster, so SW is the
  launch/return cluster and Chester Weber (by base, flexible day, fixed 12pm) is the first
  stop. NE/NW/SE days commute into the city.
- **Active roster:** already determined in a prior thread by referencing the past-year
  calendar; that produced the 47-client roster. Do not re-derive it or crawl the archive.
- **Sourcing:** use the newest populated doc per client, not the handoff index, not blank
  templates, not old spreadsheets.
- **Lisa Prater service:** depends on visit (full groom some visits, nails between).
- **Client corrections (Paul):** Chester - Windsor gone, Ula only. Chloe - Louie only
  (Boykin Spaniel), Whiskey + Skout deceased. Cynthia - Luna $45, Satin $85. Erich - Koby
  only. Harriet - start no later than 5pm (earlier better). Heather - SW near Cummings and
  Moran, evenings ok. Hope - Saturday after the Franklin/Prater nail cluster. Ligia - Daisy
  and Sissy $130 each. Lisa Irwin - Mia + Tao (Great Pyrenees puppy, $75). Marilyn - earlier
  than 4pm (gate hard 4-5pm). Mary Beth - Toby + Theo $85 each (Onyx died 6/2025; Benji was
  a visiting stray, not counted). Mary Jane - Caesar $55, Ringo and Pancho $85 each. Steve -
  nails-only legacy, 4 toy poodles (Moose, Pip, Gracie, Brewster), $65 total. Tonya - Kai
  and Lydia regular, Koa and Ruthie sometimes; Andy died; Scrappy and Pebbles are her
  brother's dogs (done once, not counted). Patty Brown - nails-only legacy, Bella (pit/boxer
  mix) + Gizmo (chihuahua/dachshund/chihuahua mix), $45 total.
- **Cadence conflicts:** Chester 3wk (sheet) and Greta 6-8wk (sheet) win over calendar.
  Kevin resolved to 6wk (the real doc states it; he is a 7-dog full-groom account, not a
  2-dog nails stop). Peter Moran still open (~8wk note vs ~12wk calendar).
- **One-off list:** leave as-is; treat as candidates to convert to standing where
  applicable; parked in CLEAN_PARKING_LOT.md.
- **From the original brief (baked):** evening/Saturday locks are real client constraints,
  not artifacts. Donna DiPasqua Tuesday route. Cynthia Tieche Tuesday 3pm. Nancy Franklin +
  Lisa Prater + Patty Brown Saturday nails cluster (neighbors). Garrett Little at-will
  nails. Richard Vieira one-off (may convert). Bonnie DiGraziano banned, excluded everywhere.
- **Naming convention:** doc set uses the DGN names with a CLEAN_ prefix (Paul chose this
  over DGC_ because DGC and DGN look alike at a glance). CLAUDE.md keeps its exact name.
- **Stack:** reuse the DGN stack for the Clean site (Astro 5 + React 18 islands, Node 20,
  npm, Supabase, DigitalOcean droplet + Caddy, GitHub Actions deploy on push to main).
  Clean gets its OWN Supabase project, droplet, domain, and Stripe account; never DGN's.
- **Git/shipping:** ship-to-completion is THE rule (open PR and squash-merge when a branch
  builds clean); it supersedes the earlier "no PR unless asked." Do not offer PR-activity
  subscriptions. The earlier prompt that contradicted this was a stale paste.
- **Database guardrail:** no Supabase project, schema, `business_rules` table, or migration
  until the rules that shape the schema are agreed with Paul. Rules first, schema second.
- **Saleability (recovered; was lost when another thread got too long):** Clean must remain
  sellable as a standalone business and never be tangled with DGN or dependent on Paul
  personally. He probably will not sell, but the option must stay open. Recorded as
  `clean_stays_saleable` in the Oracle, a hard constraint in CLAUDE.md, and implications +
  pre-sale cleanup (move source-of-truth data off Paul's personal Drive; brand rights) in
  the Parking Lot.
- **Why saleability (Paul's rationale):** it is a value test, not an exit plan. A business
  is only buyable if it is valuable; if no one would buy it, it is probably not worth running
  either, and if it is valuable enough to sell, that value is the reason to keep it.
  Building to be sellable is what forces real value. Folded into the `clean_stays_saleable`
  because in the Oracle.
- **Decision-capture workflow (locked):** on "lock it in" or a clear equivalent, write the
  decision to its live home plus this decisions log and commit/push the same turn; record
  nothing while still musing; the end-of-session scroll rebuild is a polish/reconcile pass,
  not a rescue. Baked into CLAUDE.md, the Oracle (`lock_it_in_capture`), and the header
  mandate above.
- **Business architecture (RESOLVED, supersedes the parked question):** two businesses, not
  three. DGN is the flagship, fully separate. Clean is ONE evolving business: it keeps its
  existing full-grooming clients while the marketing leans into higher-profit bath work to
  win new clients, one portal serves both, and it can expand to the Villages with bath
  service. No separate "new Clean"; the legacy book and the new direction are the same
  business being morphed ("send the legacy to the gym"). The scale-a-separate-Clean plan is
  shelved.
- **Clean is a fork of the DGN platform.** v1 replaces Paul's whole current stack
  feature-for-feature: Squarespace -> Astro site (bath-forward); Acuity + confirmations ->
  portal + String of Pearls + automated notifications; Drive folder of client Docs ->
  Supabase client book (seeded from `data/clients.json`); Google Voice texting -> SMS
  (Twilio, own number + A2P, in v1); manual location text -> pizza tracker; manual before/
  after photos -> operator-app photo capture and share.
- **String of Pearls from day one** (not deferred for low density), because it is a fork not
  new work and honoring windows/cadence helps at any density; adaptation needed = variable
  grooming durations, not DGN's fixed nail buckets.
- **Infrastructure:** separate Supabase project is the hard line (data never shared with
  DGN); a shared Supabase/DigitalOcean/Google account and a shared droplet (own dir/domain)
  are acceptable to save cost (cheap to separate later); API keys their own and domain-locked
  (own Google Cloud project for Maps + OAuth); SMS via Twilio in v1; payment in person via
  Square, not Stripe; online payment and n8n deferred.
- **DB guardrail lifted for Clean** (greenlit): build the schema iteratively and rebuildably
  in Clean's own project.
- **Pizza tracker:** client-facing live status/ETA view, companion to the operator app,
  replaces the manual "on my way" location texts; included in v1 (details from Paul later).
- **Staging:** build and preview on hurricanebath.com (kept private/non-indexed) while
  doggoneclean.us keeps serving the old Squarespace site; flip the domain at launch. Local
  `npm run dev` is the fast loop.
- **Domain (for the record):** the live site is www.DogGoneClean.us. Paul does NOT own
  DogGoneClean.com. Staging/preview build on hurricanebath.com (a domain Paul owns).
