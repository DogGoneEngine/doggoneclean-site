// src/components/portal/BookingApp.jsx
//
// Hurricane Bath signup funnel (the /book flow). Built against the real
// services from the first commit (no_mockups): Supabase auth gates entry,
// pricing comes from the live city row, the time picker reads genuinely
// open slots from bath_open_slots, and submit calls bath_start_subscription
// (which enforces the rule pack server-side).
//
// Steps: place -> dogs -> plan -> time -> review. The final card-on-file
// step is intentionally gated until the Stripe SetupIntent edge function
// lands (its own slice, needs the test keys); the funnel does not fake a
// card form. Until the operator posts availability windows, the time step
// shows an honest empty state rather than invented slots.

import { useState, useEffect, useCallback } from 'react';
import './portal.css';
import './booking.css';
import {
  sb, getBookingCity, getOpenSlots, signOut, toE164US,
} from './supabase.js';
import AuthScreen from './AuthScreen.jsx';

const CITY_SLUG = 'the-villages';
const STEPS = ['place', 'dogs', 'plan', 'time', 'review'];
const STEP_LABELS = {
  place: 'Your place',
  dogs: 'Your dogs',
  plan: 'How often',
  time: 'Pick a time',
  review: 'Review',
};

function dollars(cents) {
  if (cents == null) return null;
  const d = cents / 100;
  return Number.isInteger(d) ? `$${d}` : `$${d.toFixed(2)}`;
}

// Per-dog price for its OWN coat tier at the chosen cadence. Recurring
// shows the founders rate (the launch rate while spots remain); one-off
// shows the single price. The server snapshot is authoritative.
function dogTierCents(city, tier, cadence) {
  if (!city || (tier !== 'smoothcoat' && tier !== 'doublecoat')) return null;
  if (cadence === 'oneoff') {
    return tier === 'doublecoat' ? city.hb_doublecoat_single_cents : city.hb_smoothcoat_single_cents;
  }
  return tier === 'doublecoat' ? city.hb_founders_doublecoat_cents : city.hb_founders_smoothcoat_cents;
}

// Visit total: every dog priced at its own tier, ordered most-expensive
// first, with the per-additional-dog discount stacking down the line
// (matches the city page copy and the bath_start_subscription RPC).
function visitPriceCents(city, dogs, cadence) {
  if (!city) return null;
  const prices = dogs.map((d) => dogTierCents(city, d.coat_tier, cadence));
  if (prices.some((p) => p == null)) return null;
  const decrement = city.hb_addon_decrement_cents || 0;
  return [...prices]
    .sort((a, b) => b - a)
    .reduce((sum, c, i) => sum + Math.max(0, c - decrement * i), 0);
}

const slotFmt = new Intl.DateTimeFormat('en-US', {
  timeZone: 'America/New_York', weekday: 'short', month: 'short', day: 'numeric',
});
const timeFmt = new Intl.DateTimeFormat('en-US', {
  timeZone: 'America/New_York', hour: 'numeric', minute: '2-digit',
});

