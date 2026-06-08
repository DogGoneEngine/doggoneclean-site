// src/components/portal/PortalViews.jsx
//
// The authenticated client portal for Dog Gone Clean (Hurricane Bath).
// Slice 1 (this file): the viewing spine. A signed-in subscriber sees
// their next visit, their plan, their pack, their profile, and their
// visit history, all read live from dgc-prod through getPortalData.
//
// Read-only by design for this slice. The actions a client needs
// (cancel/pause, reschedule, skip, change cadence, edit pack, edit
// profile) each land in a following slice paired with a SECURITY DEFINER
// RPC, because bath_subscriptions and bath_appointments expose no direct
// write policy: the rule has to live in the database, not the page.

import { useState, useEffect, useRef } from 'react';
import './portal.css';
import {
  pauseSubscription, resumeSubscription, cancelSubscription, changeCadence,
  skipAppointment, rescheduleAppointment, getOpenSlots,
  addDog, updateDog, removeDog,
  updateProfile, updateServiceAddress, toE164US,
  getNotificationPrefs, setNotificationPrefs,
} from './supabase.js';
import { loadGoogleMaps, parsePlace, isInServiceArea, polygonBounds } from './maps.js';

// ── Formatting helpers ─────────────────────────────────────────────────
// Appointment times are timestamptz; render them in the city's wall clock
// (the route runs on Eastern) so a Villages client never sees UTC.
function tz(city) {
  return (city && city.hb_timezone) || 'America/New_York';
}

function fmtDate(iso, city) {
  if (!iso) return '';
  return new Date(iso).toLocaleDateString('en-US', {
    weekday: 'long', month: 'long', day: 'numeric', timeZone: tz(city),
  });
}

function fmtDateShort(iso, city) {
  if (!iso) return '';
  return new Date(iso).toLocaleDateString('en-US', {
    weekday: 'short', month: 'short', day: 'numeric', timeZone: tz(city),
  });
}

function fmtTime(iso, city) {
  if (!iso) return '';
  return new Date(iso).toLocaleTimeString('en-US', {
    hour: 'numeric', minute: '2-digit', timeZone: tz(city),
  });
}

function fmtTimeRange(start, end, city) {
  if (!start) return '';
  if (!end) return fmtTime(start, city);
  return `${fmtTime(start, city)} to ${fmtTime(end, city)}`;
}

// Date-only columns (founders_locked_until, birth_date) carry no time or
// zone. Format them as a plain calendar date so a timezone conversion
// never shifts them a day. Falls back to the raw value if it is not a
// yyyy-mm-dd string.
const MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
function fmtPlainDate(dateStr) {
  if (!dateStr) return '';
  const m = String(dateStr).match(/^(\d{4})-(\d{2})-(\d{2})/);
  if (!m) return String(dateStr);
  return `${MONTHS[+m[2] - 1]} ${+m[3]}, ${m[1]}`;
}

function dollars(cents) {
  if (cents == null) return '';
  const d = cents / 100;
  return Number.isInteger(d) ? `$${d}` : `$${d.toFixed(2)}`;
}

// The Hurricane Bath plan uses the cadence enum (4wk/2wk/oneoff); the legacy
// full-groom book carries no enum and keeps the real interval in cadence_days
// (e.g. 21 = every 3 weeks). Read the enum first, then fall back to cadence_days
// so a legacy client sees their true cadence instead of a blank.
function cadenceLabel(subscription) {
  const cadence = subscription && typeof subscription === 'object' ? subscription.cadence : subscription;
  if (cadence === '4wk') return 'Every 4 weeks';
  if (cadence === '2wk') return 'Every 2 weeks';
  if (cadence === 'oneoff') return 'Single visit';
  const days = subscription && typeof subscription === 'object' ? subscription.cadence_days : null;
  if (Number.isInteger(days) && days > 0) {
    if (days % 7 === 0) {
      const weeks = days / 7;
      return weeks === 1 ? 'Every week' : `Every ${weeks} weeks`;
    }
    return `Every ${days} days`;
  }
  if (subscription && typeof subscription === 'object' && subscription.is_recurring === false) {
    return 'Single visit';
  }
  return cadence || '';
}

function coatLabel(tier) {
  if (tier === 'smoothcoat') return 'Smooth coat';
  if (tier === 'doublecoat') return 'Double coat';
  if (tier === 'not_accepted') return 'Not eligible';
  return '';
}

function ageFromBirthDate(dateStr, approximate) {
  if (!dateStr) return '';
  const b = new Date(dateStr);
  if (Number.isNaN(b.getTime())) return '';
  const now = new Date();
  let years = now.getFullYear() - b.getFullYear();
  const m = now.getMonth() - b.getMonth();
  if (m < 0 || (m === 0 && now.getDate() < b.getDate())) years--;
  if (years < 1) {
    const months = Math.max(0, years * 12 + m);
    return `${approximate ? '~' : ''}${months} mo`;
  }
  return `${approximate ? '~' : ''}${years} yr`;
}

// Appointment statuses that mean "still on the calendar, not yet done".
const LIVE_STATUSES = ['requested', 'confirmed', 'on_the_way', 'on_site', 'in_service'];

const STATUS_LABEL = {
  requested: 'Requested',
  confirmed: 'Confirmed',
  on_the_way: 'On the way',
  on_site: 'On site',
  in_service: 'In service',
  completed: 'Completed',
  no_show: 'No show',
  cancelled: 'Cancelled',
  skipped: 'Skipped',
};

function StatusChip({ status }) {
  const tone =
    status === 'completed' ? 'good'
    : status === 'cancelled' || status === 'no_show' ? 'muted'
    : status === 'skipped' ? 'muted'
    : 'live';
  return <span className={`pt-chip pt-chip--${tone}`}>{STATUS_LABEL[status] || status}</span>;
}

// ── Home (the viewing spine) ───────────────────────────────────────────
// ── Reminders: per-client reminder opt-in/out, by channel ───────────────
// Only the reminders are opt-out-able. Confirmations, cancellations, and
// reschedules always send by email. Text saves the choice but stays dormant
// until texting is turned on (Twilio).
const REMINDER_ROWS = [
  { key: 'reminder_3d', label: '3 days before' },
  { key: 'reminder_26h', label: 'The day before' },
  { key: 'reminder_day', label: 'Day of' },
];

