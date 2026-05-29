// src/components/portal/BookingApp.jsx
//
// Hurricane Bath signup funnel (the /book flow). Low-friction shape: NO
// sign-in wall. The funnel runs anonymously (fit check -> place + dogs ->
// plan -> real slot picker -> review); the client only signs in at the
// final step, to save a card on file and confirm. Google sign-in is
// offered early as an optional name/email prefill.
//
// Built against real services from the first commit (no_mockups):
// Supabase for auth, live city pricing from the city row, genuinely open
// slots from bath_open_slots, and the bath_start_subscription RPC (which
// requires auth.uid(), satisfied by the end-of-funnel sign-in).
//
// A Google OAuth sign-in redirects the tab, which would wipe in-progress
// React state, so the funnel persists to sessionStorage and restores on
// return. The card-on-file step is gated until the Stripe SetupIntent
// slice lands (no fake card form). Google Places address autocomplete +
// polygon service-area check is its own slice (needs the Clean Maps key
// and the real Villages polygon); until then the address is typed plainly.

import { useState, useEffect, useCallback, useRef } from 'react';
import './portal.css';
import './booking.css';
import {
  sb, getBookingCity, getOpenSlots, signInWithGoogle, signOut, toE164US,
} from './supabase.js';
import AuthScreen from './AuthScreen.jsx';

const CITY_SLUG = 'the-villages';
const STEPS = ['start', 'dogs', 'plan', 'time', 'review'];
const STEP_LABELS = { start: 'Start', dogs: 'Dogs', plan: 'Plan', time: 'Time', review: 'Confirm' };
const STORE_KEY = 'dgc_booking_v1';

function dollars(cents) {
  if (cents == null) return null;
  const d = cents / 100;
  return Number.isInteger(d) ? `$${d}` : `$${d.toFixed(2)}`;
}

// Per-dog price for its OWN coat tier at the chosen cadence. Recurring
// shows the founders rate; one-off shows the single price.
function dogTierCents(city, tier, cadence) {
  if (!city || (tier !== 'smoothcoat' && tier !== 'doublecoat')) return null;
  if (cadence === 'oneoff') {
    return tier === 'doublecoat' ? city.hb_doublecoat_single_cents : city.hb_smoothcoat_single_cents;
  }
  return tier === 'doublecoat' ? city.hb_founders_doublecoat_cents : city.hb_founders_smoothcoat_cents;
}

// Visit total: every dog at its own tier, most-expensive first, with the
// per-additional-dog discount stacking down the line (matches the city
// page and the bath_start_subscription RPC).
function visitPriceCents(city, dogs, cadence) {
  if (!city) return null;
  const prices = dogs.map((d) => dogTierCents(city, d.coat_tier, cadence));
  if (prices.some((p) => p == null)) return null;
  const decrement = city.hb_addon_decrement_cents || 0;
  return [...prices].sort((a, b) => b - a).reduce((sum, c, i) => sum + Math.max(0, c - decrement * i), 0);
}

const slotFmt = new Intl.DateTimeFormat('en-US', {
  timeZone: 'America/New_York', weekday: 'short', month: 'short', day: 'numeric',
});
const timeFmt = new Intl.DateTimeFormat('en-US', {
  timeZone: 'America/New_York', hour: 'numeric', minute: '2-digit',
});

const BLANK = {
  step: 'start',
  fitOk: false,
  place: { firstName: '', lastName: '', phone: '', email: '', addressLine1: '', addressCity: '', addressState: 'FL', addressZip: '' },
  dogs: [{ name: '', breed: '', coat_tier: '' }],
  cadence: '4wk',
  chosenSlot: null,
};

function loadStored() {
  if (typeof window === 'undefined') return null;
  try {
    const raw = sessionStorage.getItem(STORE_KEY);
    return raw ? JSON.parse(raw) : null;
  } catch { return null; }
}

