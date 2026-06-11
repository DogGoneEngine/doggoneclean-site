// src/components/admin/supabase.js
//
// Supabase client and RPC wrappers for Orbit, the Dog Gone Clean admin console.
// Points at Clean's own project (dgc-prod). This file shares no data with Dog
// Gone Nails: separate project, separate anon key, separate admins table.

import { createClient } from '@supabase/supabase-js';

export const SUPABASE_URL  = 'https://urebdrosrxejhubpbxsa.supabase.co';
export const SUPABASE_ANON =
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVyZWJkcm9zcnhlamh1YnBieHNhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzk2NTE5NDMsImV4cCI6MjA5NTIyNzk0M30.CoxYUJ3GLQbLKtcvHMovYoXb76XFx8CGrnP6Sg3q94c';

let _client = null;
export function sb() {
  if (typeof window === 'undefined') return null;
  if (!_client) {
    _client = createClient(SUPABASE_URL, SUPABASE_ANON, {
      auth: { persistSession: true, autoRefreshToken: true },
    });
  }
  return _client;
}

async function rpc(fnName, params = {}) {
  const { data, error } = await sb().rpc(fnName, params);
  if (error) throw new Error(error.message || error.code || 'rpc_error');
  return data;
}

// Call an admin edge function with the signed-in user's bearer token.
async function callAdminEdge(name, body = {}) {
  const session = await getSession();
  const res = await fetch(`${SUPABASE_URL}/functions/v1/${name}`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      apikey: SUPABASE_ANON,
      Authorization: `Bearer ${session?.access_token || SUPABASE_ANON}`,
    },
    body: JSON.stringify(body),
  });
  let json = null;
  try { json = await res.json(); } catch { /* non-json */ }
  if (!res.ok || (json && json.ok === false)) {
    throw new Error((json && json.error) || `edge_${res.status}`);
  }
  return json;
}

// Riker: parse a spoken/typed update into a plan (proposes), then apply it.
export async function rikerParse(utterance, clientId = null) {
  const out = await callAdminEdge('riker', { utterance, client_id: clientId });
  return out.plan;
}
export async function rikerApply(plan) {
  return rpc('admin_riker_apply', { p_plan: plan });
}

// Auth ---------------------------------------------------------------------

export async function signInWithGoogle() {
  const { error } = await sb().auth.signInWithOAuth({
    provider: 'google',
    options: {
      redirectTo: `${window.location.origin}/orbit`,
      queryParams: { prompt: 'select_account' },
    },
  });
  if (error) throw new Error(error.message);
}

export async function signOut() {
  return sb().auth.signOut();
}

export async function getSession() {
  const { data } = await sb().auth.getSession();
  return data?.session || null;
}

export async function adminSelf() {
  const rows = await rpc('admin_self');
  return Array.isArray(rows) && rows.length > 0 ? rows[0] : null;
}

// Clients (the contact-sheet database) -------------------------------------

export async function listClients() {
  const data = await rpc('admin_list_clients');
  return Array.isArray(data) ? data : [];
}

export async function getClient(clientId) {
  return rpc('admin_get_client', { p_client_id: clientId });
}

// Visit photos: upload straight from the phone (the Android picker reaches Google
// Photos), into the private visit-photos bucket, viewed via short-lived signed URLs.
const PHOTO_BUCKET = 'visit-photos';
// Phone camera files run 5 to 12 MB; on trailer-driveway signal that is the
// "watching money fly out the window" wait Paul flagged. Resize to 1600px
// max and re-encode as JPEG before upload: 20 to 30 times smaller, visually
// identical at portal/tracker sizes. Falls back to the original on any
// hiccup, and never inflates a file that is already small.
async function compressForUpload(file) {
  try {
    if (!file.type?.startsWith('image/') || file.size < 400000) return file;
    const bmp = await createImageBitmap(file);
    const MAX = 1600;
    const scale = Math.min(1, MAX / Math.max(bmp.width, bmp.height));
    const canvas = document.createElement('canvas');
    canvas.width = Math.max(1, Math.round(bmp.width * scale));
    canvas.height = Math.max(1, Math.round(bmp.height * scale));
    canvas.getContext('2d').drawImage(bmp, 0, 0, canvas.width, canvas.height);
    const blob = await new Promise((res) => canvas.toBlob(res, 'image/jpeg', 0.82));
    if (blob && blob.size < file.size) {
      return new File([blob], (file.name || 'photo').replace(/\.\w+$/, '') + '.jpg', { type: 'image/jpeg' });
    }
  } catch { /* original is always a safe answer */ }
  return file;
}

