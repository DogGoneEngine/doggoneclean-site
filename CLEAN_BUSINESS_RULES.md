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
| recommendation_with_reason | Process | CLAUDE.md; convention | `business_rules` row |
| outcomes_not_actions | Process | CLAUDE.md; convention | `business_rules` row |
| no_mockups | Process | CLAUDE.md; convention | `business_rules` row |
| do_the_work | Process | CLAUDE.md; convention | `business_rules` row |
| read_before_redesign | Process | CLAUDE.md; Scroll header mandate; redesign checklist (run `check.py` + walk this index) | `business_rules` row |
| ship_to_completion | Process | CLAUDE.md "Shipping" | `business_rules` row |
| no_pr_activity_subscription_nudge | Process | CLAUDE.md "Shipping" | `business_rules` row |
| no_merge_across_repos | Process | CLAUDE.md "Repo separation" | n/a |
| no_database_until_rules_agreed | Build | CLAUDE.md "Hard constraints"; Oracle | lifts once rules agreed |
| own_infrastructure | Build | CLAUDE.md "Hard constraints" | infra config |
| reuse_dgn_stack | Build | CLAUDE.md "Stack"; Oracle | `package.json`, deploy workflow |
| build_gate | Build | Oracle (planned) | `npm run build` (lint + smoke) |
| classify_by_frequency | Roster | `clients.json` `status`; `data/README.md` | `business_rules` row |
| active_set | Roster | `clients.json` scope; `check.py` (count=33) | `business_rules` row |
| banned_excluded | Roster | `clients.json` `exclude_from_everything`; **`check.py`** (record flag + absent from route) | `business_rules` row |
| one_off_not_routed | Roster | `clients.json` `routed:false`; `route_template.md`; **`check.py`** (absent from route) | route-generation code |
| real_data_only | Data | `clients.json` `data_gaps[]`; convention | n/a |
| sheets_are_truth | Data | `data/sources.md`; CLAUDE.md | n/a |
| newest_doc | Data | `data/sources.md` (corrected IDs + caveat); CLAUDE.md | sheet-resolver code |
| reality_wins | Data | Scroll header mandate; convention | n/a |
| service_type_required | Data | `clients.json` `service_type`; **`check.py`** | DB not-null; `src/business/` |
| data_gap_explicit | Data | `clients.json` `data_gaps[]`; **`check.py`** | n/a |
| cadence_conflict_leans_sheet | Scheduling | `clients.json` `cadence_confidence`/`cadence_note`; **`check.py`** (valid confidence) | `business_rules` row |
| hardness_respected | Scheduling | `clients.json` `hardness`/`availability`; `route_template.md`; **`check.py`** (valid tag) | scheduling engine |
| time_is_the_constraint | Scheduling | `route_template.md` design note | scheduling engine |
| base_is_home_sw | Routing | `clients.json` `_meta`; `route_template.md` | drive-time code |
| realistic_daily_load | Routing | `route_template.md` capacity notes | scheduling engine |
| the_slot_is_the_clients | Scheduling | Oracle; `route_template.md` | booking engine |
| protect_the_operator | Scheduling | Oracle | scheduling engine constants |
| bills_in_person_today | Money | Oracle; `clients.json` (per-dog prices) | n/a |
| if_payments_added_handle_money_safely | Money | Oracle (deferred) | pricing code; webhook fn |
| grooming_vocab | Copy | CLAUDE.md; convention | lint allowlist |
| no_dgn_import | Copy | CLAUDE.md; "Repo separation" | lint pattern |
| no_em_dashes | Copy | CLAUDE.md; **`check.py`** | `lint-business-rules` em_dash |
| no_jargon | Copy | CLAUDE.md; convention | lint pattern |
| device_profile | Copy | CLAUDE.md "How Paul works" | n/a |
| maps_js_api_only | Engineering | Oracle (carried) | code + lint when site exists |
| supabase_rpc_not_raw_fetch | Engineering | Oracle (carried) | code + `raw_fetch` lint |
| auth_listener_sets_state_only | Engineering | Oracle (carried) | portal code |
| nav_no_backdrop_filter | Engineering | Oracle (carried) | `backdrop_filter_on_nav` lint |
| overlay_opacity_pairs_pointer_events | Engineering | Oracle (carried) | component CSS |
| smoke_test_on_every_build | Engineering | Oracle (carried) | `scripts/smoke-build.mjs` |
| offline_first_field_app | Engineering | Oracle (carried) | field-app code |
| bath_only_no_mats | Hurricane Bath: product | Oracle | `src/data/breeds.json`; booking-flow gating; lint pattern for accepted-breed list |
| villages_only_at_launch | Hurricane Bath: product | Oracle | booking step 1 polygon check; `villages` zone config |
| three_dog_cap | Hurricane Bath: product | Oracle | booking flow dog-count limit; `src/business/pricing.js`; DB constraint on `appointments.dog_count` |
| premium_inclusive_no_addons | Hurricane Bath: product | Oracle | absence of add-on UI in booking + portal; lint pattern banning add-on / upsell copy |
| breed_tier_pricing | Hurricane Bath: pricing | Oracle; `src/data/breeds.json` (Phase 4) | `src/business/pricing.js`; DB `subscriptions.base_price_cents` + `additional_dog_cents`; `business_rules` row |
| cadence_4wk_or_2wk_same_price | Hurricane Bath: pricing | Oracle | booking step 2 cadence picker; `src/business/pricing.js` quoter |
| single_oneoff_higher | Hurricane Bath: pricing | Oracle | `src/business/pricing.js` Reset rate = Maintenance + $20 first dog |
| tiered_founders_rate | Hurricane Bath: pricing | Oracle | `?founders=1` URL handling; `subscriptions.founders_locked_until`; `src/business/pricing.js` |
| card_on_file_at_signup | Hurricane Bath: money | Oracle | `create-setup-intent` edge function; booking step 4 Stripe Elements; DB `subscriptions.stripe_payment_method_id` not-null |
| auto_charge_at_24h | Hurricane Bath: money | Oracle | `charge-appointment` edge function (hourly cron); query ceiling `scheduled_start <= NOW() + 24h`; lint pattern banning earlier charge windows |
| card_expiry_60_30_7 | Hurricane Bath: money | Oracle | `card-expiry-alert` cron; portal banner component; `stripe-webhook` `payment_method.updated` handler |
| within_24h_non_refundable | Hurricane Bath: money | Oracle | portal cancel/skip button visibility; `portal_cancel_subscription` + `portal_skip_appointment` RPC guards; payment row preserved on cancel |
| no_show_pause_at_two | Hurricane Bath: money | Oracle | `subscriptions.consecutive_no_shows` counter; auto-pause trigger; portal reactivation flow |
| one_free_skip_per_52w | Hurricane Bath: skip | Oracle | `subscriptions.last_skip_at`; `portal_skip_appointment` RPC; skip counter in portal |
| free_skip_keeps_maintenance_rate | Hurricane Bath: skip | Oracle | `portal_skip_appointment` next-appointment pricing branch; portal copy "This is your free skip" |
| paid_skip_resets_next_visit_to_single_rate | Hurricane Bath: skip | Oracle | `portal_skip_appointment` paid branch; `subscriptions.last_skip_priced_at`; next-appointment `amount_cents` set to Reset rate |
| five_week_grace_returns_to_maintenance | Hurricane Bath: skip | Oracle | pricing function gap check (skipped -> next visit <= 35d => Maintenance); never surfaced in client copy |
| reschedule_step_up_weekly | Hurricane Bath: reschedule | Oracle | `src/business/pricing.js` reschedule quoter (curve keyed on days from original); `portal_reschedule_appointment` RPC; calendar price preview |
| reschedule_two_paths_for_recurring | Hurricane Bath: reschedule | Oracle | portal reschedule UI two-button choice; `portal_reschedule_appointment` `change_cadence` param; subscription cadence update branch |
| no_reason_field_ever | Hurricane Bath: ux | Oracle | absence of reason textbox/dropdown in skip + reschedule + cancel flows; lint pattern banning `cancel_reason` / `skip_reason` form fields in portal code |
| stop_sign_two_taps | Hurricane Bath: ux | Oracle | portal cancel flow (2-tap with cascade preview); 4 marketing copy surfaces (homepage, booking step 2, booking step 4, portal); lint pattern asserting copy presence |
| octane_selector_cadence_picker | Hurricane Bath: ux | Oracle | booking step 2 React component (3 buttons + arrow); locked copy "Want your dog fresher?"; smoke test asserts component renders all 3 options |

## How to add a row

1. Add the entry to `CLEAN_ORACLE.md` with a real because.
2. Add what enforcement exists today (a `clients.json` field, a `scripts/check.py` check, or
   convention) to the "Enforced today" column.
3. DB rows are deferred until the rules are agreed and a database exists
   (`no_database_until_rules_agreed`). Do not add a `business_rules` migration yet.
4. When the site is scaffolded, add the code mirror and/or lint pattern and move it left.

The columns are layers of defense. A rule in all of them survives any rewrite; a rule in one
survives only as long as that one place stays intact.
