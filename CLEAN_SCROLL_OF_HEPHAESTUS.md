# CLEAN_SCROLL_OF_HEPHAESTUS - Dog Gone Clean build narrative

## Header mandate (discipline for every session)

- **Read this file fully before doing any work.** It carries the decisions that context
  resets would otherwise erase.
- **Rebuild it only at end of session, on Paul's explicit instruction.** Never rewrite it
  mid-session.
- **Record every answer Paul gives** in the Decisions log, so decisions survive resets.
- **If history and reality disagree, reality wins** and this file is corrected.
- Keep the "Current focus / next action" block at the top current, so a session that ends
  abruptly still orients the next one fast.

---

## Current focus / next action

- **Data:** all 33 standing records re-verified against the current contact-sheet doc per
  client and corrected per Paul's review (2026-05-24). Considered clean.
- **Foundation:** the doc/handoff system is reworked for the coming website (CLAUDE.md,
  Oracle, Business_rules index, Parking_lot), stack decided (reuse DGN, own instances),
  ship-to-completion is the git rule, and a local `scripts/check.py` enforces the
  enforceable rules. Guardrail: NO database/schema until the rules are agreed.
- **Next action:** agree the rules that would shape a schema (so the DB guardrail can lift),
  lock the last open cadence (Peter Moran, ~8wk vs ~12wk), then tighten the route template
  against corrected stop sizes (Kevin is a half-day 7-dog stop; Steve and Patty are quick
  nails; Chester is shorter without Windsor).
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
- **Phase 4 - Website build.** NOT STARTED. Stack chosen: reuse the DGN stack (Astro +
  React islands + Supabase + DigitalOcean/Caddy + GitHub Actions), Clean's own instances.
  Blocked by the rules-before-schema guardrail: no database until the rules are agreed.
- **Phase 5 - Later.** Geocode plus codes for true drive-time; route automation;
  multi-specialist routing (apprentice Jake); possible field/operator app.

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
