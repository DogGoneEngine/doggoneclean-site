// src/components/portal/BookingApp.jsx
//
// Hurricane Bath signup funnel (the /book flow). Ported faithfully from
// the proven Dog Gone Nails booking flow, with only the bath-specific
// differences overlaid (coat-tier pricing per dog, a 2-week cadence
// option, a three-dog cap, and no add-ons). NO account required to book
// (matches nails): the funnel runs anonymously and submits through the
// anonymous bath_start_subscription RPC, keyed on phone. The portal is
// claimed later.
//
// Four steps, nails structure:
//   1. Let's get started   (eligibility -> address + gate -> contact + dogs)
//   2. Choose your plan     (cadence cards + live total)
//   3. Choose your time     (timeframe -> real slots -> card on file)
//   4. Review & confirm     (summary + recurring preview -> submit)
//
// Two pieces are gated on credentials Paul provides and degrade honestly
// until then (no fake UI): the address field is plain text until the
// Google Maps key wires live autocomplete + the in-area polygon check,
// and the card-on-file step is informational until the Stripe SetupIntent
// slice lands. Funnel state persists to sessionStorage so the optional
// Google name/email prefill (which redirects) does not lose progress.

import { useState, useEffect, useCallback, useRef } from 'react';
import './portal.css';
import './booking.css';
import {
  sb, getBookingCity, getOpenSlots, getOpenSlotsBetween,
  signInWithGoogle, toE164US,
} from './supabase.js';

const CITY_SLUG = 'the-villages';
const STORE_KEY = 'dgc_booking_v2';
const TOTAL_STEPS = 4;

const ELIGIBILITY = [
  'Bath only, no haircuts. We do not do scissor or clipper work.',
  'Smoothcoat or doublecoat that sheds without matting.',
  'No doodles or heavily matted coats (those need a full groom).',
  'Up to three dogs per visit.',
  'In The Villages, Florida service area.',
];

const MONTHS = [
  ['01', 'January'], ['02', 'February'], ['03', 'March'], ['04', 'April'],
  ['05', 'May'], ['06', 'June'], ['07', 'July'], ['08', 'August'],
  ['09', 'September'], ['10', 'October'], ['11', 'November'], ['12', 'December'],
];
const rangeDays = () => Array.from({ length: 31 }, (_, i) => String(i + 1).padStart(2, '0'));
const rangeYears = () => Array.from({ length: 27 }, (_, i) => String(new Date().getFullYear() - i));

function dollars(cents) {
  if (cents == null) return null;
  const d = cents / 100;
  return Number.isInteger(d) ? `$${d}` : `$${d.toFixed(2)}`;
}
function dogTierCents(city, tier, cadence) {
  if (!city || (tier !== 'smoothcoat' && tier !== 'doublecoat')) return null;
  if (cadence === 'oneoff') {
    return tier === 'doublecoat' ? city.hb_doublecoat_single_cents : city.hb_smoothcoat_single_cents;
  }
  return tier === 'doublecoat' ? city.hb_founders_doublecoat_cents : city.hb_founders_smoothcoat_cents;
}
// Each dog at its own tier, most-expensive first, stacking per-additional
// discount (matches the city page + the RPC).
function visitPriceCents(city, dogs, cadence) {
  if (!city) return null;
  const prices = dogs.map((d) => dogTierCents(city, d.coat_tier, cadence));
  if (prices.some((p) => p == null)) return null;
  const dec = city.hb_addon_decrement_cents || 0;
  return [...prices].sort((a, b) => b - a).reduce((sum, c, i) => sum + Math.max(0, c - dec * i), 0);
}
function computeDogAge(m, d, y) {
  if (!m || !d || !y) return null;
  const born = new Date(Number(y), Number(m) - 1, Number(d));
  if (Number.isNaN(born.getTime())) return null;
  const now = new Date();
  let months = (now.getFullYear() - born.getFullYear()) * 12 + (now.getMonth() - born.getMonth());
  if (now.getDate() < born.getDate()) months -= 1;
  if (months < 0) return null;
  if (months < 12) return `${months} mo`;
  const yrs = Math.floor(months / 12);
  const rem = months % 12;
  return rem ? `${yrs} yr ${rem} mo` : `${yrs} yr`;
}