function NotificationsSection({ toast }) {
  const [prefs, setPrefs] = useState(null);
  const [state, setState] = useState('loading'); // 'loading' | 'ready' | 'error'
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    let alive = true;
    (async () => {
      const res = await getNotificationPrefs();
      if (!alive) return;
      if (res && res.ok && res.prefs) { setPrefs(res.prefs); setState('ready'); }
      else setState('error');
    })();
    return () => { alive = false; };
  }, []);

  async function toggle(key, channel) {
    const next = { ...prefs, [key]: { ...prefs[key], [channel]: !(prefs[key] && prefs[key][channel]) } };
    setPrefs(next);
    setSaving(true);
    const res = await setNotificationPrefs(next);
    setSaving(false);
    if (toast) toast(res && res.ok ? 'Saved.' : 'Could not save. Try again.');
  }

  if (state === 'loading') return <div className="pt-card"><div className="pt-card__value">Loading...</div></div>;
  if (state !== 'ready' || !prefs) return <div className="pt-card"><div className="pt-card__value">Could not load your reminder settings.</div></div>;

  const cell = { width: 56, textAlign: 'center', display: 'inline-block' };
  const head = { ...cell, fontSize: '0.8rem', color: '#6b7280' };

  return (
    <div className="pt-card">
      <div className="pt-card__row">
        <span className="pt-card__label">Send me</span>
        <span>
          <span style={head}>Email</span>
          <span style={head}>Text</span>
        </span>
      </div>
      {REMINDER_ROWS.map(({ key, label }) => (
        <div className="pt-card__row" key={key}>
          <span className="pt-card__label">{label}</span>
          <span>
            <span style={cell}>
              <input type="checkbox" checked={!!(prefs[key] && prefs[key].email)} disabled={saving}
                onChange={() => toggle(key, 'email')} aria-label={`${label} by email`} style={{ width: 18, height: 18 }} />
            </span>
            <span style={cell}>
              <input type="checkbox" checked={!!(prefs[key] && prefs[key].sms)} disabled={saving}
                onChange={() => toggle(key, 'sms')} aria-label={`${label} by text`} style={{ width: 18, height: 18 }} />
            </span>
          </span>
        </div>
      ))}
      <p style={{ marginTop: 'var(--space-md)', fontSize: '0.85rem', color: '#6b7280' }}>
        Confirmations and cancellation notices always come by email. Text reminders save your choice now and start once we turn on texting; until then we reach you by email.
      </p>
    </div>
  );
}

// The portal is a four-tab app (Home / Appointments / Pack / Account),
// mirroring the Dog Gone Nails portal so the two surfaces match. The shell
// only routes between tabs; every tab reuses the existing section components.
const PORTAL_TABS = [
  { key: 'home', label: 'Home', Icon: IconHome },
  { key: 'appts', label: 'Visits', Icon: IconCalendar },
  { key: 'pack', label: 'Pack', Icon: IconPaw },
  { key: 'account', label: 'Account', Icon: IconPerson },
];

export function PortalHome({ data, onLogout, onChanged, toast }) {
  const [view, setView] = useState('home');

  const { subscriber, subscription, city } = data;
  const dogs = (data.dogs || []).filter(d => d.active !== false);
  const appts = data.appointments || [];

  const now = Date.now();
  const byStart = [...appts].sort(
    (a, b) => new Date(a.scheduled_start) - new Date(b.scheduled_start)
  );
  const upcoming = byStart.filter(
    a => LIVE_STATUSES.includes(a.status) && new Date(a.scheduled_start).getTime() >= now
  );
  const nextAppt = upcoming[0] || null;
  const upcomingSet = new Set(upcoming.map(a => a.id));
  const history = byStart.filter(a => !upcomingSet.has(a.id)).reverse();

  const firstName = subscriber.first_name || pickFirstName(data.authUser);
  const planStatus = subscription ? subscription.status : null;

  const ctx = {
    subscriber, subscription, city, dogs, appts,
    upcoming, nextAppt, history, planStatus, firstName, onChanged, toast,
  };

  return (
    <div className="pt-app">
      <header className="pt-topbar">
        <div className="pt-topbar__inner">
          <div>
            <div className="pt-topbar__greeting">{greetByTime()}</div>
            <div className="pt-topbar__name">{firstName ? `Hi, ${firstName}` : 'Hi there'}</div>
          </div>
          <button className="pt-signout-link" onClick={onLogout}>Sign out</button>
        </div>
      </header>

      <main className="pt-app__body">
        {view === 'home' && <HomeView ctx={ctx} />}
        {view === 'appts' && <ApptsView ctx={ctx} />}
        {view === 'pack' && <PackView ctx={ctx} />}
        {view === 'account' && <AccountView ctx={ctx} onLogout={onLogout} />}
      </main>

      <nav className="pt-bottomnav" role="tablist" aria-label="Portal sections">
        {PORTAL_TABS.map(({ key, label, Icon }) => (
          <button
            key={key}
            type="button"
            role="tab"
            aria-selected={view === key}
            className={`pt-bottomnav__item${view === key ? ' pt-bottomnav__item--on' : ''}`}
            onClick={() => setView(key)}
          >
            <Icon />
            <span className="pt-bottomnav__label">{label}</span>
          </button>
        ))}
      </nav>
    </div>
  );
}

// ── Reusable: the next-visit hero card ─────────────────────────────────
function NextVisitHero({ ctx, withActions }) {
  const { nextAppt, planStatus, city, dogs, onChanged, toast } = ctx;
  if (!nextAppt) {
    return (
      <div className="pt-hero pt-hero--empty">
        <div className="pt-hero__date">No upcoming visit</div>
        <div className="pt-hero__meta">
          {planStatus === 'active'
            ? 'Your next visit will appear here once it is scheduled.'
            : 'Book a visit to get back on the route.'}
        </div>
      </div>
    );
  }
  return (
    <>
      <div className="pt-hero">
        <div className="pt-hero__top">
          <StatusChip status={nextAppt.status} />
          {nextAppt.amount_cents > 0 && (
            <span className="pt-hero__price">{dollars(nextAppt.amount_cents)}</span>
          )}
        </div>
        <div className="pt-hero__date">{fmtDate(nextAppt.scheduled_start, city)}</div>
        <div className="pt-hero__time">{fmtTimeRange(nextAppt.scheduled_start, nextAppt.scheduled_end, city)}</div>
        <div className="pt-hero__meta">
          {nextAppt.dog_count} {nextAppt.dog_count === 1 ? 'dog' : 'dogs'}
          {dogs.length > 0 && ` · ${dogs.map(d => d.name).join(', ')}`}
        </div>
      </div>
      {withActions && (
        <VisitActions appt={nextAppt} city={city} onChanged={onChanged} toast={toast} />
      )}
    </>
  );
}