export async function uploadVisitPhoto(visitId, clientId, kind, file, dogId = null) {
  const f = await compressForUpload(file);
  const ext = (f.name?.split('.').pop() || 'jpg').toLowerCase().replace(/[^a-z0-9]/g, '') || 'jpg';
  const path = `${clientId}/${visitId}/${kind}-${Date.now()}-${Math.random().toString(36).slice(2, 7)}.${ext}`;
  const { error } = await sb().storage.from(PHOTO_BUCKET).upload(path, f, { contentType: f.type || 'image/jpeg', upsert: false });
  if (error) throw new Error(error.message);
  await rpc('admin_add_visit_photo', { p_visit_id: visitId, p_kind: kind, p_path: path, p_dog_id: dogId });
  return path;
}
// Tag (or untag) which dog a photo shows; multi-dog households are the norm.
export async function setPhotoDog(photoId, dogId) {
  return rpc('admin_set_photo_dog', { p_id: photoId, p_dog_id: dogId });
}

// People to notify (extra_notification_people): a spouse who also gets the
// appointment messages, or a temporary stand-in like a dog sitter, in
// addition to or instead of the client, optionally until a date.
export async function listNotifyPeople(clientId) {
  const data = await rpc('admin_list_notify_people', { p_client_id: clientId });
  return Array.isArray(data) ? data : [];
}
export async function upsertNotifyPerson(p) {
  return rpc('admin_upsert_notify_person', {
    p_id: p.id || null, p_client_id: p.client_id, p_name: p.name,
    p_phone: p.phone || null, p_email: p.email || null,
    p_relationship: p.relationship || null, p_mode: p.mode || 'in_addition',
    p_until: p.until || null,
  });
}
export async function setNotifyPersonActive(id, active) {
  return rpc('admin_set_notify_person_active', { p_id: id, p_active: active });
}
export async function deleteNotifyPerson(id) {
  return rpc('admin_delete_notify_person', { p_id: id });
}
export async function signedPhotoUrl(path, expirySeconds = 3600) {
  const { data, error } = await sb().storage.from(PHOTO_BUCKET).createSignedUrl(path, expirySeconds);
  if (error) throw new Error(error.message);
  return data.signedUrl;
}
export async function deleteVisitPhoto(id, path) {
  try { await sb().storage.from(PHOTO_BUCKET).remove([path]); } catch { /* row delete still proceeds */ }
  return rpc('admin_delete_visit_photo', { p_id: id });
}
// Sharing a photo with the client is a deliberate per-photo choice
// (visit_photos.client_visible); shared photos show in the client's portal.
export async function setPhotoVisibility(id, visible) {
  return rpc('admin_set_photo_visibility', { p_id: id, p_visible: visible });
}

export async function setClientNofly(clientId, banned, reason = null) {
  return rpc('admin_set_client_nofly', { p_client_id: clientId, p_banned: banned, p_reason: reason });
}

// Two-tier status: level is 'shadow' | 'banned' | null (clear).
export async function setClientStatus(clientId, level, reason = null) {
  return rpc('admin_set_client_status', { p_client_id: clientId, p_level: level, p_reason: reason });
}

export async function setDogStanding(dogId, text) {
  return rpc('admin_set_dog_standing', { p_dog_id: dogId, p_text: text });
}

export async function setDogStatus(dogId, status) {
  return rpc('admin_set_dog_status', { p_dog_id: dogId, p_status: status });
}

export async function setDogNote(dogId, text) {
  return rpc('admin_set_dog_note', { p_dog_id: dogId, p_text: text });
}

export async function setClientAccess(clientId, text) {
  return rpc('admin_set_client_access', { p_client_id: clientId, p_text: text });
}

export async function setClientOnsite(clientId, text) {
  return rpc('admin_set_client_onsite', { p_client_id: clientId, p_text: text });
}

