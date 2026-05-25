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
- **State:** Clean's own Supabase project is LIVE: `dgc-prod`, ref `urebdrosrxejhubpbxsa`,
  us-east-1, inside the shared "Mount Olympus" org (account sharing is allowed; the project
  is the hard line, never `dgn-prod`). The client book is built and seeded in it:
  `public.clients` (47: 33 standing, 11 one-off, 2 at-will, 1 banned) and `public.dogs` (61),
  RLS-locked with no policy (only the service role reaches it until portal auth exists).
  Schema-as-code in `supabase/migrations/`, reproducible seed via `scripts/gen_seed_sql.py`
  to `supabase/seed.sql`, TS types in `supabase/database.types.ts`. Route template drafted;
  doc/handoff system built; strategy/infra/workflow locked; `scripts/check.py` green.
- **Next chapter:** scaffold the Clean Astro app + bath-forward marketing skeleton (no
  credentials needed), wire it to `dgc-prod` via the publishable key, then the portal shell
  with auth (the first RLS policies land with auth). After that the scheduling tables
  (services with variable grooming durations, subscriptions, appointments) forked from DGN's
  String of Pearls, and the `business_rules` table mirroring the Oracle.
- **Needs Paul to unblock the remaining live pieces:** DONE: `dgc-prod`'s keys + DB password
  (in Dashlane); Google Cloud (`dog-gone-clean`) with a domain-locked Maps JavaScript API
  key, the OAuth consent screen published, an OAuth web client, and Google sign-in enabled on
  dgc-prod. LEFT: (1) Clean's own Twilio account, phone number, and A2P registration, which
  powers SMS notifications and the phone access-code login; (2) a DigitalOcean droplet (reuse
  DGN's or new) plus pointing hurricanebath.com at it, needed only when ready to preview. (A
  literal fork of the DGN code, if wanted, must be brought over by hand; this repo cannot
  reach the DGN repo.)
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
- **Phase 4 - Clean website + ops app (fork of the DGN platform).** IN PROGRESS. The
  database foundation is DONE: Clean's own Supabase project `dgc-prod` is live and holds the
  client book (`clients` + `dogs`) seeded from `data/clients.json`, RLS-locked. Still to
  build: Astro marketing site (bath-forward) + client portal (existing + new clients) +
  String of Pearls scheduling + operator app with photos + pizza tracker + SMS
  notifications. In-person payment (Square). Preview on hurricanebath.com until
  doggoneclean.us flips at launch.
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

### 2026-05-25 (database setup)

Stood up Clean's own Supabase project and built the client-book database layer. Created
`dgc-prod` (ref `urebdrosrxejhubpbxsa`, us-east-1) in the shared "Mount Olympus" org, the
hard-separation line per `own_infrastructure` (only `dgn-prod` existed before; nothing of
Clean's touches it). Wrote the v1 schema (`public.clients` + `public.dogs`) as a migration
in `supabase/migrations/`, RLS-locked with no policy so only the service role reaches the
data until portal auth is built (the records carry gate codes and door codes). Added
`scripts/gen_seed_sql.py`, which turns `data/clients.json` into a reproducible
`supabase/seed.sql`, and seeded the project: 47 clients (33 standing, 11 one-off, 2 at-will,
1 banned) and 61 dogs, prices stored in cents, verified with zero orphans and zero standing
records missing required fields. Saved the generated TypeScript types to
`supabase/database.types.ts`. Security advisor shows only the expected INFO
(RLS-enabled-no-policy), which is the intended locked state.

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

## Decisions log (2026-05-25)

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
  `supabase/seed.sql` from `data/clients.json`; re-running it fully refreshes the database.
  `data/clients.json` stays the authoritative file until the app writes back to Supabase.

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