function PlanBanners({ planStatus }) {
  if (planStatus === 'paused') {
    return (
      <div className="pt-banner pt-banner--warn">
        Your plan is paused. No visits are scheduled until you restart it.
      </div>
    );
  }
  if (planStatus === 'cancelled') {
    return (
      <div className="pt-banner pt-banner--muted">
        Your plan is cancelled. Book again any time to come back on the route.
      </div>
    );
  }
  return null;
}

function ApptRow({ a, city }) {
  return (
    <div className="pt-appt">
      <div className="pt-appt__date">
        <div className="pt-appt__date-main">{fmtDateShort(a.scheduled_start, city)}</div>
        <div className="pt-appt__date-time">{fmtTime(a.scheduled_start, city)}</div>
      </div>
      <StatusChip status={a.status} />
      {a.amount_cents > 0 && <span className="pt-appt__price">{dollars(a.amount_cents)}</span>}
    </div>
  );
}

// ── Tab: Home (the next thing, plus a plan glance) ─────────────────────
function HomeView({ ctx }) {
  const { subscription, planStatus } = ctx;
  return (
    <div className="pt-content">
      <PlanBanners planStatus={planStatus} />
      <section className="pt-section">
        <h2 className="pt-section__title">Next visit</h2>
        <NextVisitHero ctx={ctx} withActions />
      </section>

      {subscription && (
        <section className="pt-section">
          <h2 className="pt-section__title">Your plan</h2>
          <div className="pt-card">
            <div className="pt-card__row">
              <span className="pt-card__label">Cadence</span>
              <span className="pt-card__value">{cadenceLabel(subscription)}</span>
            </div>
            <div className="pt-card__row">
              <span className="pt-card__label">Status</span>
              <span className="pt-card__value pt-status-pill" data-status={subscription.status}>
                {subscription.status}
              </span>
            </div>
          </div>
          <p className="pt-glance-hint">Manage your plan, details, and reminders in the Account tab.</p>
        </section>
      )}
    </div>
  );
}

// ── Tab: Visits (the full ledger) ──────────────────────────────────────
function ApptsView({ ctx }) {
  const { upcoming, history, city, nextAppt } = ctx;
  const laterUpcoming = upcoming.filter(a => !nextAppt || a.id !== nextAppt.id);
  return (
    <div className="pt-content">
      <section className="pt-section">
        <h2 className="pt-section__title">Upcoming</h2>
        <NextVisitHero ctx={ctx} withActions />
        {laterUpcoming.length > 0 && (
          <div className="pt-appt-list" style={{ marginTop: 'var(--space-md)' }}>
            {laterUpcoming.map(a => <ApptRow key={a.id} a={a} city={city} />)}
          </div>
        )}
      </section>

      {history.length > 0 && (
        <section className="pt-section">
          <h2 className="pt-section__title">Visit history</h2>
          <div className="pt-appt-list">
            {history.map(a => <ApptRow key={a.id} a={a} city={city} />)}
          </div>
        </section>
      )}
    </div>
  );
}

// ── Tab: Pack ──────────────────────────────────────────────────────────
function PackView({ ctx }) {
  const { dogs, subscriber, onChanged, toast } = ctx;
  return (
    <div className="pt-content">
      <section className="pt-section">
        <h2 className="pt-section__title">Your pack</h2>
        <PackSection dogs={dogs} subscriberId={subscriber.id} onChanged={onChanged} toast={toast} />
      </section>
    </div>
  );
}

// ── Tab: Account (plan controls, details, reminders) ───────────────────
function AccountView({ ctx, onLogout }) {
  const { subscription, subscriber, city, onChanged, toast } = ctx;
  return (
    <div className="pt-content">
      {subscription && (
        <section className="pt-section">
          <h2 className="pt-section__title">Your plan</h2>
          <div className="pt-card">
            <div className="pt-card__row">
              <span className="pt-card__label">Cadence</span>
              <span className="pt-card__value">{cadenceLabel(subscription)}</span>
            </div>
            <div className="pt-card__row">
              <span className="pt-card__label">Price per visit</span>
              <span className="pt-card__value">{dollars(subscription.base_price_cents)}</span>
            </div>
            <div className="pt-card__row">
              <span className="pt-card__label">Status</span>
              <span className="pt-card__value pt-status-pill" data-status={subscription.status}>
                {subscription.status}
              </span>
            </div>
            {subscription.is_founders && (
              <div className="pt-card__row">
                <span className="pt-card__label">Founders rate</span>
                <span className="pt-card__value">
                  {subscription.founders_locked_until
                    ? `Locked through ${fmtPlainDate(subscription.founders_locked_until)}`
                    : 'Yes'}
                </span>
              </div>
            )}
          </div>
          <CadenceControl subscription={subscription} onChanged={onChanged} toast={toast} />
          <PlanActions subscription={subscription} onChanged={onChanged} toast={toast} />
        </section>
      )}

      <section className="pt-section">
        <h2 className="pt-section__title">Payment</h2>
        <PaymentSection subscription={subscription} />
      </section>

      <section className="pt-section">
        <h2 className="pt-section__title">Your details</h2>
        <ProfileSection subscriber={subscriber} city={city} onChanged={onChanged} toast={toast} />
      </section>

      <section className="pt-section">
        <h2 className="pt-section__title">Reminders</h2>
        <NotificationsSection toast={toast} />
      </section>

      <div className="pt-home__foot">
        <button className="pt-signout-link" onClick={onLogout}>Sign out</button>
      </div>
    </div>
  );
}

