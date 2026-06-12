# Schedule Adherence History: Plan vs Reality

Generated 2026-06-12 (US Eastern). Companion dataset: `legacy/data/adherence_history.json`.

## Headline numbers

- Rows in the Time is Money sheet: **1224** appointments, 2023-07-28 through 2026-06-11 (just under 3 years).
- Matched to a calendar event (same date, same client): **1161** (94.9 percent). Unmatched: 63.
- Usable arrival deltas (matched, arrival recorded, delta within 6 hours): **1158**.
- **Mean arrival delta: 82 minutes late. Median: 78 minutes late.**
- Spread: p10 = 21 min, p90 = 148 min. Almost the entire distribution is on the late side.
- On-time rate (arrived no more than X minutes after the scheduled start):
  - within 5 min: **4.4 percent**
  - within 15 min: **6.8 percent**
  - within 30 min: **16.0 percent**
- Arrived more than 15 minutes early: 1.2 percent.
- Paul left for the stop after its scheduled start time on **88.8 percent** of appointments (1028 of 1158).
- Average time on site: 122 minutes (median 99).

## The drift finding: the day starts late, it does not slip late

Lateness is NOT an accumulation effect that builds across the day. The first stop of the day is already about as late as every later stop:

| Stop in day (by scheduled order) | n | Mean delta (min) | Median delta (min) |
|---|---|---|---|
| Stop 1 | 479 | 77 | 71 |
| Stop 2 | 364 | 85 | 85 |
| Stop 3 | 211 | 84 | 83 |
| Stop 4 | 87 | 91 | 89 |
| Stop 5+ | 17 | 79 | 89 |

First stop on-time within 15 min: 5.4 percent. Later stops within 15 min: 7.8 percent.

The baseline offset (roughly 70 minutes at stop 1) dwarfs the within-day slippage (roughly 15 to 20 additional minutes by stop 4). The schedule itself is systematically optimistic about when the day begins, not just about how long stops take.

## Trend by year

| Year | n | Mean (min) | Median (min) |
|---|---|---|---|
| 2023 | 176 | 68 | 62 |
| 2024 | 403 | 78 | 76 |
| 2025 | 396 | 92 | 90 |
| 2026 | 183 | 81 | 78 |

Lateness worsened from 2023 to 2025 and improved slightly in 2026 to date.

## Day-of-week pattern

| Day | n | Mean (min) | Median (min) |
|---|---|---|---|
| Monday | 110 | 72 | 74 |
| Tuesday | 243 | 99 | 94 |
| Wednesday | 229 | 81 | 81 |
| Thursday | 181 | 65 | 55 |
| Friday | 251 | 88 | 89 |
| Saturday | 124 | 71 | 64 |
| Sunday | 20 | 71 | 68 |

Tuesdays and Fridays run latest; Thursdays run best.

## Best and worst stops by average delta (clients with 8 or more matched appointments)

Closest to schedule:

| Client | n | Mean (min) | Median (min) |
|---|---|---|---|
| Mary Jane Hunt | 43 | 29 | 29 |
| Lisa Prater | 10 | 37 | 38 |
| Garrett Little | 10 | 37 | 46 |
| Marilyn Jamison | 33 | 45 | 38 |
| Nancy Franklin | 33 | 46 | 48 |

Furthest behind schedule:

| Client | n | Mean (min) | Median (min) |
|---|---|---|---|
| Kevin Cummings | 25 | 107 | 102 |
| Robin Bennett | 28 | 112 | 104 |
| Ligia Amyotte | 15 | 128 | 104 |
| Brooksley Sheehe | 13 | 128 | 123 |
| Lisa Midgett | 54 | 137 | 136 |

Client position in the day confounds this: clients near the end of a route inherit the day's accumulated delay, and clients with long on-site times (Lisa Midgett, Ligia Amyotte) tend to sit later in the route.

## How this was derived

1. Source sheet: "Time is Money! " in Google Drive, file ID `1rxZ6WDOp2xJsb4dK4vBRFDqx2LQQiP3SAdjpwzdyDbU`, last modified 2026-06-11, exported as CSV. This is the live master; the Drive copies dated 3/9/26, 3/19/26, and the "Back up in case of catastrophe" sheet are stale duplicates and were not used. Columns used: Date, Client, Inbound Time (when Paul left for the stop), Arrival Time, Departure Time (when he finished).
2. Source calendar: Paul's primary Google Calendar (`nickerson.paul@gmail.com`, timezone America/New_York), 1,439 timed events pulled for 2023-07-27 through 2026-06-12. The dedicated "Dog Gone Clean" calendar exists but holds zero events; all appointments live on the primary calendar. The scheduled start is the calendar event start time (Acuity-created events embed the same time in their description, which confirms the reading).
3. Matching: same calendar date plus client name. Names were normalized (case, accents, punctuation) and matched exactly, by token subset (first or last name only), or by high-threshold fuzzy similarity (ratio at least 0.87) to absorb recurring spelling variants such as Donna Rodriguez/Rodriquez, Garrett/Garret Little, Jeanne Leuenberger variants, Mary Jane Hunt/Hurt. All fuzzy pairs were reviewed. Where one client had two same-day events, the event nearest the recorded arrival was used. Unmatched rows were left unmatched; nothing was guessed.
4. Deltas: arrival_delta_min = sheet Arrival Time minus calendar start, in minutes, positive means late. Eight sheet time cells lack an AM/PM marker; each was read as written unless the PM reading fit the schedule far better, and every such cell carries a note in the JSON. A guard excluded any delta beyond 6 hours from the statistics as ambiguous; no row actually tripped it (the largest real delta is 319 minutes). Three matched rows were excluded because the sheet has no arrival time for them.

## Data gaps

- **63 sheet rows have no calendar event** on that date for that client and are marked `matched: false` with null scheduled_start. Of these, 19 have a same-name event on the adjacent day (likely a sheet date typo or a moved appointment); these are noted per row but were NOT matched. The rest are most likely appointments booked without a calendar entry, or calendar events later deleted. Repeat offenders: Dottie Dimery and Sally Alderman appear several times without calendar events.
- **1 date typo:** the row "12:27/23 JoAnn Velas" was read as 2023-12-27 (noted in the row).
- **3 matched rows excluded from statistics** because the sheet records no arrival time for them: Tonya Hunt 2025-03-07, Kevin Cummings 2025-03-08, Hope Brooks 2026-05-16. They remain in the JSON marked matched with a note.
- **8 time cells across 7 rows lack an AM/PM marker.** The 3 matched rows where this touches the arrival time carry explicit notes in the JSON (all read as written; none needed the PM correction). The remaining ambiguous cells are left-at or finish cells, or sit on an unmatched row (Greta Custer 2025-12-09), and were resolved by within-row sequence (finish must follow arrival).
- The sheet does not record scheduled times itself, so any appointment Paul rescheduled on the fly will show the original calendar slot, and the computed delta then mixes lateness with rescheduling. The deltas here measure plan vs reality as the calendar planned it.
- Pre-launch caveat per CLAUDE.md does not apply: this is the real legacy Dog Gone Clean grooming history, not test data.
