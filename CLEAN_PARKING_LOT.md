# CLEAN_PARKING_LOT - Dog Gone Clean

Deferred work and forward-looking ideas, parked so they survive a context reset. Nothing
here is committed work; it is the backlog. Move an item into CLEAN_SCROLL_OF_HEPHAESTUS.md's focus block
when it becomes active.

## Website build (active next step)

The site is live at hurricanebath.com (staging), built and deployed from `main` via
`.github/workflows/deploy.yml`. The homepage is rebuilt in the Neural Expressive look (Paul
approved the visuals) with the master logo (`public/logo.png`) and real content from
`marketing/`. Next steps, decided 2026-05-25:

- **Fork the DGN site structure into Clean (multi-page).** Clean's site is currently a single
  page; it should be a multi-page site modeled on the proven Dog Gone Nails site (Clean is a
  fork of the DGN platform; the separation line is data/accounts/docs, never the site shape).
  Paul is granting this environment access to the DGN repo so a future session can read its
  structure and fork it directly. Reuse DGN's page set and layout; keep Clean's own content,
  Neural Expressive style, logo, and data. Do NOT merge DGN's docs or data.
- **Copy pass (the live copy needs real work).** The hero "A cleaner dog, without leaving
  home." is a provisional placeholder ("Dog grooming. No chaos." was rejected). Service area is
  Ocala ONLY (no surrounding towns; one-off exceptions are not advertised). No "brush out" or
  brush wording: the Hurricane Bath and high-velocity dryer do that work, Paul owns no brush.
- **Logo check.** Confirm the logo renders cleanly on the light page (may need a
  transparent-background version).

## Marketing copy ideas (parked, not ready to use)

Kernels for the site copy, captured so they are not lost. Not approved and not for publish yet.

- **Shedding interception (the two-week routine).** Paul's kernel, 2026-05-25, verbatim:
  > We can't change your dog's natural shedding cycle, but by getting on a strict two-week
  > routine, we can intercept a massive amount of that dead undercoat in our van before it ever
  > has a chance to land on your rugs, your furniture, or your clothes.

  Angle: sells the recurring two-week bath cadence as shedding control. Ties straight to the
  bath-forward pivot and to recurring standing visits. Hold until the copy pass.

## Portal and subscription ideas (parked, not ready to use)

- **Two-tap cancellation.** LOCKED 2026-05-26 as `stop_sign_two_taps` (see Oracle). The parked
  idea from 2026-05-25 became the rule the same week; kept here only as a pointer so future
  sessions do not re-park it.

## Service eligibility ideas (parked, needs work before use)

- **The Breed Firewall classification (draft).** Paul's idea, 2026-05-25. A coat-type rule for
  who the bath-only model accepts, aligning intake with `core_is_no_haircut_dogs`. Still needs
  work before it goes into intake, copy, or code.
  - **Excluded category:** any coat type that requires a haircut or styling, or that can knot,
    mat, or pack loose undercoat against the skin.
  - **Approved, smooth category:** single, short-haired coats that do not trap water and dry
    within minutes.
  - **Approved, dense category:** short or medium double-coats that shed heavily but do not mat,
    needing a standard undercoat blowout within the route time limit.

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

- **Business architecture (RESOLVED 2026-05-24, refined 2026-05-25 and 2026-05-26).** Two
  businesses in Paul's portfolio: DGN (Dog Gone Nails, new, nails only in the Villages, fully
  separate) and Clean (this repo, one evolving business, a fork of the DGN platform). Clean
  has TWO URL surfaces during the transition. **Legacy** (doggoneclean.us) keeps serving
  legacy Ocala full-grooming clients on Squarespace + Square + Acuity until its own rebuild.
  **Hurricane Bath v2.0** (hurricanebath.com) is Clean's new bath-only, subscription-default
  surface: launches in The Villages with Stripe card-on-file at signup, the locked v2.0 rule
  pack (founders rate, breed tiers, three-dog cap, free-skip allowance, no-show pause,
  reschedule step-up, two-tap cancel, etc.). Destination: bath only in the Villages by
  morphing the same business; the surfaces eventually converge. Still parked as
  forward-looking, not decided: a possible "Dog Gone" brand family named by service (Clean,
  Walking, Sitting, Training) built as forks of the same platform, each its own instance; and
  whether Paul ultimately runs a portfolio he keeps or builds units to sell.
- **Online payment:** DECIDED 2026-05-24 (legacy only), UPDATED 2026-05-26 (Hurricane Bath
  is online). Surface-scoped: legacy doggoneclean.us continues in person via Square (see
  `bills_in_person_today` + `accepted_payment_methods`). Hurricane Bath launches with Stripe
  card-on-file at signup plus auto-charge at the 24-hour mark, per the new Oracle rules
  `card_on_file_at_signup` and `auto_charge_at_24h`. DGN's payment/skip/reschedule/card
  layer IS ported to the Hurricane Bath surface (see the 2026-05-26 decisions log in the
  Scroll for the 24 captured rules); it is NOT ported to the legacy surface.
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

