# Legacy notification email templates (DRAFT)

Status: DRAFT, in review with Paul (2026-06-07). These are the legacy full-grooming
(doggoneclean.us, in-person payment) notification emails for the Acuity/Squarespace
teardown (`legacy_folds_into_v2`). They are adapted from DGN's
`supabase/functions/send-notification/index.ts` templates and Paul's existing Acuity copy.
When the Clean notification function is built (a port of DGN `send-notification` plus
`notifications-cron`, sender `service@doggoneclean.us`), these become its template bodies.

Not live: nothing sends until `service@doggoneclean.us` is a verified Resend sender and the
key is set. Reminders are EMAIL only (Acuity sent email only); SMS deferred.

## Standards applied
- Payment: in person. Cancellation uses `cancellation_24h` ("billed in full"), NOT the bath
  surface's "non-refundable" (`within_24h_non_refundable`).
- The appointment time is a "block" (`appointment_block_not_window`), expressed as a real span
  `{start_time} to {end_time}` (Acuity could only give start + duration; the new system has
  `scheduled_end`).
- Clarifier on every block mention: "The block is when the work gets done, not a wait-around
  arrival window."
- The old Acuity "breathing room / twists and turns" line is dropped: the span plus the
  clarifier plus the exact-ETA heads-up cover it without planting doubt.

## Open decisions (not yet locked)
- `lock_in_timing` says the ~26-hour reminder should read like a normal reminder, never a
  countdown, and that the 24-hour buffer is "never mentioned in the message itself." Paul's
  legacy 26-hour reminder has always stated the policy. OPEN: does `lock_in_timing` apply only
  to the bath surface, with legacy stating the policy, or does the cancellation line come out of
  the legacy 26-hour reminder too? The line is marked [OPEN] below.
- Cancellation tail: canon is third-person ("the slot is reserved for that client"); these
  emails use second-person ("that time is reserved just for you"). The "billed in full" phrase
  is verbatim either way.
- "wait-around arrival window" vs a softer "all-day window you have to wait through."
- Still to come from Paul: an on-my-way / ETA message and a follow-up / review-ask message.

## Merge fields
`{first}` `{last}` `{service_type}` `{service_address}` `{day}` `{date}` `{start_time}`
`{end_time}` `{new_day}` `{new_date}` `{new_start_time}` `{new_end_time}` `{portal}` `{eta}`

---

## Booking confirmation

Subject: You're booked for {day}, {date}

What: {service_type}
When: {day}, {date}, {start_time} to {end_time}
Where: {service_address}

Hi {first},

You're booked for {day}, {date}.

Your appointment block runs {start_time} to {end_time}. The block is when the work gets done,
not a wait-around arrival window. We usually get started within an hour of the opening and
finish before it ends, and we'll text your exact arrival time before we roll your way.

Inside the trailer, it's cool, dry, and comfortable no matter what Florida is doing outside.
Thunder at home is one thing. Once dogs are in with us, the weather fades into the background.

Payment is easy. We take cash, Visa, Mastercard, American Express, Discover, Apple Pay,
Google Pay, and Samsung Pay.

Once an appointment is within 24 hours, that time is reserved just for you. Appointments
canceled or rescheduled within 24 hours are billed in full.

Thank you,

Paul Nickerson
Dog Gone Clean
Mobile Dog Grooming
Ocala, Florida

---

## Reminder, 72 hours before

Subject: Heads up, your appointment is {day}, {date}

What: {service_type}
When: {day}, {date}, {start_time} to {end_time}
Where: {service_address}

Hi {first}!

Dog Gone Clean is on deck for {day}, {date}. Your block runs {start_time} to {end_time}. The
block is when the work gets done, not a wait-around arrival window. We usually get started
within an hour of the opening and finish before it ends.

Inside the trailer, it's cool, dry, and comfortable no matter what Florida is doing outside.
Thunder at home is one thing. Once dogs are in with us, the weather fades into the background.

We'll send a heads-up with your exact arrival time before we roll your way. You will know we
are coming.

We take cash, Visa, Mastercard, American Express, Discover, Apple Pay, Google Pay, and
Samsung Pay.

See you then,

Paul Nickerson
Dog Gone Clean
Mobile Dog Grooming
Ocala, Florida

---

## Reminder, 26 hours before

Subject: Tomorrow is the day

What: {service_type}
When: {day}, {date}, {start_time} to {end_time}
Where: {service_address}

{first},

Tomorrow is the day! Your {service_type} block runs {start_time} to {end_time}. The block is
when the work gets done, not a wait-around arrival window. We usually get started within an
hour of the opening and finish before it ends.

[OPEN, pending lock_in_timing decision] Appointments canceled or rescheduled within 24 hours
are billed in full; once inside 24 hours that time is reserved just for you.

We'll send you a reminder tomorrow, a few hours before the appointment, and as we get closer,
we'll do our best to keep you updated on our ETA.

Payment is easy. We take cash, Visa, Mastercard, American Express, Discover, Apple Pay,
Google Pay, and Samsung Pay.

Thank you,

Paul Nickerson
Dog Gone Clean
Mobile Dog Grooming
Ocala, Florida

---

## Reminder, 6 hours before (day of)

Subject: Today is the day

What: {service_type}
When: {day}, {date}, {start_time} to {end_time}
Where: {service_address}

Hi {first},

Today, the calm part of your dog's day runs {start_time} to {end_time}. The block is when we
complete the work, not a wait-around arrival window. We usually arrive within an hour of the
opening and finish before it ends.

Inside the trailer, it's cool, dry, and comfortable no matter what Florida is doing outside.
Thunder at home is one thing. Once dogs are in with us, the weather fades into the background.
We'll send a heads-up with your exact arrival time before we roll your way. You will know we
are coming.

See you soon!

Paul Nickerson
Dog Gone Clean
Mobile Dog Grooming
Ocala, Florida

---

## Cancellation

Subject: Your appointment is canceled

What: {service_type}
When: {day}, {date}, {start_time} to {end_time}
Where: {service_address}

Hi {first},

Your appointment for {day}, {date} is canceled, and that time is back open.

No hard feelings and no hassle. Whenever you're ready for the next one, we're a click away, and
the trailer will be cool, dry, and waiting.

Thank you,

Paul Nickerson
Dog Gone Clean
Mobile Dog Grooming
Ocala, Florida

---

## Reschedule

Subject: Your appointment is moved

What: {service_type}
When: {new_day}, {new_date}, {new_start_time} to {new_end_time}
Where: {service_address}

Hi {first},

You're moved. Dog Gone Clean is now on deck for {new_day}, {new_date}. Your block runs
{new_start_time} to {new_end_time}. The block is when the work gets done, not a wait-around
arrival window. We usually get started within an hour of the opening and finish before it ends.

We'll send a heads-up with your exact arrival time before we roll your way. You will know we
are coming.

We take cash, Visa, Mastercard, American Express, Discover, Apple Pay, Google Pay, and
Samsung Pay.

See you then,

Paul Nickerson
Dog Gone Clean
Mobile Dog Grooming
Ocala, Florida