const slotDayFmt = new Intl.DateTimeFormat('en-US', {
  timeZone: 'America/New_York', weekday: 'short', month: 'short', day: 'numeric',
});
const slotTimeFmt = new Intl.DateTimeFormat('en-US', {
  timeZone: 'America/New_York', hour: 'numeric', minute: '2-digit',
});

function buildRecurringPreview(slotISO, cadence, count) {
  if (!slotISO || cadence === 'oneoff') return null;
  const stepDays = cadence === '2wk' ? 14 : 28;
  const base = new Date(slotISO);
  const out = [];
  for (let i = 0; i < count; i += 1) {
    const dt = new Date(base.getTime() + stepDays * i * 86400000);
    out.push(`${slotDayFmt.format(dt)} at ${slotTimeFmt.format(dt)}`);
  }
  return out;
}

const BLANK_DOG = { name: '', breed: '', coat_tier: '', dobMonth: '', dobDay: '', dobYear: '', dobApproximate: false };
const BLANK = {
  step: 1,
  eligibilityAcked: false,
  place: { firstName: '', lastName: '', email: '', phone: '', addressLine1: '', addressCity: '', addressState: 'FL', addressZip: '', gateCode: '' },
  smsConsent: true,
  dogs: [{ ...BLANK_DOG }],
  cadence: '4wk',
  chosenSlot: null,
};

function loadStored() {
  if (typeof window === 'undefined') return null;
  try { const raw = sessionStorage.getItem(STORE_KEY); return raw ? JSON.parse(raw) : null; } catch { return null; }
}

export default function BookingApp() {
  const restored = useRef(loadStored());
  const init = restored.current || BLANK;

  const [city, setCity] = useState(null);
  const [cityError, setCityError] = useState(null);
  const [step, setStep] = useState(init.step || 1);
  const [eligibilityAcked, setEligibilityAcked] = useState(!!init.eligibilityAcked);
  const [place, setPlace] = useState(init.place || BLANK.place);
  const [smsConsent, setSmsConsent] = useState(init.smsConsent ?? true);
  const [dogs, setDogs] = useState(init.dogs || BLANK.dogs);
  const [cadence, setCadence] = useState(init.cadence || '4wk');
  const [chosenSlot, setChosenSlot] = useState(init.chosenSlot || null);
  const [error, setError] = useState('');

  // Honor /book?plan=single on a fresh funnel.
  useEffect(() => {
    if (restored.current) return;
    const params = new URLSearchParams(window.location.search);
    if (params.get('plan') === 'single') setCadence('oneoff');
  }, []);

  // Persist so the optional Google prefill redirect does not lose progress.
  useEffect(() => {
    try { sessionStorage.setItem(STORE_KEY, JSON.stringify({ step, eligibilityAcked, place, smsConsent, dogs, cadence, chosenSlot })); } catch { /* noop */ }
  }, [step, eligibilityAcked, place, smsConsent, dogs, cadence, chosenSlot]);

  // City pricing (anon-readable). On a Google-prefill return, fill name/email.
  useEffect(() => {
    let cancelled = false;
    (async () => {
      const { city: c, error: ce } = await getBookingCity(CITY_SLUG);
      if (cancelled) return;
      if (ce) setCityError(ce); else setCity(c);
      // If we returned from a Google sign-in, prefill name/email.
      const client = sb();
      if (client) {
        const { data: { user } } = await client.auth.getUser();
        if (user && !cancelled) {
          setPlace((p) => ({
            ...p,
            firstName: p.firstName || prefillFirst(user),
            lastName: p.lastName || prefillLast(user),
            email: p.email || user.email || '',
          }));
        }
      }
    })();
    return () => { cancelled = true; };
  }, []);

  function advance() { window.scrollTo({ top: 0 }); setError(''); setStep((s) => Math.min(s + 1, TOTAL_STEPS)); }
  function back() { window.scrollTo({ top: 0 }); setError(''); setStep((s) => Math.max(s - 1, 1)); }

  if (cityError) {
    return (
      <div className="pt-shell"><div className="bk-wrap">
        <div className="bk-card bk-notice">Booking is not open in this area yet. <a href="/the-villages">See where we serve</a>.</div>
      </div></div>
    );
  }

  return (
    <div className="pt-shell">
      <div className="bk-wrap">
        <div className="bk-progress2">
          <div className="bk-progress2__label">Step {step} of {TOTAL_STEPS}<span className="bk-progress2__city"> · The Villages</span></div>
          <div className="bk-progress2__bar"><div className="bk-progress2__fill" style={{ width: `${(step / TOTAL_STEPS) * 100}%` }} /></div>
        </div>

        {step === 1 && (
          <Step1
            city={city} eligibilityAcked={eligibilityAcked} setEligibilityAcked={setEligibilityAcked}
            place={place} setPlace={setPlace} smsConsent={smsConsent} setSmsConsent={setSmsConsent}
            dogs={dogs} setDogs={setDogs} error={error} setError={setError} onAdvance={advance}
          />
        )}
        {step === 2 && (
          <Step2 city={city} dogs={dogs} cadence={cadence} setCadence={setCadence} onAdvance={advance} />
        )}
        {step === 3 && (
          <Step3 city={city} cadence={cadence} chosenSlot={chosenSlot} setChosenSlot={setChosenSlot} error={error} setError={setError} onAdvance={advance} />
        )}
        {step === 4 && (
          <Step4 city={city} place={place} dogs={dogs} cadence={cadence} chosenSlot={chosenSlot} />
        )}

        {step > 1 && <button className="bk-back" type="button" onClick={back}>← Back</button>}
      </div>
    </div>
  );
}

