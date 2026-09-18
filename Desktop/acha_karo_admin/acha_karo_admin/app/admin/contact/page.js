'use client';

import { useEffect, useState } from 'react';
import { supabase } from '../../../lib/supabaseClient';

// Website "Contact Us" submissions -- separate table from `feedback` on purpose: no star
// rating, no login required to submit (source is the public marketing site, not the app),
// and kept fully apart so it can never affect the Analytics average-rating calculation.
export default function ContactPage() {
  const [messages, setMessages] = useState([]);
  const [stats, setStats] = useState({ total: 0, responded: 0, unresponded: 0 });
  const [loadError, setLoadError] = useState(null);
  const [loading, setLoading] = useState(true);
  const [openMessage, setOpenMessage] = useState(null);

  useEffect(() => {
    load();
  }, []);

  async function load() {
    setLoading(true);
    const { data, error } = await supabase
      .from('website_contact_messages')
      .select('*')
      .order('created_at', { ascending: false });
    if (error) {
      setLoadError(error.message);
      setLoading(false);
      return;
    }
    setLoadError(null);
    const rows = data ?? [];
    setStats({
      total: rows.length,
      responded: rows.filter((r) => r.responded).length,
      unresponded: rows.filter((r) => !r.responded).length,
    });
    setMessages(rows);
    setLoading(false);
  }

  return (
    <div style={{ height: 'calc(100vh - 100px)', display: 'flex', flexDirection: 'column' }}>
      <div style={{ marginBottom: 16, flexShrink: 0 }}>
        <h1 style={{ fontSize: 22 }}>Contact Us</h1>
        <p style={{ fontSize: 12, color: 'var(--text-soft)', marginTop: 4 }}>From the website's Contact form — {messages.length} submitted.</p>
      </div>

      {loadError && <div style={errorBoxStyle}>Could not load contact messages: {loadError}</div>}

      <div style={{ display: 'flex', gap: 20, flex: 1, minHeight: 0 }}>
        <div style={{ flex: 6, minHeight: 0 }}>
          <div style={panelStyle}>
            <div style={panelTitleStyle}>Messages</div>
            <div style={{ overflowY: 'auto', flex: 1 }}>
              {loading ? (
                <p style={{ color: 'var(--text-soft)', fontSize: 13 }}>Loading…</p>
              ) : messages.length === 0 ? (
                <p style={{ color: 'var(--text-soft)', fontSize: 13 }}>{loadError ? '' : 'No messages yet.'}</p>
              ) : (
                messages.map((m) => (
                  <div key={m.id} style={rowStyle}>
                    <div style={avatarStyle}>{(m.name || '?').charAt(0).toUpperCase()}</div>
                    <div style={{ flex: 1 }}>
                      <div style={{ fontWeight: 600, fontSize: 13.5 }}>{m.name}</div>
                      <div style={{ fontSize: 11, color: 'var(--text-soft)' }}>{m.email} · {new Date(m.created_at).toLocaleDateString()}</div>
                    </div>
                    {!m.responded && <span style={badgeStyle}>Unresponded</span>}
                    <button onClick={() => setOpenMessage(m)} style={btnGhost}>View</button>
                  </div>
                ))
              )}
            </div>
          </div>
        </div>

        <div style={{ flex: 4, minHeight: 0 }}>
          <div style={panelStyle}>
            <div style={panelTitleStyle}>Overview</div>
            <div style={{ overflowY: 'auto', flex: 1, display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10, alignContent: 'start' }}>
              <StatCard value={stats.total} label="Total" color="var(--text)" />
              <StatCard value={stats.responded} label="Responded" color="var(--olive)" />
              <StatCard value={stats.unresponded} label="Unresponded" color="var(--gold)" />
            </div>
          </div>
        </div>
      </div>

      {openMessage && (
        <MessageDetail
          message={openMessage}
          onClose={() => setOpenMessage(null)}
          onChanged={() => { setOpenMessage(null); load(); }}
        />
      )}
    </div>
  );
}

function StatCard({ value, label, color }) {
  return (
    <div style={{ background: 'var(--olive-card-strong)', borderRadius: 10, padding: '10px 12px' }}>
      <div style={{ fontSize: 18, fontWeight: 700, fontFamily: 'Georgia, serif', color }}>{value}</div>
      <div style={{ fontSize: 9.5, color: 'var(--text-soft)', textTransform: 'uppercase', letterSpacing: 0.3, marginTop: 2 }}>{label}</div>
    </div>
  );
}

