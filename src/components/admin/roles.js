// roles.js - the single source of truth for Orbit access: who sees which floors.
//
// Both AdminApp (the live nav gating) and AccessView (the access map + Preview as)
// read the menu rules from here, so the menu half of the access map can never
// drift from what the app actually enforces: there is one definition, not two.
// The data-masking half (what is hidden inside a floor a role can open) is NOT
// described here; AccessView reads it live from the server (admin_access_probe),
// which diffs the real RPC output per role, so that half cannot drift either.

// The department taxonomy. `what` is the one-line definition shown in the shell
// until the department is built; it is the to-do list in plain sight.
export const SECTIONS = [
  { key: 'family',    label: 'Family',         ready: true,
    what: 'The stakeholder window: how the business is doing, where Paul is today, and the dogs. Signal, not noise.' },
  { key: 'today',     label: 'Today',          ready: true,
    what: 'The crystal ball. Today’s route and next stop, money in motion, and the briefing feed from your AI department heads.' },
  { key: 'calendar',  label: 'Calendar',       ready: true,
    what: 'Every appointment across the bath book and the legacy book, month and week, with a Google Calendar import overlay.' },
  { key: 'schedule',  label: 'Schedule',       ready: true,
    what: 'Set your work days and work hours, block a date, open a Saturday. Your real availability per city.' },
  { key: 'clients',   label: 'Clients',        ready: true,
    what: 'The contact-sheet database. Each client’s semi-permanent header over a growing visit history.' },
  { key: 'geography', label: 'Geography',      ready: true,
    what: 'Service polygons, plus-code zones, and the drive-time perimeter that gates new signups.' },
  { key: 'operations', label: 'Operations',    ready: true,
    what: 'The trailer, wash system, generators, climate, and maintenance intervals. Pre-trip checklist and maintenance-due alerts.' },
  { key: 'finance',   label: 'Finance',        ready: true,
    what: 'Revenue per visit and per hour, who owes you, the Square and Stripe split, and the expense ledger. Home of the CFO.' },
  { key: 'pricing',   label: 'Pricing',        ready: true,
    what: 'The locked price grid per city and coat tier, and the founders-spot counter.' },
  { key: 'hr',        label: 'HR',             ready: true,
    what: 'You today, your specialists later. Roles, hours, pay, commission tiers, and onboarding.' },
  { key: 'growth',    label: 'Growth',         ready: true,
    what: 'The lead funnel, the waitlist, referrals, retention, and a churn watch.' },
  { key: 'compliance', label: 'Compliance',    ready: true,
    what: 'Insurance and license renewals, A2P registration, payment-processor verification, and tax dates.' },
  { key: 'vendors',   label: 'Vendors',        ready: true,
    what: 'Suppliers, reorder points, and the running-low tracker for shampoo, water, and parts.' },
  { key: 'knowledge', label: 'Knowledge base', ready: true,
    what: 'The wisdom inbox: reasons captured by the speed dial or by replying to an agent, on their way into the Oracle or a client record.' },
  { key: 'library',   label: 'Library',        ready: true,
    what: 'The asset library: every photo and video you hand the business, with notes, even before it has a use. Claude reads it each session.' },
  { key: 'reports',   label: 'Reports',        ready: true,
    what: 'Cross-department rollups: the weekly business review, the revenue-per-hour trend, and the briefing archive.' },
  { key: 'prospectus', label: 'Prospectus',    ready: true,
    what: 'The standing pitch to a buyer who does not exist yet, computed live from the operating data, every claim with a receipt.' },
  { key: 'access',    label: 'Access',         ready: true,
    what: 'Who can see what. Each role’s menu, generated from the live rules, plus what is masked inside, read from the system itself.' },
  { key: 'audit',     label: 'Audit log',      ready: true,
    what: 'Every owner action and every AI recommendation, append-only.' },
  { key: 'settings',  label: 'Settings',       ready: true,
    what: 'Owner identity, the Google, Stripe, Square, and Claude integrations, and notification killswitches.' },
];

export const READY = SECTIONS.filter((s) => s.ready).map((s) => s.key);

// A Hurricane Bath Operator sees the floors the route needs and nothing else;
// the data inside them is masked server-side (admin_get_client and
// admin_today_appointments strip contact and money for the operator role), so
// this list is navigation, not the security boundary.
export const OPERATOR_FLOORS = ['today', 'calendar', 'clients'];
// The viewer role (Kristin): a stakeholder, not day-to-day. The Family window
// (family_window_into_the_business) plus the Prospectus, so a stakeholder sees
// both how the business is doing day to day and what it is worth.
export const VIEWER_FLOORS = ['family', 'prospectus'];

// Paul's words for each role, for the access map and the preview banner.
export const ROLES = [
  { key: 'owner',    mode: 'Emperor',     blurb: 'You. The full run of the house.' },
  { key: 'operator', mode: 'Employee',    blurb: 'Jake and future specialists. The route floors, with contact info and money hidden inside.' },
  { key: 'viewer',   mode: 'Stakeholder', blurb: 'Kristin and family. The window into how the business is doing and what it is worth.' },
];
export const ROLE_MODE = Object.fromEntries(ROLES.map((r) => [r.key, r.mode]));

// floorsFor: null means the owner default (everything except the Family window,
// which is for stakeholders and stays reachable by role, not menu clutter).
// AdminApp uses this for its existing gating logic.
export function floorsFor(role) {
  if (role === 'operator') return OPERATOR_FLOORS;
  if (role === 'viewer') return VIEWER_FLOORS;
  return null;
}

// The one definition of which section keys a role sees in the nav.
export function visibleSectionKeysFor(role) {
  const floors = floorsFor(role);
  return floors
    ? SECTIONS.filter((s) => floors.includes(s.key)).map((s) => s.key)
    : SECTIONS.filter((s) => s.key !== 'family').map((s) => s.key);
}
