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

export async function setClientNofly(clientId, banned, reason = null) {
  return rpc('admin_set_client_nofly', { p_client_id: clientId, p_banned: banned, p_reason: reason });
}

export async function listNofly() {
  const data = await rpc('admin_list_nofly');
  return Array.isArray(data) ? data : [];
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
  });
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

export async function calendar(daysBack = 7, daysForward = 30) {
  const data = await rpc('admin_calendar', { p_days_back: daysBack, p_days_forward: daysForward });
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
