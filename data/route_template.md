# DGC first zone-day route template (v1)

Built 2026-05-24 from `clients.json`. Covers the 33 standing clients. This is the
recurring weekly skeleton the scheduler repeats; each client recurs on their own cadence,
so any given week is a subset of the rows below.

**Design priority (from the book's reality):** time-of-day is the binding constraint, not
distance. A large share of the standing book is evening- or Saturday-locked, so each
weekday is themed around one geographic zone, daytime flex stops fill the zone, and the
day ends with that zone's evening-locked clients.

**Base:** home 3885 SW 114th Court 34481 (rural SW). Home is adjacent to the SW / On Top
of the World cluster (densest in the book), so SW is the launch/return cluster and no
separate anchor is invented. Chester Weber (by base, flexible day, fixed 12pm) is the
default first stop.

Legend: [H]=HARD window, [S]=soft pref, [F]=flex, time = target arrival, qN = every N days.

## Weekly skeleton

### Monday - SE daytime + SE evening (lighter day; holds gap-fills)
| Time | Client | Cadence | Why here |
|---|---|---|---|
| daytime | Harriet Woolf [S] | q28 | SE, weekdays |
| daytime | Mary Beth Anderson [F] | q28 | SE |
| daytime | Heather Albinson [F] | q42 | S Ocala (plus 3RM3+J29; confirm quadrant) |
| 6:00pm | Steve Crandall [H] | q28 | SE, weekday 6-7pm only |

Note: Amy Blessing cannot be booked Monday (or Friday). Monday's light load is the
landing spot for Tonya (big Williston day), Ligia gap-fills, and SE one-offs.

### Tuesday - SE midday + Cynthia (SW carve-out)
| Time | Client | Cadence | Why here |
|---|---|---|---|
| 12:00 | Lisa Irwin [H] | q14 (every OTHER Tue) | fixed 12pm every-other-Tuesday, SE |
| daytime | Donna DiPasqua [F] | q28 | SE, your Tuesday-route decision |
| daytime | Amy Blessing [H] | q28 | SE, Tue ok (not Mon/Fri) |
| 3:00pm | Cynthia Tieche [H] | q14 | your decision: Tuesday 3pm (SW) |

Note: Michelle Reiners is excluded Tuesdays, so no NE evening runs Tuesday.

### Wednesday - base + NW
| Time | Client | Cadence | Why here |
|---|---|---|---|
| 12:00 | Chester Weber [H] | q21 | by base, fixed 12pm first-slot |
| 4:00pm | Marilyn Jamison [H] | q28 | NW (Golden Ocala), ~4pm, husband WFH Wed |
| flex | SW/base overflow | - | absorbs SW flex to relieve Friday |

### Thursday - NW noon anchor + NE evening run
| Time | Client | Cadence | Why here |
|---|---|---|---|
| 12:00-3:00 | Mary Jane Hunt [H] | q14 | NW, Thu noon only; AWAY Jun-Nov |
| daytime | Linda Giza [F] | q84 | NE, attach when in the north |
| 5:00pm | Ginger Fink [H] | q28 | NE, after 5pm |
| 5:15pm+ | Michelle Reiners [H] | q28 | NE, after 5:15, not Tue |
| 5-6pm | Chloe Castellano [H] | q42 | NE, weekday 5 or 6pm |

Note: the NE evening trio (Ginger q28, Michelle q28, Chloe q42) is the single tightest
pinch. Three back-to-back evening grooms is the practical max. When all three land the
same Thursday, push Ginger or Chloe to Saturday (both ok weekends). Michelle has no
weekend option, so she anchors the Thursday slot. Jun-Nov the noon anchor is empty
(Mary Jane away) but the NE evening run still holds.

### Friday - SW day (densest)
| Time | Client | Cadence | Why here |
|---|---|---|---|
| ~10:00 | Barbara Lape [H] | q21 | SW gated club, daytime, gate before 6pm |
| ~11:00 | Debra Koerner [S] | q98 (bath) | SAME gated club + gate as Barbara |
| daytime | Ray Russell [F] | q28 | SW |
| daytime | Terri McDonnell [F] | q42 | SW (On Top of the World, use Waze) |
| daytime | Bradley Johnson [S] | q42 | SW, weekday daytime |
| daytime | Greta Custer [F] | q49 | Dunnellon, <10 min from base |
| daytime | Chris Votos / Erich / Jeanne / Patricia [F] | q56 each | SW, rotate by cadence |
| 5:30pm | Peter Moran [H] | q~8wk (pending) | SW, late afternoon/evening only |

Note: with home in the SW cluster, most SW flex lives here, but they are q21-q98, so a
typical Friday is ~4-5 stops (e.g. Barbara + Debra + one q42-56 + Peter evening). Spill
the rest to Wednesday and Saturday.

### Saturday - SW Saturday cluster + big stops
| Time | Client | Cadence | Why here |
|---|---|---|---|
| ~10:00 | Nancy Franklin [H] | q28 (nails) | SW 34474, neighbor cluster |
| ~10:20 | Lisa Prater [H] | q28 (mixed) | next to Nancy |
| ~10:40 | Patty Brown [H] | q28 (nails) | nearby (no sheet; rides this cluster) |
| midday | Hope Brooks [S] | q56 | SW-ish, prefers Saturday |
| half-day | Tonya Hunt [F] | q28 | Williston (~20 min W); $300-500, 3-5 hrs |
| flex | Kevin Cummings [F] | q? (pending) | SW, nails-focused |

## Per-client day assignment (all 33)

SW: Chester(Wed), Barbara(Fri), Debra Koerner(Fri), Ray(Fri), Terri(Fri),
Bradley(Fri), Greta(Fri), Chris Votos(Fri), Erich(Fri), Jeanne(Fri), Patricia(Fri),
Peter(Fri eve), Cynthia(Tue 3pm), Kevin(Sat), Tonya(Sat/Williston), Nancy(Sat),
Lisa Prater(Sat), Patty(Sat), Hope(Sat), Ligia(gap-fill).
SE: Lisa Irwin(Tue 12), Donna DiPasqua(Tue), Amy(Tue), Harriet(Mon), Mary Beth(Mon),
Steve(Mon 6pm), Heather(Mon, confirm quadrant).
NW: Marilyn(Wed 4pm), Mary Jane(Thu 12).
NE: Ginger(Thu 5pm), Michelle(Thu 5:15), Chloe(Thu 5-6), Linda Giza(Thu day).

## Gap-fill plan

- **Ligia Amyotte (FLEX+):** the no-confirmation, owner-absent, outside-dogs stop. Drop
  her into any open SW/base block, especially to backfill a same-day cancellation. She is
  a chunky stop (4 dogs, ~half day, $360), so she best fills a freed morning.
- **Chester Weber:** flexible day, fixed 12pm by base. Use his 12pm slot to anchor
  whichever day has the lightest start; nominally Wednesday.
- **Weekend pressure valve:** Ginger and Chloe accept weekends, so overflow them to
  Saturday when the Thursday NE evening run is full.

## Capacity / load notes

- Tightest pinch: Thursday NE evening trio (Ginger, Michelle, Chloe). See note above.
- Tuesday is split SE-midday + SW-mid-afternoon (Cynthia) by your standing decisions.
- Tonya is effectively a half-to-full day; do not stack other big stops with her.
- Friday is intentionally cadence-thinned; Wednesday absorbs SW overflow.

## Pending (do not finalize cadence/zone until Paul confirms)

- Kevin Cummings cadence (sheet is an empty stub; calendar ~6wk vs your note 4wk).
- Peter Moran cadence (sheet blank; your note ~8wk vs calendar ~12wk).
- Heather Albinson and Hope Brooks exact quadrant (resolve from plus codes).
- Patty Brown: no sheet; everything assumed from the Saturday neighbor cluster.
