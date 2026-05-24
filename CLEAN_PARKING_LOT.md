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

- **Business architecture (raised 2026-05-24, UNRESOLVED).** Up to three businesses are
  emerging: (1) legacy full-service grooming in Ocala (this repo's current book; keep,
  maintain, keep sellable), (2) Dog Gone Nails (sculpt nails, Villages and other markets),
  and (3) a reinvented productized service: bath + nails + sanitary shave, NO haircuts,
  Villages-first then other high-density profitable areas (likely not Ocala). Two questions
  decide the whole shape: (a) is (3) a separate brand or just DGN with a wider menu (three
  businesses vs two)? (b) which business carries the "Dog Gone Clean" name, the legacy Ocala
  grooming (what this repo holds today) or the new reinvented one? Answer to (b) decides
  what THIS repo becomes. Working recommendation: one website per sellable brand, but build
  the productized businesses from a shared template (each with its own instance and infra)
  so the engine and lessons are reused without entangling them (per clean_stays_saleable);
  the legacy business stays lean.
  - Newer thinking (2026-05-24): Paul may launch a family of "Dog Gone" brands named by
    service (Clean, Walking, Sitting, Training). Under that taxonomy the legacy Ocala
    business is full grooming, not "clean," so "Dog Gone Clean" fits the new Villages bath
    business better; open whether to give the keeper name to the new business and let the
    winding-down legacy take a distinct grooming name.
  - Deeper fork that sets everything else: does Paul want a portfolio he owns and runs
    together, or independent businesses each separately sellable? That, not "sell or not,"
    sets the saleability scope and the shared-vs-separate infrastructure call.
  - The Ocala legacy is the income bridge that funds the new builds, so keep it stable and
    low-investment while the new businesses come up.
  - Assistant recommendation (2026-05-24, for Paul to weigh, NOT decided): run this as a
    platform-and-brands business funded by the legacy. (1) The reusable engine/playbook for
    productized, density-routed mobile pet-service businesses is the real asset and the thing
    to keep. (2) Each Dog Gone brand (nails, new Clean, later Walking/Sitting/Training) is a
    separable, individually sellable instance forked from that template, each on its own
    infra, so the platform is kept while any one brand stays sellable. (3) Legacy full
    grooming in Ocala is the cash bridge: lean, priced to value, documented into a clean
    transferable book, sold or sunset once the new brands carry the income. Structural crux:
    the platform is a template each brand FORKS and OWNS, never one shared live system (a
    shared live platform would entangle the brands and break saleability). Caution: solo
    operator, so prove the model on one brand first (the Villages bath-Clean) before stamping
    the next.
- **Online payment:** does the Clean site take payment online, or stay in-person
  invoice/cash/card like the sheets show today? This one answer decides whether the entire
  DGN payment/skip/reschedule/card layer ever gets ported.
- **Paul's FL/GA travel:** does the biweekly Florida/Georgia travel that shapes DGN's
  Villages schedule also constrain the Clean route, or is it DGN-only? Clean data today
  only has client seasonality (Mary Jane away Jun-Nov), not Paul's own travel.
- **Field/operator app:** is a Clean grooming-day app on the horizon? If yes, DGN's
  operator-app lessons are the most valuable thing to mine.

## Saleability (keep the door open)

Constraint (Oracle `clean_stays_saleable`): Clean must stay sellable as a standalone
business, never tangled with DGN or dependent on Paul personally. Probably never sold, but
the option stays open. Implications to honor as the build proceeds:

- Separate everything from DGN: Supabase project, domain, droplet, Stripe, API keys, repo,
  and data. No shared services or imports.
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
