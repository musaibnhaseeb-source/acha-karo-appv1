'use client';

import { useEffect, useState } from 'react';
import { supabase } from '../../../lib/supabaseClient';

// Real, simple admin control for the freeze mechanism that already exists entirely at the
// database level (app_config.badges_frozen + an RLS check on user_badges' own insert policy).
// The app itself never needs to know this exists — it just tries to write earned badges, and
// the database silently allows or refuses depending on this one flag. This page just flips it.
export default function BadgesPage() {
  const [frozen, setFrozen] = useState(null);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [loadError, setLoadError] = useState(null);

  useEffect(() => {
    load();
  }, []);

  async function load() {
    setLoading(true);
    const { data, error } = await supabase.from('app_config').select('badges_frozen').eq('id', 1).single();
    if (error) {
      setLoadError(error.message);
      setLoading(false);
      return;
    }
    setLoadError(null);
    setFrozen(data?.badges_frozen ?? true);
    setLoading(false);
  }

  async function toggle() {
    setSaving(true);
    const { error } = await supabase.from('app_config').update({ badges_frozen: !frozen }).eq('id', 1);
    if (!error) setFrozen(!frozen);
    setSaving(false);
  }

  return (
    <div>
      <div style={{ marginBottom: 20 }}>
        <h1 style={{ fontSize: 22 }}>Badges</h1>
        <p style={{ fontSize: 12, color: 'var(--text-soft)', marginTop: 4 }}>
          One global switch — while frozen, nobody can earn any new badge at all. No app update needed either way; the database enforces this directly.
        </p>
      </div>

      {loadError && <div style={errorBoxStyle}>Could not load badge state: {loadError}</div>}

      {!loading && frozen !== null && (
        <div style={panelStyle}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 16 }}>
            <div style={{ fontSize: 32 }}>{frozen ? '❄️' : '✅'}</div>
            <div style={{ flex: 1 }}>
              <div style={{ fontSize: 15, fontWeight: 700 }}>{frozen ? 'Badges are frozen' : 'Badges are live'}</div>
              <div style={{ fontSize: 12, color: 'var(--text-soft)', marginTop: 2 }}>
                {frozen ? 'No one can earn a new badge right now.' : 'Badges are being earned normally.'}
              </div>
            </div>
            <button onClick={toggle} disabled={saving} style={frozen ? unfreezeButtonStyle : freezeButtonStyle}>
              {saving ? 'Saving…' : frozen ? 'Unfreeze Badges' : 'Freeze Badges'}
            </button>
          </div>
        </div>
      )}
    </div>
  );
}

const panelStyle = { background: 'var(--olive-card)', border: '1px solid var(--line)', borderRadius: 16, padding: 24 };
const freezeButtonStyle = { background: 'var(--olive-card-strong)', border: '1px solid var(--line)', borderRadius: 100, padding: '10px 20px', fontSize: 13, color: 'var(--text)', fontWeight: 700 };
const unfreezeButtonStyle = { background: 'var(--gold)', border: 'none', borderRadius: 100, padding: '10px 20px', fontSize: 13, color: 'var(--ink-on-gold)', fontWeight: 700 };
const errorBoxStyle = { background: 'rgba(193, 87, 61, 0.12)', border: '1px solid rgba(193, 87, 61, 0.4)', borderRadius: 10, padding: '10px 14px', fontSize: 12, color: '#E39B84', marginBottom: 16 };