/* ── Step 1: Let's get started ─────────────────────────────────────── */
function Step1({ city, eligibilityAcked, setEligibilityAcked, place, setPlace, smsConsent, setSmsConsent, dogs, setDogs, error, setError, onAdvance }) {
  const set = (f) => (e) => setPlace((p) => ({ ...p, [f]: e.target.value }));
  const stage2 = eligibilityAcked;
  const stage3 = stage2 && place.addressLine1.trim() && place.addressZip.trim() && place.addressCity.trim();

  const [authed, setAuthed] = useState(false);
  useEffect(() => {
    (async () => { const c = sb(); if (!c) return; const { data: { user } } = await c.auth.getUser(); setAuthed(!!user); })();
  }, []);

  function updateDog(i, field, val) { setDogs((ds) => ds.map((d, idx) => (idx === i ? { ...d, [field]: val } : d))); }
  function setDogCount(n) {
    const target = Math.max(1, Math.min(3, n));
    setDogs((ds) => {
      const next = [...ds];
      while (next.length < target) next.push({ ...BLANK_DOG });
      while (next.length > target) next.pop();
      return next;
    });
  }

  const contactValid = place.firstName.trim() && toE164US(place.phone);
  const dogsValid = dogs.every((d) => d.name.trim() && (d.coat_tier === 'smoothcoat' || d.coat_tier === 'doublecoat'));
  const canContinue = stage3 && contactValid && dogsValid;

  async function googlePrefill() {
    try { await signInWithGoogle('/book/'); } catch { /* user can type manually */ }
  }

  return (
    <div className="bk-card">
      <h2 className="bk-step__title">Let's get started</h2>
      <p className="bk-step__sub">First, let's make sure the Hurricane Bath is a good fit for your dog in The Villages.</p>

      {/* Stage 1: fit check */}
      <div className="bk-friendly">
        <p className="bk-friendly__title">Friendly dogs only</p>
        <p className="bk-friendly__body">Dogs that show aggression toward people, or are excessively uncooperative, are not eligible. Normal wiggling is fine.</p>
      </div>
      <ul className="bk-checklist">
        {ELIGIBILITY.map((item) => (
          <li key={item} className="bk-checklist__item"><span className="bk-checklist__bullet">✓</span><span>{item}</span></li>
        ))}
      </ul>
      <label className="bk-fit">
        <input type="checkbox" checked={eligibilityAcked} onChange={(e) => setEligibilityAcked(e.target.checked)} />
        <span>My dog fits these requirements and is friendly toward people.</span>
      </label>

      {/* Stage 2: address */}
      {stage2 && (
        <div className="bk-reveal">
          <div className="bk-stage__divider" />
          <div className="bk-stage__heading">Where do we bring the bath?</div>
          <Field label="Street address"><input className="pt-input" value={place.addressLine1} onChange={set('addressLine1')} autoComplete="address-line1" /></Field>
          <div className="bk-grid-3">
            <Field label="City"><input className="pt-input" value={place.addressCity} onChange={set('addressCity')} autoComplete="address-level2" /></Field>
            <Field label="State"><input className="pt-input" value={place.addressState} onChange={set('addressState')} autoComplete="address-level1" /></Field>
            <Field label="ZIP"><input className="pt-input" inputMode="numeric" value={place.addressZip} onChange={set('addressZip')} autoComplete="postal-code" /></Field>
          </div>
          <Field label="Gate code (if applicable)"><input className="pt-input" value={place.gateCode} onChange={set('gateCode')} maxLength={32} autoComplete="off" /></Field>
          <p className="bk-fineprint">We confirm your address is on the route before your first visit.</p>
        </div>
      )}

      {/* Stage 3: contact + dogs */}
      {stage3 && (
        <div className="bk-reveal">
          <div className="bk-stage__divider" />
          <div className="bk-stage__heading">Your information</div>

          {!authed && !place.firstName && !place.email && (
            <button type="button" className="bk-google-prefill" onClick={googlePrefill}>
              <GoogleMark /> Pre-fill with Google
              <span className="bk-google-prefill__note">Optional. Fills your name and email from your Google account.</span>
            </button>
          )}

          <div className="bk-grid-2">
            <Field label="First name"><input className="pt-input" value={place.firstName} onChange={set('firstName')} autoComplete="given-name" /></Field>
            <Field label="Last name"><input className="pt-input" value={place.lastName} onChange={set('lastName')} autoComplete="family-name" /></Field>
          </div>
          <div className="bk-grid-2">
            <Field label="Mobile number"><input className="pt-input" type="tel" inputMode="tel" placeholder="(352) 555-0100" value={place.phone} onChange={set('phone')} autoComplete="tel" /></Field>
            <Field label="Email (optional)"><input className="pt-input" type="email" value={place.email} onChange={set('email')} autoComplete="email" placeholder="you@example.com" /></Field>
          </div>

          <label className="bk-fit bk-fit--sms">
            <input type="checkbox" checked={smsConsent} onChange={(e) => setSmsConsent(e.target.checked)} />
            <span>Text me appointment reminders and account messages. Msg &amp; data rates may apply. Reply STOP to unsubscribe. <a href="/sms" target="_blank" rel="noopener">SMS Terms</a> and <a href="/privacy" target="_blank" rel="noopener">Privacy</a>.</span>
          </label>

          <div className="bk-stage__divider" />
          <div className="bk-stage__heading">How many dogs?</div>
          <div className="bk-counter">
            <button type="button" className="bk-counter__btn" onClick={() => setDogCount(dogs.length - 1)} disabled={dogs.length <= 1} aria-label="Fewer">−</button>
            <div className="bk-counter__num">{dogs.length}</div>
            <button type="button" className="bk-counter__btn" onClick={() => setDogCount(dogs.length + 1)} disabled={dogs.length >= 3} aria-label="More">+</button>
          </div>

          {dogs.map((d, i) => (
            <DogCard key={i} idx={i} dog={d} showNumber={dogs.length > 1} onChange={(f, v) => updateDog(i, f, v)} />
          ))}
        </div>
      )}

      {error && <div className="pt-error-msg bk-error">{error}</div>}
      <button
        className="pt-btn pt-btn-primary bk-continue"
        disabled={!canContinue}
        onClick={() => { if (!canContinue) { setError('Fill in the fit check, address, your name and phone, and each dog.'); return; } onAdvance(); }}
      >
        Choose your plan →
      </button>
    </div>
  );
}

