# CLEAN_PARKING_LOT - Dog Gone Clean

Deferred work and forward-looking ideas, parked so they survive a context reset. Nothing
here is committed work; it is the backlog. Move an item into CLEAN_SCROLL_OF_HEPHAESTUS.md's focus block
when it becomes active.

## Conversion candidates (one-off -> standing)

Leave the one-off list as-is and treat it as people to try to convert to standing where
applicable. These are NOT contact-sheet-verified (calendar-derived + Paul's notes only) and
are not routed until converted. Verify against the real sheet at conversion time.

- **Richard Vieira** (SE, ~5wk, no sheet) - most likely to convert; watch first.
- Eric Shannon (NE, was standing; money issues) - has a sheet.
- Emily Walker / Russ Walker account (SE) - has a sheet.
- Brooksley Sheehe (Anthony; moved to Miami, occasional) - has a sheet; low priority.
- Sally O'Laughlin (NW; moving to Lake Wales ~90 min S) - likely leaving service area.
- Arlene Calbo, Becky Swinford, Coleen Smith, Elijah Weber, Maria Arvanitis, Martica Ewers
  - calendar-only, no sheet; convert only if cadence reappears.

## Open data questions (need Paul)

- Peter Moran cadence: ~8wk (his note) vs ~12wk (calendar).
- Lisa Irwin: current home vs office address and the every-other-Tuesday alternation.
- Terri McDonnell: confirm works-from-home (affects daytime availability).
- Mary Beth Anderson: Theo's breed.
- Patty Brown: real availability beyond the Saturday assumption (no contact sheet).
- Chester Weber: exact bearing/zone from base (minor).

## Route work (after cadences lock)

- Rebalance the template against corrected stop sizes: Kevin is now a half-day 7-dog stop;
  Steve and Patty are quick nails; Chester is shorter without Windsor.
- Confirm the Thursday NE evening trio (Ginger, Michelle, Chloe) overflow plan to Saturday.

## Bigger questions for Paul (decide before the build needs them)

- **Business architecture (RESOLVED 2026-05-24).** Two businesses, not three: DGN (flagship)
  and Clean (ONE evolving business, a fork of the DGN platform). The separate scalable "new
  Clean" folds back into Clean. Full decision in the Scroll decisions log. Still parked as
  forward-looking, not decided: a possible "Dog Gone" brand family named by service (Clean,
  Walking, Sitting, Training) built as forks of the same platform, each its own instance; and
  whether Paul ultimately runs a portfolio he keeps or builds units to sell.
- **Online payment:** DECIDED 2026-05-24 (legacy doggoneclean.us only), UPDATED 2026-05-26
  (Hurricane Bath is online). Legacy doggoneclean.us continues in person via Square until
  its own rebuild. Hurricane Bath (hurricanebath.com) launches with Stripe card-on-file
  plus auto-charge at the 24-hour mark, per the new Oracle rules
  `card_on_file_at_signup` and `auto_charge_at_24h`. DGN's payment/skip/reschedule/card
  layer IS ported now for the Hurricane Bath surface (see the 2026-05-26 decisions log
  in the Scroll for the 24 captured rules); it is NOT ported to the legacy surface.
- **Field/operator app:** DECIDED 2026-05-24. Yes, operator app plus pizza tracker in Clean
  v1, forked from DGN. (Pizza-tracker details to come from Paul.)
- **Paul's FL/GA travel:** still open. Does the biweekly Florida/Georgia travel that shapes
  DGN's Villages schedule also constrain the Clean route, or is it DGN-only? Clean data today
  only has client seasonality (Mary Jane away Jun-Nov), not Paul's own travel.

## Hurricane Bath open decisions (parked from the 2026-05-26 plan)

These do not gate the build but should be resolved as Phase 4 progresses.

- **Cycle time per appointment.** 1 hour placeholder including drive + work; Paul
  measures real cycle times in The Villages once routes start running. Capacity
  planning gut estimate also parked: 65% one-dog, 30% two-dog, 5% three-dog.
  Updates `breed_tier_pricing` and operator-app capacity math.
- **Tier slug names.** Recommended `smoothcoat` and `doublecoat` per the plan;
  Paul may rename (candidates considered: `tier_1` / `tier_2`, `quick` /
  `extended`, `standard` / `extended`, `express` / `full`). Descriptive beats
  hierarchical because the categories are coat-type differences, not levels.
- **Breed list refinement.** First attempt at `src/data/breeds.json` lives in
  Appendix A of the approved plan, with smoothcoat (~52 breeds), doublecoat
  (~11 breeds, small after Paul's mat/impact exclusion), and a long
  not_accepted list including all poodles/crosses, Goldens/Aussies/Border
  Collies (per Paul's call-outs), feathered retrievers/setters, spaniels, toy
  grooming breeds, long-coat herders, wirehairs, corded/heavy-coat, and the
  excluded Nordic/spitz/heavy-undercoat group. Mixed-breed dogs route through
  an eligibility questionnaire. Paul iterates.

## Paul-actions deferred from 2026-05-26 rule capture

Mechanical work that the session could not complete itself.

- **Push the `pre-hurricane-snapshot` git tag** to origin. The tag was created
  locally on commit `f65a096` but the harness proxy returns HTTP 403 on tag
  pushes. Local `git push --tags origin` from Paul's machine should
  propagate it.
- **Create the private archive repo `doggoneclean-legacy-data`.** The harness
  scope cannot reach repos outside `doggoneclean-site` and `doggonenails-site`.
  Until it exists, the `data/` directory is held in `legacy/data/` in this
  repo (move executed 2026-05-26). When the archive repo exists, move the
  files there and strip from `main`.
- **Hurricane Bath Supabase project** (`dgc-prod`): create separate from
  `dgn-prod`, hand over URL + service-role key.
- **New Stripe account for Dog Gone Clean.** Separate from DGN's account.
- **Domain-locked Maps + OAuth keys** for hurricanebath.com (own Google Cloud
  project per `own_infrastructure`).

## Saleability (keep the door open)

Constraint (Oracle `clean_stays_saleable`): Clean must stay sellable as a standalone
business, never tangled with DGN or dependent on Paul personally. Probably never sold, but
the option stays open. Implications to honor as the build proceeds:

- Separate from DGN where it counts: the Supabase project (data) is the hard line, never
  shared. A shared droplet, account, or tooling is acceptable to save cost since those are
  cheap to separate before a sale. Keep API keys their own and domain-locked. No shared data
  or imports.
- Operate without Paul: routes, rules, and the client book live in the system and the docs,
  not in his head. No DGN-style dynastic/bloodline ownership; ownership and operator roles
  must be transferable.
- Keep Clean's docs self-contained: DGN references should be incidental, not load-bearing,
  so a buyer can read the Oracle and records without needing DGN context.

Pre-sale cleanup (not urgent, but would block a sale if left):
- Authoritative client data currently lives in Paul's personal Google Drive. For a real
  transfer, the source of truth should move into Clean's own infrastructure (its Supabase
  project) so the asset is self-contained.
- Brand/trademark: a buyer gets "Dog Gone Clean"; Paul keeps "Dog Gone Nails." Confirm what
  rights to the shared "Dog Gone" name transfer. Real-world task for Paul, not a build task.

## Website build, when the rules are locked (the DB guardrail lifts first)

Tooling to port from DGN at scaffold time (adapted, never shared): `package.json`,
`astro.config.mjs`, `scripts/lint-business-rules.mjs` (rewrite patterns for Clean; keep
em_dash and the generic ones, drop/invert the nail-terminology patterns),
`scripts/smoke-build.mjs`, the GitHub Actions deploy workflow, the stop-hook. Plus the
`business_rules` table + `src/business/` module pattern once the DB exists.

Architecture to clone, not reinvent:
- **Scheduling / recurring engine.** DGN's "book once, the slot is yours, materialize the
  recurring chain, route around it" (subscriptions + horizon + cascade + get_available_slots)
  is literally Clean's standing-client-on-a-cadence operation. `route_template.md` is the
  manual version. Re-derive grooming durations (Clean times run 17 to 367 minutes, not
  DGN's fixed 15/25/40), the Ocala service-area polygon, and Clean's own cascade numbers.
- **Offline-first field app** lessons (cache is the render source, writes never block render,
  advance controls always visible, manual time corrections, persistent End Day) if a Clean
  field app is built.

## Future / bigger ideas

- Geocode the plus codes to compute true drive-time clusters instead of NE/NW/SE/SW buckets.
- Multi-specialist routing: apprentice Jake can take solo dogs (e.g. Spero at Heather's).
- Route-generation automation that reads `clients.json` + the template and honors every
  HARD window, plus a check that banned/one-off clients never appear in a generated route.
