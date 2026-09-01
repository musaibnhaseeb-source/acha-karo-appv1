'use client';

import { useEffect, useState } from 'react';
import { supabase } from '../../../lib/supabaseClient';

// Same user-grouped redesign as Moderation and Rewards, per direction — real respond logic
// underneath is unchanged (same table, same notification on response), only the organization
// and presentation changed.
export default function FeedbackPage() {
  const [userGroups, setUserGroups] = useState([]); // [{userId, name, items: [...]}]
  const [globalStats, setGlobalStats] = useState({ total: 0, responded: 0, unresponded: 0 });
  const [loadError, setLoadError] = useState(null);
  const [loading, setLoading] = useState(true);
  const [openUser, setOpenUser] = useState(null);

  useEffect(() => {
    load();
  }, []);

  async function load() {
    setLoading(true);
    const { data, error } = await supabase
      .from('feedback')
      .select('*, profiles!user_id(name)')
      .order('created_at', { ascending: false });
    if (error) {
      setLoadError(error.message);
      setLoading(false);
      return;
    }
    setLoadError(null);

    const rows = data ?? [];
    const stats = { total: rows.length, responded: 0, unresponded: 0 };
    const groups = {};
    for (const item of rows) {
      if (item.responded) stats.responded++;
      else stats.unresponded++;

      const userId = item.user_id;
      if (!groups[userId]) {
        groups[userId] = { userId, name: item.profiles?.name ?? 'Unknown user', items: [] };
      }
      groups[userId].items.push(item);
    }

    setGlobalStats(stats);
    setUserGroups(Object.values(groups));
    setLoading(false);
  }

  return (
    <div style={{ height: 'calc(100vh - 100px)', display: 'flex', flexDirection: 'column' }}>
      <div style={{ marginBottom: 16, flexShrink: 0 }}>
        <h1 style={{ fontSize: 22 }}>Feedback</h1>
        <p style={{ fontSize: 12, color: 'var(--text-soft)', marginTop: 4 }}>Grouped by user — {userGroups.length} have sent feedback.</p>
      </div>

      {loadError && <div style={errorBoxStyle}>Could not load feedback: {loadError}</div>}

      <div style={{ display: 'flex', gap: 20, flex: 1, minHeight: 0 }}>
        <div style={{ flex: 6, minHeight: 0 }}>
          <div style={panelStyle}>
            <div style={panelTitleStyle}>Users</div>
            <div style={{ overflowY: 'auto', flex: 1 }}>
              {loading ? (
                <p style={{ color: 'var(--text-soft)', fontSize: 13 }}>Loading…</p>
              ) : userGroups.length === 0 ? (
                <p style={{ color: 'var(--text-soft)', fontSize: 13 }}>{loadError ? '' : 'No feedback yet.'}</p>
              ) : (
                userGroups.map((g) => {
                  const unresponded = g.items.filter((i) => !i.responded).length;
                  return (
                    <div key={g.userId} style={rowStyle}>
                      <div style={avatarStyle}>{g.name.charAt(0).toUpperCase()}</div>
                      <div style={{ flex: 1, fontWeight: 600, fontSize: 13.5 }}>{g.name}</div>
                      <span style={{ fontSize: 11, color: 'var(--text-soft)', marginRight: 10 }}>
                        {g.items.length} item{g.items.length === 1 ? '' : 's'}{unresponded > 0 ? ` · ${unresponded} unresponded` : ''}
                      </span>
                      <button onClick={() => setOpenUser(g)} style={btnGhost}>View</button>
                    </div>
                  );
                })
              )}
            </div>
          </div>
        </div>

        <div style={{ flex: 4, minHeight: 0 }}>
          <div style={panelStyle}>
            <div style={panelTitleStyle}>Overview</div>
            <div style={{ overflowY: 'auto', flex: 1, display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10, alignContent: 'start' }}>
              <StatCard value={globalStats.total} label="Total" color="var(--text)" />
              <StatCard value={globalStats.responded} label="Responded" color="var(--olive)" />
              <StatCard value={globalStats.unresponded} label="Unresponded" color="var(--gold)" />
            </div>
          </div>
        </div>
      </div>

      {openUser && (
        <UserFeedbackDetail
          userGroup={openUser}
          onClose={() => setOpenUser(null)}
          onChanged={() => { setOpenUser(null); load(); }}
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

function UserFeedbackDetail({ userGroup, onClose, onChanged }) {
  const [drafts, setDrafts] = useState({});
  const [saving, setSaving] = useState(null);

  async function respond(item) {
    const text = (drafts[item.id] || '').trim();
    if (!text) return;
    setSaving(item.id);
    const { data: { user } } = await supabase.auth.getUser();
    const { error } = await supabase
      .from('feedback')
      .update({ responded: true, response: text, responded_by: user?.id, responded_at: new Date().toISOString() })
      .eq('id', item.id);
    if (!error) {
      await supabase.from('notifications').insert({
        user_id: item.user_id,
        type: 'feedback',
        title: 'You got a response',
        body: `A moderator responded to your feedback: "${text.length > 60 ? text.slice(0, 60) + '…' : text}"`,
      });
    }
    setSaving(null);
    if (!error) onChanged();
  }

  return (
    <div style={overlayStyle}>
      <div style={formCardStyle}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '20px 24px 0', flexShrink: 0 }}>
          <h2 style={{ fontSize: 18 }}>{userGroup.name}</h2>
          <button onClick={onClose} style={btnGhost}>Close</button>
        </div>
        <div style={{ overflowY: 'auto', flex: 1, padding: '20px 24px' }}>
          <div style={{ display: 'grid', gap: 14 }}>
            {userGroup.items.map((item) => (
              <div key={item.id} style={feedbackCardStyle}>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 8 }}>
                  <span className="mono" style={{ fontSize: 10.5, color: 'var(--text-soft)' }}>{new Date(item.created_at).toLocaleDateString()}</span>
                  <span style={{ color: 'var(--gold)', fontSize: 14 }}>{'★'.repeat(item.stars)}{'☆'.repeat(5 - item.stars)}</span>
                </div>
                {item.text && <p style={{ fontSize: 12.5, color: 'var(--text-soft)', marginBottom: 10 }}>{item.text}</p>}
                {item.responded ? (
                  <div style={respondedBoxStyle}>
                    <p className="mono" style={{ fontSize: 9.5, color: 'var(--olive)', marginBottom: 4 }}>YOUR RESPONSE</p>
                    <p style={{ fontSize: 12.5, color: 'var(--text)' }}>{item.response}</p>
                  </div>
                ) : (
                  <div style={{ display: 'flex', gap: 8, marginTop: 8 }}>
                    <input
                      type="text"
                      placeholder="Write a response…"
                      value={drafts[item.id] || ''}
                      onChange={(e) => setDrafts({ ...drafts, [item.id]: e.target.value })}
                      onKeyDown={(e) => e.key === 'Enter' && respond(item)}
                      style={inputStyle}
                    />
                    <button onClick={() => respond(item)} disabled={saving === item.id} style={sendButtonStyle}>
                      {saving === item.id ? '…' : 'Send'}
                    </button>
                  </div>
                )}
              </div>
            ))}
          </div>
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
const respondedBoxStyle = { background: 'rgba(159, 174, 110, 0.1)', border: '1px solid rgba(159, 174, 110, 0.3)', borderRadius: 10, padding: 10, marginTop: 8 };
const inputStyle = { flex: 1, padding: '9px 12px', borderRadius: 9, border: '1px solid rgba(246, 245, 236, 0.28)', background: '#1A2818', color: 'var(--text)', fontSize: 12.5, outline: 'none' };
const sendButtonStyle = { background: 'var(--gold)', border: 'none', borderRadius: 9, padding: '9px 16px', color: 'var(--ink-on-gold)', fontWeight: 700, fontSize: 12 };
const btnGhost = { background: 'var(--olive-card-strong)', color: 'var(--text)', border: '1px solid var(--line)', borderRadius: 100, padding: '8px 16px', fontSize: 12 };
const errorBoxStyle = { background: 'rgba(193, 87, 61, 0.12)', border: '1px solid rgba(193, 87, 61, 0.4)', borderRadius: 10, padding: '10px 14px', fontSize: 12, color: '#E39B84', marginBottom: 16 };
const overlayStyle = { position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.6)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 100 };
const formCardStyle = { background: 'var(--bg2)', border: '1px solid var(--line)', borderRadius: 20, width: '90%', maxWidth: 900, height: '85vh', display: 'flex', flexDirection: 'column', overflow: 'hidden' };