function DogCard({ idx, dog, showNumber, onChange }) {
  const age = computeDogAge(dog.dobMonth, dog.dobDay, dog.dobYear);
  return (
    <div className="bk-dog">
      <div className="bk-dog__head">
        {showNumber && <span className="bk-dog__n">Dog {idx + 1}</span>}
        <span className="bk-dog__name">Tell us about {dog.name || 'your dog'}</span>
      </div>
      <div className="bk-grid-2">
        <Field label="Name"><input className="pt-input" value={dog.name} onChange={(e) => onChange('name', e.target.value)} /></Field>
        <Field label="Breed (optional)"><input className="pt-input" value={dog.breed} onChange={(e) => onChange('breed', e.target.value)} placeholder="e.g. Labrador, Husky" /></Field>
      </div>
      <Field label="Coat type">
        <div className="bk-tier-row">
          {[['smoothcoat', 'Smoothcoat', 'Short, single coat'], ['doublecoat', 'Doublecoat', 'Sheds, does not mat']].map(([val, lab, sub]) => (
            <button key={val} type="button" className={`bk-tier${dog.coat_tier === val ? ' is-on' : ''}`} onClick={() => onChange('coat_tier', val)}>
              <span className="bk-tier__lab">{lab}</span><span className="bk-tier__sub">{sub}</span>
            </button>
          ))}
        </div>
      </Field>
      <Field label="Date of birth (optional)">
        <div className="bk-dob-row">
          <select className="pt-input" value={dog.dobMonth} onChange={(e) => onChange('dobMonth', e.target.value)} aria-label="Birth month">
            <option value="">Month</option>{MONTHS.map(([v, n]) => <option key={v} value={v}>{n}</option>)}
          </select>
          <select className="pt-input" value={dog.dobDay} onChange={(e) => onChange('dobDay', e.target.value)} aria-label="Birth day">
            <option value="">Day</option>{rangeDays().map((dd) => <option key={dd} value={dd}>{Number(dd)}</option>)}
          </select>
          <select className="pt-input" value={dog.dobYear} onChange={(e) => onChange('dobYear', e.target.value)} aria-label="Birth year">
            <option value="">Year</option>{rangeYears().map((y) => <option key={y} value={y}>{y}</option>)}
          </select>
        </div>
      </Field>
      {age && <div className="bk-age-badge">{age}</div>}
    </div>
  );
}

