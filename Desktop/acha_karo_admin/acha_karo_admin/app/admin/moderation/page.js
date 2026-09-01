'use client';

import { useEffect, useState } from 'react';
import { supabase } from '../../../lib/supabaseClient';

// Complete redesign, per direction — grouped by user rather than a flat queue, matching the
// same UI language as Campaigns/Rewards. Real approve/reject/reject-and-flag logic unchanged
// underneath (same tables, same points-crediting, same notifications) — only the organization
// and presentation changed.
export default function ModerationPage() {
  const [userGroups, setUserGroups] = useState([]); // [{userId, name, pending: [...]}]
  const [globalStats, setGlobalStats] = useState({ pending: 0, approved: 0, rejected: 0, flagged: 0 });
  const [loading, setLoading] = useState(true);
  const [loadError, setLoadError] = useState(null);
  const [openUser, setOpenUser] = useState(null);

  useEffect(() => {
    load();
  }, []);

  async function load() {
    setLoading(true);
    // Real fix here too, matching the same "newest first" direction — this previously ordered
    // ascending (oldest first), the opposite of what was actually asked for.
    const { data, error } = await supabase
      .from('moderation_queue')
      .select('*, deeds(*, profiles(name))')
      // Real fix here: reverted a genuine misread on my part — a moderation queue should
      // naturally process oldest-first, so nothing sits waiting longer than necessary. My
      // earlier change to newest-first was a mistake, not what was actually meant.
      .order('created_at', { ascending: true });
    if (error) {
      setLoadError(error.message);
      setLoading(false);
      return;
    }
    setLoadError(null);

    const rows = data ?? [];
    const stats = { pending: 0, approved: 0, rejected: 0, flagged: 0 };
    const groups = {};

    for (const item of rows) {
      if (item.flagged) stats.flagged++;
      if (item.outcome === 'approved') stats.approved++;
      else if (item.outcome === 'rejected') stats.rejected++;
      else stats.pending++;

      if (item.outcome !== null) continue; // only pending items form the reviewable groups below
      const userId = item.deeds?.user_id;
      if (!userId) continue;
      if (!groups[userId]) {
        groups[userId] = { userId, name: item.deeds?.profiles?.name ?? 'Unknown user', pending: [] };
      }
      groups[userId].pending.push(item);
    }

    setGlobalStats(stats);
    setUserGroups(Object.values(groups));
    setLoading(false);
  }

  return (
    <div style={{ height: 'calc(100vh - 100px)', display: 'flex', flexDirection: 'column' }}>
      <div style={{ marginBottom: 16, flexShrink: 0 }}>
        <h1 style={{ fontSize: 22 }}>Moderation</h1>
        <p style={{ fontSize: 12, color: 'var(--text-soft)', marginTop: 4 }}>Grouped by user — {userGroups.length} with something pending.</p>
      </div>

      {loadError && <div style={errorBoxStyle}>Could not load moderation queue: {loadError}</div>}

      <div style={{ display: 'flex', gap: 20, flex: 1, minHeight: 0 }}>
        <div style={{ flex: 6, minHeight: 0 }}>
          <div style={panelStyle}>
            <div style={panelTitleStyle}>Users with Pending Deeds</div>
            <div style={{ overflowY: 'auto', flex: 1 }}>
              {loading ? (
                <p style={{ color: 'var(--text-soft)', fontSize: 13 }}>Loading…</p>
              ) : userGroups.length === 0 ? (
                <p style={{ color: 'var(--text-soft)', fontSize: 13 }}>Nothing pending review.</p>
              ) : (
                userGroups.map((g) => (
                  <div key={g.userId} style={rowStyle}>
                    <div style={avatarStyle}>{g.name.charAt(0).toUpperCase()}</div>
                    <div style={{ flex: 1, fontWeight: 600, fontSize: 13.5 }}>{g.name}</div>
                    <span style={{ fontSize: 11, color: 'var(--text-soft)', marginRight: 10 }}>{g.pending.length} pending</span>
                    <button onClick={() => setOpenUser(g)} style={btnGhost}>Review</button>
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
              <StatCard value={globalStats.pending} label="Pending" color="var(--gold)" />
              <StatCard value={globalStats.approved} label="Approved" color="var(--olive)" />
              <StatCard value={globalStats.rejected} label="Rejected" color="var(--rust)" />
              <StatCard value={globalStats.flagged} label="Flagged" color="var(--rust)" />
            </div>
          </div>
        </div>
      </div>

      {openUser && (
        <UserReviewDetail
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

function UserReviewDetail({ userGroup, onClose, onChanged }) {
  const [photoUrls, setPhotoUrls] = useState({});
  const [actingOn, setActingOn] = useState(null);

  useEffect(() => {
    loadPhotos();
  }, []);

  async function loadPhotos() {
    const urls = {};
    for (const item of userGroup.pending) {
      const path = item.deeds?.photo_url;
      if (!path) continue;
      const { data } = await supabase.storage.from('deed-photos').createSignedUrl(path, 60);
      if (data?.signedUrl) urls[item.id] = data.signedUrl;
    }
    setPhotoUrls(urls);
  }

  async function act(item, outcome, flag) {
    setActingOn(item.id);
    const { data: { user } } = await supabase.auth.getUser();

    const { error: deedError } = await supabase.from('deeds').update({ status: outcome }).eq('id', item.deed_id);
    const { error: queueError } = await supabase
      .from('moderation_queue')
      .update({ outcome, resolved_at: new Date().toISOString(), resolved_by: user?.id, flagged: !!flag })
      .eq('id', item.id);

    if (deedError || queueError) {
      setActingOn(null);
      return;
    }

    if (outcome === 'approved' && item.deeds) {
      const { data: profile } = await supabase.from('profiles').select('points').eq('id', item.deeds.user_id).single();
      if (profile) {
        await supabase.from('profiles').update({ points: profile.points + item.deeds.points, last_points_activity: new Date().toISOString() }).eq('id', item.deeds.user_id);
      }
    }

    if (item.deeds) {
      // Real fix here: a flag is genuinely an internal, admin-only signal — the notification
      // sent to the person is worded identically to a normal rejection either way, matching
      // "for the user it will be the same as rejected."
      await supabase.from('notifications').insert({
        user_id: item.deeds.user_id,
        type: 'taskActioned',
        title: outcome === 'approved' ? 'Deed approved' : 'Deed rejected',
        body: outcome === 'approved'
          ? `Your ${item.deeds.type} submission was approved — +${item.deeds.points} points.`
          : `Your ${item.deeds.type} submission was rejected.`,
      });
    }

    setActingOn(null);
    onChanged();
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
            {userGroup.pending.map((item) => (
              <div key={item.id} style={deedCardStyle}>
                <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 8 }}>
                  <strong style={{ fontSize: 13.5 }}>{item.deeds?.type ?? 'unknown'}</strong>
                  <span className="mono" style={{ fontSize: 11, color: 'var(--text-soft)' }}>+{item.deeds?.points ?? 0} pts</span>
                </div>
                {item.reason && <p style={{ fontSize: 11.5, color: 'var(--text-soft)', marginBottom: 8 }}>{item.reason}</p>}
                {item.deeds?.gps_lat && (
                  <p className="mono" style={{ fontSize: 10, color: 'var(--text-soft)', marginBottom: 8 }}>
                    📍 {item.deeds.gps_lat.toFixed(4)}, {item.deeds.gps_lng.toFixed(4)}
                  </p>
                )}
                {photoUrls[item.id] ? (
                  <img src={photoUrls[item.id]} alt="Submitted deed" style={{ width: 140, height: 140, objectFit: 'cover', borderRadius: 10, marginBottom: 10 }} />
                ) : (
                  <div style={noPhotoStyle}>⚠️ No photo attached</div>
                )}
                <div style={{ display: 'flex', gap: 8 }}>
                  <button onClick={() => act(item, 'approved', false)} disabled={actingOn === item.id} style={approveButtonStyle}>✓ Approve</button>
                  <button onClick={() => act(item, 'rejected', false)} disabled={actingOn === item.id} style={rejectButtonStyle}>✕ Reject</button>
                  <button onClick={() => act(item, 'rejected', true)} disabled={actingOn === item.id} style={flagButtonStyle}>🚩 Reject & Flag</button>
                </div>
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
const deedCardStyle = { background: 'var(--olive-card-strong)', border: '1px solid var(--line)', borderRadius: 14, padding: 16 };
const noPhotoStyle = { background: 'rgba(193, 87, 61, 0.12)', borderRadius: 10, padding: '10px 0', textAlign: 'center', fontSize: 11, color: '#E39B84', marginBottom: 10, width: 140 };
const btnGhost = { background: 'var(--olive-card-strong)', color: 'var(--text)', border: '1px solid var(--line)', borderRadius: 100, padding: '8px 16px', fontSize: 12 };
const errorBoxStyle = { background: 'rgba(193, 87, 61, 0.12)', border: '1px solid rgba(193, 87, 61, 0.4)', borderRadius: 10, padding: '10px 14px', fontSize: 12, color: '#E39B84', marginBottom: 16 };
const overlayStyle = { position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.6)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 100 };
const formCardStyle = { background: 'var(--bg2)', border: '1px solid var(--line)', borderRadius: 20, width: '90%', maxWidth: 900, height: '85vh', display: 'flex', flexDirection: 'column', overflow: 'hidden' };
const approveButtonStyle = { flex: 1, background: 'var(--olive)', border: 'none', borderRadius: 10, padding: '10px 0', color: 'var(--ink-on-gold)', fontWeight: 700, fontSize: 12 };
const rejectButtonStyle = { flex: 1, background: 'rgba(193, 87, 61, 0.16)', border: '1px solid rgba(193, 87, 61, 0.4)', borderRadius: 10, padding: '10px 0', color: '#E39B84', fontWeight: 700, fontSize: 12 };
const flagButtonStyle = { flex: 1, background: 'rgba(193, 87, 61, 0.3)', border: '1px solid var(--rust)', borderRadius: 10, padding: '10px 0', color: '#F6D6CC', fontWeight: 700, fontSize: 12 };