export default function BookingApp() {
  const [authState, setAuthState] = useState('checking');
  const [authUser, setAuthUser] = useState(null);
  const [city, setCity] = useState(null);
  const [cityError, setCityError] = useState(null);

  // Restore an in-progress funnel (survives a Google OAuth redirect).
  const restored = useRef(loadStored());
  const init = restored.current || BLANK;
  const [step, setStep] = useState(init.step || 'start');
  const [fitOk, setFitOk] = useState(!!init.fitOk);
  const [place, setPlace] = useState(init.place || BLANK.place);
  const [dogs, setDogs] = useState(init.dogs || BLANK.dogs);
  const [cadence, setCadence] = useState(init.cadence || '4wk');
  const [chosenSlot, setChosenSlot] = useState(init.chosenSlot || null);

  const [slots, setSlots] = useState(null);
  const [slotsLoading, setSlotsLoading] = useState(false);
  const [error, setError] = useState('');

  // Honor /book?plan=single (the single-visit CTA) on a fresh funnel.
  useEffect(() => {
    if (restored.current) return;
    const params = new URLSearchParams(window.location.search);
    if (params.get('plan') === 'single') setCadence('oneoff');
  }, []);

  // Persist the funnel so a sign-in redirect does not lose progress.
  useEffect(() => {
    try {
      sessionStorage.setItem(STORE_KEY, JSON.stringify({ step, fitOk, place, dogs, cadence, chosenSlot }));
    } catch { /* sessionStorage unavailable; not fatal */ }
  }, [step, fitOk, place, dogs, cadence, chosenSlot]);

  // Auth listener: set state only (auth_listener_sets_state_only).
  useEffect(() => {
    const client = sb();
    if (!client) return;
    const { data: { subscription } } = client.auth.onAuthStateChange((event, session) => {
      if (event === 'INITIAL_SESSION') setAuthState(session ? 'authenticated' : 'anonymous');
      else if (event === 'SIGNED_IN') setAuthState('authenticated');
      else if (event === 'SIGNED_OUT') { setAuthState('anonymous'); setAuthUser(null); }
    });
    return () => subscription.unsubscribe();
  }, []);

  // City pricing loads regardless of auth (cities is anon-readable).
  useEffect(() => {
    let cancelled = false;
    (async () => {
      const { city: c, error: ce } = await getBookingCity(CITY_SLUG);
      if (cancelled) return;
      if (ce) setCityError(ce); else setCity(c);
    })();
    return () => { cancelled = true; };
  }, []);

  // On sign-in, grab the user and prefill empty name/email fields.
  useEffect(() => {
    if (authState !== 'authenticated') return;
    let cancelled = false;
    (async () => {
      const { data: { user } } = await sb().auth.getUser();
      if (cancelled || !user) return;
      setAuthUser(user);
      setPlace((p) => ({
        ...p,
        firstName: p.firstName || prefillFirst(user),
        lastName: p.lastName || prefillLast(user),
        email: p.email || user.email || '',
      }));
    })();
    return () => { cancelled = true; };
  }, [authState]);

  const loadSlots = useCallback(async () => {
    if (!city) return;
    setSlotsLoading(true);
    const { slots: s } = await getOpenSlots(city.id, city.hb_booking_horizon_days || 28);
    setSlots(s);
    setSlotsLoading(false);
  }, [city]);

  useEffect(() => {
    if (step === 'time' && slots === null && !slotsLoading) loadSlots();
  }, [step, slots, slotsLoading, loadSlots]);

  function placeValid() {
    return fitOk && place.firstName.trim() && place.addressLine1.trim() &&
      place.addressCity.trim() && place.addressZip.trim() && toE164US(place.phone);
  }
  function dogsValid() {
    return dogs.length >= 1 && dogs.length <= 3 &&
      dogs.every((d) => d.name.trim() && (d.coat_tier === 'smoothcoat' || d.coat_tier === 'doublecoat'));
  }

  function goNext() {
    setError('');
    const i = STEPS.indexOf(step);
    if (step === 'start' && !placeValid()) {
      setError(fitOk ? 'Please fill in your name, phone, and service address.' : 'Confirm the fit check to continue.');
      return;
    }
    if (step === 'dogs' && !dogsValid()) { setError('Give each dog a name and a coat type (one to three dogs).'); return; }
    if (step === 'time' && !chosenSlot) { setError('Pick a time for your first visit.'); return; }
    if (i < STEPS.length - 1) setStep(STEPS[i + 1]);
  }
  function goBack() {
    setError('');
    const i = STEPS.indexOf(step);
    if (i > 0) setStep(STEPS[i - 1]);
  }

  function updateDog(idx, field, val) { setDogs((ds) => ds.map((d, i) => (i === idx ? { ...d, [field]: val } : d))); }
  function addDog() { if (dogs.length < 3) setDogs((ds) => [...ds, { name: '', breed: '', coat_tier: '' }]); }
  function removeDog(idx) { setDogs((ds) => ds.filter((_, i) => i !== idx)); }

  if (authState === 'checking' && !restored.current) {
    return <div className="pt-center-fill"><div className="pt-spinner" /></div>;
  }

  const price = visitPriceCents(city, dogs, cadence);
  const authed = authState === 'authenticated' && authUser;

  return (
    <div className="pt-shell">
      <div className="bk-wrap">
        <BookingProgress step={step} />

        {cityError && (
          <div className="bk-card bk-notice">
            Booking is not open in this area yet. <a href="/the-villages">See where we serve</a>.
          </div>
        )}

        {!cityError && (
          <div className="bk-card">
            {step === 'start' && (
              <StartStep
                place={place} setPlace={setPlace} fitOk={fitOk} setFitOk={setFitOk}
                authed={authed} authUser={authUser}
                onGoogle={() => signInWithGoogle('/book/')}
              />
            )}
            {step === 'dogs' && <DogsStep dogs={dogs} updateDog={updateDog} addDog={addDog} removeDog={removeDog} />}
            {step === 'plan' && <PlanStep city={city} dogs={dogs} cadence={cadence} setCadence={setCadence} />}
            {step === 'time' && (
              <TimeStep slots={slots} loading={slotsLoading} chosen={chosenSlot} setChosen={setChosenSlot} onRefresh={() => setSlots(null)} />
            )}
            {step === 'review' && (
              <ReviewStep place={place} dogs={dogs} cadence={cadence} chosenSlot={chosenSlot} price={price} authed={authed} authUser={authUser} />
            )}

            {error && <div className="pt-error-msg bk-error">{error}</div>}

            <div className="bk-nav">
              {step !== 'start' ? <button className="pt-btn pt-btn-ghost" onClick={goBack}>Back</button> : <span />}
              {step !== 'review'
                ? <button className="pt-btn pt-btn-primary" onClick={goNext}>Continue</button>
                : <button className="pt-btn pt-btn-primary" disabled title="Card on file opens with online payment">
                    Add card &amp; confirm
                  </button>}
            </div>
          </div>
        )}

        <div className="bk-footer">
          {price != null && step !== 'start' && (
            <span className="bk-footer__price">
              {dollars(price)}{cadence === 'oneoff' ? ' / single visit' : ' / visit'}
              {cadence !== 'oneoff' && <span className="bk-founders-tag">founders rate</span>}
            </span>
          )}
          {authed && <button className="bk-signout" onClick={() => signOut()}>Not you? Sign out</button>}
        </div>
      </div>
    </div>
  );
}

