// src/components/admin/AccessView.jsx
//
// The access map (access_map_reads_the_truth): one emperor-only page that shows,
// per role, exactly what that person sees, so access never quietly drifts.
//
// The menu half is generated from roles.js, the same definition the live nav
// uses to gate, so it is always true. The masking half (what is hidden inside a
// floor a role can open) is read live from the server by admin_access_probe,
// which diffs the real RPC output per role, so it cannot drift either. Preview
// as flips the whole console to walk a role's menu yourself.

import { useEffect, useState } from 'react';
import { SECTIONS, ROLES, ROLE_MODE, floorsFor, visibleSectionKeysFor } from './roles.js';
import { accessProbe } from './supabase.js';

// Friendly names for the fields the probe reports, grouped into plain buckets.
// Anything not listed still shows by its raw key, so a new masked field can
// never hide from this page.
const FIELD_LABELS = {
  phone_e164: 'phone number', email: 'email', note: 'private notes',
  message_thoughts: 'your private thoughts',
  amount_collected_cents: 'amount collected', tip_cents: 'tips',
  payment_method: 'payment method', amount_cents: 'appointment price',
  briefing_feed: 'the AI department-head feed (win-back, pricing, churn, money counsel)',
  reminders_feed: 'your "On your plate" reminders',
};
const CONTACT = new Set(['phone_e164', 'email', 'note', 'message_thoughts']);
const MONEY = new Set(['amount_collected_cents', 'tip_cents', 'payment_method', 'amount_cents']);

function hiddenSummary(probeRole) {
  if (!probeRole || !probeRole.probed) return null;
  const all = new Set([
    ...(probeRole.client || []), ...(probeRole.visit || []),
    ...(probeRole.upcoming || []), ...(probeRole.today || []),
    ...(probeRole.feeds || []),
  ]);
  if (all.size === 0) return null;
  const contact = [], money = [], other = [];
  for (const f of all) {
    const label = FIELD_LABELS[f] || f;
    if (CONTACT.has(f)) contact.push(label);
    else if (MONEY.has(f)) money.push(label);
    else other.push(label);
  }
  return { contact, money, other };
}

export default function AccessView({ onPreview }) {
  const [probe, setProbe] = useState(null);
  const [err, setErr] = useState(null);
  useEffect(() => { accessProbe().then(setProbe).catch((e) => setErr(e.message || 'load_failed')); }, []);

  const roles = probe?.roles || {};

  return (
    <>
      <h1>Access</h1>
      <p className="ad-sub">
        Who can see what, by role. The menu is generated from the live rules and the hidden-data list is read from the system itself, so this page is always the truth, not a description that can fall out of date.
      </p>

      {err && <div className="ad-error">{err}</div>}

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(280px, 1fr))', gap: 14 }}>
        {ROLES.map((role) => {
          const keys = visibleSectionKeysFor(role.key);
          const sections = SECTIONS.filter((s) => keys.includes(s.key));
          const isOwnerRole = role.key === 'owner';
          const hidden = hiddenSummary(roles[role.key]);
          const noOneInRole = roles[role.key] && roles[role.key].probed === false;
          return (
            <div key={role.key} className="ad-panel" style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
              <div>
                <div style={{ fontSize: 18, fontWeight: 800 }}>{role.mode}</div>
                <div style={{ fontSize: 13, opacity: 0.7 }}>{role.blurb}</div>
              </div>

              <div>
                <div style={{ fontSize: 12, textTransform: 'uppercase', letterSpacing: 0.4, opacity: 0.55, marginBottom: 6 }}>
                  Menu ({sections.length})
                </div>
                <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6 }}>
                  {sections.map((s) => (
                    <span key={s.key} style={{
                      fontSize: 12, padding: '3px 9px', borderRadius: 999,
                      background: 'var(--ad-primary-container, #e6edfc)', color: 'var(--ad-on-primary-container, #14346e)',
                    }}>{s.label}</span>
                  ))}
                </div>
              </div>

              <div>
                <div style={{ fontSize: 12, textTransform: 'uppercase', letterSpacing: 0.4, opacity: 0.55, marginBottom: 6 }}>
                  Hidden inside
                </div>
                {isOwnerRole ? (
                  <div style={{ fontSize: 13, opacity: 0.7 }}>Nothing. The emperor sees everything.</div>
                ) : !hidden ? (
                  <div style={{ fontSize: 13, opacity: 0.7 }}>
                    Nothing extra is masked on the floors they can open.
                  </div>
                ) : (
                  <div style={{ fontSize: 13, display: 'flex', flexDirection: 'column', gap: 4 }}>
                    {hidden.contact.length > 0 && <div><strong>Contact:</strong> {hidden.contact.join(', ')}</div>}
                    {hidden.money.length > 0 && <div><strong>Money:</strong> {hidden.money.join(', ')}</div>}
                    {hidden.other.length > 0 && <div><strong>Other:</strong> {hidden.other.join(', ')}</div>}
                    <div style={{ fontSize: 11, opacity: 0.55 }}>Stripped server-side on the floors they can open.</div>
                  </div>
                )}
                {noOneInRole && <div style={{ fontSize: 11, opacity: 0.55 }}>No active member in this role to sample.</div>}
              </div>

              {!isOwnerRole && onPreview && (
                <div>
                  <button className="ad-btn ad-btn--sm" onClick={() => onPreview(role.key)}>Preview this menu</button>
                </div>
              )}
            </div>
          );
        })}
      </div>

      <p className="ad-sub" style={{ marginTop: 16, fontSize: 12, opacity: 0.6 }}>
        {probe ? 'Read live from the operating system. Reopen this page any time to re-check.' : 'Reading the live access rules…'}
      </p>
    </>
  );
}
