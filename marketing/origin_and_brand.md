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

## Homepage hero and taglines

The current homepage hero and brand taglines, strong and worth keeping:
- Hero: "Grooming. No Chaos." with "Dogs are the reason. The system is how we do it right."
- Tagline trio: "Structured. Reliable. Personal."
- "Calm handling. Clear communication. Clean dogs."
- "Comfort is engineered."
- Owner's statement signs as: Paul Nickerson, Owner, Dog Gone Clean.

The brand hero is "Grooming. No Chaos."; the product hero is the Hurricane Bath. They coexist on
the site.

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

Service at your doorstep and the mobile model:
- "We bring the entire grooming system to your driveway."
- "Our mobile unit carries its own water, power, and climate control. We park at your home,
  complete the groom, and send arrival notifications along the way."
- "No driving across town. No sitting in a lobby. No disruption to your day. You stay home. Your
  dog gets focused care. The route keeps moving."
- "Every appointment runs on a structured system built over two decades."
- "We groom one household at a time. No cages. No assembly line. No crowded lobby."
- "The process is deliberate. The workflow is repeatable. The results are consistent."

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
- **Payment (RESOLVED 2026-05-24).** Public list is the journal's: cash plus Visa, Mastercard,
  Amex, Discover, Apple Pay, Google Pay, Samsung Pay, all through Square. No checks. PayPal and
  Cash App exist but are not advertised. Drop the live site's PayPal mention on rebuild;
  `accepted_payment_methods`, `bills_in_person_today`, and CLAUDE.md are updated to match.

## Real policies captured from these pages

Now held as Oracle rules: online-only communication (`online_only_comms`), friendly-dogs-only
safety boundary (`friendly_dogs_only`), no-haircut specialization (`core_is_no_haircut_dogs`), and
the Ocala service area with exclusions (`service_area_ocala`). Pack grooming (dogs that live
together are groomed together unless there is a reason not to) is in CLEAN_FIELD_MANUAL.md.