function BookingProgress({ step }) {
  const current = STEPS.indexOf(step);
  return (
    <ol className="bk-progress">
      {STEPS.map((s, i) => (
        <li key={s} className={`bk-progress__item${i === current ? ' is-current' : ''}${i < current ? ' is-done' : ''}`}>
          <span className="bk-progress__dot">{i < current ? '✓' : i + 1}</span>
          <span className="bk-progress__label">{STEP_LABELS[s]}</span>
        </li>
      ))}
    </ol>
  );
}

function StartStep({ place, setPlace, fitOk, setFitOk, authed, authUser, onGoogle }) {
  const set = (f) => (e) => setPlace((p) => ({ ...p, [f]: e.target.value }));
  return (
    <div className="bk-step">
      <h2 className="bk-step__title">Let's get started</h2>
      <p className="bk-step__sub">A couple of minutes, no obligation. Hurricane Bath comes to your driveway in The Villages, Florida.</p>

      <label className="bk-fit">
        <input type="checkbox" checked={fitOk} onChange={(e) => setFitOk(e.target.checked)} />
        <span>My dog is friendly, and I'm in The Villages area. (Bath only: smoothcoat or doublecoat dogs that shed without matting, no haircuts.)</span>
      </label>

      {fitOk && (
        <div className="bk-reveal">
          {!authed ? (
            <button type="button" className="bk-google-prefill" onClick={onGoogle}>
              <GoogleMark /> Pre-fill with Google
              <span className="bk-google-prefill__note">Optional. Fills your name and email, and saves your spot for the card step.</span>
            </button>
          ) : (
            <p className="bk-signedin">Signed in as <strong>{authUser.email || prefillFirst(authUser)}</strong>.</p>
          )}

          <div className="bk-grid-2">
            <Field label="First name"><input className="pt-input" value={place.firstName} onChange={set('firstName')} autoComplete="given-name" /></Field>
            <Field label="Last name"><input className="pt-input" value={place.lastName} onChange={set('lastName')} autoComplete="family-name" /></Field>
          </div>
          <div className="bk-grid-2">
            <Field label="Mobile phone"><input className="pt-input" type="tel" inputMode="tel" placeholder="(352) 555-0100" value={place.phone} onChange={set('phone')} autoComplete="tel" /></Field>
            <Field label="Email (optional)"><input className="pt-input" type="email" value={place.email} onChange={set('email')} autoComplete="email" /></Field>
          </div>
          <Field label="Street address"><input className="pt-input" value={place.addressLine1} onChange={set('addressLine1')} autoComplete="address-line1" /></Field>
          <div className="bk-grid-3">
            <Field label="City"><input className="pt-input" value={place.addressCity} onChange={set('addressCity')} autoComplete="address-level2" /></Field>
            <Field label="State"><input className="pt-input" value={place.addressState} onChange={set('addressState')} autoComplete="address-level1" /></Field>
            <Field label="ZIP"><input className="pt-input" inputMode="numeric" value={place.addressZip} onChange={set('addressZip')} autoComplete="postal-code" /></Field>
          </div>
        </div>
      )}
    </div>
  );
}