export default function BookingApp() {
  const [authState, setAuthState] = useState('checking');
  const [authUser, setAuthUser] = useState(null);
  const [city, setCity] = useState(null);
  const [cityError, setCityError] = useState(null);

  const [step, setStep] = useState('place');
  const [place, setPlace] = useState({
    firstName: '', lastName: '', phone: '',
    addressLine1: '', addressCity: '', addressState: 'FL', addressZip: '',
  });
  const [dogs, setDogs] = useState([{ name: '', breed: '', coat_tier: '' }]);
  const [cadence, setCadence] = useState('4wk');
  const [slots, setSlots] = useState(null); // null = not loaded, [] = none
  const [slotsLoading, setSlotsLoading] = useState(false);
  const [chosenSlot, setChosenSlot] = useState(null);
  const [error, setError] = useState('');

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

  // On auth, grab the user (prefill) and the city (pricing).
  useEffect(() => {
    if (authState !== 'authenticated') return;
    let cancelled = false;
    (async () => {
      const client = sb();
      const { data: { user } } = await client.auth.getUser();
      if (cancelled) return;
      setAuthUser(user);
      setPlace((p) => ({
        ...p,
        firstName: p.firstName || prefillFirst(user),
        lastName: p.lastName || prefillLast(user),
      }));
      const { city: c, error: ce } = await getBookingCity(CITY_SLUG);
      if (cancelled) return;
      if (ce) setCityError(ce); else setCity(c);
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

  // ── step gating ──
  function placeValid() {
    return place.firstName.trim() && place.addressLine1.trim() &&
      place.addressCity.trim() && place.addressZip.trim() &&
      toE164US(place.phone);
  }
  function dogsValid() {
    return dogs.length >= 1 && dogs.length <= 3 &&
      dogs.every((d) => d.name.trim() && (d.coat_tier === 'smoothcoat' || d.coat_tier === 'doublecoat'));
  }

  function goNext() {
    setError('');
    const i = STEPS.indexOf(step);
    if (step === 'place' && !placeValid()) { setError('Please fill in your name, phone, and service address.'); return; }
    if (step === 'dogs' && !dogsValid()) { setError('Give each dog a name and a coat type (one to three dogs).'); return; }
    if (step === 'time' && !chosenSlot) { setError('Pick a time for your first visit.'); return; }
    if (i < STEPS.length - 1) setStep(STEPS[i + 1]);
  }
  function goBack() {
    setError('');
    const i = STEPS.indexOf(step);
    if (i > 0) setStep(STEPS[i - 1]);
  }

  function updateDog(idx, field, val) {
    setDogs((ds) => ds.map((d, i) => (i === idx ? { ...d, [field]: val } : d)));
  }
  function addDog() { if (dogs.length < 3) setDogs((ds) => [...ds, { name: '', breed: '', coat_tier: '' }]); }
  function removeDog(idx) { setDogs((ds) => ds.filter((_, i) => i !== idx)); }

  if (authState === 'checking') {
    return <div className="pt-center-fill"><div className="pt-spinner" /></div>;
  }
  if (authState === 'anonymous') {
    return (
      <div>
        <div className="bk-auth-intro">
          <div className="bk-auth-intro__eyebrow">Hurricane Bath signup</div>
          <p>Sign in to start. We tie your booking to your account so your card on file, schedule, and two-tap cancel all live in one place.</p>
        </div>
        <AuthScreen redirectPath="/book/" />
      </div>
    );
  }

  const price = visitPriceCents(city, dogs, cadence);

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
            {step === 'place' && (
              <PlaceStep place={place} setPlace={setPlace} />
            )}

            {step === 'dogs' && (
              <DogsStep dogs={dogs} updateDog={updateDog} addDog={addDog} removeDog={removeDog} />
            )}

            {step === 'plan' && (
              <PlanStep city={city} dogs={dogs} cadence={cadence} setCadence={setCadence} />
            )}

            {step === 'time' && (
              <TimeStep
                slots={slots} loading={slotsLoading} chosen={chosenSlot}
                setChosen={setChosenSlot} onRefresh={() => { setSlots(null); }}
              />
            )}

            {step === 'review' && (
              <ReviewStep
                place={place} dogs={dogs} cadence={cadence} city={city}
                chosenSlot={chosenSlot} price={price}
              />
            )}

            {error && <div className="pt-error-msg bk-error">{error}</div>}

            <div className="bk-nav">
              {step !== 'place'
                ? <button className="pt-btn pt-btn-ghost" onClick={goBack}>Back</button>
                : <span />}
              {step !== 'review'
                ? <button className="pt-btn pt-btn-primary" onClick={goNext}>Continue</button>
                : <button className="pt-btn pt-btn-primary" disabled title="Card on file opens with online payment">
                    Add card &amp; confirm
                  </button>}
            </div>
          </div>
        )}

        <div className="bk-footer">
          {price != null && step !== 'place' && (
            <span className="bk-footer__price">
              {dollars(price)}{cadence === 'oneoff' ? ' / single visit' : ' / visit'}
              {cadence !== 'oneoff' && <span className="bk-founders-tag">founders rate</span>}
            </span>
          )}
          <button className="bk-signout" onClick={() => signOut()}>Sign out</button>
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

function PlaceStep({ place, setPlace }) {
  const set = (f) => (e) => setPlace((p) => ({ ...p, [f]: e.target.value }));
  return (
    <div className="bk-step">
      <h2 className="bk-step__title">Where do we bring the bath?</h2>
      <p className="bk-step__sub">Hurricane Bath serves The Villages, Florida. We pull up to your driveway, so this is where your dog gets clean.</p>
      <div className="bk-grid-2">
        <Field label="First name"><input className="pt-input" value={place.firstName} onChange={set('firstName')} autoComplete="given-name" /></Field>
        <Field label="Last name"><input className="pt-input" value={place.lastName} onChange={set('lastName')} autoComplete="family-name" /></Field>
      </div>
      <Field label="Mobile phone"><input className="pt-input" type="tel" inputMode="tel" placeholder="(352) 555-0100" value={place.phone} onChange={set('phone')} autoComplete="tel" /></Field>
      <Field label="Street address"><input className="pt-input" value={place.addressLine1} onChange={set('addressLine1')} autoComplete="address-line1" /></Field>
      <div className="bk-grid-3">
        <Field label="City"><input className="pt-input" value={place.addressCity} onChange={set('addressCity')} autoComplete="address-level2" /></Field>
        <Field label="State"><input className="pt-input" value={place.addressState} onChange={set('addressState')} autoComplete="address-level1" /></Field>
        <Field label="ZIP"><input className="pt-input" inputMode="numeric" value={place.addressZip} onChange={set('addressZip')} autoComplete="postal-code" /></Field>
      </div>
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
                <button
                  key={val}
                  type="button"
                  className={`bk-tier${d.coat_tier === val ? ' is-on' : ''}`}
                  onClick={() => updateDog(i, 'coat_tier', val)}
                >
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
  // Group slots by local date.
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
                <button
                  key={s.slot_start}
                  type="button"
                  className={`bk-slot${chosen === s.slot_start ? ' is-on' : ''}`}
                  onClick={() => setChosen(s.slot_start)}
                >
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

function ReviewStep({ place, dogs, cadence, city, chosenSlot, price }) {
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
      <div className="bk-notice bk-notice--soft">
        <strong>One step left: your card on file.</strong> We charge the day before each visit, never sooner, and you cancel in two taps. Secure online payment is being finalized right now; the card step opens with it, and nothing is booked or charged until then.
      </div>
    </div>
  );
}

function Field({ label, children }) {
  return (
    <div className="pt-field bk-field">
      <label>{label}</label>
      {children}
    </div>
  );
}

function prefillFirst(user) {
  const md = user?.user_metadata || {};
  if (md.first_name) return md.first_name;
  if (md.given_name) return md.given_name;
  if (md.full_name) return String(md.full_name).split(' ')[0];
  if (md.name) return String(md.name).split(' ')[0];
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