export async function setClientPlus(clientId, text) {
  return rpc('admin_set_client_plus', { p_client_id: clientId, p_text: text });
}

export async function setClientAlt(clientId, label, address) {
  return rpc('admin_set_client_alt', { p_client_id: clientId, p_label: label, p_address: address });
}

export async function setClientThoughts(clientId, text) {
  return rpc('admin_set_client_thoughts', { p_client_id: clientId, p_text: text });
}

// Dog follow-ups (open -> resolved lifecycle).
export async function listDogFollowups(dogId) {
  const data = await rpc('admin_list_dog_followups', { p_dog_id: dogId });
  return Array.isArray(data) ? data : [];
}
export async function addDogFollowup(dogId, body) {
  return rpc('admin_add_dog_followup', { p_dog_id: dogId, p_body: body });
}
export async function resolveDogFollowup(id, resolution) {
  return rpc('admin_resolve_dog_followup', { p_id: id, p_resolution: resolution });
}
export async function dropDogFollowup(id) {
  return rpc('admin_drop_dog_followup', { p_id: id });
}

export async function setDogBirthday(dogId, birthDate, approximate) {
  return rpc('admin_set_dog_birthday', { p_dog_id: dogId, p_birth_date: birthDate, p_approximate: approximate });
}

// Message draft (test): turn Paul's stream-of-consciousness into a client message.
export async function messageDraft(clientId, thoughts) {
  return callAdminEdge('message-draft', { client_id: clientId, thoughts });
}

export async function listNofly() {
  const data = await rpc('admin_list_nofly');
  return Array.isArray(data) ? data : [];
}

export async function listArchivedClients() {
  const data = await rpc('admin_list_archived_clients');
  return Array.isArray(data) ? data : [];
}

export async function unarchiveClient(clientId) {
  return rpc('admin_unarchive_client', { p_client_id: clientId });
}

export async function listAliases(clientId) {
  const data = await rpc('admin_list_aliases', { p_client_id: clientId });
  return Array.isArray(data) ? data : [];
}

export async function addAlias(clientId, alias) {
  return rpc('admin_add_alias', { p_client_id: clientId, p_alias: alias });
}

export async function removeAlias(aliasId) {
  return rpc('admin_remove_alias', { p_alias_id: aliasId });
}

export async function logVisit(v) {
  return rpc('admin_log_visit', {
    p_client_id:             v.clientId ?? null,
    p_subscriber_id:         v.subscriberId ?? null,
    p_appointment_id:        v.appointmentId ?? null,
    p_visited_at:            v.visitedAt ?? null,
    p_service_type:          v.serviceType ?? null,
    p_dog_ids:               v.dogIds ?? null,
    p_work_done:             v.workDone ?? null,
    p_visit_notes:           v.visitNotes ?? null,
    p_condition_flags:       v.conditionFlags ?? null,
    p_actual_minutes:        v.actualMinutes ?? null,
    p_amount_collected_cents: v.amountCollectedCents ?? null,
    p_tip_cents:             v.tipCents ?? null,
    p_payment_method:        v.paymentMethod ?? null,
    p_source:                v.source ?? 'manual',
    p_dog_scores:            v.dogScores ?? null,
    p_inbound_at:            v.inboundAt ?? null,
    p_arrived_at:            v.arrivedAt ?? null,
    p_departed_at:           v.departedAt ?? null,
    p_charged_cents:         v.chargedCents ?? null,
  });
}

export async function exportTimeIsMoney(since = null) {
  return rpc('admin_export_time_is_money', { p_since: since });
}

export async function completeAppointment(appointmentId, v = {}) {
  return rpc('admin_complete_appointment', {
    p_appointment_id:        appointmentId,
    p_work_done:             v.workDone ?? null,
    p_visit_notes:           v.visitNotes ?? null,
    p_actual_minutes:        v.actualMinutes ?? null,
    p_amount_collected_cents: v.amountCollectedCents ?? null,
    p_tip_cents:             v.tipCents ?? null,
    p_payment_method:        v.paymentMethod ?? null,
    p_condition_flags:       v.conditionFlags ?? null,
    p_dog_ids:               v.dogIds ?? null,
  });
}

// Schedule (work days, work hours, exceptions) -----------------------------