/* ── Step 2: plan ──────────────────────────────────────────────────── */
function Step2({ city, dogs, cadence, setCadence, onAdvance }) {
  const options = [
    { key: '4wk', label: 'Every 4 weeks', hook: 'It just gets done.', sub: 'Book once. We show up every 4 weeks automatically.', badge: 'Founders rate' },
    { key: '2wk', label: 'Every 2 weeks', hook: 'Extra fresh.', sub: 'Same price as every 4 weeks. Heavy shedders love it.', badge: 'Same price' },
    { key: 'oneoff', label: 'Single visit', hook: 'Just this once.', sub: 'One bath, one charge. No subscription.', badge: null },
  ];
  const total = visitPriceCents(city, dogs, cadence);
  const dogLabel = dogs.length === 1 ? '1 dog' : `${dogs.length} dogs`;
  const periodLabel = cadence === 'oneoff' ? 'One bath' : (cadence === '2wk' ? 'Every 2 weeks' : 'Every 4 weeks');
  return (
    <div className="bk-card">
      <h2 className="bk-step__title">Choose your plan</h2>
      <p className="bk-step__sub">Every 4 and every 2 weeks are the same price; pick the freshness you want. Cancel any time in two taps.</p>
      <div className="bk-plans">
        {options.map((o) => {
          const cents = visitPriceCents(city, dogs, o.key);
          return (
            <button key={o.key} type="button" className={`bk-plan${cadence === o.key ? ' is-on' : ''}`} onClick={() => setCadence(o.key)}>
              {o.badge && <span className="bk-plan__badge">{o.badge}</span>}
              <span className="bk-plan__hook">{o.hook}</span>
              <span className="bk-plan__top"><span className="bk-plan__label">{o.label}</span><span className="bk-plan__price">{dollars(cents) ?? '--'}</span></span>
              <span className="bk-plan__sub">{o.sub}</span>
              {o.key !== 'oneoff' && <span className="bk-plan__per">per visit · founders rate locked 1 year</span>}
            </button>
          );
        })}
      </div>
      <div className="bk-livetotal">
        <div><div className="bk-livetotal__label">{periodLabel}</div><div className="bk-livetotal__sub">{dogLabel}{dogs.length > 1 ? ', each priced for its own coat' : ''}</div></div>
        <div className="bk-livetotal__amount">{dollars(total) ?? '--'}</div>
      </div>
      <button className="pt-btn pt-btn-primary bk-continue" onClick={onAdvance}>Choose your time →</button>
    </div>
  );
}

