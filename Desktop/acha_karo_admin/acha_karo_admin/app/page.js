'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { supabase } from '../lib/supabaseClient';

// Mirrors the Flutter app's email-code flow exactly, with one deliberate difference:
// shouldCreateUser is false here — an admin account should already exist (signed up normally
// through the app, then manually promoted to moderator/owner in Table Editor, same one-time step
// documented in the schema). This screen shouldn't let a random email create a brand-new account.
export default function LoginPage() {
  const [step, setStep] = useState('email'); // 'email' | 'code'
  const [email, setEmail] = useState('');
  const [code, setCode] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  const router = useRouter();

  async function sendCode() {
    if (!email.includes('@')) {
      setError('Enter a valid email address.');
      return;
    }
    setLoading(true);
    setError(null);
    const { error: sendError } = await supabase.auth.signInWithOtp({
      email,
      options: { shouldCreateUser: false },
    });
    setLoading(false);
    if (sendError) {
      setError(
        sendError.status === 429 || sendError.message.toLowerCase().includes('rate')
          ? 'You just requested a code — wait a few seconds before trying again.'
          : `Could not send the code: ${sendError.message}`
      );
      return;
    }
    setStep('code');
  }

  async function verifyCode() {
    if (code.trim().length !== 6) {
      setError('Enter the 6-digit code from your email.');
      return;
    }
    setLoading(true);
    setError(null);
    const { data, error: verifyError } = await supabase.auth.verifyOtp({ email, token: code.trim(), type: 'email' });
    if (verifyError || !data.user) {
      setLoading(false);
      setError("That code didn't work — it may be wrong or expired.");
      return;
    }

    const { data: profile } = await supabase.from('profiles').select('role').eq('id', data.user.id).single();
    setLoading(false);

    if (!profile || (profile.role !== 'moderator' && profile.role !== 'owner')) {
      setError("This account doesn't have admin access.");
      await supabase.auth.signOut();
      return;
    }

    router.push('/admin/moderation');
  }

  return (
    <main style={{ minHeight: '100vh', display: 'flex', alignItems: 'center', justifyContent: 'center', padding: 24 }}>
      <div style={{ width: '100%', maxWidth: 380 }}>
        <div style={{ marginBottom: 32, textAlign: 'center' }}>
          <h1 style={{ fontSize: 22, fontWeight: 600, color: 'var(--gold)' }}>Acha Karo</h1>
          <p className="mono" style={{ fontSize: 11, color: 'var(--text-soft)', letterSpacing: 1, marginTop: 4 }}>ADMIN ACCESS</p>
        </div>

        <div style={{ background: 'var(--olive-card)', border: '1px solid var(--line)', borderRadius: 18, padding: 24 }}>
          {step === 'email' ? (
            <>
              <label style={{ fontSize: 12, color: 'var(--text-soft)', display: 'block', marginBottom: 8 }}>Email address</label>
              <input
                type="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                onKeyDown={(e) => e.key === 'Enter' && sendCode()}
                placeholder="you@email.com"
                style={inputStyle}
              />
              {error && <p style={errorStyle}>{error}</p>}
              <button onClick={sendCode} disabled={loading} style={buttonStyle(loading)}>
                {loading ? 'Sending…' : 'Send code'}
              </button>
            </>
          ) : (
            <>
              <p style={{ fontSize: 12, color: 'var(--text-soft)', marginBottom: 16, lineHeight: 1.5 }}>
                We sent a 6-digit code to <strong style={{ color: 'var(--text)' }}>{email}</strong>.
              </p>
              <label style={{ fontSize: 12, color: 'var(--text-soft)', display: 'block', marginBottom: 8 }}>Code</label>
              <input
                type="text"
                inputMode="numeric"
                maxLength={6}
                value={code}
                onChange={(e) => setCode(e.target.value.replace(/\D/g, ''))}
                onKeyDown={(e) => e.key === 'Enter' && verifyCode()}
                placeholder="000000"
                className="mono"
                style={{ ...inputStyle, fontSize: 20, letterSpacing: 4, textAlign: 'center' }}
              />
              {error && <p style={errorStyle}>{error}</p>}
              <button onClick={verifyCode} disabled={loading} style={buttonStyle(loading)}>
                {loading ? 'Verifying…' : 'Verify and continue'}
              </button>
              <button
                onClick={() => { setStep('email'); setError(null); }}
                style={{ width: '100%', marginTop: 10, background: 'none', border: 'none', color: 'var(--text-soft)', fontSize: 12, padding: 8 }}
              >
                ← Use a different email
              </button>
            </>
          )}
        </div>
      </div>
    </main>
  );
}

const inputStyle = {
  width: '100%',
  padding: '12px 14px',
  borderRadius: 12,
  border: '1px solid var(--line)',
  background: 'rgba(8, 18, 9, 0.4)',
  color: 'var(--text)',
  fontSize: 14,
  outline: 'none',
};

const errorStyle = { color: 'var(--rust)', fontSize: 11.5, marginTop: 8, lineHeight: 1.4 };

function buttonStyle(loading) {
  return {
    width: '100%',
    marginTop: 16,
    padding: '13px 0',
    borderRadius: 12,
    border: 'none',
    background: loading ? 'var(--olive-card-strong)' : 'var(--gold)',
    color: loading ? 'var(--text-soft)' : 'var(--ink-on-gold)',
    fontSize: 14,
    fontWeight: 700,
  };
}