export async function listSchedule() {
  const data = await rpc('admin_list_schedule');
  return Array.isArray(data) ? data : [];
}

export async function setWindow(w) {
  return rpc('admin_set_window', {
    p_id: w.id ?? null,
    p_city_id: w.cityId,
    p_weekday: w.weekday,
    p_start: w.start,
    p_end: w.end,
    p_active: w.active ?? true,
  });
}

export async function deleteWindow(id) {
  return rpc('admin_delete_window', { p_id: id });
}

export async function addException(e) {
  return rpc('admin_add_exception', {
    p_city_id: e.cityId,
    p_date: e.date,
    p_is_closed: e.isClosed,
    p_start: e.start ?? null,
    p_end: e.end ?? null,
    p_note: e.note ?? null,
  });
}

export async function deleteException(id) {
  return rpc('admin_delete_exception', { p_id: id });
}

// AI department heads (briefings) ------------------------------------------

export async function listBriefings(department = null, status = null) {
  const data = await rpc('admin_list_briefings', {
    p_department: department, p_status: status,
  });
  return Array.isArray(data) ? data : [];
}

export async function todayAppointments() {
  const data = await rpc('admin_today_appointments');
  return Array.isArray(data) ? data : [];
}

// Stamp one clock (inbound | arrived | departed) on a stop's time_is_money
// capture. p_at is a full ISO timestamp (or null to clear). Returns the visit's
// current three times + minutes so the Today row can update in place.
export async function stampAppointmentTime(appointmentId, field, at) {
  return rpc('admin_stamp_appointment_time', { p_appointment_id: appointmentId, p_field: field, p_at: at });
}

// One tap when leaving for a stop: flips the appointment to on_the_way (never
// downgrades a later status) and returns the Dog Gone Tracker token so the
// Today sheet can hand Paul the ready-to-send heads-up message.
export async function onMyWay(appointmentId) {
  return rpc('admin_on_my_way', { p_appointment: appointmentId });
}

// One tap when pulling up: flips the appointment to on_site, stamps the
// Arrived clock server-side if empty, and stops the live-location broadcast.
// The tracker turns to "We're here, getting set up, with you shortly."
export async function adminArrived(appointmentId) {
  return rpc('admin_arrived', { p_appointment: appointmentId });
}

// One tap when walking the dogs back: flips the appointment to returning so
// the tracker tells the client to watch the door. Deliberately manual (Paul):
// only he knows the moment the dogs are headed back.
export async function adminReturning(appointmentId) {
  return rpc('admin_returning', { p_appointment: appointmentId });
}

// The Today sheet's geolocation watch pushes the truck's position here while
// a stop is on_the_way; the tracker-eta edge function serves it (token-scoped)
// to the one client waiting on that stop.
export async function trackerLocation(appointmentId, lat, lng) {
  return rpc('admin_tracker_location', { p_appointment: appointmentId, p_lat: lat, p_lng: lng });
}

// Run the Availability watcher on demand (it also runs on its daily cron).
export async function runCapacityCheck() {
  return rpc('admin_capacity_check');
}

// In-app booking for an existing client (admin side). Slots are sized to the
// client's own duration; booking enforces the slot engine for everyone except
// Paul, who can override with a confirm (operator_override_with_confirm).
// The intelligent half of booking: due date from the client's real cadence
// and last visit, candidate days around it filtered by THEIR constraints,
// each with its offset from due and the stops already on that day.
export async function adminSuggestSlots(clientId) {
  return rpc('admin_suggest_slots', { p_client_id: clientId });
}
export async function adminOpenSlots(clientId, fromDate, days = 1) {
  return rpc('admin_open_slots', { p_client_id: clientId, p_from: fromDate, p_days: days });
}
export async function adminBookAppointment(clientId, startISO, override = false, dogIds = null) {
  return rpc('admin_book_appointment', { p_client_id: clientId, p_start: startISO, p_override: override, p_dog_ids: dogIds });
}

// Suggestions annotated with real drive minutes from the previous stop and to
// the next stop per slot (suggest-drive edge fn, drive_cache behind it). Falls
// back to the plain RPC so booking never breaks if the annotator is down.
export async function suggestSlotsWithDrive(clientId) {
  try {
    const out = await callAdminEdge('suggest-drive', { client_id: clientId });
    if (out && out.suggestions) return out.suggestions;
  } catch { /* fall through to plain suggestions */ }
  return rpc('admin_suggest_slots', { p_client_id: clientId });
}

