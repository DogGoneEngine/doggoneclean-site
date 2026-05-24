# DGC rulebook

Every rule is "KEY (domain): Statement. Because <reason>." The because is mandatory; a rule
without one is not a rule yet. Where a rule is enforced is tracked in CLEAN_BUSINESS_RULES.md.

## Roster and classification

- **CLASSIFY-BY-FREQUENCY (roster):** If a client's contact sheet lists a Frequency, the
  client is STANDING, even if only one future booking exists. Because Paul books one
  appointment at a time to stay flexible, so a single booking does not mean one-off.
- **ACTIVE-SET (roster):** The active roster is the past-year set already derived from the
  calendar in a prior session; do not re-derive it or crawl the full contact-sheet archive.
  Because that determination was already made, and the archive holds years of inactive
  clients who would pollute the active set.
- **BANNED-EXCLUDED (roster):** Banned clients (Bonnie DiGraziano) are excluded everywhere:
  records, routes, summaries. Because a client Paul has fired must never resurface in a plan.
- **ONE-OFF-NOT-ROUTED (roster):** One-off and at-will clients are served on request and are
  not placed in the recurring route. Because the route template is the standing backbone;
  on-request work fills gaps around it.

## Data integrity

- **REAL-DATA-ONLY (data):** Build only from real sources; unknown fields are recorded as
  data gaps, never invented. Because for a 20-year operating book, a wrong value is worse
  than an admitted blank.
- **SHEETS-ARE-TRUTH (data):** Per-client detail comes from the contact sheets, not from the
  calendar extract or any digest. Because the extract is rough and digests drift from the
  source.
- **NEWEST-DOC (data):** Resolve a client to the most recently modified populated file for
  that name; never a blank template or an old spreadsheet duplicate. Because the folder
  holds ~172 files with stale duplicates, and the handoff index already caused six wrong
  records by pointing at blanks.
- **REALITY-WINS (data):** If the history or records disagree with the live sheet or Paul's
  correction, reality wins and the record is corrected. Because the records exist to mirror
  the business, not the other way around.
- **SERVICE-TYPE-REQUIRED (data):** Every client record carries a service type (full groom,
  bath, nails-only legacy, or mixed). Because routing duration and pricing both depend on it.
- **DATA-GAP-EXPLICIT (data):** Each record lists its open gaps explicitly. Because a hidden
  gap gets treated as fact; a listed gap gets resolved.

## Scheduling and routing

- **CADENCE-CONFLICT-LEANS-SHEET (scheduling):** When the sheet cadence and calendar history
  disagree, lean to the sheet, record a confidence level, and flag the residual for Paul.
  Because the sheet is Paul's stated intent and the calendar is noisy, but he still gets the
  final call.
- **HARDNESS-RESPECTED (scheduling):** HARD windows (evening locks, Saturday locks,
  fixed-noon slots, not-days) are the clients' real, permanent schedules and are planned
  around; SOFT is a movable preference; FLEX is free; FLEX+ is an ultra-flexible gap-filler
  needing no confirmation. Because these constraints are real client availability, not
  artifacts of how Paul currently sequences his day.
- **TIME-IS-THE-CONSTRAINT (scheduling):** Build days around time-of-day windows first, then
  cluster by geography within the window. Because a large share of the book is evening- or
  Saturday-locked, so geography alone cannot drive the route.
- **BASE-IS-HOME-SW (routing):** Use Paul's home (3885 SW 114th Court 34481) for drive-time
  math; treat the SW / On Top of the World cluster as the launch/return zone; no separate
  fictional anchor. Because home sits inside the densest cluster, so inventing an anchor
  would distort distances.
- **REALISTIC-DAILY-LOAD (routing):** Keep each day's stops geographically tight and within
  a workable count; do not pack one day with stops scattered across town. Because drive time
  between far stops is the main cost a route exists to cut.

## Copy and terminology

- **GROOMING-VOCAB (copy):** "groom / groomer / grooming" are correct DGC terms; build
  vocabulary from how DGC talks about itself. Because DGC is a full-service grooming business.
- **NO-DGN-IMPORT (copy):** Never import DGN's nail vocabulary or bans into DGC. Because the
  two businesses talk about themselves in opposite terms and merged vocabulary mis-describes
  the work.
- **NO-EM-DASHES (copy):** No em dashes in any copy, code, comment, or doc. Because Paul's
  house style forbids them.
- **NO-JARGON (copy):** No corporate jargon ("reach out," "circle back," "bandwidth," "free
  up"). Because it is noise.
- **DEVICE-PROFILE (copy):** Write instructions for Pixel 8 Pro on Chrome, a Chromebook, and
  occasionally Windows; never assume Safari, iOS, Apple Pay, or Apple Sign In. Because Paul
  uses no Apple devices, ever.

## Process

- **REC-WITH-REASON (process):** Every offered choice leads with the recommended option,
  labeled "(Recommended)", each with a because. Because a recommendation without a reason is
  just a vote.
- **OUTCOMES-NOT-ACTIONS (process):** Propose outcomes for Paul to approve; implementation
  steps are the assistant's call. Because Paul's time is for decisions, not for picking
  implementation steps.
- **DO-THE-WORK (process):** Anything doable with available tools, do; do not hand Paul a
  task list for work the assistant can complete. Because his plate is decisions,
  physical-world actions, and credentials no tool exposes.
- **READ-BEFORE-REDESIGN (process):** Read CLEAN_SCROLL_OF_HEPHAESTUS.md and this rulebook in full before
  any redesign; a redesign that drops an existing rule is rejected. Because dropped rules are
  how an operating business breaks silently.
- **NO-MERGE-ACROSS-REPOS (process):** Never share, symlink, or merge these docs between the
  DGN and DGC repos. Because merged history mis-applies rules across products.
- **GIT-BRANCH-NO-PR (process):** Develop on the assigned feature branch, commit, and push;
  never push to main or open a PR unless Paul explicitly asks. Because there is no CI and
  nothing deploys on merge, so an unrequested PR or main push is pure risk.
