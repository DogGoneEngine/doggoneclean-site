# Dog Gone Clean - Scheduling & Routing

This repo holds the scheduling and routing data model for **Dog Gone Clean (DGC)**,
Paul Nickerson's mobile full-service dog grooming business in the Ocala, FL area.

## What this is

DGC is a real, operating book of business. We are building the authoritative client
records and the recurring zone-day route template that the scheduler must honor. The
roster here is Paul's existing DGC book, moved into its own repo to keep it fully
separate from the Dog Gone Nails site.

## Operating rules (honor these on every task)

1. **Real data only. No mockups.** Every record traces to a real source (contact
   sheet, Paul's correction, or calendar history). If a field is unknown, mark it a
   data gap. Never invent a value to fill a blank.
2. **Recommendation with reason on every choice.** Lead with the recommended option,
   and give each option a "because". Recommended option goes first.
3. **No em dashes** anywhere in output, code, comments, or commits.
4. **Do the mechanical work.** Read the sheets, decode the files, build the records.
   Do not punt mechanical tasks back to Paul. Only escalate genuine decisions.

## Grooming terminology

This is a **full-service grooming** business. The words **groom / groomer / grooming**
are correct and expected here. (This is the opposite of the Dog Gone Nails repo, which
bans those words. Do not carry the Nails ban into this repo.)

## Source of truth

- **Authoritative per-client detail: the contact sheets** in Google Drive folder
  `1oTHLDKe6ao-Q39OoudL058PezwXX8lQG` (header table = Frequency / Availability /
  Location / Plus Codes, then per-dog specs, then visit history). The doc-ID index is
  in `data/sources.md`.
- **Classification rule (Paul's):** if the contact sheet lists a Frequency, the client
  is STANDING (even if only one future booking exists; Paul books one at a time to stay
  flexible). One-off = no frequency / explicitly one-off. At-will = serve on request,
  not routed. Banned = exclude everywhere.
- The calendar-derived extract (`dgc_active_enriched`) is **rough and unreliable**,
  especially dog info and some cadences. It is a cross-check only, never a record source.

## Cadence-conflict policy

When the contact sheet cadence disagrees with calendar history, **lean toward the
sheet** and record a confidence level. Flag the residual conflicts for Paul.

## Data model

`data/clients.json` is the authoritative record set. Fields per client: name, aka /
account name, status, service type, cadence (value + confidence), dogs, location,
access, availability (hard / soft / not-days / seasonal), hardness tag, flags,
relationships, and an explicit `data_gaps` list. See `data/README.md`.

## Hardness tags

- **HARD** = a real client constraint that must be respected (evening locks, Saturday
  locks, fixed-noon slots, not-days). These are the clients' actual schedules and are
  permanent. Plan around them.
- **SOFT** = a stated preference, movable if needed.
- **FLEX** = movable / flexible day and time.
- **FLEX+** = ultra-flexible gap-filler (no confirmation needed).