// Reminders: time-based commitments. In through Riker or code, out on Today.
export async function listReminders() {
  return rpc('admin_list_reminders');
}
export async function addReminder(body, due, clientId = null) {
  return rpc('admin_add_reminder', { p_body: body, p_due: due, p_client_id: clientId });
}
export async function setReminderDone(id, done = true) {
  return rpc('admin_set_reminder_done', { p_id: id, p_done: done });
}

// What the AI staff actually costs, from logged token usage.
export async function adminAgentCosts() {
  return rpc('admin_agent_costs');
}

// The human team roster (Paul, Jake, whoever joins).
export async function listTeam() {
  return rpc('admin_list_team');
}

// The hours-ask briefing card's Save button: writes the panel reading
// straight onto the named equipment (never a free-text reply into the void).
export async function setEquipmentHoursByName(name, hours) {
  return rpc('admin_set_equipment_hours_by_name', { p_name: name, p_hours: hours });
}

export async function setBriefingStatus(id, status) {
  return rpc('admin_set_briefing_status', { p_id: id, p_status: status });
}

export async function replyBriefing(id, body) {
  return rpc('admin_add_briefing_note', { p_briefing_id: id, p_body: body });
}

export async function resolveBriefing(id, disposition, note = null) {
  return rpc('admin_resolve_briefing', { p_briefing_id: id, p_disposition: disposition, p_note: note });
}

// Wisdom / knowledge capture --------------------------------------------------

export async function captureWisdom(body, clientId = null) {
  // No category from Paul; the Archivist agent assigns scope + home.
  return rpc('admin_capture_wisdom', { p_body: body, p_scope: 'unsorted', p_client_id: clientId, p_source: 'quick_capture' });
}

export async function triggerArchivist() {
  return rpc('admin_trigger_archivist');
}

// Growth / win-back -----------------------------------------------------------

export async function growthSummary() {
  return rpc('admin_growth_summary');
}

export async function calendar(daysBack = 7, daysForward = 30) {  const data = await rpc('admin_calendar', { p_days_back: daysBack, p_days_forward: daysForward });
  return Array.isArray(data) ? data : [];
}

export async function hrSummary(windowDays = 30) {
  return rpc('admin_hr_summary', { p_window_days: windowDays });
}

export async function geographySummary() {
  return rpc('admin_geography_summary');
}

export async function runWinbackCheck() {
  return rpc('admin_winback_check');
}

export async function listWisdom(status = null) {
  const data = await rpc('admin_list_wisdom', { p_status: status });
  return Array.isArray(data) ? data : [];
}

export async function setWisdomStatus(id, status) {
  return rpc('admin_set_wisdom_status', { p_id: id, p_status: status });
}

// Vendors / supplies ----------------------------------------------------------

export async function listSupplies() {
  return rpc('admin_list_supplies');
}

export async function upsertSupply(s) {
  return rpc('admin_upsert_supply', {
    p_id: s.id ?? null, p_name: s.name, p_category: s.category ?? 'other', p_vendor: s.vendor ?? null,
    p_reorder_url: s.reorderUrl ?? null, p_interval_days: s.intervalDays ?? null, p_notes: s.notes ?? null, p_active: s.active ?? true,
  });
}

export async function supplyAction(id, action) {
  return rpc('admin_supply_action', { p_id: id, p_action: action });
}

export async function runReorderCheck() {
  return rpc('admin_reorder_check');
}

export async function listAgents() {
  const data = await rpc('admin_list_agents');
  return Array.isArray(data) ? data : [];
}

// Finance + Reports -----------------------------------------------------------

export async function financeSummary(windowDays = 90) {
  return rpc('admin_finance_summary', { p_window_days: windowDays });
}

export async function reportsSummary() {
  return rpc('admin_reports_summary');
}

// Recurring costs (subscriptions / tech-stack burn) --------------------------

export async function listRecurringCosts() {
  return rpc('admin_list_recurring_costs');
}

