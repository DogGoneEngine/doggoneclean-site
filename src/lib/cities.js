// src/lib/cities.js
//
// Build-time city data loader. The `/the-villages` page (and any future
// city page) hydrates its pricing from the cities table at build time
// instead of carrying hardcoded literals that would drift when the DB
// value changes. Cities are anon-readable per the cities_anon_read
// policy, so the publishable key is enough.
//
// Used in Astro frontmatter (runs at build time on static sites):
//   import { getCityBySlug, cityTiers } from '../lib/cities.js';
//   const city = await getCityBySlug('the-villages');
//   const tiers = cityTiers(city);

import { createClient } from '@supabase/supabase-js';
import {
  SUPABASE_URL,
  SUPABASE_PUBLISHABLE_KEY,
} from '../components/portal/supabase.js';

let _client = null;
function client() {
  if (_client) return _client;
  _client = createClient(SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  return _client;
}

// Fetch a single city by slug. Fails loud (throws) if the row is missing
// or pricing columns are null, since a wrong price that looks right is
// worse than a build failure (`if_payments_added_handle_money_safely`).
export async function getCityBySlug(slug) {
  const { data, error } = await client()
    .from('cities')
    .select('*')
    .eq('slug', slug)
    .limit(1);
  if (error) throw new Error(`cities fetch failed for "${slug}": ${error.message}`);
  if (!data || data.length === 0) throw new Error(`city not found: "${slug}"`);
  return data[0];
}

function centsToDollars(cents, label, slug) {
  if (cents == null) {
    throw new Error(`city "${slug}" missing required pricing column ${label}`);
  }
  return cents / 100;
}

// Returns the smoothcoat/doublecoat tier shape the city page consumes.
// Throws if any required Hurricane Bath price column is missing on the
// city row, because the page cannot honestly render with a guess.
export function cityTiers(city) {
  const slug = city?.slug || '?';
  return [
    {
      key: 'smooth',
      label: 'Smoothcoat',
      sub: 'The easy kind: smooth, short single coats. Pit bulls, Boxers, Labs.',
      recurring: centsToDollars(city.hb_smoothcoat_recurring_cents, 'hb_smoothcoat_recurring_cents', slug),
      single:    centsToDollars(city.hb_smoothcoat_single_cents,    'hb_smoothcoat_single_cents',    slug),
      founders:  centsToDollars(city.hb_founders_smoothcoat_cents,  'hb_founders_smoothcoat_cents',  slug),
    },
    {
      key: 'double',
      label: 'Doublecoat',
      sub: 'The full-coat kind: thick double coats that shed without matting. German Shepherds, Australian Shepherds.',
      recurring: centsToDollars(city.hb_doublecoat_recurring_cents, 'hb_doublecoat_recurring_cents', slug),
      single:    centsToDollars(city.hb_doublecoat_single_cents,    'hb_doublecoat_single_cents',    slug),
      founders:  centsToDollars(city.hb_founders_doublecoat_cents,  'hb_founders_doublecoat_cents',  slug),
    },
  ];
}

// Per-additional-dog decrement in dollars (a city-level setting, also in cents).
export function cityAddonDecrement(city) {
  return centsToDollars(city.hb_addon_decrement_cents, 'hb_addon_decrement_cents', city?.slug || '?');
}