function DogsStep({ dogs, updateDog, addDog, removeDog }) {
  return (
    <div className="bk-step">
      <h2 className="bk-step__title">Who is getting a bath?</h2>
      <p className="bk-step__sub">Up to three dogs per visit. The Hurricane Bath is bath only: smoothcoat or doublecoat dogs that shed without matting.</p>
      {dogs.map((d, i) => (
        <div className="bk-dog" key={i}>
          <div className="bk-dog__head">
            <span className="bk-dog__n">Dog {i + 1}</span>
            {dogs.length > 1 && <button className="bk-dog__remove" onClick={() => removeDog(i)}>Remove</button>}
          </div>
          <div className="bk-grid-2">
            <Field label="Name"><input className="pt-input" value={d.name} onChange={(e) => updateDog(i, 'name', e.target.value)} /></Field>
            <Field label="Breed (optional)"><input className="pt-input" value={d.breed} onChange={(e) => updateDog(i, 'breed', e.target.value)} /></Field>
          </div>
          <Field label="Coat type">
            <div className="bk-tier-row">
              {[['smoothcoat', 'Smoothcoat', 'Short, single coat'], ['doublecoat', 'Doublecoat', 'Sheds, does not mat']].map(([val, lab, sub]) => (
                <button key={val} type="button" className={`bk-tier${d.coat_tier === val ? ' is-on' : ''}`} onClick={() => updateDog(i, 'coat_tier', val)}>
                  <span className="bk-tier__lab">{lab}</span>
                  <span className="bk-tier__sub">{sub}</span>
                </button>
              ))}
            </div>
          </Field>
        </div>
      ))}
      {dogs.length < 3 && <button className="bk-add-dog" onClick={addDog}>+ Add another dog</button>}
      <p className="bk-fineprint">Not sure if your dog qualifies? Doodles and heavily matted coats need a full groom, which the Hurricane Bath does not do. <a href="/the-villages">See coat eligibility</a>.</p>
    </div>
  );
}

