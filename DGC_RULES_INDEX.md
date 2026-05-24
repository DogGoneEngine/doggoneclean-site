# DGC rules index

Where each rule in DGC_RULES.md is actually enforced. This repo has no database, app code,
or lint yet, so enforcement today is the rulebook, the data file, the route template, and
plain convention. Started thin on purpose; split more out as automation appears.

| Rule | Rulebook | Also enforced in |
|------|----------|------------------|
| CLASSIFY-BY-FREQUENCY | Roster | `data/clients.json` `status` field; `data/README.md` |
| ACTIVE-SET | Roster | `data/clients.json` (roster is the file's scope); CLAUDE.md source section |
| BANNED-EXCLUDED | Roster | `data/clients.json` `banned[]` + `exclude_from_everything`; `route_template.md` (omitted) |
| ONE-OFF-NOT-ROUTED | Roster | `data/clients.json` `routed:false`; `route_template.md` (standing only) |
| REAL-DATA-ONLY | Data | `data/clients.json` `data_gaps[]`; convention |
| SHEETS-ARE-TRUTH | Data | `data/sources.md`; CLAUDE.md source-of-truth section |
| NEWEST-DOC | Data | `data/sources.md` (corrected IDs + caveat); CLAUDE.md |
| REALITY-WINS | Data | DGC_HISTORY.md header mandate; convention |
| SERVICE-TYPE-REQUIRED | Data | `data/clients.json` `service_type` (every record) |
| DATA-GAP-EXPLICIT | Data | `data/clients.json` `data_gaps[]`; `data/README.md` open-gaps list |
| CADENCE-CONFLICT-LEANS-SHEET | Scheduling | `data/clients.json` `cadence_confidence` + `cadence_note`; `data/README.md` |
| HARDNESS-RESPECTED | Scheduling | `data/clients.json` `hardness` + `availability`; `route_template.md` |
| TIME-IS-THE-CONSTRAINT | Scheduling | `route_template.md` design-priority note |
| BASE-IS-HOME-SW | Routing | `data/clients.json` `_meta.base_home`/`base_anchor`; `route_template.md` |
| REALISTIC-DAILY-LOAD | Routing | `route_template.md` capacity/load notes |
| GROOMING-VOCAB | Copy | CLAUDE.md terminology; convention across all docs |
| NO-DGN-IMPORT | Copy | CLAUDE.md terminology; "Repo separation" |
| NO-EM-DASHES | Copy | CLAUDE.md; convention across all docs |
| NO-JARGON | Copy | CLAUDE.md; convention |
| DEVICE-PROFILE | Copy | CLAUDE.md "How Paul works" |
| REC-WITH-REASON | Process | CLAUDE.md "How Paul works" |
| OUTCOMES-NOT-ACTIONS | Process | CLAUDE.md "How Paul works" |
| DO-THE-WORK | Process | CLAUDE.md "How Paul works" |
| READ-BEFORE-REDESIGN | Process | CLAUDE.md; DGC_HISTORY.md header mandate |
| NO-MERGE-ACROSS-REPOS | Process | CLAUDE.md "Repo separation" |
| GIT-BRANCH-NO-PR | Process | CLAUDE.md "Stack and commands" |

Gaps in enforcement (candidates for future automation): no schema validation on
`clients.json` beyond JSON parse; no lint for em dashes or banned vocabulary; no automated
check that banned/one-off clients stay out of the route. Parked in DGC_PARKING_LOT.md.
