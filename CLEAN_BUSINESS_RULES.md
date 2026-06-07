# CLEAN_BUSINESS_RULES - enforcement index

The map of where each rule in `CLEAN_ORACLE.md` is enforced. The Oracle holds the rationale;
this file holds the map. A rule that lives in only one place is a rule waiting to be lost.

The target is four layers of defense, mirroring DGN: **Oracle (rationale) -> `business_rules`
DB row -> code mirror -> lint pattern.** Clean has no database or app yet, and per
`no_database_until_rules_agreed` the DB layer stays empty until the rules are locked, so
today the live layers are: the Oracle, the data files, the local check script
(`scripts/check.py`), and convention. The two right-hand columns fill in as the site is
built. This is normal: even DGN has many rules sitting in only one or two layers.

| Rule | Oracle domain | Enforced today | Deferred layer (when built) |
|------|---------------|----------------|------------------------------|
| redesign_survival_is_a_ship_gate | Process | CLAUDE.md "Ship gate"; Oracle; **`check.py`** tiered audit (durable-layer misses BLOCK, copy reminders WARN); SessionStart + pre-commit + CI | `business_rules` row |
| recommendation_with_reason | Process | CLAUDE.md; convention | `business_rules` row |
| outcomes_not_actions | Process | CLAUDE.md; convention | `business_rules` row |
| no_mockups | Process | CLAUDE.md; convention | `business_rules` row |
| do_the_work | Process | CLAUDE.md; convention | `business_rules` row |
| read_before_redesign | Process | CLAUDE.md; Scroll header mandate; redesign checklist (run `check.py` + walk this index) | `business_rules` row |
| elons_algorithm | Process | CLAUDE.md "How Paul works"; Oracle | `business_rules` row |
| dig_the_moat | Process | CLAUDE.md "How Paul works"; Oracle | `business_rules` row |
| ship_to_completion | Process | CLAUDE.md "Shipping" | `business_rules` row |
| no_pr_activity_subscription_nudge | Process | CLAUDE.md "Shipping" | `business_rules` row |
| verify_the_change_before_done | Process | CLAUDE.md "Stack and commands"; session-start orient footer; convention | `business_rules` row |
| recovery_from_a_bad_session | Process | CLAUDE.md "How Paul works"; Oracle; convention | `business_rules` row |
| ci_workflows_capped_and_validated | Engineering | `.github/workflows/*.yml` (every job declares timeout-minutes); convention | `check.py` lint that scans workflows for the timeout setting |
| transient_ci_rerun_first | Engineering | CLAUDE.md "Stack and commands"; Oracle; convention | `business_rules` row |
| no_merge_across_repos | Process | CLAUDE.md "Repo separation" | n/a |
| persistent_status_update | Process | Oracle; convention | `business_rules` row |
| dates_use_local_eastern | Process | Oracle; Scroll header mandate; CLAUDE.md | `business_rules` row |
| lock_it_in_capture | Process | CLAUDE.md; Scroll header mandate; Oracle | `business_rules` row |
| clean_stays_saleable | Build | CLAUDE.md "Hard constraints"; Oracle | n/a (guardrail, not feature) |
| no_database_until_rules_agreed | Build | CLAUDE.md "Hard constraints"; Oracle | lifts once rules agreed |
| own_infrastructure | Build | CLAUDE.md "Hard constraints" | infra config |
| reuse_dgn_stack | Build | CLAUDE.md "Stack"; Oracle | `package.json`, deploy workflow |
| build_gate | Build | Oracle; **CI deploy gate live (2026-05-29)**: `deploy.yml` `deploy` job `needs` an `audit` job running `scripts/check.py`, so a push to `main` that fails the audit never publishes | local `npm run build` (lint + smoke) chain still to build |
| classify_by_frequency | Roster | `legacy/data/clients.json` `status`; `legacy/data/README.md` | `business_rules` row |
| active_set | Roster | `legacy/data/clients.json` scope; `check.py` (count=33) | `business_rules` row |
| banned_excluded | Roster | `legacy/data/clients.json` `exclude_from_everything`; **`check.py`** (record flag + absent from route) | `business_rules` row |
| toes_over_the_precipice | Roster | Oracle; convention (runtime judgment call at the moment of the incident) | client-status flag (`ended_for_cause`) when the operator app has a client-management surface |
| one_off_not_routed | Roster | `legacy/data/clients.json` `routed:false`; `legacy/data/route_template.md`; **`check.py`** (absent from route) | route-generation code |
| no_doodles | Roster | Oracle; convention | intake/booking gate; `business_rules` row |
| real_data_only | Data | `legacy/data/clients.json` `data_gaps[]`; convention | n/a |
| sheets_are_truth | Data | `legacy/data/sources.md`; CLAUDE.md | n/a |
| newest_doc | Data | `legacy/data/sources.md` (corrected IDs + caveat); CLAUDE.md | sheet-resolver code |
| reality_wins | Data | Scroll header mandate; convention | n/a |
| service_type_required | Data | `legacy/data/clients.json` `service_type`; **`check.py`** | DB not-null; `src/business/` |
| data_gap_explicit | Data | `legacy/data/clients.json` `data_gaps[]`; **`check.py`** | n/a |
| cadence_conflict_leans_sheet | Scheduling | `legacy/data/clients.json` `cadence_confidence`/`cadence_note`; **`check.py`** (valid confidence) | `business_rules` row |
| hardness_respected | Scheduling | `legacy/data/clients.json` `hardness`/`availability`; `legacy/data/route_template.md`; **`check.py`** (valid tag) | scheduling engine |
| time_is_the_constraint | Scheduling | `legacy/data/route_template.md` design note | scheduling engine |
| use_the_smart_scheduler_from_day_one | Scheduling | Oracle | scheduling engine (String of Pearls fork); v2.0 booking surface |
| base_is_home_sw | Routing | `legacy/data/clients.json` `_meta`; `legacy/data/route_template.md` | drive-time code |
| realistic_daily_load | Routing | `legacy/data/route_template.md` capacity notes | scheduling engine |
| the_slot_is_the_clients | Scheduling | Oracle; `legacy/data/route_template.md` | booking engine |
| protect_the_operator | Scheduling | Oracle | scheduling engine constants |
| income_target_caps_the_day | Scheduling | Oracle | scheduling engine constants |
| heads_up_on_the_way | Scheduling | Oracle | pizza tracker; notifications code |
| lock_in_timing | Scheduling | Oracle | scheduling engine; notifications code |
| gated_community_hours | Routing | Oracle; `legacy/data/clients.json` access notes | scheduling engine |
| bills_in_person_today | Money | Oracle; `legacy/data/clients.json` (per-dog prices) | n/a |
| legacy_folds_into_v2 | Clean app: architecture | Oracle; one generalized service-relationship model carries bath, grooming, and nails; doggoneclean.us redirects into the app, Squarespace + Acuity retired; legacy stays in-person Square (card-on-file deferred); Acuity reminders rebuilt on n8n before cutover. | migration 0018: bath_subscriptions + bath_appointments carry service_type (full_groom/bath/nails) + payment_method (stripe_card/square_in_person) + visit/duration minutes + is_recurring + cadence_days; bath_subscribers.client_id links the legacy CRM record. Migration 0019 adds clients.visit_minutes (+ confidence), each client's on-site block time seeded from cycle history (legacy/data/block_times.json); legacy book loaded into clients/dogs (52 clients, 51 with block times). RPC generalization (bath_start_subscription must pass service_type/duration/payment_method), legacy login, reminder job, opening Ocala, and the bath_ table rename still pending. Migration 0021 makes the slot engine (bath_open_slots) duration-aware: a 4th p_duration_minutes arg reserves each client's block on a 15-minute grid, falling back to the city slot for bath; a gist no-overlap exclusion constraint replaces the unique-on-start index. |
| confirmations_and_reminders_via_supabase | Clean: architecture | Oracle; planned as a Supabase scheduled edge function (pg_cron + SMS/email providers), mirroring DGN `send-notification` with Clean's own instances; n8n deferred to later automation | (pending build: Clean send-notification edge fn + cron) |
| if_payments_added_handle_money_safely | Money | Oracle (deferred) | pricing code; webhook fn |
| grooming_vocab | Copy | CLAUDE.md; **`check.py`** (dog-qualified, over `src/`) | lint allowlist |
| specialist_named_not_promised | Copy | Oracle; **`check.py`** asserts `class="specialist-card"` present + forbids "always Paul" / "will be Paul" / "only Paul" on the city page | additional lint patterns when more operators join (per-name) |
| specialist_assigned_per_route | Scheduling | Oracle | `routes.operator_id`; booking step 1 polygon-check response includes `route_operator` (name + photo URL); portal "your specialist" section reads the same join |
| cancellation_24h | Money | Oracle | booking engine; site copy |
| favor_high_hourly_work | Money | Oracle; convention | `business_rules` row |
| accepted_payment_methods | Money | Oracle; convention | site copy; lint pattern |
| house_shampoo | Service | Oracle; convention | site copy; intake form |
| online_only_comms | Process | Oracle; convention | site copy; intake; `business_rules` row |
| friendly_dogs_only | Safety | Oracle; site copy; **`check.py`** asserts "friendly dogs" + "aggression" present on `index.astro`, `the-villages.astro`, and `BookingApp.jsx` (the booking gate) | intake gate |
| core_is_no_haircut_dogs | Roster | Oracle; site copy; **`check.py`** asserts "bath only" present on `the-villages.astro`, `process.astro`, and `BookingApp.jsx` | intake gate |
| service_area_ocala | Routing | Oracle; `legacy/data/` | scheduling engine; intake address check |
| no_dgn_import | Copy | CLAUDE.md; "Repo separation"; **`check.py`** forbids "rotary tool" / "sculpt nails" / "grind nails" on customer-facing pages | n/a |
| no_em_dashes | Copy | CLAUDE.md; **`check.py`** | `lint-business-rules` em_dash |
| no_jargon | Copy | CLAUDE.md; **`check.py`** forbids "reach out", "circle back", "bandwidth", "free up the slot" on customer-facing pages | n/a |
| device_profile | Copy | CLAUDE.md "How Paul works" | n/a |
| neural_expressive_design | Design | CLAUDE.md "Design language"; Oracle; design tokens in `src/styles/global.css`; **`check.py`** asserts `--accent`, `--accent2`, `--ink`, `--bg` tokens present in `global.css` | restyle lint that asserts token *values* unchanged (the present lint only asserts presence) |
| website_is_ground_zero | Copy | Oracle; convention | build copy check |
| reminder_voice | Copy | Oracle; **`check.py`** forbids "friendly reminder", "just a reminder", "reaching out", "please be advised", "last chance", "make changes now" on customer-facing pages (arrival window already covered by appointment_block_not_window) | n/a |
| post_appointment_show_someone_nudge | Copy | Oracle; convention (Paul's manual MMS send today off Google Voice) | post-appointment notification template when Twilio MMS lands; `/share/[token]` share page when photo pipeline lands (parked in CLEAN_PARKING_LOT.md); `check.py` lint forbidding "@doggoneclean" / "tag us" / "tag @" in post-appointment template + share-page copy once those surfaces exist |
| dont_knock_competitors | Copy | Oracle; convention | lint pattern |
| appointment_block_not_window | Copy | Oracle; **`check.py`** forbids "arrival window" anywhere in `src/pages/index.astro`, `the-villages.astro`, `process.astro` | n/a |
| language_bank | Copy | Oracle; site copy; **`check.py`** asserts "belongs to the process" present on `process.astro` | additional banked-line presence checks as the bank grows |
| no_trailer_graphics | Copy | Oracle | n/a (real-world) |
| show_dont_tell | Copy | Oracle; site structure (the "See it work" video block sits above the intro on `process.astro`); convention | footage shot-list parked in CLEAN_PARKING_LOT.md; `check.py` lint asserting the video block precedes the intro on `process.astro` once the layout settles |
| maps_js_api_only | Engineering | Oracle (carried) | code + lint when site exists |
| service_area_enforced_server_side | Engineering | Oracle; DB `_bath_point_in_area` + `bath_start_subscription` hard-rejects coordinate-less and out-of-area (migration 0009); `BookingApp.jsx` autocomplete-only gate, no manual path; **`check.py`** bans manual-entry copy in the booking island | charge job still honors `address_verified` as a guard |
| supabase_rpc_not_raw_fetch | Engineering | Oracle (carried); **`check.py`** forbids `fetch(...SUPABASE_URL...)` pattern in `src/components/portal/` (catches raw REST without flagging legitimate edge-function calls) | n/a |
| auth_listener_sets_state_only | Engineering | Oracle (carried); **`check.py`** scans `onAuthStateChange((...))` blocks in `src/components/portal/` and forbids `.from(`, `.rpc(`, `await fetch(`, `loadPortalData(` inside them | n/a |
| nav_no_backdrop_filter | Engineering | Oracle (carried); **`check.py`** forbids "backdrop-filter" anywhere in `src/components/Nav.astro` | n/a |
| overlay_opacity_pairs_pointer_events | Engineering | Oracle (carried) | component CSS |
| smoke_test_on_every_build | Engineering | Oracle (carried) | `scripts/smoke-build.mjs` |
| offline_first_field_app | Engineering | Oracle (carried) | field-app code |
| bath_only_no_mats | Hurricane Bath: product | Oracle; DB `bath_dogs.coat_tier` CHECK; **`check.py`** asserts "Smoothcoat" + "Doublecoat" tier names + "we bath" / "we do not bath" eligibility headers on `the-villages.astro`, and the two tier names on `BookingApp.jsx` (the booking coat picker) | `src/data/breeds.json` (mixed-breed eligibility); booking-flow gating |
| villages_only_at_launch | Hurricane Bath: product | Oracle; DB `bath_start_subscription` rejects coordinate-less and out-of-area via `_bath_point_in_area` (authoritative, migration 0009); client `maps.js` `isInServiceArea` as UX. Updated 2026-06-07: Ocala added as the pivot-origin city (`ocala_is_a_served_city`), no longer Villages-only. | (none) |
| ocala_is_a_served_city | Clean: service area | Oracle; DB `cities` row slug 'ocala' (added 2026-06-07, hb_active false pending polygon/pricing/slot minutes); home of the legacy book | `cities` table (Supabase) |
| new_ocala_clients_are_v2_only | Clean: product | Oracle; public booking funnel offers bath only; `bath_start_subscription` defaults service_type 'bath'; legacy groom/nails set only by admin load | booking funnel + `bath_start_subscription` (hardened as the funnel/RPC generalization lands) |
| ocala_service_area_by_anchor | Clean: service area | Oracle; schema `clients.is_anchor` + `bath_subscribers.is_anchor` + `clients.geo_lat/geo_lng` (migration 0020; 31 legacy anchors set, Tonya/Greta excluded); live drive-time gate (Distance Matrix on the Maps key) + one-time anchor geocode pending | `clients.is_anchor` / `bath_subscribers.is_anchor` (Supabase); gate logic pending |
| bath_starting_durations | Clean: scheduling | Oracle; `cities.hb_smoothcoat_minutes` (30) + `hb_doublecoat_minutes` (60) set on The Villages and Ocala (migration 0022) | `cities` table (Supabase) |
| minimum_stop_block | Clean: scheduling | Oracle; `cities.hb_min_stop_minutes` (30, migration 0022); reserved duration = greatest(client/tier minutes, floor) | `cities.hb_min_stop_minutes` (enforced in the duration calc when the booking RPC is generalized) |
| ocala_prices_match_villages | Clean: pricing | Oracle; Ocala `cities` row copies The Villages bath cents (all tiers + decrement + founders) | `cities` table (Supabase) |
| schedule_by_client_history | Clean: scheduling | Oracle; per-client time = `clients.visit_minutes` (Supabase, seeded from Time is Money on-site times); cold-start default = nails 15/25/40 by dog count + bath 30/60 (`cities.hb_*_minutes`), floored by `minimum_stop_block` | `clients.visit_minutes` + `cities.hb_*_minutes` (Supabase); applied in the duration calc when the booking RPC is generalized |
| villages_only_in_copy | Hurricane Bath: copy | Oracle; **`check.py`** forbids "Ocala", "Fernandina", "St. Simons", "Saint Simons" in customer-facing markup on `index.astro`, `the-villages.astro`, `process.astro` (frontmatter + HTML comments stripped before check) | n/a |
| three_dog_cap | Hurricane Bath: product | Oracle; cap lifted 2026-06-07 (migration 0017). DB `bath_appointments.dog_count` CHECK is now `>= 1` (no upper bound); `bath_start_subscription` requires >= 1 dog; pack trigger removed; booking form and portal allow any count. Pricing is per dog (decrement per additional). | n/a |
| premium_inclusive_no_addons | Hurricane Bath: product | Oracle; **`check.py`** asserts "no add ons" present on `the-villages.astro` and bans priced add-ons / "+ $N" upcharges in `BookingApp.jsx` | absence of add-on UI in portal |
| breed_tier_pricing | Hurricane Bath: pricing | Oracle; `src/data/breeds.json` (Phase 4) | `src/business/pricing.js`; DB `subscriptions.base_price_cents` + `additional_dog_cents`; `business_rules` row |
| cadence_4wk_or_2wk_same_price | Hurricane Bath: pricing | Oracle; **`check.py`** asserts "same price" present on `index.astro` (the 2-week cadence is freshness, not a different rate) | booking step 2 cadence picker; `src/business/pricing.js` quoter |
| single_oneoff_higher | Hurricane Bath: pricing | Oracle | `src/business/pricing.js` Reset rate = Maintenance + $20 first dog |
| tiered_founders_rate | Hurricane Bath: pricing | Oracle | `?founders=1` URL handling; `subscriptions.founders_locked_until`; `src/business/pricing.js` |
| card_on_file_at_signup | Hurricane Bath: money | Oracle; DB `bath_subscriptions.stripe_payment_method_id`; **`check.py`** asserts "card on file" present on `the-villages.astro`, `book.astro`, `terms.astro` | `create-setup-intent` edge function; booking step 4 Stripe Elements |
| auto_charge_at_24h | Hurricane Bath: money | Oracle; **`check.py`** asserts "the day before" customer-facing promise present on `the-villages.astro`, `book.astro`, `terms.astro` | `charge-appointment` edge function (hourly cron); query ceiling `scheduled_start <= NOW() + 24h`; lint pattern banning earlier charge windows in cron query |
| card_expiry_60_30_7 | Hurricane Bath: money | Oracle | `card-expiry-alert` cron; portal banner component; `stripe-webhook` `payment_method.updated` handler |
| within_24h_non_refundable | Hurricane Bath: money | Oracle; **`check.py`** asserts "24 hour" present on `the-villages.astro` + `terms.astro`, and "non-refundable" present on `terms.astro` | portal cancel/skip button visibility; `portal_cancel_subscription` + `portal_skip_appointment` RPC guards; payment row preserved on cancel |
| no_show_pause_at_two | Hurricane Bath: money | Oracle | `subscriptions.consecutive_no_shows` counter; auto-pause trigger; portal reactivation flow |
| one_free_skip_per_52w | Hurricane Bath: skip | Oracle | `subscriptions.last_skip_at`; `portal_skip_appointment` RPC; skip counter in portal |
| free_skip_keeps_maintenance_rate | Hurricane Bath: skip | Oracle | `portal_skip_appointment` next-appointment pricing branch; portal copy "This is your free skip" |
| paid_skip_resets_next_visit_to_single_rate | Hurricane Bath: skip | Oracle | `portal_skip_appointment` paid branch; `subscriptions.last_skip_priced_at`; next-appointment `amount_cents` set to Reset rate |
| five_week_grace_returns_to_maintenance | Hurricane Bath: skip | Oracle | pricing function gap check (skipped -> next visit <= 35d => Maintenance); never surfaced in client copy |
| reschedule_step_up_weekly | Hurricane Bath: reschedule | Oracle | `src/business/pricing.js` reschedule quoter (curve keyed on days from original); `portal_reschedule_appointment` RPC; calendar price preview |
| reschedule_two_paths_for_recurring | Hurricane Bath: reschedule | Oracle | portal reschedule UI two-button choice; `portal_reschedule_appointment` `change_cadence` param; subscription cadence update branch |
| no_reason_field_ever | Hurricane Bath: ux | Oracle | absence of reason textbox/dropdown in skip + reschedule + cancel flows; lint pattern banning `cancel_reason` / `skip_reason` form fields in portal code |
| stop_sign_two_taps | Hurricane Bath: ux | Oracle; **`check.py`** asserts "two taps" present on `index.astro`, `the-villages.astro`, `book.astro`, `terms.astro`, and `src/components/portal/PortalApp.jsx` (the four-surfaces requirement from the Oracle) | portal cancel flow (2-tap with cascade preview) when the cancel RPC lands |
| octane_selector_cadence_picker | Hurricane Bath: ux | Oracle; `BookingApp.jsx` Step 2 (3 cadence options + "Want your dog fresher?" framing); **`check.py`** asserts the locked copy + all 3 cadence options on the booking island | smoke test asserts component renders all 3 options |
| calendar_shows_price_per_date | Hurricane Bath: ux | Oracle | portal reschedule + skip-pick calendar component (per-date price label); `src/business/pricing.js` quote-per-date helper |
| founders_spots_remaining_counter | Hurricane Bath: ux | Oracle; `/the-villages` page `#launch-spot-count` element (hidden above threshold, fed by public read on counted subscriptions); **`check.py`** asserts `id="launch-spot-count"` present on `the-villages.astro` | threshold constant in `src/business/pricing.js`; counter JS wires up when `bath_subscriptions` is being written to |
| founders_cap_statement_always_visible | Hurricane Bath: ux | Oracle; `/the-villages` launch card eyebrow + headline + subhead + terms-grid tile (cap stated four places, always visible, independent of the counter element); **`check.py`** asserts "households" appears 2+ times in customer-facing copy on `the-villages.astro` | n/a |
| video_audio_only_when_visible | UX | Oracle; inline script on `process.astro` (muted-autoplay markup + tap-to-unmute, one-at-a-time, IntersectionObserver mute on scroll-away, visibilitychange mute on tab-hide) | shared helper or lint once a second video page exists |
| single_visit_as_own_path | Hurricane Bath: ux | Oracle; `/the-villages` "Other ways in" section (single-visit card with its own CTA `/book?plan=single`, alongside standard recurring); **`check.py`** asserts `/book?plan=single` CTA href present on `the-villages.astro` | booking-flow plan picker (top-level choice before card entry) |
| string_of_pearls_is_a_service | Hurricane Bath: engineering | Oracle | `get-available-slots` / `create-booking` / `reschedule-appointment` / `skip-appointment` / `stop-subscription` CORS-locked edge functions; `/schedule-widget` iframe route; service-type query param |

## How to add a row

1. Add the entry to `CLEAN_ORACLE.md` with a real because.
2. Add what enforcement exists today (a `legacy/data/clients.json` field, a `scripts/check.py` check, or
   convention) to the "Enforced today" column.
3. DB rows are deferred until the rules are agreed and a database exists
   (`no_database_until_rules_agreed`). Do not add a `business_rules` migration yet.
4. When the site is scaffolded, add the code mirror and/or lint pattern and move it left.

The columns are layers of defense. A rule in all of them survives any rewrite; a rule in one
survives only as long as that one place stays intact.
