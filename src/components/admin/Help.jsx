// src/components/admin/Help.jsx
//
// help_on_demand: the standard fallback for any card with action buttons. A
// small "i" pinned to the card's TOP-RIGHT corner (one per card, the same place
// every time, well clear of the action buttons so it can't be fat-fingered).
// Tapping it gives a thorough rundown of every action on that card; tapping
// again hides it. Buttons stay terse for daily use; the explanation is there for
// the control you have not used yet, have forgotten, or a new teammate is
// learning. Tap-based so it works on a phone.
//
// Usage: give the card `position: relative` and drop <HelpToggle corner items=
// {[[term, desc], ...]} /> as a child. Without `corner` it renders inline.

import { useState } from 'react';

export default function HelpToggle({ items, label = 'What can I do here?', corner = false }) {
  const [open, setOpen] = useState(false);
  return (
    <span style={corner
      ? { position: 'absolute', top: 8, right: 10, zIndex: 6 }
      : { position: 'relative', display: 'inline-flex', verticalAlign: 'middle' }}>
      <button
        type="button"
        aria-label={label}
        aria-expanded={open}
        title={label}
        onClick={() => setOpen((o) => !o)}
        style={{
          width: 20, height: 20, borderRadius: '50%', flexShrink: 0,
          border: '1px solid ' + (open ? 'var(--ad-primary, #2563d8)' : 'var(--ad-outline, #d5d5dd)'),
          background: open ? 'var(--ad-primary, #2563d8)' : 'var(--ad-surface-container-low, #fff)',
          color: open ? '#fff' : 'var(--ad-text-dim, #565b6c)',
          fontSize: 13, fontWeight: 700, lineHeight: 1, cursor: 'pointer',
          fontStyle: 'italic', fontFamily: 'Georgia, "Times New Roman", serif',
        }}
      >
        i
      </button>
      {open && (
        <div
          role="dialog"
          style={{
            position: 'absolute', top: 26, right: 0, zIndex: 40, width: 260, maxWidth: '76vw',
            padding: '12px 14px', borderRadius: 10, textAlign: 'left',
            background: 'var(--ad-surface-container-low, #fff)',
            border: '1px solid var(--ad-line, #e6e3dc)',
            boxShadow: '0 12px 30px rgba(0,0,0,0.18)',
            fontSize: 12.5, lineHeight: 1.5, color: 'var(--ad-text, #1a1d28)',
          }}
        >
          {items.map(([term, desc]) => (
            <div key={term} style={{ marginBottom: 7 }}>
              <strong>{term}:</strong> {desc}
            </div>
          ))}
          <button
            type="button"
            onClick={() => setOpen(false)}
            style={{ marginTop: 2, background: 'transparent', border: 0, padding: 0, cursor: 'pointer', fontSize: 11, textDecoration: 'underline', color: 'var(--ad-text-dim, #565b6c)' }}
          >
            close
          </button>
        </div>
      )}
    </span>
  );
}
