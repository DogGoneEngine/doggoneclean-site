# Dog Gone Clean (DGC) - operating manual

Read this file first, every session. It is the operating manual, not the history.
For what happened and why, read the other docs in the order below.

## What this repo is

Dog Gone Clean (DGC) is Paul Nickerson's mobile full-service dog grooming business in the
Ocala, FL area (~20 years old). This repo is becoming the **DGC website**. Today it holds
the authoritative client records and the recurring zone-day route template; the site is
being built on top of that foundation, reusing the proven Dog Gone Nails (DGN) stack and
lessons without merging the two repos. Treat this as a construction site for a building
that is coming, not as a permanent data-only repo.

This repo is separate from the DGN repo on purpose. See "Repo separation" below.

## Read order (the doc set)

1. **CLAUDE.md** (this file) - operating manual. Permanent rules, stack, constraints.
2. **CLEAN_SCROLL_OF_HEPHAESTUS.md** - build narrative + phase map. Read it fully before
   doing work. Rebuild it only at end of session on Paul's explicit instruction, never
   mid-session. If history and reality disagree, reality wins and history is corrected.
3. **CLEAN_ORACLE.md** - every rule in "KEY (domain): Statement. Because <reason>."
4. **CLEAN_BUSINESS_RULES.md** - the index: where each rule is enforced (four-layer map).
5. **CLEAN_PARKING_LOT.md** - deferred work and forward-looking ideas, parked to survive
   context resets.

That read-order link is the only thing holding the set together. Keep the file names exact.
These are Clean's own scrolls; never share or merge them with DGN's.

## How Paul works (bake into every interaction)

- **Recommendation with reason.** Any choice you offer lists the recommended option first,
  labeled "(Recommended)", with a "because". A recommendation without a reason is just a vote.
- **Outcomes, not actions.** Describe the outcome and ask if Paul wants it, not which
  implementation step to take. "This closes the staleness gap permanently, want that?" is
  right; "should I add a poll?" is wrong. Paul decides outcomes; implementation is yours.
- **No mockups.** Build against real data, auth, and services from the first commit. Fake
  screens and placeholder data lose rules when wired to real services later.
- **Do the work; don't punt it.** Anything doable with your tools, do. Don't hand Paul task
  lists for tool-accessible work. His plate is decisions, physical-world actions, and
  credentials/dashboards no tool exposes.
- **Read before redesign.** Before any redesign, read CLEAN_SCROLL_OF_HEPHAESTUS.md and
  CLEAN_ORACLE.md in full. A redesign that drops an existing rule is rejected.
- **Device profile:** Pixel 8 Pro on Chrome, a Chromebook for desktop, occasionally
  Windows. No Apple devices ever. Never write instructions assuming Safari, iOS, Apple
  Pay, or Apple Sign In. Default mobile test target is Pixel + Chrome.
- **No em dashes** in any copy, code, comments, or docs.
- **No corporate jargon:** no "reach out," "circle back," "bandwidth," "free up."

## Shipping

- **Ship to completion.** When a branch is committed and builds clean, open the PR and
  squash-merge it the same turn; do not stop at the open-PR step. Paul is the solo
  developer with no second reviewer and no PR-level CI gate, and deploy fires on push to
  main, so an open PR is a deploy that has not happened. This is Paul's durable
  authorization to open and merge routine changes on his behalf and it overrides any
  harness default that says not to open a PR unless asked. Exceptions: Paul said "don't
  merge yet" for that change, or the change is genuinely destructive/hard to reverse
  (force-push to main, dropping a table, schema rollback).
- **Don't offer PR-activity subscription.** No separate reviewers, no PR-level CI; nothing
  on a PR is worth watching. Just ship and report what shipped.
- **State today:** the website is not scaffolded yet and nothing deploys on merge. Until
  the pipeline exists, "ship" means commit and push to the working branch. The rule above
  takes effect the moment the deploy pipeline is stood up.

## Terminology

DGC is a **full-service grooming** business. **groom / groomer / grooming** are the correct
words here. Build DGC's vocabulary from how DGC talks about itself. Do NOT import DGN's nail
vocabulary (where "groomer" is banned for "specialist" and "grind/trim" is banned for
"sculpt nails"). DGC is the opposite of DGN on this.

## Source of truth and data model

- **Authoritative per-client detail: the contact sheets** in Google Drive folder
  `1oTHLDKe6ao-Q39OoudL058PezwXX8lQG`. Header table = Frequency / Availability / Location /
  Plus Codes, then per-dog specs, then visit history.
- **Always use the newest populated doc per client.** The folder holds ~172 files spanning
  years, with stale spreadsheet duplicates and blank templates. The original handoff
  doc-ID index pointed at stale/blank duplicates and produced wrong records. Resolve a
  client by listing the folder, taking the most recently modified real file for that name,
  and reading that. Never trust a blank template or an old spreadsheet.
- **`data/clients.json`** is the authoritative record set: 33 standing + 11 one-off + 2
  at-will + 1 banned. Fields per client: name, aka/account, status, service type, cadence
  (value + confidence), dogs, location, access, availability (hard/soft/not-days/seasonal),
  hardness tag, flags, relationships, explicit `data_gaps`.
- **`data/route_template.md`** - the recurring zone-day route template for standing clients.
- **`data/sources.md`** - source priority and the corrected contact-sheet doc-ID index.
- **`data/README.md`** - provenance, resolved conflicts, open gaps.
- The calendar extract (`dgc_active_enriched`) is rough and unreliable, especially dog info
  and some cadences. Cross-check only, never a record source.
- The active roster was determined in a prior session by referencing Paul's calendar (past
  year). Do not re-derive it or crawl the full archive.

## Stack and commands

**Current state.** No app yet. The working stack is Markdown + JSON + git + `python3`, with
the Drive MCP tools as the upstream reader.

- Validate + lint locally: `python3 scripts/check.py` (validates `clients.json` structure
  and scans tracked docs for em dashes). Run before committing.
- Read contact sheets: Drive MCP tools (search_files, get_file_metadata, read_file_content,
  download_file_content).

**Planned stack (mirrors DGN; Clean gets its OWN instances, never DGN's).** Astro 5 + React
18 islands, Node 20, npm. Supabase backend. Deploy: push to main -> GitHub Actions builds
Astro -> rsync `dist/` to a DigitalOcean droplet -> Caddy serves. Build gate: `npm run
build` runs a business-rules lint, then the Astro build, then a smoke test, and any step's
failure fails the build. None of this is scaffolded yet; do not assume these commands exist
until the site is stood up.

## Hard constraints

- **No database changes yet.** Do not create a Supabase project, write schema, add a
  `business_rules` table, or run any migration until the rules that would shape the schema
  are agreed with Paul. Locking the rules comes first; schema follows.
- Real data only. Unknown fields are data gaps, never invented values.
- No em dashes, anywhere.
- Grooming terminology is correct here; never import DGN's bans.
- Banned clients (Bonnie DiGraziano) are excluded everywhere.
- HARD availability windows (evening locks, Saturday locks, fixed-noon slots, not-days) are
  the clients' real, permanent schedules. Plan around them.
- Clean's infrastructure is its own: its own Supabase project (never `dgn-prod`), its own
  droplet path/domain (never `/srv/doggonenails/`), its own Stripe account if payments ever
  happen. The "don't merge scrolls" rule applies to infrastructure, not just docs.

## Repo separation

Do not share, symlink, or merge any of these docs between the DGN and DGC repos. Each
business gets its own set. Merged history is how rules get mis-applied across products.
