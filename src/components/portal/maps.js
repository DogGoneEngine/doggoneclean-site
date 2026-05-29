// src/components/portal/maps.js
//
// Google Maps loader + service-area check for the booking funnel.
//
// MAPS_BROWSER_KEY is a browser (publishable) key: it ships in the page
// HTML by design, exactly like SUPABASE_PUBLISHABLE_KEY in supabase.js.
// What protects it is the restrictions on the key in Google Cloud, NOT
// secrecy: it must be HTTP-referrer locked to hurricanebath.com and
// restricted to the Maps JavaScript API + Places API. A leaked key with
// those restrictions is useless off-domain. (Its own Google Cloud
// project, never shared with DGN, per clean_stays_saleable.)
export const MAPS_BROWSER_KEY = 'AIzaSyA77l7vz6_hr1CtJ8OGAUsy549TEAAclhw';

// Load the Maps JS API (Places library) once. Resolves with google.maps,
// rejects if the script fails (network / bad key). On failure the funnel
// shows an honest "booking opens shortly" notice and keeps the gate closed:
// there is no manual address path, because an address we cannot verify is
// in-area must not be bookable.
let _mapsPromise = null;
export function loadGoogleMaps() {
  if (typeof window === 'undefined') return Promise.reject(new Error('no_window'));
  const ready = () => window.google && window.google.maps && window.google.maps.places
    && window.google.maps.places.PlaceAutocompleteElement;
  if (ready()) return Promise.resolve(window.google.maps);
  if (_mapsPromise) return _mapsPromise;
  _mapsPromise = new Promise((resolve, reject) => {
    const s = document.createElement('script');
    // Classic loader (libraries=places, v=weekly): this is the exact form
    // that loads successfully on Clean's project (proven by the suggestions
    // rendering in the field). We use the MODERN PlaceAutocompleteElement off
    // it, NOT the legacy google.maps.places.Autocomplete widget — Google
    // blocked the legacy widget for new Cloud projects (March 2025), so it
    // errors here (nails' legacy widget works only because nails' project
    // predates the cutoff). v=weekly guarantees the element is present.
    s.src = `https://maps.googleapis.com/maps/api/js?key=${MAPS_BROWSER_KEY}&libraries=places&v=weekly`;
    s.async = true;
    s.defer = true;
    s.onerror = () => { _mapsPromise = null; reject(new Error('maps_load_failed')); };
    s.onload = () => { if (ready()) resolve(window.google.maps); else { _mapsPromise = null; reject(new Error('maps_load_failed')); } };
    document.head.appendChild(s);
  });
  return _mapsPromise;
}

// Pull structured address + coordinates out of a Places API (New) Place
// (returned by PlaceAutocompleteElement after fetchFields). The New API
// uses longText/shortText on address components (not long_name/short_name)
// and `location` (a LatLng or literal) instead of `geometry.location`.
export function parsePlace(place) {
  const comp = place.addressComponents || [];
  const get = (type, useShort) => {
    const c = comp.find((x) => (x.types || []).includes(type));
    return c ? (useShort ? c.shortText : c.longText) : '';
  };
  const line1 = [get('street_number'), get('route')].filter(Boolean).join(' ');
  const city = get('locality') || get('sublocality') || get('administrative_area_level_3');
  const state = get('administrative_area_level_1', true);
  const zip = get('postal_code');
  const loc = place.location;
  const num = (v) => (typeof v === 'function' ? v() : v);
  return {
    line1,
    city,
    state,
    zip,
    lat: loc ? num(loc.lat) : null,
    lng: loc ? num(loc.lng) : null,
    formatted: place.formattedAddress || '',
  };
}

// Ray-casting point-in-ring. Coordinates are [lng, lat] (GeoJSON order);
// we test x=lng, y=lat consistently, so the axis labels do not matter.
function pointInRing(lng, lat, ring) {
  let inside = false;
  for (let i = 0, j = ring.length - 1; i < ring.length; j = i, i += 1) {
    const xi = ring[i][0]; const yi = ring[i][1];
    const xj = ring[j][0]; const yj = ring[j][1];
    const hit = ((yi > lat) !== (yj > lat)) && (lng < ((xj - xi) * (lat - yi)) / (yj - yi) + xi);
    if (hit) inside = !inside;
  }
  return inside;
}

// True if (lat,lng) falls inside the city's service polygon. city.polygon
// is GeoJSON-style [[[lng,lat], ...]] (a single outer ring); we also
// tolerate a bare ring [[lng,lat], ...]. Returns false if no polygon.
export function isInServiceArea(lat, lng, city) {
  if (lat == null || lng == null || !city || !city.polygon) return false;
  const poly = city.polygon;
  const ring = Array.isArray(poly[0]) && Array.isArray(poly[0][0]) ? poly[0] : poly;
  if (!Array.isArray(ring) || ring.length < 3) return false;
  return pointInRing(lng, lat, ring);
}
