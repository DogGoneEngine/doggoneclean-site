// src/components/portal/AuthScreen.jsx
//
// Sign-in surface for the Dog Gone Clean portal. Ported from the DGN
// portal's AuthScreen, adapted to the bath surface voice and Clean's
// Neural Expressive idiom.
//
// Step 1: Google primary, with a "phone or email instead" fallback link.
// Step 2a (phone): 6-digit OTP boxes.
// Step 2b (email): "check your inbox" — magic link redirect closes the loop.

import { useState, useRef } from 'react';
import { sendOtp, verifyOtp, signInWithGoogle } from './supabase.js';

export default function AuthScreen() {
  const [step, setStep]               = useState('identity'); // 'identity' | 'otp' | 'magic_sent'
  const [identity, setIdentity]       = useState('');
  const [isPhone, setIsPhone]         = useState(false);
  const [e164, setE164]               = useState('');
  const [otp, setOtp]                 = useState(['', '', '', '', '', '']);
  const [sending, setSending]         = useState(false);
  const [verifying, setVerifying]     = useState(false);
  const [error, setError]             = useState('');
  const [googleLoading, setGoogleLoading] = useState(false);
  const [showFallback, setShowFallback]   = useState(false);

  const digitRefs = [useRef(), useRef(), useRef(), useRef(), useRef(), useRef()];

  async function handleSend() {
    const val = identity.trim();
    if (!val) { setError('Please enter your phone number or email.'); return; }
    setSending(true);
    setError('');

    const result = await sendOtp(val);
    setSending(false);

    if (result.error) {
      const which = result.isPhone ? 'phone number' : 'email address';
      setError(`We could not send a code to that ${which}. Double-check and try again.`);
      return;
    }

    setIsPhone(result.isPhone);
    setE164(result.e164 || '');

    if (result.isPhone) {
      setStep('otp');
      setTimeout(() => digitRefs[0].current?.focus(), 50);
    } else {
      setStep('magic_sent');
    }
  }

  function handleDigitChange(e, idx) {
    const val = e.target.value.replace(/\D/g, '').slice(-1);
    const next = [...otp];
    next[idx] = val;
    setOtp(next);
    if (val && idx < 5) digitRefs[idx + 1].current?.focus();
  }

  function handleDigitKeydown(e, idx) {
    if (e.key === 'Backspace' && !otp[idx] && idx > 0) {
      digitRefs[idx - 1].current?.focus();
    }
    if (e.key === 'Enter') handleVerify();
  }

  function handleDigitPaste(e) {
    e.preventDefault();
    const pasted = e.clipboardData.getData('text').replace(/\D/g, '').slice(0, 6);
    if (!pasted) return;
    const next = ['', '', '', '', '', ''];
    for (let i = 0; i < pasted.length; i++) next[i] = pasted[i];
    setOtp(next);
    const focusIdx = Math.min(pasted.length, 5);
    digitRefs[focusIdx].current?.focus();
  }

  async function handleVerify() {
    const token = otp.join('');
    if (token.length !== 6) { setError('Enter the full 6-digit code.'); return; }
    setVerifying(true);
    setError('');

    const { error: verifyErr } = await verifyOtp(identity.trim(), isPhone, e164, token);
    setVerifying(false);

    if (verifyErr) {
      setError('That code did not work. Check the code, or go back and re-enter your number.');
      return;
    }
    // onAuthStateChange fires SIGNED_IN in PortalApp; the rest is handled there.
  }

  function reset() {
    setStep('identity');
    setIdentity('');
    setOtp(['', '', '', '', '', '']);
    setError('');
    setIsPhone(false);
    setE164('');
    setShowFallback(false);
  }

  async function handleGoogle() {
    setGoogleLoading(true);
    setError('');
    try {
      await signInWithGoogle();
      // Browser redirects to Google; no further action here.
    } catch {
      setError('Could not connect to Google. Try again, or sign in with your phone or email.');
      setGoogleLoading(false);
    }
  }

  return (
    <div className="pt-center-fill">
      <div className="pt-auth-card">

        {step === 'identity' && (
          <>
            <div className="pt-auth-eyebrow">Client portal</div>
            <h1 className="pt-auth-heading">Sign in</h1>

            <button
              className="pt-btn-google"
              onClick={handleGoogle}
              disabled={googleLoading}
            >
              {googleLoading ? (
                <><span className="pt-spinner-sm" style={{ borderTopColor: '#3c4043', borderColor: 'rgba(60,64,67,0.2)' }} /> Connecting...</>
              ) : (
                <>
                  <svg width="18" height="18" viewBox="0 0 48 48" xmlns="http://www.w3.org/2000/svg">
                    <path fill="#4285F4" d="M43.6 20.5H42V20H24v8h11.3C33.7 32.7 29.2 36 24 36c-6.6 0-12-5.4-12-12s5.4-12 12-12c3.1 0 5.8 1.1 8 2.9l5.7-5.7C34 6.3 29.3 4 24 4 12.9 4 4 12.9 4 24s8.9 20 20 20 20-8.9 20-20c0-1.2-.1-2.4-.4-3.5z"/>
                    <path fill="#34A853" d="M6.3 14.7l6.6 4.8C14.7 16.1 19 13 24 13c3.1 0 5.8 1.1 8 2.9l5.7-5.7C34 6.3 29.3 4 24 4c-7.7 0-14.3 4.4-17.7 10.7z"/>
                    <path fill="#FBBC05" d="M24 44c5.2 0 9.9-1.9 13.4-5l-6.2-5.2c-2 1.4-4.5 2.2-7.2 2.2-5.2 0-9.6-3.3-11.2-8l-6.5 5C9.5 39.5 16.2 44 24 44z"/>
                    <path fill="#EA4335" d="M43.6 20.5H42V20H24v8h11.3c-.8 2.3-2.3 4.3-4.3 5.8l6.2 5.2C41.4 35.5 44 30.2 44 24c0-1.2-.1-2.4-.4-3.5z"/>
                  </svg>
                  Continue with Google
                </>
              )}
            </button>

            {error && !showFallback && (
              <div className="pt-error-msg" style={{ textAlign: 'center', marginTop: 'var(--space-sm)' }}>{error}</div>
            )}

            {!showFallback ? (
              <button
                className="pt-auth-fallback-link"
                onClick={() => { setShowFallback(true); setError(''); }}
              >
                Sign in with phone or email instead
              </button>
            ) : (
              <div className="pt-auth-fallback">
                <div className="pt-field">
                  <label htmlFor="pt-identity">Phone or email</label>
                  <input
                    id="pt-identity"
                    type="text"
                    inputMode="tel"
                    autoComplete="tel"
                    className={`pt-input${error ? ' pt-input-error' : ''}`}
                    placeholder="(352) 555-0100 or you@example.com"
                    value={identity}
                    onChange={e => { setIdentity(e.target.value); setError(''); }}
                    onKeyDown={e => e.key === 'Enter' && handleSend()}
                    autoFocus
                  />
                  {error && <div className="pt-error-msg">{error}</div>}
                </div>
                <button
                  className="pt-btn pt-btn-secondary pt-btn-block"
                  onClick={handleSend}
                  disabled={sending}
                >
                  {sending ? <><span className="pt-spinner-sm" /> Sending...</> : 'Send access code'}
                </button>
                <button
                  className="pt-auth-fallback-link"
                  style={{ marginTop: 'var(--space-md)' }}
                  onClick={() => { setShowFallback(false); setIdentity(''); setError(''); }}
                >
                  Back to Google sign-in
                </button>
              </div>
            )}
          </>
        )}

        {step === 'otp' && (
          <>
            <button
              className="pt-back-btn"
              onClick={reset}
              style={{ padding: '0 0 var(--space-lg)', fontSize: 'var(--text-xs)' }}
            >
              Back
            </button>
            <div className="pt-auth-eyebrow">Check your messages</div>
            <h1 className="pt-auth-heading">Enter your code</h1>
            <p className="pt-auth-sub" style={{ marginBottom: 'var(--space-xl)' }}>
              We sent a 6-digit code to <strong>{identity}</strong>.
            </p>

            <div className="pt-otp-row">
              {otp.map((digit, idx) => (
                <input
                  key={idx}
                  ref={digitRefs[idx]}
                  type="text"
                  inputMode="numeric"
                  maxLength={1}
                  className="pt-otp-digit"
                  value={digit}
                  onChange={e => handleDigitChange(e, idx)}
                  onKeyDown={e => handleDigitKeydown(e, idx)}
                  onPaste={idx === 0 ? handleDigitPaste : undefined}
                  autoComplete={idx === 0 ? 'one-time-code' : 'off'}
                />
              ))}
            </div>

            {error && (
              <div className="pt-error-msg" style={{ textAlign: 'center', marginBottom: 'var(--space-md)' }}>
                {error}
              </div>
            )}

            <button
              className="pt-btn pt-btn-primary pt-btn-block"
              onClick={handleVerify}
              disabled={verifying || otp.join('').length < 6}
            >
              {verifying ? <><span className="pt-spinner-sm" /> Verifying...</> : 'Verify and continue'}
            </button>

            <button
              className="pt-btn pt-btn-ghost pt-btn-block"
              style={{ marginTop: 'var(--space-sm)' }}
              onClick={reset}
            >
              Use a different number
            </button>
          </>
        )}

        {step === 'magic_sent' && (
          <div style={{ textAlign: 'center' }}>
            <div style={{ fontSize: '2.5rem', marginBottom: 'var(--space-lg)' }}>📬</div>
            <h1 className="pt-auth-heading" style={{ marginBottom: 'var(--space-md)' }}>
              Check your inbox
            </h1>
            <p style={{ fontSize: 'var(--text-sm)', color: 'var(--soft)', lineHeight: 1.7, marginBottom: 'var(--space-xl)' }}>
              We sent a sign-in link to <strong>{identity}</strong>. Tap the
              link in that email to access your account. You can close this
              tab.
            </p>
            <button className="pt-btn pt-btn-ghost" onClick={reset}>
              Use a different address
            </button>
          </div>
        )}

      </div>
    </div>
  );
}