function PlanStep({ city, dogs, cadence, setCadence }) {
  const options = [
    { key: '4wk', label: 'Every 4 weeks', sub: 'The standard cadence. Most dogs, most coats.' },
    { key: '2wk', label: 'Every 2 weeks', sub: 'Same price, more freshness. Heavy shedders love it.' },
    { key: 'oneoff', label: 'Single visit', sub: 'One bath, no subscription. Priced higher than recurring.' },
  ];
  return (
    <div className="bk-step">
      <h2 className="bk-step__title">How often?</h2>
      <p className="bk-step__sub">Every 4 and every 2 weeks are the same price; pick the freshness you want. Cancel any time in two taps.</p>
      <div className="bk-plans">
        {options.map((o) => {
          const cents = visitPriceCents(city, dogs, o.key);
          return (
            <button key={o.key} type="button" className={`bk-plan${cadence === o.key ? ' is-on' : ''}`} onClick={() => setCadence(o.key)}>
              <span className="bk-plan__top">
                <span className="bk-plan__label">{o.label}</span>
                <span className="bk-plan__price">{dollars(cents) ?? '--'}</span>
              </span>
              <span className="bk-plan__sub">{o.sub}</span>
              {o.key !== 'oneoff' && <span className="bk-founders-tag">founders rate, locked 1 year</span>}
            </button>
          );
        })}
      </div>
      {dogs.length > 1 && (
        <p className="bk-fineprint">Total for all {dogs.length} dogs. Each dog is priced for its own coat; each additional dog is {dollars(city?.hb_addon_decrement_cents)} less than the one before.</p>
      )}
    </div>
  );
}