function MessageDetail({ message, onClose, onChanged }) {
  const [draft, setDraft] = useState(message.response || '');
  const [saving, setSaving] = useState(false);

  async function respond() {
    const text = draft.trim();
    if (!text) return;
    setSaving(true);
    const { data: { user } } = await supabase.auth.getUser();
    const { error } = await supabase
      .from('website_contact_messages')
      .update({ responded: true, response: text, responded_by: user?.id, responded_at: new Date().toISOString() })
      .eq('id', message.id);
    setSaving(false);
    if (!error) onChanged();
  }

  return (
    <div style={overlayStyle}>
      <div style={{ ...formCardStyle, maxWidth: 560, height: 'auto', maxHeight: '85vh' }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '20px 24px 0', flexShrink: 0 }}>
          <h2 style={{ fontSize: 16 }}>{message.name}</h2>
          <button onClick={onClose} style={btnGhost}>Close</button>
        </div>
        <div style={{ padding: '16px 24px', overflowY: 'auto', display: 'flex', flexDirection: 'column', gap: 14 }}>
          <div style={{ fontSize: 11.5, color: 'var(--text-soft)' }}>{message.email} · {new Date(message.created_at).toLocaleString()}</div>
          <div style={feedbackCardStyle}>
            <p style={{ fontSize: 13, color: 'var(--text)' }}>{message.message}</p>
          </div>
          {message.responded ? (
            <div style={respondedBoxStyle}>
              <p className="mono" style={{ fontSize: 9.5, color: 'var(--olive)', marginBottom: 4 }}>YOUR RESPONSE</p>
              <p style={{ fontSize: 12.5, color: 'var(--text)' }}>{message.response}</p>
            </div>
          ) : (
            <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
              <textarea
                placeholder="Write a response… (this is a record only -- there's no app account to notify)"
                value={draft}
                onChange={(e) => setDraft(e.target.value)}
                rows={4}
                style={{ ...inputStyle, resize: 'vertical', fontFamily: 'inherit' }}
              />
              <button onClick={respond} disabled={saving} style={sendButtonStyle}>{saving ? '…' : 'Mark responded'}</button>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}

const panelStyle = { background: 'var(--olive-card)', border: '1px solid var(--line)', borderRadius: 16, padding: 20, height: '100%', display: 'flex', flexDirection: 'column' };
const panelTitleStyle = { fontSize: 13, fontWeight: 700, textTransform: 'uppercase', letterSpacing: 0.5, color: 'var(--text-soft)', marginBottom: 14, flexShrink: 0 };
const rowStyle = { display: 'flex', alignItems: 'center', gap: 12, padding: 12, borderRadius: 12, marginBottom: 8, background: 'var(--olive-card-strong)' };
const avatarStyle = { width: 36, height: 36, borderRadius: 100, background: 'var(--gold)', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 15, fontWeight: 700, color: 'var(--ink-on-gold)', flexShrink: 0 };
const feedbackCardStyle = { background: 'var(--olive-card-strong)', border: '1px solid var(--line)', borderRadius: 14, padding: 16 };
const respondedBoxStyle = { background: 'rgba(159, 174, 110, 0.1)', border: '1px solid rgba(159, 174, 110, 0.3)', borderRadius: 10, padding: 10 };
const inputStyle = { padding: '9px 12px', borderRadius: 9, border: '1px solid rgba(246, 245, 236, 0.28)', background: '#1A2818', color: 'var(--text)', fontSize: 12.5, outline: 'none' };
const sendButtonStyle = { background: 'var(--gold)', border: 'none', borderRadius: 9, padding: '9px 16px', color: 'var(--ink-on-gold)', fontWeight: 700, fontSize: 12 };
const btnGhost = { background: 'var(--olive-card-strong)', color: 'var(--text)', border: '1px solid var(--line)', borderRadius: 100, padding: '8px 16px', fontSize: 12 };
const badgeStyle = { fontSize: 10, fontWeight: 700, padding: '3px 8px', borderRadius: 100, background: 'rgba(224,178,61,0.16)', color: 'var(--gold)', marginRight: 10 };
const errorBoxStyle = { background: 'rgba(193, 87, 61, 0.12)', border: '1px solid rgba(193, 87, 61, 0.4)', borderRadius: 10, padding: '10px 14px', fontSize: 12, color: '#E39B84', marginBottom: 16 };
const overlayStyle = { position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.6)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 100 };
const formCardStyle = { background: 'var(--bg2)', border: '1px solid var(--line)', borderRadius: 20, width: '90%', display: 'flex', flexDirection: 'column', overflow: 'hidden' };
