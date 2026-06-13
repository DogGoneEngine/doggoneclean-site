// src/components/admin/Help.jsx
//
// help_on_demand: the fallback for any control whose meaning isn't obvious. A
// small "i" button sits next to a cluster of buttons; tapping it reveals a short
// legend of what each one does, and tapping again hides it. Buttons stay terse
// for daily use; the explanation is there for the thing you haven't used yet,
// have forgotten, or a new teammate is learning. Tap-based, so it works on a
// phone (a hover title does not).

import { useState } from 'react';

export default function HelpToggle({ items, label = 'What do these do?' }) {
  const [open, setOpen] = useState(false);
  return (
    <span style={{ position: 'relative', display: 'inline-flex', verticalAlign: 'middle' }}>
      <button
        type="button"
        aria-label={label}
        aria-expanded={open}
        title={label}
        onClick={() => setOpen((o) => !o)}
        style={{
          width: 18, height: 18, borderRadius: '50%', flexShrink: 0,
          border: '1px solid ' + (open ? 'var(--ad-primary, #2563d8)' : 'var(--ad-outline, #d5d5dd)'),
          background: open ? 'var(--ad-primary, #2563d8)' : 'transparent',
          color: open ? '#fff' : 'var(--ad-text-dim, #565b6c)',
          fontSize: 12, fontWeight: 700, lineHeight: 1, cursor: 'pointer',
          fontStyle: 'italic', fontFamily: 'Georgia, "Times New Roman", serif',
        }}
      >
        i
      </button>
      {open && (
        <div
          role="dialog"
          style={{
            position: 'absolute', top: 24, left: 0, zIndex: 40, width: 250, maxWidth: '72vw',
            padding: '10px 12px', borderRadius: 10, textAlign: 'left',
            background: 'var(--ad-surface-container-low, #fff)',
            border: '1px solid var(--ad-line, #e6e3dc)',
            boxShadow: '0 10px 28px rgba(0,0,0,0.16)',
            fontSize: 12, lineHeight: 1.45, color: 'var(--ad-text, #1a1d28)',
          }}
        >
          {items.map(([term, desc]) => (
            <div key={term} style={{ marginBottom: 6 }}>
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
