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
// rejects if the script fails (network / bad key) so the funnel can fall
// back to plain manual address entry instead of dead-ending.
let _mapsPromise = null;
export function loadGoogleMaps() {
  if (typeof window === 'undefined') return Promise.reject(new Error('no_window'));
  if (window.google && window.google.maps && window.google.maps.places) {
    return Promise.resolve(window.google.maps);
  }
  if (_mapsPromise) return _mapsPromise;
  _mapsPromise = new Promise((resolve, reject) => {
    const s = document.createElement('script');
    s.src = `https://maps.googleapis.com/maps/api/js?key=${MAPS_BROWSER_KEY}&libraries=places&loading=async`;
    s.async = true;
    s.onerror = () => { _mapsPromise = null; reject(new Error('maps_load_failed')); };
    s.onload = () => {
      if (window.google && window.google.maps) resolve(window.google.maps);
      else reject(new Error('maps_load_failed'));
    };
    document.head.appendChild(s);
  });
  return _mapsPromise;
}

// Pull the structured address + coordinates out of a Places result.
export function parsePlace(place) {
  const comp = place.address_components || [];
  const get = (type, useShort) => {
    const c = comp.find((x) => x.types.includes(type));
    return c ? (useShort ? c.short_name : c.long_name) : '';
  };
  const line1 = [get('street_number'), get('route')].filter(Boolean).join(' ');
  const city = get('locality') || get('sublocality') || get('administrative_area_level_3');
  const state = get('administrative_area_level_1', true);
  const zip = get('postal_code');
  const loc = place.geometry && place.geometry.location;
  return {
    line1,
    city,
    state,
    zip,
    lat: loc ? loc.lat() : null,
    lng: loc ? loc.lng() : null,
    formatted: place.formatted_address || '',
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