/* ── Step 3: date & time + card on file (gated) ────────────────────── */
function Step3({ city, cadence, chosenSlot, setChosenSlot, error, setError, onAdvance }) {
  const [phase, setPhase] = useState('ask'); // ask | load | cards | empty
  const [slots, setSlots] = useState([]);
  const [tf, setTf] = useState('next_available');
  const [month, setMonth] = useState('');
  const [year, setYear] = useState('');

  const loadSlots = useCallback(async () => {
    if (!city) return;
    setPhase('load');
    let res;
    if (tf === 'specific' && month && year) {
      const from = new Date(Number(year), Number(month) - 1, 1);
      const to = new Date(Number(year), Number(month), 1);
      res = await getOpenSlotsBetween(city.id, from, to);
    } else {
      res = await getOpenSlots(city.id, city.hb_booking_horizon_days || 28);
    }
    const s = res.slots || [];
    setSlots(s);
    setPhase(s.length ? 'cards' : 'empty');
  }, [city, tf, month, year]);

  const byDay = {};
  for (const s of slots) { const k = slotDayFmt.format(new Date(s.slot_start)); (byDay[k] ||= []).push(s); }
  const thisYear = new Date().getFullYear();

  return (
    <div className="bk-card">
      <h2 className="bk-step__title">Choose your date &amp; time</h2>
      <p className="bk-step__sub">
        {cadence === 'oneoff' ? 'Pick a day and time that works for you.' : 'This is your first visit. After that we keep you on the same rhythm, same day, same time. Change or cancel in two taps.'}
      </p>

      {phase === 'ask' && (
        <>
          <div className="bk-stage__heading">When are you looking to start?</div>
          <div className="bk-radio-group">
            <label className={`bk-radio${tf === 'next_available' ? ' is-on' : ''}`}>
              <input type="radio" name="tf" checked={tf === 'next_available'} onChange={() => setTf('next_available')} />
              <span className="bk-radio__t">Next available</span><span className="bk-radio__d">The soonest opening on the route.</span>
            </label>
            <label className={`bk-radio${tf === 'specific' ? ' is-on' : ''}`}>
              <input type="radio" name="tf" checked={tf === 'specific'} onChange={() => setTf('specific')} />
              <span className="bk-radio__t">A specific month</span><span className="bk-radio__d">Pick when you'd like to start.</span>
            </label>
            {tf === 'specific' && (
              <div className="bk-grid-2">
                <select className="pt-input" value={month} onChange={(e) => setMonth(e.target.value)}><option value="">Month</option>{MONTHS.map(([v, n]) => <option key={v} value={v}>{n}</option>)}</select>
                <select className="pt-input" value={year} onChange={(e) => setYear(e.target.value)}><option value="">Year</option>{[thisYear, thisYear + 1].map((y) => <option key={y} value={y}>{y}</option>)}</select>
              </div>
            )}
          </div>
          <button className="pt-btn pt-btn-primary bk-continue" disabled={tf === 'specific' && (!month || !year)} onClick={loadSlots}>Find my times →</button>
        </>
      )}

      {phase === 'load' && <div className="pt-center-fill" style={{ minHeight: 160 }}><div className="pt-spinner" /></div>}

      {phase === 'empty' && (
        <div className="bk-empty-slots">
          <p>No open times in that window yet. We are finalizing the route schedule for The Villages.</p>
          <p className="bk-fineprint">Try another month, or <a href="/the-villages">reserve your founders spot</a> and we will let you know the moment a slot opens.</p>
          <button className="pt-btn pt-btn-ghost" onClick={() => setPhase('ask')}>Pick a different timeframe</button>
        </div>
      )}

      {phase === 'cards' && (
        <>
          <div className="bk-days">
            {Object.entries(byDay).map(([day, daySlots], gi) => (
              <div className="bk-day" key={day}>
                <div className="bk-day__label">{day}</div>
                <div className="bk-day__slots">
                  {daySlots.map((s, ti) => (
                    <button key={s.slot_start} type="button" className={`bk-slot${chosenSlot === s.slot_start ? ' is-on' : ''}`} onClick={() => setChosenSlot(s.slot_start)}>
                      {gi === 0 && ti === 0 && <span className="bk-slot__badge">Best fit</span>}
                      {slotTimeFmt.format(new Date(s.slot_start))}
                    </button>
                  ))}
                </div>
              </div>
            ))}
          </div>

          <div className="bk-cof">
            <div className="bk-cof__heading">Card on file</div>
            <div className="bk-cof__sub">You won't be charged right now.</div>
            <div className="bk-cof__charge"><strong>Your card is charged the day before each visit, never sooner.</strong></div>
            <div className="bk-cof__shell">
              <p>Secure card entry is being finalized. Your card will go straight to Stripe (the platform Amazon and millions of businesses use); we never see your number. This is the last piece before booking goes live.</p>
            </div>
            <div className="bk-policy">
              <strong>{cadence === 'oneoff' ? 'Payment policy.' : 'Recurring care policy.'}</strong>{' '}
              {cadence === 'oneoff'
                ? 'Your card is charged the day before your appointment. Once charged, the appointment is confirmed and the payment is non-refundable.'
                : 'Your card is charged the day before each visit. Stop future visits any time in two taps. Once a visit is charged, it is confirmed and that payment is non-refundable.'}
            </div>
          </div>

          {error && <div className="pt-error-msg bk-error">{error}</div>}
          <button className="pt-btn pt-btn-ghost" style={{ marginRight: 12 }} onClick={() => setPhase('ask')}>Change timeframe</button>
          <button className="pt-btn pt-btn-primary" disabled={!chosenSlot} onClick={() => { if (!chosenSlot) { setError('Pick a time first.'); return; } onAdvance(); }}>Review &amp; confirm →</button>
        </>
      )}
    </div>
  );
}