// ── Payment section (gated by how the client actually pays) ────────────
// Legacy clients pay in person via Square and must NEVER be shown a card
// field. Only Hurricane Bath clients (payment_method = 'stripe_card') have a
// card on file. The full card-management surface (see brand/last4/expiry,
// update card, failed-charge + expiry banners, mirroring the Nails portal)
// requires Clean's own Stripe account to be wired first (create-setup-intent
// edge function + card-detail columns + Stripe Elements); until then this shows
// the honest real state and never fakes a card. No mockups.
function PaymentSection({ subscription }) {
  const method = subscription && subscription.payment_method;

  // Anything that is not an explicit card-on-file plan is treated as in person,
  // so a legacy or unknown client is never prompted for a card.
  if (method !== 'stripe_card') {
    return (
      <div className="pt-card">
        <div className="pt-card__row">
          <span className="pt-card__label">How you pay</span>
          <span className="pt-card__value">In person</span>
        </div>
        <p className="pt-glance-hint">
          You pay in person at your appointment: card, cash, or mobile wallet via Square.
          There is no card on file and nothing is charged online.
        </p>
      </div>
    );
  }

  const hasCard = !!subscription.stripe_payment_method_id;
  return (
    <div className="pt-card">
      <div className="pt-card__row">
        <span className="pt-card__label">Card on file</span>
        <span className="pt-card__value">{hasCard ? 'On file' : 'None yet'}</span>
      </div>
      <p className="pt-glance-hint">
        {hasCard
          ? 'Your card on file is charged the day before each visit, never sooner.'
          : 'You will add a card when you book. It is charged the day before each visit, never sooner.'}
      </p>
    </div>
  );
}

// ── Bottom-nav icons (inline SVG, currentColor) ────────────────────────
function IconHome() {
  return (
    <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
      <path d="M3 10.5 12 3l9 7.5" /><path d="M5 9.5V20a1 1 0 0 0 1 1h12a1 1 0 0 0 1-1V9.5" />
    </svg>
  );
}
function IconCalendar() {
  return (
    <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
      <rect x="3" y="4.5" width="18" height="16" rx="2" /><path d="M3 9h18M8 3v3M16 3v3" />
    </svg>
  );
}
function IconPaw() {
  return (
    <svg width="22" height="22" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
      <circle cx="6" cy="11" r="2" /><circle cx="10.5" cy="6.5" r="2" /><circle cx="15.5" cy="6.5" r="2" /><circle cx="19" cy="11" r="2" />
      <path d="M12.5 12c2.2 0 4 1.6 4 3.6 0 1.6-1.3 2.4-2.7 2.4-.9 0-1-.3-1.8-.3s-.9.3-1.8.3c-1.4 0-2.7-.8-2.7-2.4 0-2 1.8-3.6 4-3.6z" />
    </svg>
  );
}
function IconPerson() {
  return (
    <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
      <circle cx="12" cy="8" r="3.5" /><path d="M5 20a7 7 0 0 1 14 0" />
    </svg>
  );
}

// ── Cadence control: switch every 4 weeks <-> every 2 weeks ─────────────
// Only for an active recurring plan. Same price either way (the server
// enforces that; this is just the chooser). One tap to switch.
function CadenceControl({ subscription, onChanged, toast }) {
  const [busy, setBusy] = useState(false);
  const current = subscription.cadence;

  if (subscription.status !== 'active') return null;
  if (current !== '4wk' && current !== '2wk') return null;

  async function pick(next) {
    if (next === current || busy) return;
    setBusy(true);
    let res;
    try {
      res = await changeCadence(next);
    } catch {
      res = { ok: false, error: 'network' };
    }
    setBusy(false);
    if (res && res.ok) {
      if (toast) toast(next === '2wk' ? 'Switched to every 2 weeks.' : 'Switched to every 4 weeks.');
      if (onChanged) await onChanged();
    } else if (toast) {
      toast('Could not change your cadence. Please try again.', true);
    }
  }

  return (
    <div className="pt-cadence">
      <div className="pt-cadence__seg" role="group" aria-label="Visit cadence">
        {[['4wk', 'Every 4 weeks'], ['2wk', 'Every 2 weeks']].map(([val, label]) => (
          <button
            key={val}
            type="button"
            className={`pt-cadence__opt${current === val ? ' pt-cadence__opt--on' : ''}`}
            aria-pressed={current === val}
            disabled={busy}
            onClick={() => pick(val)}
          >
            {label}
          </button>
        ))}
      </div>
      <div className="pt-cadence__hint">Same price either way. Every 2 weeks just keeps the coat fresher.</div>
    </div>
  );
}

