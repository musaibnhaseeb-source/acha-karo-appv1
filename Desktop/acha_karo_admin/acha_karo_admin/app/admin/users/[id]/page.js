'use client';

import { useEffect, useState } from 'react';
import { useParams, useRouter } from 'next/navigation';
import { supabase } from '../../../../lib/supabaseClient';
import { DEED_CATALOG } from '../../../../lib/deedCatalog';

// New — a moderator's view of a single user's full activity. Reachable from Analytics' #1 User
// card for now; a proper user search/list is a reasonable follow-up if this needs to be reached
// more generally, not built in this pass.
export default function UserProfilePage() {
  const { id } = useParams();
  const router = useRouter();
  const [profile, setProfile] = useState(null);
  const [deeds, setDeeds] = useState([]);
  const [friendNames, setFriendNames] = useState([]);
  const [friendsAddedCount, setFriendsAddedCount] = useState(0);
  const [feedback, setFeedback] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    load();
  }, [id]);

  async function load() {
    setLoading(true);

    const [profileRes, deedsRes, friendshipsRes, inviteCodesRes, feedbackRes] = await Promise.all([
      supabase.from('profiles').select('*').eq('id', id).single(),
      supabase.from('deeds').select('*').eq('user_id', id).order('created_at', { ascending: false }),
      supabase.from('friendships').select('*').or(`requester_id.eq.${id},addressee_id.eq.${id}`).eq('status', 'approved'),
      supabase.from('invite_codes').select('id', { count: 'exact', head: true }).eq('issued_by', id).eq('used', true),
      supabase.from('feedback').select('*').eq('user_id', id).order('created_at', { ascending: false }),
    ]);

    setProfile(profileRes.data);
    setDeeds(deedsRes.data || []);
    setFriendsAddedCount(inviteCodesRes.count || 0);
    setFeedback(feedbackRes.data || []);

    // Friendships reference two different people depending on which side this user is on —
    // fetched separately and matched in JS here rather than relying on exact auto-generated
    // foreign-key constraint names for an embedded query, which can't be verified without
    // actually running this.
    const friendships = friendshipsRes.data || [];
    const otherIds = friendships.map((f) => (f.requester_id === id ? f.addressee_id : f.requester_id));
    if (otherIds.length > 0) {
      const { data: friendProfiles } = await supabase.from('profiles').select('id, name').in('id', otherIds);
      setFriendNames(friendProfiles || []);
    } else {
      setFriendNames([]);
    }

    setLoading(false);
  }

  if (loading) return <p style={{ color: 'var(--text-soft)', fontSize: 13 }}>Loading…</p>;
  if (!profile) return <p style={{ color: 'var(--text-soft)', fontSize: 13 }}>User not found.</p>;

  const avgRating = feedback.length > 0 ? (feedback.reduce((s, f) => s + f.stars, 0) / feedback.length).toFixed(1) : null;
  const approvedDeeds = deeds.filter((d) => d.status === 'approved');
  const pendingDeeds = deeds.filter((d) => d.status === 'pending');

  return (
    <div>
      <button onClick={() => router.back()} style={backButtonStyle}>← Back</button>

      <div style={{ display: 'flex', alignItems: 'center', gap: 16, marginBottom: 24 }}>
        <div style={avatarStyle}>{profile.name?.[0]?.toUpperCase() ?? '?'}</div>
        <div>
          <h2 style={{ fontSize: 19, fontWeight: 600 }}>{profile.name}</h2>
          <p className="mono" style={{ fontSize: 11.5, color: 'var(--text-soft)' }}>{profile.email}</p>
        </div>
      </div>

      <div style={cardGridStyle}>
        <StatCard label="Points Earned" value={(profile.points ?? 0).toLocaleString()} />
        <StatCard label="Registered Since" value={new Date(profile.joined_at).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' })} small />
        <StatCard label="Total Deeds" value={deeds.length} sub={`${approvedDeeds.length} approved, ${pendingDeeds.length} pending`} />
        <StatCard label="Feedbacks Given" value={feedback.length} sub={avgRating ? `Average rating given: ${avgRating} ★` : 'No feedback yet'} />
        <StatCard label="Friends Of" value={friendNames.length} sub={friendNames.length ? friendNames.map((f) => f.name).join(', ') : null} small />
        <StatCard label="Friends Added" value={friendsAddedCount} sub="via their invite links" />
      </div>

      {/* Honest placeholders — no redemption feature exists yet, per the current direction */}
      <div style={{ ...panelStyle, marginBottom: 20 }}>
        <div style={panelTitleStyle}>Redemptions</div>
        <p style={{ fontSize: 12, color: 'var(--text-soft)' }}>No redemption feature yet — will populate once built.</p>
      </div>
      <div style={{ ...panelStyle, marginBottom: 20 }}>
        <div style={panelTitleStyle}>Assigned Voucher Codes</div>
        <p style={{ fontSize: 12, color: 'var(--text-soft)' }}>No redemption feature yet — will populate once built.</p>
      </div>

      <div style={{ ...panelStyle, marginBottom: 20 }}>
        <div style={panelTitleStyle}>Activity History</div>
        {deeds.length === 0 ? (
          <p style={{ fontSize: 12, color: 'var(--text-soft)' }}>No deeds submitted yet.</p>
        ) : (
          <div style={{ display: 'grid', gap: 8 }}>
            {deeds.map((d) => (
              <div key={d.id} style={deedRowStyle}>
                <span>{DEED_CATALOG[d.type]?.icon ?? '❓'} {DEED_CATALOG[d.type]?.name ?? d.type}</span>
                <span className="mono" style={{ fontSize: 10.5, color: 'var(--text-soft)' }}>
                  {new Date(d.created_at).toLocaleDateString('en-US', { month: 'short', day: 'numeric' })}
                </span>
                <StatusPill status={d.status} />
              </div>
            ))}
          </div>
        )}
      </div>

      <div style={panelStyle}>
        <div style={panelTitleStyle}>Feedback Given</div>
        {feedback.length === 0 ? (
          <p style={{ fontSize: 12, color: 'var(--text-soft)' }}>No feedback submitted yet.</p>
        ) : (
          <div style={{ display: 'grid', gap: 10 }}>
            {feedback.map((f) => (
              <div key={f.id} style={feedbackRowStyle}>
                <div style={{ color: 'var(--gold)', fontSize: 13, marginBottom: 4 }}>{'★'.repeat(f.stars)}{'☆'.repeat(5 - f.stars)}</div>
                {f.text && <p style={{ fontSize: 12, color: 'var(--text-soft)' }}>{f.text}</p>}
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}

function StatCard({ label, value, sub, small }) {
  return (
    <div style={panelStyle}>
      <div style={{ fontSize: 10.5, color: 'var(--text-soft)', textTransform: 'uppercase', letterSpacing: 0.5, marginBottom: 6 }}>{label}</div>
      <div style={{ fontSize: small ? 14 : 20, fontWeight: 700 }}>{value}</div>
      {sub && <div style={{ fontSize: 10.5, color: 'var(--text-soft)', marginTop: 3 }}>{sub}</div>}
    </div>
  );
}

function StatusPill({ status }) {
  const colors = { approved: 'var(--olive)', pending: 'var(--text-soft)', rejected: 'var(--rust)' };
  return (
    <span style={{ fontSize: 10, fontWeight: 700, color: colors[status] || 'var(--text-soft)', textTransform: 'uppercase', marginLeft: 'auto' }}>{status}</span>
  );
}

const cardGridStyle = { display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 12, marginBottom: 20 };
const panelStyle = { background: 'var(--olive-card)', border: '1px solid var(--line)', borderRadius: 16, padding: 18 };
const panelTitleStyle = { fontSize: 13, fontWeight: 700, marginBottom: 12 };
const avatarStyle = { width: 56, height: 56, borderRadius: '50%', background: 'var(--olive-card-strong)', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 22, fontWeight: 700, color: 'var(--gold)' };
const backButtonStyle = { background: 'none', border: 'none', color: 'var(--text-soft)', fontSize: 12.5, marginBottom: 16, padding: 0 };
const deedRowStyle = { display: 'flex', alignItems: 'center', gap: 12, fontSize: 12.5, padding: '8px 0', borderBottom: '1px solid var(--line)' };
const feedbackRowStyle = { padding: '10px 0', borderBottom: '1px solid var(--line)' };