/* ── Step 4: review & confirm ──────────────────────────────────────── */
function Step4({ city, place, dogs, cadence, chosenSlot }) {
  const total = visitPriceCents(city, dogs, cadence);
  const cadenceLabel = { '4wk': 'Every 4 weeks', '2wk': 'Every 2 weeks', oneoff: 'Single visit' }[cadence];
  const preview = buildRecurringPreview(chosenSlot, cadence, 4);
  return (
    <div className="bk-card">
      <h2 className="bk-step__title">Review &amp; confirm</h2>
      <p className="bk-step__sub">Everything look right?</p>
      <dl className="bk-review">
        <div><dt>Name</dt><dd>{place.firstName} {place.lastName}</dd></div>
        <div><dt>Address</dt><dd>{place.addressLine1}, {place.addressCity} {place.addressState} {place.addressZip}</dd></div>
        <div><dt>Dogs</dt><dd>{dogs.map((d) => `${d.name} (${d.coat_tier})`).join(', ')}</dd></div>
        <div><dt>Plan</dt><dd>{cadenceLabel}</dd></div>
        <div><dt>First visit</dt><dd>{chosenSlot ? `${slotDayFmt.format(new Date(chosenSlot))}, ${slotTimeFmt.format(new Date(chosenSlot))}` : '--'}</dd></div>
        <div className="bk-review__total"><dt>Total per visit</dt><dd>{dollars(total) ?? '--'}</dd></div>
      </dl>
      {preview && (
        <div className="bk-preview">
          <div className="bk-preview__label">Your first 4 visits</div>
          <ul>{preview.map((p) => <li key={p}>{p}</li>)}</ul>
          <div className="bk-fineprint">And continuing {cadence === '2wk' ? 'every 2 weeks' : 'every 4 weeks'}. This slot is yours.</div>
        </div>
      )}
      <div className="bk-notice bk-notice--soft">
        <strong>One step left: your card on file.</strong> Secure online payment is being finalized right now; the card step opens with it, and nothing is booked or charged until then. We charge the day before each visit, never sooner, and you cancel in two taps.
      </div>
      <button className="pt-btn pt-btn-primary bk-continue" disabled title="Card on file opens with secure payment">Confirm booking</button>
    </div>
  );
}