// ── Plan actions: pause, restart, cancel ───────────────────────────────
// Active  -> Pause plan, Cancel plan (each with a confirm step: two taps).
// Paused  -> Restart plan, Cancel plan.
// Cancelled -> nothing (the banner up top already explains it).
function PlanActions({ subscription, onChanged, toast }) {
  const [mode, setMode] = useState('idle'); // 'idle' | 'confirmPause' | 'confirmCancel'
  const [busy, setBusy] = useState(false);
  const status = subscription.status;

  if (status === 'cancelled') return null;

  async function run(fn, successMsg) {
    setBusy(true);
    let res;
    try {
      res = await fn();
    } catch {
      res = { ok: false, error: 'network' };
    }
    setBusy(false);
    if (res && res.ok) {
      setMode('idle');
      if (toast) toast(successMsg);
      if (onChanged) await onChanged();
    } else if (toast) {
      toast(humanError(res), true);
    }
  }

  if (mode === 'confirmCancel') {
    return (
      <div className="pt-confirm">
        <div className="pt-confirm__text">
          Cancel your plan? This takes any upcoming visit off the schedule.
          You can book again any time.
        </div>
        <div className="pt-confirm__row">
          <button className="pt-btn pt-btn-danger pt-btn-sm" disabled={busy}
            onClick={() => run(cancelSubscription, 'Plan cancelled.')}>
            {busy ? <span className="pt-spinner-sm" /> : 'Yes, cancel plan'}
          </button>
          <button className="pt-btn pt-btn-ghost pt-btn-sm" disabled={busy}
            onClick={() => setMode('idle')}>
            Keep plan
          </button>
        </div>
      </div>
    );
  }

  if (mode === 'confirmPause') {
    return (
      <div className="pt-confirm">
        <div className="pt-confirm__text">
          Pause your plan? We hold your spot and take any upcoming visit off
          the schedule until you restart. No visits, no charges while paused.
        </div>
        <div className="pt-confirm__row">
          <button className="pt-btn pt-btn-primary pt-btn-sm" disabled={busy}
            onClick={() => run(pauseSubscription, 'Plan paused.')}>
            {busy ? <span className="pt-spinner-sm" /> : 'Yes, pause'}
          </button>
          <button className="pt-btn pt-btn-ghost pt-btn-sm" disabled={busy}
            onClick={() => setMode('idle')}>
            Keep active
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className="pt-plan-actions">
      {status === 'paused' && (
        <button className="pt-btn pt-btn-primary pt-btn-sm" disabled={busy}
          onClick={() => run(resumeSubscription, 'Plan restarted.')}>
          {busy ? <span className="pt-spinner-sm" /> : 'Restart plan'}
        </button>
      )}
      {status === 'active' && (
        <button className="pt-btn pt-btn-secondary pt-btn-sm"
          onClick={() => setMode('confirmPause')}>
          Pause plan
        </button>
      )}
      <button className="pt-btn pt-btn-ghost pt-btn-sm"
        onClick={() => setMode('confirmCancel')}>
        Cancel plan
      </button>
    </div>
  );
}

function humanError(res) {
  const e = res && res.error;
  if (e === 'no_active_subscription') return 'No active plan to change.';
  if (e === 'no_paused_subscription') return 'Your plan is not paused.';
  if (e === 'too_late') return 'Changes close 24 hours before your visit.';
  if (e === 'slot_unavailable') return 'That time is no longer open. Pick another.';
  if (e === 'not_found') return 'That visit could not be found.';
  if (e === 'not_skippable' || e === 'not_reschedulable') return 'That visit can no longer be changed.';
  return 'Something went wrong. Please try again.';
}

// ── Visit actions: reschedule, skip (the upcoming visit) ────────────────
// Locked inside the 24-hour window (matches the charge window). Reschedule
// only lands on a free slot the server revalidates: no human in the loop.
function VisitActions({ appt, city, onChanged, toast }) {
  const [mode, setMode] = useState('idle'); // 'idle' | 'confirmSkip' | 'pickSlot'
  const [busy, setBusy] = useState(false);

  const hoursUntil = appt.scheduled_start
    ? (new Date(appt.scheduled_start).getTime() - Date.now()) / 3600000
    : null;
  const locked = hoursUntil !== null && hoursUntil < 24;

  if (locked) {
    return (
      <div className="pt-locked-note">
        This visit is locked in. Changes close 24 hours before.
      </div>
    );
  }

  async function run(fn, successMsg) {
    setBusy(true);
    let res;
    try {
      res = await fn();
    } catch {
      res = { ok: false, error: 'network' };
    }
    setBusy(false);
    if (res && res.ok) {
      setMode('idle');
      if (toast) toast(successMsg);
      if (onChanged) await onChanged();
    } else if (toast) {
      toast(humanError(res), true);
    }
  }

  if (mode === 'confirmSkip') {
    return (
      <div className="pt-confirm">
        <div className="pt-confirm__text">
          Skip this visit? It comes off the schedule. Your plan stays active.
        </div>
        <div className="pt-confirm__row">
          <button className="pt-btn pt-btn-danger pt-btn-sm" disabled={busy}
            onClick={() => run(() => skipAppointment(appt.id), 'Visit skipped.')}>
            {busy ? <span className="pt-spinner-sm" /> : 'Yes, skip it'}
          </button>
          <button className="pt-btn pt-btn-ghost pt-btn-sm" disabled={busy}
            onClick={() => setMode('idle')}>
            Keep visit
          </button>
        </div>
      </div>
    );
  }

  if (mode === 'pickSlot') {
    return (
      <SlotPicker
        city={city}
        busy={busy}
        onPick={(slotStart) => run(() => rescheduleAppointment(appt.id, slotStart), 'Visit moved.')}
        onCancel={() => setMode('idle')}
      />
    );
  }

  return (
    <div className="pt-visit-actions">
      <button className="pt-btn pt-btn-secondary pt-btn-sm" onClick={() => setMode('pickSlot')}>
        Reschedule
      </button>
      <button className="pt-btn pt-btn-ghost pt-btn-sm" onClick={() => setMode('confirmSkip')}>
        Skip this visit
      </button>
    </div>
  );
}

// ── Slot picker: live open times from bath_open_slots ──────────────────
function SlotPicker({ city, busy, onPick, onCancel }) {
  const [state, setState] = useState('loading'); // 'loading' | 'ready' | 'error'
  const [slots, setSlots] = useState([]);
  const [selected, setSelected] = useState(null);

  useEffect(() => {
    let alive = true;
    (async () => {
      if (!city || !city.id) { setState('ready'); setSlots([]); return; }
      const res = await getOpenSlots(city.id);
      if (!alive) return;
      if (res.error) { setState('error'); return; }
      setSlots(res.slots || []);
      setState('ready');
    })();
    return () => { alive = false; };
  }, [city]);

  // Group slots by local calendar day.
  const days = [];
  const byDay = new Map();
  for (const s of slots) {
    const key = new Date(s.slot_start).toLocaleDateString('en-US', { timeZone: tz(city) });
    if (!byDay.has(key)) { byDay.set(key, []); days.push(key); }
    byDay.get(key).push(s);
  }

  return (
    <div className="pt-slotpicker">
      <div className="pt-slotpicker__head">Pick a new time</div>

      {state === 'loading' && (
        <div className="pt-slotpicker__msg"><span className="pt-spinner-sm" /> Loading open times...</div>
      )}
      {state === 'error' && (
        <div className="pt-slotpicker__msg">Could not load open times. Try again.</div>
      )}
      {state === 'ready' && slots.length === 0 && (
        <div className="pt-slotpicker__msg">No open times right now. Check back soon.</div>
      )}

      {state === 'ready' && slots.length > 0 && (
        <div className="pt-slotpicker__days">
          {days.map(day => (
            <div className="pt-slot-day" key={day}>
              <div className="pt-slot-day__label">{fmtDate(byDay.get(day)[0].slot_start, city)}</div>
              <div className="pt-slot-grid">
                {byDay.get(day).map(s => (
                  <button
                    key={s.slot_start}
                    className={`pt-slot${selected === s.slot_start ? ' pt-slot--selected' : ''}`}
                    onClick={() => setSelected(s.slot_start)}
                  >
                    {fmtTime(s.slot_start, city)}
                  </button>
                ))}
              </div>
            </div>
          ))}
        </div>
      )}

      <div className="pt-confirm__row" style={{ marginTop: 'var(--space-md)' }}>
        <button className="pt-btn pt-btn-primary pt-btn-sm" disabled={!selected || busy}
          onClick={() => onPick(selected)}>
          {busy ? <span className="pt-spinner-sm" /> : 'Confirm new time'}
        </button>
        <button className="pt-btn pt-btn-ghost pt-btn-sm" disabled={busy} onClick={onCancel}>
          Back
        </button>
      </div>
    </div>
  );
}

// ── Pack section: view, add, edit, remove dogs ──────────────────────────
// Add lets the client pick coat tier (same as booking, since it is a new
// dog). Edit keeps coat tier read-only, because coat tier sets the price
// tier and the in-person assessment owns that. The 3-dog cap is enforced by
// the database trigger; here the Add control simply hides at 3.
function PackSection({ dogs, subscriberId, onChanged, toast }) {
  const [editing, setEditing] = useState(null); // null | dogId | 'new'
  const [busy, setBusy] = useState(false);

  async function run(fn, successMsg) {
    setBusy(true);
    let res;
    try { res = await fn(); } catch { res = { ok: false, error: 'network' }; }
    setBusy(false);
    if (res && res.ok) {
      setEditing(null);
      if (toast) toast(successMsg);
      if (onChanged) await onChanged();
      return true;
    }
    if (toast) toast(packError(res), true);
    return false;
  }

  // No hard cap on dog count: visit time and route capacity are the real
  // limits (three_dog_cap was the borrowed Villages residency number, lifted).
  const canAdd = true;

  return (
    <>
      {dogs.length > 0 ? (
        <div className="pt-card">
          {dogs.map(d => (
            editing === d.id ? (
              <DogForm
                key={d.id}
                mode="edit"
                busy={busy}
                initial={d}
                onSave={(form) => run(() => updateDog(d.id, form), 'Saved.')}
                onRemove={() => run(() => removeDog(d.id), `${d.name} removed.`)}
                onCancel={() => setEditing(null)}
              />
            ) : (
              <div className="pt-dog" key={d.id}>
                <div className="pt-dog__head">
                  <div className="pt-dog__name">{d.name}</div>
                  <button className="pt-dog__edit" onClick={() => setEditing(d.id)}>Edit</button>
                </div>
                {(() => {
                  const bits = [d.breed, coatLabel(d.coat_tier), ageFromBirthDate(d.birth_date, d.dob_approximate)].filter(Boolean);
                  return bits.length > 0 ? <div className="pt-dog__meta">{bits.join(' · ')}</div> : null;
                })()}
                {d.behavior_notes && <div className="pt-dog__notes">{d.behavior_notes}</div>}
              </div>
            )
          ))}
        </div>
      ) : (
        editing !== 'new' && <div className="pt-card pt-card--muted">No dogs on file yet.</div>
      )}

      {editing === 'new' ? (
        <div className="pt-card" style={{ marginTop: 'var(--space-sm)' }}>
          <DogForm
            mode="add"
            busy={busy}
            initial={{}}
            onSave={(form) => run(() => addDog({ subscriberId, ...form }), `${form.name} added.`)}
            onCancel={() => setEditing(null)}
          />
        </div>
      ) : (
        canAdd && (
          <button
            className="pt-btn pt-btn-secondary pt-btn-sm"
            style={{ marginTop: 'var(--space-sm)' }}
            onClick={() => setEditing('new')}
          >
            Add a dog
          </button>
        )
      )}
    </>
  );
}

function DogForm({ mode, initial, busy, onSave, onCancel, onRemove }) {
  const [name, setName] = useState(initial.name || '');
  const [breed, setBreed] = useState(initial.breed || '');
  const [coatTier, setCoatTier] = useState(initial.coat_tier || '');
  const [behaviorNotes, setBehaviorNotes] = useState(initial.behavior_notes || '');
  const [confirmRemove, setConfirmRemove] = useState(false);

  const isAdd = mode === 'add';
  const canSave = name.trim().length > 0 && (!isAdd || coatTier === 'smoothcoat' || coatTier === 'doublecoat');

  function submit() {
    if (!canSave) return;
    const form = { name: name.trim(), breed: breed.trim(), behaviorNotes: behaviorNotes.trim() };
    if (isAdd) form.coatTier = coatTier;
    onSave(form);
  }

  return (
    <div className="pt-dogform">
      <div className="pt-field">
        <label>Name</label>
        <input className="pt-input" value={name} onChange={e => setName(e.target.value)} autoFocus />
      </div>
      <div className="pt-field">
        <label>Breed</label>
        <input className="pt-input" value={breed} onChange={e => setBreed(e.target.value)} placeholder="Optional" />
      </div>
      {isAdd ? (
        <div className="pt-field">
          <label>Coat</label>
          <div className="pt-coat-choose">
            {[['smoothcoat', 'Smooth coat'], ['doublecoat', 'Double coat']].map(([val, label]) => (
              <button
                key={val}
                type="button"
                className={`pt-coat-opt${coatTier === val ? ' pt-coat-opt--on' : ''}`}
                onClick={() => setCoatTier(val)}
              >
                {label}
              </button>
            ))}
          </div>
        </div>
      ) : (
        initial.coat_tier && (
          <div className="pt-field">
            <label>Coat</label>
            <div className="pt-dog__meta" style={{ marginTop: 2 }}>{coatLabel(initial.coat_tier)}</div>
          </div>
        )
      )}
      <div className="pt-field">
        <label>Behavior notes</label>
        <textarea
          className="pt-input"
          rows={2}
          value={behaviorNotes}
          onChange={e => setBehaviorNotes(e.target.value)}
          placeholder="Anything we should know"
        />
      </div>

      <div className="pt-confirm__row">
        <button className="pt-btn pt-btn-primary pt-btn-sm" disabled={!canSave || busy} onClick={submit}>
          {busy ? <span className="pt-spinner-sm" /> : (isAdd ? 'Add dog' : 'Save')}
        </button>
        <button className="pt-btn pt-btn-ghost pt-btn-sm" disabled={busy} onClick={onCancel}>Cancel</button>
      </div>

      {!isAdd && onRemove && (
        confirmRemove ? (
          <div className="pt-confirm" style={{ marginTop: 'var(--space-sm)' }}>
            <div className="pt-confirm__text">Remove {initial.name} from your pack?</div>
            <div className="pt-confirm__row">
              <button className="pt-btn pt-btn-danger pt-btn-sm" disabled={busy} onClick={onRemove}>
                {busy ? <span className="pt-spinner-sm" /> : 'Yes, remove'}
              </button>
              <button className="pt-btn pt-btn-ghost pt-btn-sm" disabled={busy} onClick={() => setConfirmRemove(false)}>Keep</button>
            </div>
          </div>
        ) : (
          <button className="pt-dog__remove" onClick={() => setConfirmRemove(true)}>Remove dog</button>
        )
      )}
    </div>
  );
}

function packError(res) {
  const e = (res && res.error) || '';
  if (/dog_cap_exceeded/.test(e)) return 'You already have the maximum number of dogs.';
  return 'Something went wrong. Please try again.';
}

// ── Profile section: view + edit contact details and preferences ────────
// Service address is shown read-only here: changing it needs the in-area
// verification flow and lands in its own slice. Everything else is editable.
function ProfileSection({ subscriber, city, onChanged, toast }) {
  const [mode, setMode] = useState('view'); // 'view' | 'contact' | 'address'

  if (mode === 'contact') {
    return (
      <ProfileForm
        subscriber={subscriber}
        onCancel={() => setMode('view')}
        onSaved={async () => { setMode('view'); if (onChanged) await onChanged(); }}
        toast={toast}
      />
    );
  }

  if (mode === 'address') {
    return (
      <AddressEditor
        subscriber={subscriber}
        city={city}
        onCancel={() => setMode('view')}
        onSaved={async () => { setMode('view'); if (onChanged) await onChanged(); }}
        toast={toast}
      />
    );
  }

  return (
    <div className="pt-card">
      <div className="pt-card__row">
        <span className="pt-card__label">Name</span>
        <span className="pt-card__value">
          {[subscriber.first_name, subscriber.last_name].filter(Boolean).join(' ') || '-'}
        </span>
      </div>
      {subscriber.phone_e164 && (
        <div className="pt-card__row">
          <span className="pt-card__label">Phone</span>
          <span className="pt-card__value">{formatPhone(subscriber.phone_e164)}</span>
        </div>
      )}
      {subscriber.email && (
        <div className="pt-card__row">
          <span className="pt-card__label">Email</span>
          <span className="pt-card__value">{subscriber.email}</span>
        </div>
      )}
      <div className="pt-card__row">
        <span className="pt-card__label">Service address</span>
        <span className="pt-card__value">
          {formatAddress(subscriber)}
          <button className="pt-inline-link" onClick={() => setMode('address')}>Change</button>
        </span>
      </div>
      {subscriber.gate_code && (
        <div className="pt-card__row">
          <span className="pt-card__label">Gate code</span>
          <span className="pt-card__value">{subscriber.gate_code}</span>
        </div>
      )}
      <div className="pt-card__row">
        <span className="pt-card__label">Text reminders</span>
        <span className="pt-card__value">{subscriber.sms_opt_in ? 'On' : 'Off'}</span>
      </div>
      <div className="pt-card__row">
        <span className="pt-card__label">Email updates</span>
        <span className="pt-card__value">{subscriber.email_opt_in ? 'On' : 'Off'}</span>
      </div>
      <button className="pt-btn pt-btn-secondary pt-btn-sm" style={{ marginTop: 'var(--space-md)' }}
        onClick={() => setMode('contact')}>
        Edit details
      </button>
    </div>
  );
}

// ── Address editor: Google Places autocomplete + in-area gate ───────────
// Mirrors the booking funnel: pick from Places, check the point against the
// city polygon client-side for instant feedback, and the server re-verifies
// on save. No manual address path: an address we cannot verify in-area is
// not savable.
function AddressEditor({ subscriber, city, onCancel, onSaved, toast }) {
  const boxRef = useRef(null);
  const elRef = useRef(null);
  const cityRef = useRef(city);
  useEffect(() => { cityRef.current = city; }, [city]);

  const [mapsReady, setMapsReady] = useState(false);
  const [mapsFailed, setMapsFailed] = useState(false);
  const [picked, setPicked] = useState(null);
  const [areaStatus, setAreaStatus] = useState(null); // null | 'pass' | 'fail'
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState('');

  useEffect(() => {
    let alive = true;
    loadGoogleMaps().then(() => { if (alive) setMapsReady(true); }).catch(() => { if (alive) setMapsFailed(true); });
    return () => { alive = false; };
  }, []);

  useEffect(() => {
    if (!mapsReady || !boxRef.current || elRef.current) return undefined;
    const places = window.google && window.google.maps && window.google.maps.places;
    if (!places || !places.PlaceAutocompleteElement) { setMapsFailed(true); return undefined; }
    const opts = { includedRegionCodes: ['us'] };
    const bias = polygonBounds(cityRef.current);
    if (bias) opts.locationBias = bias;
    const el = new places.PlaceAutocompleteElement(opts);
    el.style.width = '100%';
    boxRef.current.appendChild(el);
    elRef.current = el;

    async function onSelect(event) {
      try {
        const place = event.placePrediction ? event.placePrediction.toPlace() : event.place;
        if (!place) { setAreaStatus('fail'); return; }
        await place.fetchFields({ fields: ['formattedAddress', 'addressComponents', 'location'] });
        const parsed = parsePlace(place);
        setPicked(parsed);
        setErr('');
        setAreaStatus(isInServiceArea(parsed.lat, parsed.lng, cityRef.current) ? 'pass' : 'fail');
      } catch {
        setAreaStatus('fail');
      }
    }
    el.addEventListener('gmp-select', onSelect);
    el.addEventListener('gmp-placeselect', onSelect);
    return () => {
      el.removeEventListener('gmp-select', onSelect);
      el.removeEventListener('gmp-placeselect', onSelect);
      el.remove();
      if (elRef.current === el) elRef.current = null;
    };
  }, [mapsReady]);

  async function save() {
    if (!picked || areaStatus !== 'pass') return;
    setBusy(true);
    let res;
    try {
      res = await updateServiceAddress({
        line1: picked.line1, city: picked.city, state: picked.state || 'FL',
        zip: picked.zip, lat: picked.lat, lng: picked.lng,
      });
    } catch { res = { ok: false, error: 'network' }; }
    setBusy(false);
    if (res && res.ok) {
      if (toast) toast('Service address updated.');
      await onSaved();
    } else {
      setErr(res && res.error === 'out_of_area'
        ? 'That address is outside the service area.'
        : 'Could not save the address. Please try again.');
    }
  }

  return (
    <div className="pt-card">
      <div className="pt-slotpicker__head">New service address</div>

      {mapsFailed ? (
        <>
          <div className="pt-slotpicker__msg">Address lookup is not available right now. Try again in a moment.</div>
          <div className="pt-confirm__row"><button className="pt-btn pt-btn-ghost pt-btn-sm" onClick={onCancel}>Back</button></div>
        </>
      ) : (
        <>
          <div className="pt-address-box" ref={boxRef} />
          {!mapsReady && <div className="pt-slotpicker__msg"><span className="pt-spinner-sm" /> Loading address lookup...</div>}

          {picked && (
            <div className="pt-address-preview">
              <div className="pt-address-preview__line">{picked.formatted || `${picked.line1}, ${picked.city} ${picked.state} ${picked.zip}`}</div>
              {areaStatus === 'fail' && (
                <div className="pt-error-msg">That address is outside the Villages service area.</div>
              )}
              {areaStatus === 'pass' && (
                <div className="pt-address-preview__ok">In the service area.</div>
              )}
            </div>
          )}

          {err && <div className="pt-error-msg" style={{ marginTop: 'var(--space-sm)' }}>{err}</div>}

          <div className="pt-confirm__row" style={{ marginTop: 'var(--space-md)' }}>
            <button className="pt-btn pt-btn-primary pt-btn-sm" disabled={!picked || areaStatus !== 'pass' || busy} onClick={save}>
              {busy ? <span className="pt-spinner-sm" /> : 'Save address'}
            </button>
            <button className="pt-btn pt-btn-ghost pt-btn-sm" disabled={busy} onClick={onCancel}>Cancel</button>
          </div>
        </>
      )}
    </div>
  );
}

function ProfileForm({ subscriber, onCancel, onSaved, toast }) {
  const [firstName, setFirstName] = useState(subscriber.first_name || '');
  const [lastName, setLastName] = useState(subscriber.last_name || '');
  const [phone, setPhone] = useState(subscriber.phone_e164 ? formatPhone(subscriber.phone_e164) : '');
  const [email, setEmail] = useState(subscriber.email || '');
  const [gateCode, setGateCode] = useState(subscriber.gate_code || '');
  const [smsOptIn, setSmsOptIn] = useState(subscriber.sms_opt_in !== false);
  const [emailOptIn, setEmailOptIn] = useState(subscriber.email_opt_in !== false);
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState('');

  async function save() {
    if (!firstName.trim()) { setErr('Please enter your name.'); return; }
    let phoneE164 = null;
    if (phone.trim()) {
      phoneE164 = toE164US(phone);
      if (!phoneE164) { setErr('Enter a valid US phone number, or leave it blank.'); return; }
    }
    if (email.trim() && !email.includes('@')) { setErr('Enter a valid email, or leave it blank.'); return; }
    setErr('');
    setBusy(true);
    let res;
    try {
      res = await updateProfile({
        firstName: firstName.trim(), lastName: lastName.trim(), phoneE164,
        email: email.trim(), gateCode: gateCode.trim(), smsOptIn, emailOptIn,
      });
    } catch { res = { ok: false, error: 'network' }; }
    setBusy(false);
    if (res && res.ok) {
      if (toast) toast('Details saved.');
      await onSaved();
    } else {
      setErr(res && res.error === 'invalid_phone'
        ? 'Enter a valid US phone number, or leave it blank.'
        : 'Could not save. Please try again.');
    }
  }

  return (
    <div className="pt-card">
      <div className="pt-form-grid">
        <div className="pt-field">
          <label>First name</label>
          <input className="pt-input" value={firstName} onChange={e => setFirstName(e.target.value)} autoFocus />
        </div>
        <div className="pt-field">
          <label>Last name</label>
          <input className="pt-input" value={lastName} onChange={e => setLastName(e.target.value)} placeholder="Optional" />
        </div>
      </div>
      <div className="pt-field">
        <label>Phone</label>
        <input className="pt-input" type="tel" inputMode="tel" value={phone}
          onChange={e => setPhone(e.target.value)} placeholder="(352) 555-0100" />
      </div>
      <div className="pt-field">
        <label>Email</label>
        <input className="pt-input" type="email" value={email}
          onChange={e => setEmail(e.target.value)} placeholder="you@example.com" />
      </div>
      <div className="pt-field">
        <label>Gate code</label>
        <input className="pt-input" value={gateCode}
          onChange={e => setGateCode(e.target.value)} placeholder="Optional" />
      </div>

      <label className="pt-toggle">
        <input type="checkbox" checked={smsOptIn} onChange={e => setSmsOptIn(e.target.checked)} />
        <span>Text reminders before each visit</span>
      </label>
      <label className="pt-toggle">
        <input type="checkbox" checked={emailOptIn} onChange={e => setEmailOptIn(e.target.checked)} />
        <span>Email updates</span>
      </label>

      <div className="pt-profile-addr-note">
        Service address: {formatAddress(subscriber)}
      </div>

      {err && <div className="pt-error-msg" style={{ marginTop: 'var(--space-sm)' }}>{err}</div>}

      <div className="pt-confirm__row" style={{ marginTop: 'var(--space-md)' }}>
        <button className="pt-btn pt-btn-primary pt-btn-sm" disabled={busy} onClick={save}>
          {busy ? <span className="pt-spinner-sm" /> : 'Save details'}
        </button>
        <button className="pt-btn pt-btn-ghost pt-btn-sm" disabled={busy} onClick={onCancel}>Cancel</button>
      </div>
    </div>
  );
}

// ── small shared helpers (kept local to the portal island) ─────────────
function greetByTime() {
  const h = new Date().getHours();
  if (h < 12) return 'Good morning';
  if (h < 18) return 'Good afternoon';
  return 'Good evening';
}

function formatPhone(e164) {
  if (!e164) return '';
  const m = String(e164).match(/^\+1(\d{3})(\d{3})(\d{4})$/);
  return m ? `(${m[1]}) ${m[2]}-${m[3]}` : e164;
}

function formatAddress(s) {
  const line1 = s.address_line_1;
  const cityState = [s.address_city, s.address_state].filter(Boolean).join(', ');
  const tail = [cityState, s.address_zip].filter(Boolean).join(' ');
  return [line1, tail].filter(Boolean).join(', ') || '-';
}

function pickFirstName(authUser) {
  if (!authUser) return '';
  const md = authUser.user_metadata || {};
  if (md.first_name) return md.first_name;
  if (md.given_name) return md.given_name;
  if (md.full_name) return String(md.full_name).split(' ')[0];
  if (md.name) return String(md.name).split(' ')[0];
  if (authUser.email) return authUser.email.split('@')[0];
  return '';
}
