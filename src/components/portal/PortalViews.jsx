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

import './portal.css';

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

function cadenceLabel(cadence) {
  if (cadence === '4wk') return 'Every 4 weeks';
  if (cadence === '2wk') return 'Every 2 weeks';
  if (cadence === 'oneoff') return 'Single visit';
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
export function PortalHome({ data, onLogout }) {
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

  return (
    <div className="pt-content">
      <div className="pt-home">
        <header className="pt-home__head">
          <div>
            <div className="pt-home__greeting">{greetByTime()}</div>
            <h1 className="pt-home__name">{firstName ? `Hi, ${firstName}` : 'Hi there'}</h1>
          </div>
          <button className="pt-signout-link" onClick={onLogout}>Sign out</button>
        </header>

        {planStatus === 'paused' && (
          <div className="pt-banner pt-banner--warn">
            Your plan is paused. No visits are scheduled until you restart it.
          </div>
        )}
        {planStatus === 'cancelled' && (
          <div className="pt-banner pt-banner--muted">
            Your plan is cancelled. Book again any time to come back on the route.
          </div>
        )}

        {/* Next visit */}
        <section className="pt-section">
          <h2 className="pt-section__title">Next visit</h2>
          {nextAppt ? (
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
          ) : (
            <div className="pt-hero pt-hero--empty">
              <div className="pt-hero__date">No upcoming visit</div>
              <div className="pt-hero__meta">
                {planStatus === 'active'
                  ? 'Your next visit will appear here once it is scheduled.'
                  : 'Book a visit to get back on the route.'}
              </div>
            </div>
          )}
        </section>

        {/* Plan */}
        {subscription && (
          <section className="pt-section">
            <h2 className="pt-section__title">Your plan</h2>
            <div className="pt-card">
              <div className="pt-card__row">
                <span className="pt-card__label">Cadence</span>
                <span className="pt-card__value">{cadenceLabel(subscription.cadence)}</span>
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
          </section>
        )}

        {/* Pack */}
        <section className="pt-section">
          <h2 className="pt-section__title">Your pack</h2>
          {dogs.length > 0 ? (
            <div className="pt-card">
              {dogs.map(d => {
                const age = ageFromBirthDate(d.birth_date, d.dob_approximate);
                const bits = [d.breed, coatLabel(d.coat_tier), age].filter(Boolean);
                return (
                  <div className="pt-dog" key={d.id}>
                    <div className="pt-dog__name">{d.name}</div>
                    {bits.length > 0 && <div className="pt-dog__meta">{bits.join(' · ')}</div>}
                    {d.behavior_notes && <div className="pt-dog__notes">{d.behavior_notes}</div>}
                  </div>
                );
              })}
            </div>
          ) : (
            <div className="pt-card pt-card--muted">No dogs on file yet.</div>
          )}
        </section>

        {/* Profile */}
        <section className="pt-section">
          <h2 className="pt-section__title">Your details</h2>
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
              <span className="pt-card__value">{formatAddress(subscriber)}</span>
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
          </div>
        </section>

        {/* History */}
        {history.length > 0 && (
          <section className="pt-section">
            <h2 className="pt-section__title">Visit history</h2>
            <div className="pt-appt-list">
              {history.map(a => (
                <div className="pt-appt" key={a.id}>
                  <div className="pt-appt__date">
                    <div className="pt-appt__date-main">{fmtDateShort(a.scheduled_start, city)}</div>
                    <div className="pt-appt__date-time">{fmtTime(a.scheduled_start, city)}</div>
                  </div>
                  <StatusChip status={a.status} />
                  {a.amount_cents > 0 && <span className="pt-appt__price">{dollars(a.amount_cents)}</span>}
                </div>
              ))}
            </div>
          </section>
        )}

        <div className="pt-home__foot">
          <button className="pt-signout-link" onClick={onLogout}>Sign out</button>
        </div>
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
