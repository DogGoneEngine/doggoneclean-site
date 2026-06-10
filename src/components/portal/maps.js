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

// Load the Maps JS API (Places library) once, using Google's documented
// dynamic bootstrap + importLibrary('places'). Resolves with google.maps,
// rejects if the script or library fails (network / bad key / blocked API).
// On failure the funnel shows an honest "booking opens shortly" notice and
// keeps the gate closed: there is no manual address path, because an address
// we cannot verify is in-area must not be bookable.
//
// DIAGNOSED 2026-06-10 (live request, API_KEY_SERVICE_BLOCKED): suggestions
// not appearing is NOT a code failure mode here; the browser key's API
// restrictions in Google Cloud must include "Places API (New)" or every
// autocomplete request is rejected server-side while the box renders fine.
// See maps_js_api_only in CLEAN_ORACLE.md. lastMapsError below exists so the
// funnel can name the reason instead of failing silently.
export let lastMapsError = '';
let _mapsPromise = null;
export function loadGoogleMaps() {
  if (typeof window === 'undefined') return Promise.reject(new Error('no_window'));
  if (_mapsPromise) return _mapsPromise;
  // Surfaces key/referer auth failures that otherwise only hit the console.
  window.gm_authFailure = () => { lastMapsError = 'maps_auth_failure (check the key referrer lock and API restrictions)'; };
  _mapsPromise = (async () => {
    if (!(window.google && window.google.maps && window.google.maps.importLibrary)) {
      bootstrapMapsLoader({ key: MAPS_BROWSER_KEY, v: 'weekly' });
    }
    const places = await window.google.maps.importLibrary('places');
    if (!places.PlaceAutocompleteElement) {
      lastMapsError = 'places_element_missing (PlaceAutocompleteElement not in this channel)';
      throw new Error(lastMapsError);
    }
    return window.google.maps;
  })().catch((e) => {
    if (!lastMapsError) lastMapsError = (e && e.message) || 'maps_load_failed';
    _mapsPromise = null;
    throw e;
  });
  return _mapsPromise;
}

// Google's official dynamic library import bootstrap (from the Maps JS
// docs), reformatted. It registers google.maps.importLibrary and loads the
// script once with whatever libraries are requested.
function bootstrapMapsLoader(g) {
  var h; var a; var k; var p = 'The Google Maps JavaScript API'; var c = 'google';
  var l = 'importLibrary'; var q = '__ib__'; var m = document; var b = window;
  b = b[c] || (b[c] = {});
  var d = b.maps || (b.maps = {}); var r = new Set(); var e = new URLSearchParams();
  var u = function () {
    return h || (h = new Promise(async function (f, n) {
      a = m.createElement('script');
      e.set('libraries', Array.from(r).join(','));
      for (k in g) e.set(k.replace(/[A-Z]/g, function (t) { return '_' + t[0].toLowerCase(); }), g[k]);
      e.set('callback', c + '.maps.' + q);
      a.src = 'https://maps.' + c + 'apis.com/maps/api/js?' + e;
      d[q] = f;
      a.onerror = function () { h = n(Error(p + ' could not load.')); };
      a.nonce = (m.querySelector('script[nonce]') || {}).nonce || '';
      m.head.append(a);
    }));
  };
  if (d[l]) {
    console.warn(p + ' only loads once. Ignoring:', g);
  } else {
    d[l] = function (f) {
      var n = Array.prototype.slice.call(arguments, 1);
      r.add(f);
      return u().then(function () { return d[l].apply(d, [f].concat(n)); });
    };
  }
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

// Bounding box of the city's service polygon as a LatLngBounds literal
// ({north, south, east, west}), for biasing the address autocomplete toward
// the service area so the right address surfaces fast. Derived from
// cities.polygon (the database), so the bias moves with the polygon and no
// coordinates are hard-coded in the page. Returns null if there is no polygon.
export function polygonBounds(city) {
  if (!city || !city.polygon) return null;
  const poly = city.polygon;
  const ring = Array.isArray(poly[0]) && Array.isArray(poly[0][0]) ? poly[0] : poly;
  if (!Array.isArray(ring) || ring.length < 3) return null;
  let north = -90; let south = 90; let east = -180; let west = 180;
  for (const pt of ring) {
    const lng = pt[0]; const lat = pt[1];
    if (lat > north) north = lat;
    if (lat < south) south = lat;
    if (lng > east) east = lng;
    if (lng < west) west = lng;
  }
  return { north, south, east, west };
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
