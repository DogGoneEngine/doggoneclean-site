# Origin and brand - source copy and voice (from the live site)

**What this is.** The real origin story and brand voice from the current site (www.DogGoneClean.us),
captured 2026-05-24 from Paul because this environment cannot reach the live site (its host is not
on the network allowlist). Authentic source material for the rebuild, in Paul's own words
(`real_data_only`).

---

## Origin story (the About / front-page block)

> Meet Paul Nickerson
>
> Paul did not fall into this business by accident. He chose dogs.
>
> He wanted to build his life around working with them. So he trained at the Florida Institute of
> Animal Arts and built Dog Gone Clean from the ground up in Ocala, Florida.
>
> What started as one trailer and one decision became a focused mobile dog grooming service built
> on calm handling and full attention.
>
> The system came later. The dogs came first.

Keep this close to as-is for the rebuild's About. It is authentic and un-promptable.

## Brand voice (keep this)

The live "How We Operate" page nails the DGC voice: functional, plainspoken, system-first, no
fluff. Anchor lines:

- "Not a spa. Not a salon. A structured mobile dog grooming system built for calm dogs and
  consistent results."
- "The dogs came first. The system came second." / "The system came later. The dogs came first."
- "Built for Function." / "Built for performance. Designed for dogs."
- "Hot and humid. Cold and rainy. Doesn't matter."
- "You will know we are coming."

## Existing copy worth keeping (the rebuild can lift these)

Climate, power, drying:
- "Oversized generators power true climate control."
- "Air conditioning and heat are supported by a dedicated dehumidifier that maintains humidity
  around 30 percent regardless of what Florida is doing outside."
- "Powerful vacuums contain loose coat. High-output dryers move moisture efficiently so dogs can
  get back to their day."

Hurricane Bath (existing, already moat-safe, no build revealed):
- "A recirculating bathing system we call the Hurricane Bath."
- "...continuously circulates a shampoo and water mixture through the coat at strong, steady flow."
- "The movement lifts dirt, debris, and loose undercoat from deep within the coat while using less
  total water than traditional hand washing."
- "A controlled storm that leaves the coat refreshed and balanced."
- "It is controlled. It is efficient. It is thorough."

## Reconciliation notes (live site vs locked rules)

The live site predates several locked decisions. On rebuild, apply the rules:
- "Arrival windows" becomes "block" (`appointment_block_not_window`).
- "Same-day cancellations are billed 100%" becomes "Appointments canceled or rescheduled within 24
  hours are billed in full" (`cancellation_24h`).
- "Most mobile grooming units rely on RV-style water pumps. They trickle. We don't." drops the
  knock, keeps "water flow similar to city water" (`dont_knock_competitors`).
- **Payment line conflict (OPEN, needs Paul).** The live site says "Cash, Credit Cards, and
  PayPal. NO CHECKS!" This conflicts with the journal's list (cash, the card networks, Apple/
  Google/Samsung Pay) and with CLAUDE.md / `bills_in_person_today` (which says checks are
  accepted). Resolve before the rebuild and update `accepted_payment_methods`. See Scroll open
  questions.

## Real policies captured from these pages

Now held as Oracle rules: online-only communication (`online_only_comms`), friendly-dogs-only
safety boundary (`friendly_dogs_only`), no-haircut specialization (`core_is_no_haircut_dogs`), and
the Ocala service area with exclusions (`service_area_ocala`). Pack grooming (dogs that live
together are groomed together unless there is a reason not to) is in CLEAN_FIELD_MANUAL.md.
