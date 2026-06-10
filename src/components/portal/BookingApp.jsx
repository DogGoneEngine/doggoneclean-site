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
  signInWithGoogle, toE164US, looksLikeEmail, lookupSubscriberByPhone,
} from './supabase.js';
import { loadGoogleMaps, parsePlace, isInServiceArea, polygonBounds, lastMapsError } from './maps.js';

const CITY_SLUG = 'the-villages';
const STORE_KEY = 'dgc_booking_v2';
const TOTAL_STEPS = 4;

// Cities the funnel knows about. The Villages runs the live funnel; Ocala
// (home base, over 20 years of clients) opens for NEW-client booking when the
// anchor drive-time gate is wired in and hb_active flips, so until then it
// gets an honest panel that routes to the waitlist and the portal.
const FUNNEL_CITIES = [
  ['the-villages', 'The Villages, FL'],
  ['ocala', 'Ocala, FL'],
];

// No service-area line here: the address step right below verifies it, and
// the intro already says The Villages. Stating it as a requirement is noise.
// (No unpaved-roads line either: The Villages has no unpaved roads, so per
// no_unpaved_roads the rule is stated only where it applies, e.g. Ocala.)
const ELIGIBILITY = [
  'You live in a private home with a driveway.',
  'There is room to park our truck and trailer (about 2 standard car spaces, front to back).',
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

// excluded_breeds_are_slide_holes: the hard breed exclusions, declined kindly
// and early (here) and rejected server-side in bath_start_subscription (the
// durable teeth). Doodles and poodle crosses, Siberian Huskies, Great
// Pyrenees, Great Danes: coats and sizes that need hours, not a route stop.
const EXCLUDED_BREED_RE = /(doodle|poodle|husky|huskies|pyrenees|great\s*dane)/i;
function breedNotAFit(breed) {
  return EXCLUDED_BREED_RE.test(breed || '');
}

const BLANK_DOG = { name: '', breed: '', coat_tier: '', dobMonth: '', dobDay: '', dobYear: '', dobApproximate: false };
const BLANK = {
  step: 1,
  eligibilityAcked: false,
  place: { firstName: '', lastName: '', email: '', phone: '', addressLine1: '', addressCity: '', addressState: 'FL', addressZip: '', gateCode: '', serviceLat: null, serviceLng: null },
  smsConsent: true,
  dogs: [{ ...BLANK_DOG }],
  cadence: '4wk',
  chosenSlot: null,
};

function loadStored() {
  if (typeof window === 'undefined') return null;
  try { const raw = sessionStorage.getItem(STORE_KEY); return raw ? JSON.parse(raw) : null; } catch { return null; }
}

// Which city this funnel run is for. Priority: explicit ?city= param, then
// params that only exist on Villages links (founders / plan), then whatever
// a restored session chose, else null (show the chooser).
function initialCitySlug(restoredSlug) {
  if (typeof window === 'undefined') return restoredSlug || null;
  const params = new URLSearchParams(window.location.search);
  const fromParam = params.get('city');
  if (FUNNEL_CITIES.some(([slug]) => slug === fromParam)) return fromParam;
  if (params.get('founders') || params.get('plan')) return CITY_SLUG;
  return restoredSlug || null;
}

export default function BookingApp() {
  const restored = useRef(loadStored());
  const init = restored.current || BLANK;

  const [citySlug, setCitySlug] = useState(() => initialCitySlug(init.citySlug));
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
    try { sessionStorage.setItem(STORE_KEY, JSON.stringify({ citySlug, step, eligibilityAcked, place, smsConsent, dogs, cadence, chosenSlot })); } catch { /* noop */ }
  }, [citySlug, step, eligibilityAcked, place, smsConsent, dogs, cadence, chosenSlot]);

  // City pricing (anon-readable). On a Google-prefill return, fill name/email.
  useEffect(() => {
    let cancelled = false;
    if (citySlug !== CITY_SLUG) return undefined;
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
  }, [citySlug]);

  function advance() { window.scrollTo({ top: 0 }); setError(''); setStep((s) => Math.min(s + 1, TOTAL_STEPS)); }
  function back() { window.scrollTo({ top: 0 }); setError(''); setStep((s) => Math.max(s - 1, 1)); }

  // City chooser: the generic Book buttons land here with no city, and the
  // funnel has to accommodate every served city, not just The Villages.
  if (!citySlug) {
    return (
      <div className="pt-shell"><div className="bk-wrap">
        <div className="bk-card">
          <h2 className="bk-step__title">Where does <span className="grad">your dog</span> live?</h2>
          <p className="bk-step__sub">Dog Gone Clean serves Ocala and The Villages, Florida.</p>
          <div className="bk-plans">
            {FUNNEL_CITIES.map(([slug, label]) => (
              <button key={slug} type="button" className="bk-plan" onClick={() => setCitySlug(slug)}>
                <span className="bk-plan__top"><span className="bk-plan__label">{label}</span></span>
              </button>
            ))}
          </div>
        </div>
      </div></div>
    );
  }

  // Ocala: home base for over 20 years, but online booking for NEW clients opens
  // with the anchor service-area gate. Honest panel, no dead end.
  if (citySlug === 'ocala') {
    return (
      <div className="pt-shell"><div className="bk-wrap">
        <div className="bk-card">
          <h2 className="bk-step__title">Ocala is <span className="grad">home base.</span></h2>
          <p className="bk-step__sub">Dog Gone Clean has groomed Ocala's dogs for over 20 years.</p>
          <p>
            Online booking for new Ocala clients opens soon, and it will be for dogs that
            do not need haircuts: the Hurricane Bath, deshedding, nails, the works.
            <a href="/ocala"> Join the Ocala waitlist</a> and we will let you know the moment it opens.
          </p>
          <p>Already a client? <a href="/portal">Your portal is ready.</a></p>
          <button className="bk-back" type="button" onClick={() => setCitySlug(null)}>← Pick a different city</button>
        </div>
      </div></div>
    );
  }

  if (cityError) {
    return (
      <div className="pt-shell"><div className="bk-wrap">
        <div className="bk-card bk-notice">Booking is not open in this area yet. <a href="/#cities">See where we serve</a>.</div>
      </div></div>
    );
  }

  return (
    <div className="pt-shell">
      <div className="bk-glows" aria-hidden="true">
        <span className="glow glow-a" />
        <span className="glow glow-b" />
      </div>
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
// Mirrors the nails Step 1 (three reveal stages: fit check -> service-area
// address -> contact + dogs). Bath divergences: coat-tier picker per dog,
// three-dog cap, no silk-finish upsell, anonymous (no account).
function Step1({ city, eligibilityAcked, setEligibilityAcked, place, setPlace, smsConsent, setSmsConsent, dogs, setDogs, error, setError, onAdvance }) {
  const set = (f) => (e) => setPlace((p) => ({ ...p, [f]: e.target.value }));

  const [authed, setAuthed] = useState(false);
  const boxRef = useRef(null);
  const elRef = useRef(null);
  const [mapsReady, setMapsReady] = useState(false);
  const [mapsFailed, setMapsFailed] = useState(false);
  const [areaStatus, setAreaStatus] = useState(place.serviceLat != null ? 'pass' : null); // null | pass | fail
  const [returning, setReturning] = useState(null); // null | { firstName }

  const stage1 = eligibilityAcked;
  // No manual path: the ONLY way past this gate is an address chosen from
  // autocomplete that the in-area polygon check passed. If Maps cannot load,
  // the gate stays closed (an address we cannot verify must not be bookable).
  const stage2done = areaStatus === 'pass';

  useEffect(() => {
    (async () => { const c = sb(); if (!c) return; const { data: { user } } = await c.auth.getUser(); setAuthed(!!user); })();
  }, []);

  // Ref so the once-attached select handler always sees the latest city.
  const cityRef = useRef(city);
  useEffect(() => { cityRef.current = city; }, [city]);

  // Load Maps once eligibility is acked.
  useEffect(() => {
    if (!stage1) return undefined;
    let mounted = true;
    loadGoogleMaps().then(() => { if (mounted) setMapsReady(true); }).catch((e) => {
      console.error('maps load failed:', e, lastMapsError);
      if (mounted) setMapsFailed(true);
    });
    return () => { mounted = false; };
  }, [stage1]);

  // Mount the modern PlaceAutocompleteElement (Places API New). On select,
  // fetch the place fields, parse to structured address + lat/lng, and run
  // the in-area polygon check.
  useEffect(() => {
    if (!mapsReady || !stage1 || !boxRef.current || elRef.current) return undefined;
    const places = window.google && window.google.maps && window.google.maps.places;
    if (!places || !places.PlaceAutocompleteElement) { setMapsFailed(true); return undefined; }
    const opts = { includedRegionCodes: ['us'] };
    // Bias suggestions toward the service area (derived from the DB polygon).
    const bias = polygonBounds(cityRef.current);
    if (bias) opts.locationBias = bias;
    const el = new places.PlaceAutocompleteElement(opts);
    el.style.width = '100%';
    boxRef.current.appendChild(el);
    elRef.current = el;

    async function onSelect(event) {
      try {
        const place_ = event.placePrediction ? event.placePrediction.toPlace() : event.place;
        if (!place_) { setAreaStatus('fail'); return; }
        await place_.fetchFields({ fields: ['formattedAddress', 'addressComponents', 'location'] });
        const parsed = parsePlace(place_);
        setPlace((p) => ({
          ...p,
          addressLine1: parsed.line1, addressCity: parsed.city,
          addressState: parsed.state || 'FL', addressZip: parsed.zip,
          serviceLat: parsed.lat, serviceLng: parsed.lng, verifiedAddress: parsed.formatted,
        }));
        setAreaStatus(isInServiceArea(parsed.lat, parsed.lng, cityRef.current) ? 'pass' : 'fail');
      } catch {
        setAreaStatus('fail');
      }
    }
    // gmp-select is the current event; gmp-placeselect covers older builds.
    el.addEventListener('gmp-select', onSelect);
    el.addEventListener('gmp-placeselect', onSelect);

    // Tear down when the address stage unmounts (eligibility unchecked). Without
    // this, elRef kept pointing at the detached element, so re-checking the box
    // skipped re-creating it and left an empty, cursorless box until a refresh.
    return () => {
      el.removeEventListener('gmp-select', onSelect);
      el.removeEventListener('gmp-placeselect', onSelect);
      el.remove();
      if (elRef.current === el) elRef.current = null;
    };
  }, [mapsReady, stage1, setPlace]);

  function updateDog(i, field, val) { setDogs((ds) => ds.map((d, idx) => (idx === i ? { ...d, [field]: val } : d))); }
  function setDogCount(n) {
    const target = Math.max(1, n);
    setDogs((ds) => {
      const next = [...ds];
      while (next.length < target) next.push({ ...BLANK_DOG });
      while (next.length > target) next.pop();
      return next;
    });
  }

  const contactValid = place.firstName.trim() && place.lastName.trim() && looksLikeEmail(place.email) && toE164US(place.phone);
  const dogsValid = dogs.every((d) => d.name.trim() && d.breed.trim()
    && !breedNotAFit(d.breed)
    && (d.coat_tier === 'smoothcoat' || d.coat_tier === 'doublecoat')
    && d.dobMonth && d.dobDay && d.dobYear);
  const canContinue = stage1 && stage2done && contactValid && dogsValid;

  async function googlePrefill() {
    try { await signInWithGoogle('/book/'); } catch { /* user can type manually */ }
  }

  // Returning-client recognition: on blur, if the phone matches someone we
  // already know, greet them by name. Never blocks the flow.
  async function onPhoneBlur() {
    const e164 = toE164US(place.phone);
    if (!e164) { setReturning(null); return; }
    try {
      const { found, firstName } = await lookupSubscriberByPhone(e164);
      setReturning(found ? { firstName } : null);
    } catch { setReturning(null); }
  }

  return (
    <div className="bk-card">
      <h2 className="bk-step__title">Let's Get <span className="grad">Started</span></h2>
      <p className="bk-step__sub">First, let's make sure we're a good fit for The Villages.</p>

      {/* Stage 1: fit check */}
      <div className="bk-friendly">
        <p className="bk-friendly__title">Friendly Dogs Only</p>
        <p className="bk-friendly__body">Normal wiggling is fine. Dogs that show aggression toward people or are excessively uncooperative are not eligible for this service.</p>
        <p className="bk-friendly__note">A mobile dog grooming visit runs on the trust between the dog and the Hurricane Bath Operator.</p>
      </div>
      <ul className="bk-checklist">
        {ELIGIBILITY.map((item) => (
          <li key={item} className="bk-checklist__item"><span className="bk-checklist__bullet">✓</span><span>{item}</span></li>
        ))}
      </ul>
      <p className="bk-fineprint">You don't need to clear your driveway. We can park on the street when it's safe and legal.</p>
      <label className="bk-fit">
        <input type="checkbox" checked={eligibilityAcked} onChange={(e) => setEligibilityAcked(e.target.checked)} />
        <span>My location fits these requirements and my dog is friendly toward people.</span>
      </label>

      {/* Stage 2: service-area address */}
      {stage1 && (
        <div className="bk-reveal">
          <div className="bk-stage__divider" />
          <div className="bk-stage__heading">Are you in our service area?</div>

          {!mapsFailed ? (
            <Field label="Service address">
              {!mapsReady && <input type="text" className="pt-input" placeholder="Loading address search..." disabled />}
              <div ref={boxRef} className="bk-place-box" />
            </Field>
          ) : (
            <div className="bk-notice">
              Online booking for The Villages is being set up and opens shortly. <a href="/the-villages">Reserve your founders spot</a> and we will let you know the moment it is live.
              {lastMapsError && <span className="bk-fineprint" style={{ display: 'block', marginTop: 8, opacity: 0.7 }}>technical note: {lastMapsError}</span>}
            </div>
          )}

          {areaStatus === 'pass' && <div className="bk-area bk-area--in"><span className="bk-area__icon">✓</span> You're in our service area.</div>}
          {areaStatus === 'fail' && (
            <div className="bk-area bk-area--out">
              <span className="bk-area__icon">!</span> That address is outside our The Villages route right now. Try a different address, or <a href="/the-villages">join the waitlist</a>.
            </div>
          )}

          {stage2done && (
            <Field label="Gate code (if applicable)"><input className="pt-input" value={place.gateCode} onChange={set('gateCode')} maxLength={32} autoComplete="off" /></Field>
          )}
        </div>
      )}

      {/* Stage 3: contact + dogs */}
      {stage1 && stage2done && (
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
          <Field label="Email address"><input className="pt-input" type="email" value={place.email} onChange={set('email')} autoComplete="email" placeholder="you@example.com" /></Field>
          <Field label="Mobile number"><input className="pt-input" type="tel" inputMode="tel" placeholder="(352) 555-0100" value={place.phone} onChange={set('phone')} onBlur={onPhoneBlur} autoComplete="tel" /></Field>
          {returning && (
            <div className="bk-area bk-area--in">
              <span className="bk-area__icon">✓</span> Welcome back{returning.firstName ? `, ${returning.firstName}` : ''}. We already have you on file. Fill in your current information and we'll make sure everything is up to date.
            </div>
          )}

          <label className="bk-fit bk-fit--sms">
            <input type="checkbox" checked={smsConsent} onChange={(e) => setSmsConsent(e.target.checked)} />
            <span>I agree to receive appointment and account text messages from Dog Gone Clean. Msg &amp; data rates may apply. Reply STOP to unsubscribe or HELP for help. <a href="/sms" target="_blank" rel="noopener">SMS Terms</a> and <a href="/privacy" target="_blank" rel="noopener">Privacy Policy</a>.</span>
          </label>

          <div className="bk-stage__divider" />
          <div className="bk-stage__heading">How many dogs?</div>
          <div className="bk-counter">
            <button type="button" className="bk-counter__btn" onClick={() => setDogCount(dogs.length - 1)} disabled={dogs.length <= 1} aria-label="Fewer">−</button>
            <div className="bk-counter__num">{dogs.length}</div>
            <button type="button" className="bk-counter__btn" onClick={() => setDogCount(dogs.length + 1)} aria-label="More">+</button>
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
        onClick={() => { if (!canContinue) { setError('Fill in the fit check, a verified address, your name, email and phone, and each dog (name, breed, coat, date of birth).'); return; } onAdvance(); }}
      >
        Choose Your Appointment →
      </button>
    </div>
  );
}

function DogCard({ idx, dog, showNumber, onChange }) {
  const age = computeDogAge(dog.dobMonth, dog.dobDay, dog.dobYear);
  const notAFit = breedNotAFit(dog.breed);
  return (
    <div className="bk-dog">
      <div className="bk-dog__head">
        {showNumber && <span className="bk-dog__n">{idx + 1}</span>}
        <span className="bk-dog__name">Tell us about {dog.name || 'your dog'}</span>
      </div>
      <Field label="Name"><input className="pt-input" value={dog.name} onChange={(e) => onChange('name', e.target.value)} autoComplete="off" /></Field>
      <Field label="Breed"><input className="pt-input" value={dog.breed} onChange={(e) => onChange('breed', e.target.value)} placeholder="e.g. Lab, German Shepherd, or Boxer mix" autoComplete="off" /></Field>
      {notAFit && (
        <div className="bk-area bk-area--out">
          <span className="bk-area__icon">!</span> We have to be honest up front: we are not built for this one.
          Doodles and poodle crosses, Siberian Huskies, Great Pyrenees, and Great Danes need haircut-level
          coat work or more hours than a mobile route can give one stop. A full-service dog grooming salon
          is the right home for that coat, and we would rather tell you here, kindly, than at your door.
        </div>
      )}
      <Field label="Which kind of dog?">
        <div className="bk-tier-row">
          {[
            ['smoothcoat', 'Smoothcoat', 'The easy kind. Smooth, short coat: pit bulls, Boxers, Labs.'],
            ['doublecoat', 'Doublecoat', 'The full-coat kind. Thick double coat: Golden Retrievers, German Shepherds, Australian Shepherds. Longer visit, deeper deshed, priced for it.'],
          ].map(([val, lab, sub]) => (
            <button key={val} type="button" className={`bk-tier${dog.coat_tier === val ? ' is-on' : ''}`} onClick={() => onChange('coat_tier', val)}>
              <span className="bk-tier__lab">{lab}</span><span className="bk-tier__sub">{sub}</span>
            </button>
          ))}
        </div>
        <p className="bk-fineprint">Mixed breed? Pick by the coat your dog actually wears: smooth and short, or thick double coat. No haircut either way; that is the point.</p>
      </Field>
      <Field label="Date of birth">
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
      <div className="bk-dob-toggle">
        <button type="button" className={`bk-dob-toggle__btn${!dog.dobApproximate ? ' is-active' : ''}`} onClick={() => onChange('dobApproximate', false)}>I know the exact date</button>
        <button type="button" className={`bk-dob-toggle__btn${dog.dobApproximate ? ' is-active' : ''}`} onClick={() => onChange('dobApproximate', true)}>Approximate, my best guess</button>
      </div>
      {age && <div className="bk-age-badge">{age}</div>}
    </div>
  );
}

/* ── Step 2: plan ──────────────────────────────────────────────────── */
function Step2({ city, dogs, cadence, setCadence, onAdvance }) {
  const options = [
    { key: '4wk', label: 'Every 4 weeks', hook: 'It just gets done.', sub: 'Book once. We show up every 4 weeks automatically.', badge: 'Founders rate' },
    { key: '2wk', label: 'Every 2 weeks', hook: 'Extra fresh.', sub: 'Same price as every 4 weeks. Heavy shedders love it.', badge: 'Same price' },
    { key: 'oneoff', label: 'Single visit', hook: 'Just this once.', sub: 'One visit, one charge. No subscription.', badge: null },
  ];
  const total = visitPriceCents(city, dogs, cadence);
  const dogLabel = dogs.length === 1 ? '1 dog' : `${dogs.length} dogs`;
  const periodLabel = cadence === 'oneoff' ? 'One visit' : (cadence === '2wk' ? 'Every 2 weeks' : 'Every 4 weeks');
  return (
    <div className="bk-card">
      <h2 className="bk-step__title">Choose your <span className="grad">plan</span></h2>
      <p className="bk-step__sub">Every 4 and every 2 weeks are the same price; pick the freshness you want. Cancel any time in two taps.</p>
      <div className="bk-octane">
        <span className="bk-octane__q">Want your dog fresher?</span>
        <span className="bk-octane__arrow" aria-hidden="true">→</span>
      </div>
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
      <h2 className="bk-step__title">Choose your date &amp; <span className="grad">time</span></h2>
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
      <h2 className="bk-step__title">Review &amp; <span className="grad">confirm</span></h2>
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