function Field({ label, children }) { return (<div className="pt-field bk-field"><label>{label}</label>{children}</div>); }

function GoogleMark() {
  return (
    <svg width="17" height="17" viewBox="0 0 48 48" xmlns="http://www.w3.org/2000/svg" aria-hidden="true">
      <path fill="#4285F4" d="M43.6 20.5H42V20H24v8h11.3C33.7 32.7 29.2 36 24 36c-6.6 0-12-5.4-12-12s5.4-12 12-12c3.1 0 5.8 1.1 8 2.9l5.7-5.7C34 6.3 29.3 4 24 4 12.9 4 4 12.9 4 24s8.9 20 20 20 20-8.9 20-20c0-1.2-.1-2.4-.4-3.5z"/>
      <path fill="#34A853" d="M6.3 14.7l6.6 4.8C14.7 16.1 19 13 24 13c3.1 0 5.8 1.1 8 2.9l5.7-5.7C34 6.3 29.3 4 24 4c-7.7 0-14.3 4.4-17.7 10.7z"/>
      <path fill="#FBBC05" d="M24 44c5.2 0 9.9-1.9 13.4-5l-6.2-5.2c-2 1.4-4.5 2.2-7.2 2.2-5.2 0-9.6-3.3-11.2-8l-6.5 5C9.5 39.5 16.2 44 24 44z"/>
      <path fill="#EA4335" d="M43.6 20.5H42V20H24v8h11.3c-.8 2.3-2.3 4.3-4.3 5.8l6.2 5.2C41.4 35.5 44 30.2 44 24c0-1.2-.1-2.4-.4-3.5z"/>
    </svg>
  );
}

function prefillFirst(user) {
  const md = user?.user_metadata || {};
  return md.first_name || md.given_name || (md.full_name || md.name || '').split(' ')[0] || (user?.email ? user.email.split('@')[0] : '');
}
function prefillLast(user) {
  const md = user?.user_metadata || {};
  if (md.last_name) return md.last_name;
  if (md.family_name) return md.family_name;
  const full = md.full_name || md.name || '';
  return full.includes(' ') ? full.split(' ').slice(1).join(' ') : '';
}
