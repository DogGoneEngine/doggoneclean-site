# Dog Gone Clean (DGC) - operating manual

Read this file first, every session. It is the operating manual, not the history.
For what happened and why, read the other docs in the order below.

## What this repo is

Dog Gone Clean (DGC) is Paul's mobile dog grooming business in the Ocala, FL area (~20 years
old). This repo is becoming the **DGC website and operations app**. Clean is one evolving
business: it keeps serving its existing full-grooming clients while repositioning the
marketing toward higher-profit bath work to attract new clients, and it can expand to the
Villages with bath service. There is no separate "new Clean"; the existing book and the new
direction are the same business being morphed (sending the legacy business to the gym). Clean
is built as a fork of the proven Dog Gone Nails (DGN) platform, with its own instances and
infrastructure, never merged with DGN. The authoritative client records in `data/` seed it.
Treat this as a construction site for the building that is coming.

There are two businesses total: DGN (the flagship, fully separate) and Clean (this repo).

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
6. **CLEAN_FIELD_MANUAL.md** - the hands-on SOPs for the work itself (grooming craft,
   equipment, power, climate, trailer, maintenance). Reference manual, not a read-every-session
   doc: read it when doing field, equipment, or operator-app-feature work. Absorbed from Paul's
   original Drive journal (`the_oracle_journal`).

That read-order link is the only thing holding the set together. Keep the file names exact.
These are Clean's own scrolls; never share or merge them with DGN's.

## Recording ideas and decisions (lock it in)

Paul's ideas now come into a Claude thread, not a separate document. He may not know where any
given idea should live, and that is fine: he describes the idea and the reason, and you choose
its home. Default to thread-first capture, because the idea lands in its real home immediately
instead of piling up for a later absorption pass.

- **Triggers to save now:** "put it where it belongs," "capture this," "lock it in," or a clear
  equivalent. On any of these, capture the same turn: write it to its live home (an Oracle rule,
  a constraint in this file, the parking lot, the field manual, or a record field), add a dated
  line to the Scroll's decisions log if it is a decision, run `python3 scripts/check.py`, and
  commit/push. Then tell Paul where you filed it so he can redirect you.
- **Hold signal:** "just thinking out loud," or Paul clearly still musing, means record nothing
  yet.
- **Always attach a because.** If an idea is becoming a rule and Paul did not say why, ask one
  quick question for the reason rather than saving a reasonless rule. A rule without a because
  is not a rule.
- **Durability:** an idea in a thread is not safe until it is committed to git, since a thread
  can compact and the container can be reclaimed. Committing on each capture is the whole point.
- **Offline fallback:** when Paul is mid-route and cannot do a back-and-forth, voice-dumping
  into the Drive journal (`the_oracle_journal`) is still the better quick inbox; absorb it into
  the docs later in a batch. Threads when he can talk, journal as the offline buffer.

See `lock_it_in_capture` in the Oracle.

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
- **Elon's algorithm (run every build/scope call through it).** In order: make the requirement
  less dumb (tie each to a real reason and a real person, never "because DGN had it"), delete the
  part or step, simplify what survives, accelerate cycle time, then automate last. Never optimize
  or automate something that should have been deleted. See `elons_algorithm` in the Oracle.
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

- **Clean must stay sellable.** Paul wants the option to sell Dog Gone Clean someday (he
  does not plan to, but it must stay possible). Never entangle Clean with DGN or with Paul's
  personal accounts: separate Supabase project, domain, droplet, Stripe, API keys, and data,
  and operations documented well enough that a buyer could run it without Paul. This is a
  guardrail on every decision, not a feature to build; avoid entanglement now. See
  `clean_stays_saleable` in the Oracle.
- **Build Clean's data in its own Supabase project, iteratively.** Clean is greenlit to
  build (2026-05-24). Build the schema in the flow and treat early tables as rebuildable
  until they settle; no rules summit needed. The hard line is separation, not delay: Clean's
  data lives only in its own Supabase project, never DGN's (`dgn-prod`).
- **Data is the hard-separation line; host and accounts are soft.** Never share a database or
  data with DGN (expensive and ugly to undo). The web host (a shared DigitalOcean droplet
  with its own directory/domain/Caddy block) and even a shared Supabase or Google Cloud
  account are cheaper layers where sharing to save money and overhead is acceptable, because
  a static site and a Supabase project both move to their own home with low effort before any
  sale. Keep each set of API keys its own (a separate Google Cloud project for Maps and
  OAuth, domain-locked).
- **Clean is paid in person.** Square (or the current method) for in-person card, cash, and
  check; not Stripe. Online payment is deferred until it earns its place.
- Real data only. Unknown fields are data gaps, never invented values.
- No em dashes, anywhere.
- Grooming terminology is correct here; never import DGN's bans.
- Banned clients (Bonnie DiGraziano) are excluded everywhere.
- HARD availability windows (evening locks, Saturday locks, fixed-noon slots, not-days) are
  the clients' real, permanent schedules. Plan around them.
- Clean's infrastructure separates from DGN where it counts: its own Supabase project (never
  `dgn-prod`) is the hard line. A shared droplet (own directory/domain), shared account, or
  shared tooling is acceptable to save cost since those are cheap to separate later. Its own
  Stripe/Square account if payments ever go online.

## Repo separation

Do not share, symlink, or merge any of these docs between the DGN and DGC repos. Each
business gets its own set. Merged history is how rules get mis-applied across products.