export async function upsertRecurringCost(c) {
  return rpc('admin_upsert_recurring_cost', {
    p_id: c.id ?? null,
    p_name: c.name,
    p_category: c.category ?? 'other',
    p_amount_cents: c.amountCents ?? null,
    p_cadence: c.cadence ?? 'monthly',
    p_billing_day: c.billingDay ?? null,
    p_billing_month: c.billingMonth ?? null,
    p_vendor: c.vendor ?? null,
    p_url: c.url ?? null,
    p_notes: c.notes ?? null,
    p_active: c.active ?? true,
  });
}

export async function deleteRecurringCost(id) {
  return rpc('admin_delete_recurring_cost', { p_id: id });
}

// Expense ledger (the business account's money-out) --------------------------

export async function importExpenses(rows) {
  return rpc('admin_import_expenses', { p_rows: rows });
}

export async function expenseSummary(windowDays = 90) {
  return rpc('admin_expense_summary', { p_window_days: windowDays });
}

export async function addExpense(e) {
  return rpc('admin_add_expense', {
    p_txn_date: e.txnDate, p_description: e.description, p_amount_cents: e.amountCents,
    p_category: e.category ?? 'other', p_card: e.card ?? null, p_vendor: e.vendor ?? null, p_notes: e.notes ?? null,
  });
}

export async function setExpenseBusiness(id, isBusiness) {
  return rpc('admin_set_expense_business', { p_id: id, p_is_business: isBusiness });
}

export async function setExpenseCategory(id, category) {
  return rpc('admin_set_expense_category', { p_id: id, p_category: category });
}

export async function exportExpenses(from = null, to = null) {
  const data = await rpc('admin_export_expenses', { p_from: from, p_to: to });
  return Array.isArray(data) ? data : [];
}

// Compliance ------------------------------------------------------------------

export async function listCompliance() {
  return rpc('admin_list_compliance');
}

export async function upsertComplianceItem(c) {
  return rpc('admin_upsert_compliance_item', {
    p_id: c.id ?? null, p_name: c.name, p_category: c.category ?? 'other', p_status: c.status ?? 'pending',
    p_renewal_date: c.renewalDate ?? null, p_provider: c.provider ?? null, p_reference: c.reference ?? null,
    p_amount_cents: c.amountCents ?? null, p_notes: c.notes ?? null, p_active: c.active ?? true,
  });
}

export async function deleteComplianceItem(id) {
  return rpc('admin_delete_compliance_item', { p_id: id });
}

export async function runComplianceCheck() {
  return rpc('admin_compliance_check');
}

// Settings + Audit ------------------------------------------------------------

export async function systemStatus() {
  return rpc('admin_system_status');
}

export async function auditFeed(limit = 60) {
  return rpc('admin_audit_feed', { p_limit: limit });
}

export async function pricingGrid() {
  const data = await rpc('admin_pricing_grid');
  return Array.isArray(data) ? data : [];
}

// Operations / equipment ------------------------------------------------------

export async function listEquipment() {
  return rpc('admin_list_equipment');
}

export async function upsertEquipment(e) {
  return rpc('admin_upsert_equipment', {
    p_id: e.id ?? null, p_name: e.name, p_category: e.category ?? 'other',
    p_last_service_date: e.lastServiceDate ?? null, p_interval_days: e.intervalDays ?? null,
    p_provider: e.provider ?? null, p_notes: e.notes ?? null, p_active: e.active ?? true,
  });
}

export async function deleteEquipment(id) {
  return rpc('admin_delete_equipment', { p_id: id });
}

export async function runMaintenanceCheck() {
  return rpc('admin_maintenance_check');
}

export async function powerSummary() {
  return rpc('admin_power_summary');
}

export async function updateEquipmentHours(id, hours) {
  return rpc('admin_update_equipment_hours', { p_id: id, p_hours: hours });
}

export async function setPower(id, { watts = null, ratedWatts = null }) {
  return rpc('admin_set_power', { p_id: id, p_watts: watts, p_rated_watts: ratedWatts });
}

export async function listMaintenanceTasks() {
  const data = await rpc('admin_list_maintenance_tasks');
  return Array.isArray(data) ? data : [];
}

export async function markTaskDone(taskId) {
  return rpc('admin_mark_task_done', { p_task_id: taskId, p_done_date: null, p_done_hours: null });
}