## Paul-actions still open

Mechanical work the container cannot do itself.

- **New Stripe account for Dog Gone Clean.** Separate from DGN's account and Paul's
  personal account per `own_infrastructure`. Hand over publishable + secret keys for the
  Hurricane Bath v2.0 surface (gates `card_on_file_at_signup`).
- **Twilio account, number, and A2P registration.** For SMS notifications and phone-login
  fallback. Clean's own account, not DGN's.
- **Grant the remote environment access to `doggonenails-site`** so a future session can
  read its multi-page structure and fork it into Clean.
- **Create the private archive repo `doggoneclean-legacy-data` (eventually, not urgent).**
  The harness scope is limited to `doggoneclean-site` and `doggonenails-site`. For now the
  records live under `legacy/data/` in this repo, which is fine; move them out only if and
  when the legacy book moves into Supabase and the static files become true archive.

## Repo housekeeping

- **Default branch + stale `claude/*` branches: DONE 2026-05-26.** Repo default branch was
  pointing at a stale `claude/amazing-noether-4Mo5W` snapshot, which is why every new
  session kept opening on stale state regardless of which branch was picked: GitHub itself
  was telling them that was the trunk. Switched the default to `main` (Settings > General),
  deleted every `claude/*` branch. The SessionStart hook in `.claude/hooks/session-start.sh`
  is now the belt-and-suspenders defense; the default-branch fix is the root cause cure.

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

**Marketing showcase content lives in `marketing/`.** When building the marketing page, pull from
there: the Hurricane Bath hero (`marketing/hurricane_bath_showcase.md`) and differentiator
showcases like power and fast drying (`marketing/power_and_drying_showcase.md`), with their copy,
FAQ, and banked gold lines. Keep build details (CLEAN_FIELD_MANUAL.md) and the shampoo brand off
the public page.

**Marketing-site features (forward-looking):**
- **Photo-to-gallery toggle.** In the operator app, when Paul takes an after photo that looks
  exceptional, a toggle marks it for the website gallery on the spot. Because the best moment to
  curate is while looking at the shot, and it feeds the rotating gallery with no later sorting
  chore.
- **Before/after gallery.** A curated, rotating display (recent and best work, out with the old as
  new comes in) backed by a permanent, growing archive of every shot. Show a fresh subset, keep
  everything. Because rotation signals an active, in-demand business, lets quality stay high,
  keeps pages fast, and the archive stays an owned asset that compounds. Needs client permission
  to display, and curate so no shot reveals the Hurricane Bath build.
- **Reviews built into the pizza tracker (recovered plan, was getting lost).** Track whether a
  client clicked the Google review link; once they have left one, stop asking; never pester a
  long-standing client who reviewed years ago; add a light "show someone" nudge to the
  after-photo drop. Review volume is throughput-limited (near full capacity, few new clients a
  week), so the system optimizes and times the ask, it does not manufacture volume.

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

## Website redesign (Neural Expressive) - blocked on screenshots

The marketing site's visual direction is Google's "Neural Expressive" language (decided
2026-05-25; full rule `neural_expressive_design` in the Oracle): blue gradient washes and
glows, ombre/gradient key words, a simple sans-serif with strong size contrast, editorial
hierarchy, gentle motion; expressiveness from color, not a special typeface. Approach is
restyle-not-reinvent: rebuild the existing DogGoneClean.us content in the new look, replacing
the current placeholder green palette (`src/pages/index.astro`) with the brand blues. BLOCKED
pending Paul's screenshots of the current DogGoneClean.us pages: the live site 403s automated
fetches and WebFetch is blocked in this remote environment, so the existing content cannot be
pulled here.

## Session ergonomics (parked, not urgent)

- **End-of-session documents-touched summary (parked 2026-05-26).** Paul wants, at the
  end of every session, a summary of which documents the session updated. Don't work
  out the mechanism now; decide later. Likely options when picked up: a Stop hook that
  runs `git log --name-only` against the session's commit range and prints the changed
  paths; or a session-end skill; or a footer the assistant prints from memory.

## Future / bigger ideas

- **Apple Sign In for clients (parked 2026-05-25).** Add Apple sign-in as an extra client
  login provider once Google login is live. Deferred to keep the first auth pass simple. This
  is a client-facing option for iPhone owners and does NOT change `device_profile`: that rule
  is about Paul's own environment (he uses no Apple devices) and how instructions are written,
  not which login providers clients are offered.
- Geocode the plus codes to compute true drive-time clusters instead of NE/NW/SE/SW buckets.
- Multi-specialist routing: apprentice Jake can take solo dogs (e.g. Spero at Heather's).
- Route-generation automation that reads `clients.json` + the template and honors every
  HARD window, plus a check that banned/one-off clients never appear in a generated route.
