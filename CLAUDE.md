# Dog Gone Clean (DGC) - operating manual

Read this file first, every session. It is the operating manual, not the history.
For what happened and why, read the other docs in the order below.

## What this repo is

The scheduling and routing knowledge base for **Dog Gone Clean (DGC)**, Paul Nickerson's
mobile full-service dog grooming business in the Ocala, FL area (~20 years old). It holds
the authoritative client records and the recurring zone-day route template the scheduler
must honor. It is a data/knowledge repo, not a website yet, despite the repo name.

This repo is separate from the Dog Gone Nails (DGN) repo on purpose. See "Repo
separation" below.

## Read order (the doc set)

1. **CLAUDE.md** (this file) - operating manual. Permanent rules, stack, constraints.
2. **DGC_HISTORY.md** - session-by-session history + phase map. Read it fully before
   doing work. Rebuild it only at end of session on Paul's explicit instruction, never
   mid-session. If history and reality disagree, reality wins and history is corrected.
3. **DGC_RULES.md** - every business rule in "KEY (domain): Statement. Because <reason>."
4. **DGC_RULES_INDEX.md** - table mapping each rule to every place it is enforced.
5. **DGC_PARKING_LOT.md** - deferred work and forward-looking ideas, parked to survive
   context resets.

That read-order link is the only thing holding the set together. Keep the file names exact.

## How Paul works (bake into every interaction)

- **Recommendation with reason.** Any choice you offer lists the recommended option first,
  labeled "(Recommended)", with a "because". A recommendation without a reason is just a vote.
- **Outcomes, not actions.** Propose the outcome and ask if he wants it, not which
  implementation step to take. Implementation is your call.
- **No mockups.** Build against real data, auth, and services from the first commit.
- **Do the work; don't punt it.** Anything doable with your tools, do. Don't hand Paul task
  lists for things you can do. His plate is decisions, physical-world actions, and
  credentials no tool exposes.
- **Read before redesign.** Before any redesign, read DGC_HISTORY.md and DGC_RULES.md in
  full. A redesign that drops an existing rule is rejected.
- **Device profile:** Pixel 8 Pro on Chrome, a Chromebook for desktop, occasionally
  Windows. No Apple devices ever. Never write instructions assuming Safari, iOS, Apple
  Pay, or Apple Sign In.
- **No em dashes** in any copy, code, comments, or docs.
- **No corporate jargon:** no "reach out," "circle back," "bandwidth," "free up."

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

There is no app, build, server, or deploy here. The "stack" is Markdown + JSON + git, with
the Drive MCP tools as the upstream reader.

- Validate the data file: `python3 -c "import json; json.load(open('data/clients.json'))"`
- Read contact sheets: Drive MCP tools (search_files, get_file_metadata, read_file_content,
  download_file_content).
- Git: develop on the feature branch you are assigned, commit with clear messages, and
  `git push -u origin <branch>`. Never push to main and never open a pull request unless
  Paul explicitly asks. There is no CI and nothing deploys on merge.

## Hard constraints

- Real data only. Unknown fields are data gaps, never invented values.
- No em dashes, anywhere.
- Grooming terminology is correct here; never import DGN's bans.
- Banned clients (Bonnie DiGraziano) are excluded everywhere.
- HARD availability windows (evening locks, Saturday locks, fixed-noon slots, not-days) are
  the clients' real, permanent schedules. Plan around them.

## Repo separation

Do not share, symlink, or merge any of these docs between the DGN and DGC repos. Each
business gets its own set. Merged history is how rules get mis-applied across products.
