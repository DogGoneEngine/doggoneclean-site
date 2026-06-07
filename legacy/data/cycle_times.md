# Legacy client cycle times (per-client appointment block time)

Provenance: Google Sheet `Claude-dgc_legacy_cycle_times`
(id `1mEdpMN8nuQDrhm9lzh3Q0v5qzJDqt0oqTxBNfrolvuU`), created by Paul 2026-06-07,
derived from ~12 months of his real appointment book. Captured into the repo on
2026-06-07 so the data survives independent of Drive. Source of truth for the
per-client schedule block when the app schedules legacy full-grooming clients
(`legacy_folds_into_v2`).

## How these columns are used

- `median_cycle_min` is the **block time** the scheduler reserves for that client
  (on-site arrive-to-depart). Use the median, not the average, so one odd day does
  not skew the block. Drive time between stops is a separate route concern, not part
  of this per-client block.
- `median_groom_min` is hands-on grooming time; the gap to cycle is setup, dog
  handling, and payment.
- `avg_charged` is a price reference only. Legacy still bills in person via Square
  (`bills_in_person_today`); this is not a stored online price.
- `avg_cycle_rate_per_hr` is revenue per hour, a strategic signal for
  `favor_high_hourly_work` (which clients clear high vs low per hour).

## Data gaps (do not seed a block time until resolved)

- **Lisa Prater**: 11 visits but an 11-min cycle / 9-min groom and a $209/hr rate.
  Implausible for a full groom; likely a nail-only / quick drop-in or a recording
  artifact. Confirm the real service and duration before seeding.
- **Short-cycle regulars** (Nancy Franklin 35, Patty Brown 45, Steve Crandall 53,
  Garrett Little 64): many visits, so real, but short. Confirm whether these are
  nail-only / small-dog quick service rather than full grooms.
- **Single-visit clients** (visits_12mo_book = 1: Amanda Posner, Arlene Calbo, Becky
  Swinford, Billye Mallory, Edely Abreu, Elijah Weber): one data point, low-confidence
  duration. Seed but mark low confidence.

## Reconciliation note

This sheet lists 51 clients; `legacy/data/clients.json` carries 33 standing + 11
one-off + 2 at-will + 1 banned. Reconcile names before seeding: the banned client
(Bonnie DiGraziano) is correctly absent here; some single-visit names here are the
one-offs; resolve any name that appears in one file but not the other.

## Data