function TimeStep({ slots, loading, chosen, setChosen, onRefresh }) {
  if (loading || slots === null) {
    return <div className="bk-step"><div className="pt-center-fill" style={{ minHeight: 160 }}><div className="pt-spinner" /></div></div>;
  }
  if (slots.length === 0) {
    return (
      <div className="bk-step">
        <h2 className="bk-step__title">Pick a time</h2>
        <div className="bk-empty-slots">
          <p>No open times are posted yet. We are finalizing the route schedule for The Villages.</p>
          <p className="bk-fineprint">Check back shortly, or <a href="/the-villages">reserve your founders spot</a> and we will let you know the moment a slot opens.</p>
          <button className="pt-btn pt-btn-ghost" onClick={onRefresh}>Refresh</button>
        </div>
      </div>
    );
  }
  const byDay = {};
  for (const s of slots) {
    const key = slotFmt.format(new Date(s.slot_start));
    (byDay[key] ||= []).push(s);
  }
  return (
    <div className="bk-step">
      <h2 className="bk-step__title">Pick a time</h2>
      <p className="bk-step__sub">First visit. After that, we keep you on the same rhythm.</p>
      <div className="bk-days">
        {Object.entries(byDay).map(([day, daySlots]) => (
          <div className="bk-day" key={day}>
            <div className="bk-day__label">{day}</div>
            <div className="bk-day__slots">
              {daySlots.map((s) => (
                <button key={s.slot_start} type="button" className={`bk-slot${chosen === s.slot_start ? ' is-on' : ''}`} onClick={() => setChosen(s.slot_start)}>
                  {timeFmt.format(new Date(s.slot_start))}
                </button>
              ))}
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}

function ReviewStep({ place, dogs, cadence, chosenSlot, price, authed, authUser }) {
  const cadenceLabel = { '4wk': 'Every 4 weeks', '2wk': 'Every 2 weeks', oneoff: 'Single visit' }[cadence];
  return (
    <div className="bk-step">
      <h2 className="bk-step__title">Review</h2>
      <dl className="bk-review">
        <div><dt>Name</dt><dd>{place.firstName} {place.lastName}</dd></div>
        <div><dt>Address</dt><dd>{place.addressLine1}, {place.addressCity} {place.addressState} {place.addressZip}</dd></div>
        <div><dt>Dogs</dt><dd>{dogs.map((d) => `${d.name} (${d.coat_tier})`).join(', ')}</dd></div>
        <div><dt>Cadence</dt><dd>{cadenceLabel}</dd></div>
        <div><dt>First visit</dt><dd>{chosenSlot ? `${slotFmt.format(new Date(chosenSlot))}, ${timeFmt.format(new Date(chosenSlot))}` : 'Not selected'}</dd></div>
        <div><dt>Estimated price</dt><dd>{dollars(price) ?? '--'}{cadence === 'oneoff' ? ' (single visit)' : ' per visit'}</dd></div>
      </dl>

      {!authed ? (
        <div className="bk-signin-block">
          <div className="bk-notice bk-notice--soft">
            <strong>Last step: create your account.</strong> It saves your card on file and gives you the portal to reschedule, skip, or cancel in two taps. We charge the day before each visit, never sooner. Your booking details are saved, so signing in will not lose them.
          </div>
          <AuthScreen redirectPath="/book/" />
        </div>
      ) : (
        <div className="bk-notice bk-notice--soft">
          <strong>Signed in as {authUser.email || prefillFirst(authUser)}. One step left: your card on file.</strong> We charge the day before each visit, never sooner, and you cancel in two taps. Secure online payment is being finalized right now; the card step opens with it, and nothing is booked or charged until then.
        </div>
      )}
    </div>
  );
}

function Field({ label, children }) {
  return (<div className="pt-field bk-field"><label>{label}</label>{children}</div>);
}

function GoogleMark() {
  return (
    <svg width="18" height="18" viewBox="0 0 48 48" xmlns="http://www.w3.org/2000/svg" aria-hidden="true">
      <path fill="#4285F4" d="M43.6 20.5H42V20H24v8h11.3C33.7 32.7 29.2 36 24 36c-6.6 0-12-5.4-12-12s5.4-12 12-12c3.1 0 5.8 1.1 8 2.9l5.7-5.7C34 6.3 29.3 4 24 4 12.9 4 4 12.9 4 24s8.9 20 20 20 20-8.9 20-20c0-1.2-.1-2.4-.4-3.5z"/>
      <path fill="#34A853" d="M6.3 14.7l6.6 4.8C14.7 16.1 19 13 24 13c3.1 0 5.8 1.1 8 2.9l5.7-5.7C34 6.3 29.3 4 24 4c-7.7 0-14.3 4.4-17.7 10.7z"/>
      <path fill="#FBBC05" d="M24 44c5.2 0 9.9-1.9 13.4-5l-6.2-5.2c-2 1.4-4.5 2.2-7.2 2.2-5.2 0-9.6-3.3-11.2-8l-6.5 5C9.5 39.5 16.2 44 24 44z"/>
      <path fill="#EA4335" d="M43.6 20.5H42V20H24v8h11.3c-.8 2.3-2.3 4.3-4.3 5.8l6.2 5.2C41.4 35.5 44 30.2 44 24c0-1.2-.1-2.4-.4-3.5z"/>
    </svg>
  );
}

function prefillFirst(user) {
  const md = user?.user_metadata || {};
  if (md.first_name) return md.first_name;
  if (md.given_name) return md.given_name;
  if (md.full_name) return String(md.full_name).split(' ')[0];
  if (md.name) return String(md.name).split(' ')[0];
  if (user?.email) return user.email.split('@')[0];
  return '';
}
function prefillLast(user) {
  const md = user?.user_metadata || {};
  if (md.last_name) return md.last_name;
  if (md.family_name) return md.family_name;
  const full = md.full_name || md.name;
  if (full && String(full).includes(' ')) return String(full).split(' ').slice(1).join(' ');
  return '';
}
