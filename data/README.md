# DGC client data

`clients.json` is the authoritative record set, built 2026-05-24 from the per-client
contact sheets (see `sources.md`). It supersedes the rough working file and the
discarded first-draft route template from the prior Nails-repo session.

## How records were built

1. Contact-sheet header (Frequency / Availability / Location / Plus Codes) and per-dog
   specs are the primary source.
2. Paul's `dgc_overrides.json` corrections take precedence over the sheet where they
   conflict (newer info).
3. Calendar history (`dgc_active_enriched`) was used only to sanity-check cadence and to
   fill addresses/zips where the sheet had none. It is never the sole source for dog
   info or service type.

## Cadence conflicts

- **Chester Weber:** 3wk (sheet) over 4wk (calendar). Resolved -> 21 days, high.
- **Greta Custer:** 6-8wk (sheet) over 16wk (calendar). Resolved -> 49 days, high.
- **Kevin Cummings:** PENDING. His contact sheet is an empty stub (no Frequency line).
  The "4wk" was from Paul's notes digest, not the sheet; calendar shows ~6wk. This is
  Paul-intent vs booking-history, not sheet vs calendar.
- **Peter Moran:** PENDING. Sheet Frequency is blank. "~8wk" is only Paul's override
  note; calendar shows ~12wk (10/13/25 -> 1/9/26 = ~88 days).

## Base / anchor (Paul, 2026-05-24)

Home is 3885 SW 114th Court, Ocala 34481 (rural SW Marion County). It sits adjacent to
the SW Ocala / On Top of the World cluster, the densest part of the book, so no separate
fictional anchor is needed: use home for drive-time math, treat SW as the launch/return
cluster, and use Chester Weber (by base, flexible day, fixed 12pm) as the natural first
stop. NE/NW/SE days commute into the city.

## Open data gaps (need Paul)

Highest impact first:

1. **Patty Brown:** no contact sheet at all. Missing dogs, real availability, service
   type, cadence. Currently modeled as nails-only-legacy Saturday cluster per Paul.
3. **Steve Crandall:** dog names/breeds/count unknown (sheet header blank).
4. **Lisa Irwin:** which dogs are current (recent visits show 2), and the current
   home-vs-office address alternation. Sheet plus codes (Evinston) are stale.
5. **Erich Blunt:** is Sophie (very old standard poodle) still being groomed? Recent
   visits show only Koby (and Jethro?).
7. **Kevin Cummings:** dog prices; cadence (see above).
8. **Terri McDonnell:** confirm works-from-home (affects daytime availability).
9. **Cynthia Tieche:** confirm Satin + Luna are current (old spreadsheet sheet).
10. **Bradley Johnson:** name of the second cocker spaniel.
11. **Tonya Hunt:** which dogs are routine vs occasional/visiting.
12. **Heather Albinson / Hope Brooks:** precise NE/SW zone (resolve from plus codes once
    base is set).

## Standing roster at a glance (33)

- Service types: 27 full groom, 1 full+nails (Chester), 1 bath (Debra Koerner),
  1 nails-focused (Kevin), 3 nails-only legacy (Nancy, Lisa Prater, Patty).
- Hardness: 14 HARD, 3 SOFT, 15 FLEX, 1 FLEX+ (Ligia).
- Fixed-slot anchors: Mary Jane Hunt (Thu 12, away Jun-Nov), Chester Weber (weekday 12),
  Lisa Irwin (every-other-Tue 12).
- Evening-locked: Ginger, Chloe, Michelle, Steve, Marilyn, Peter (and Barbara's gate).
- Saturday cluster: Nancy + Lisa Prater + Patty Brown (neighbors), plus Hope (prefers Sat).
- Gap-fillers: Ligia Amyotte (FLEX+), Chester Weber.
- Seasonal: Mary Jane Hunt away Jun-Nov.