| client | visits_12mo_book | last_visit | median_cycle_min | avg_cycle_min | median_groom_min | avg_charged | avg_cycle_rate_per_hr | merged_aka |
| :-- | :-: | :-: | :-: | :-: | :-: | :-: | :-: | :-- |
| Amanda Posner | 1 | 2025-10-08 | 71 | 71 | 55 | 75 | 63 |  |
| Amy Blessing | 31 | 2026-05-27 | 179 | 178 | 147 | 192 | 80 |  |
| Arlene Calbo | 1 | 2026-04-15 | 121 | 121 | 89 | 105 | 57 |  |
| Barbara Lape | 42 | 2026-05-26 | 88 | 89 | 60 | 70 | 57 |  |
| Becky Swinford | 1 | 2026-04-04 | 168 | 168 | 124 | 180 | 64 |  |
| Billye Mallory | 1 | 2025-08-24 | 189 | 189 | 169 | 180 | 57 |  |
| Bradley Johnson | 23 | 2026-05-13 | 130 | 134 | 105 | 75 | 36 |  |
| Brooksley Sheehe | 14 | 2026-01-24 | 368 | 367 | 330 | 450 | 92 |  |
| Chester Weber | 32 | 2026-05-01 | 94 | 94 | 79 | 101 | 66 |  |
| Chloe Castellano | 22 | 2026-05-19 | 122 | 125 | 92 | 97 | 59 |  |
| Colleen Smith | 2 | 2026-05-14 | 204 | 204 | 180 | 210 | 87 |  |
| Cynthia Tieche | 73 | 2026-05-26 | 142 | 140 | 111 | 115 | 69 |  |
| Debra Koerner | 9 | 2026-03-06 | 150 | 138 | 119 | 134 | 69 |  |
| Donna Dipasqua | 37 | 2026-05-12 | 85 | 85 | 62 | 100 | 87 |  |
| Donna Rodriquez | 19 | 2026-05-02 | 145 | 144 | 122 | 101 | 44 | Chris Votos |
| Edely Abreu | 1 | 2025-08-10 | 107 | 107 | 71 | 75 | 42 |  |
| Elijah Weber | 1 | 2026-04-10 | 232 | 232 | 206 | 180 | 47 |  |
| Emily Walker | 3 | 2026-04-15 | 147 | 161 | 117 | 160 | 61 |  |
| Eric Shannon | 21 | 2026-03-16 | 118 | 118 | 84 | 95 | 52 |  |
| Erich Blunt | 17 | 2026-05-29 | 254 | 240 | 220 | 221 | 62 |  |
| Garrett Little | 19 | 2026-01-24 | 64 | 62 | 33 | 45 | 54 |  |
| Ginger Fink | 18 | 2026-05-11 | 76 | 77 | 52 | 77 | 79 |  |
| Greta Custer | 10 | 2026-05-19 | 142 | 179 | 128 | 167 | 65 |  |
| Harriet Woolf | 36 | 2026-05-27 | 147 | 149 | 130 | 126 | 60 |  |
| Heather Albinson | 23 | 2026-04-28 | 234 | 234 | 228 | 190 | 61 |  |
| Hope Brooks | 13 | 2026-05-16 | 96 | 99 | 80 | 79 | 60 |  |
| Jane Henrich | 6 | 2025-12-27 | 269 | 262 | 218 | 156 | 39 |  |
| Jeanne Leuenberger | 16 | 2026-04-17 | 103 | 105 | 88 | 76 | 51 |  |
| Karen Evans | 2 | 2026-04-17 | 127 | 127 | 85 | 105 | 61 |  |
| Kevin Cummings | 26 | 2026-05-20 | 395 | 389 | 370 | 384 | 66 |  |
| Ligia Amyotte | 17 | 2026-05-20 | 308 | 320 | 287 | 357 | 69 |  |
| Linda Giza | 11 | 2026-03-29 | 144 | 148 | 106 | 118 | 56 |  |
| Lisa Irwin | 58 | 2026-05-26 | 133 | 139 | 85 | 108 | 59 |  |
| Lisa Prater | 11 | 2026-05-16 | 11 | 23 | 9 | 38 | 209 |  |
| Maria Arvanitis | 2 | 2026-05-29 | 94 | 94 | 68 | 105 | 77 |  |
| Marilyn Jamison | 33 | 2026-05-27 | 119 | 121 | 96 | 100 | 54 |  |
| Martica Ewers | 2 | 2026-05-12 | 130 | 130 | 102 | 105 | 63 |  |
| Mary Beth Anderson | 35 | 2026-05-12 | 174 | 173 | 148 | 148 | 65 |  |
| Mary Jane Hunt | 45 | 2026-05-28 | 220 | 230 | 202 | 225 | 80 |  |
| Michelle Reiners | 24 | 2026-05-15 | 118 | 120 | 98 | 96 | 61 |  |
| Nancy Franklin | 35 | 2026-05-16 | 35 | 40 | 17 | 26 | 41 |  |
| Patricia Angelucci | 15 | 2026-05-13 | 107 | 106 | 86 | 100 | 75 |  |
| Patty Brown | 5 | 2026-05-29 | 45 | 48 | 25 | 45 | 60 |  |
| Peter Moran | 4 | 2026-03-31 | 138 | 138 | 118 | 102 | 45 |  |
| Ray Russell | 36 | 2026-05-13 | 116 | 117 | 95 | 84 | 45 |  |
| Richard Vieira | 3 | 2026-05-11 | 124 | 135 | 94 | 105 | 53 |  |
| Sally O'Laughlin | 18 | 2026-05-14 | 128 | 130 | 104 | 70 | 37 |  |
| Shane Smith | 3 | 2026-05-29 | 264 | 264 | 232 | 292 | 64 |  |
| Steve Crandall | 37 | 2026-05-27 | 53 | 54 | 41 | 65 | 81 |  |
| Terri McDonnell | 4 | 2026-05-15 | 290 | 288 | 258 | 315 | 79 |  |
| Tonya Hunt | 33 | 2026-05-28 | 293 | 295 | 262 | 296 | 86 |  |
