'use client';

import { useState } from 'react';
import { supabase } from '../../../lib/supabaseClient';

// New — real, single-user compilation view. Search by either membership number or email in one
// field, auto-detecting which based on format (contains '@' = email, otherwise treated as a
// membership number). Three real actions: raising feedback on someone's behalf, sending a
// service-call invite (same invites mechanism already proven for KaroCast/co-create, a new
// invite_type value), and compensating points with a genuine, auditable log — not a silent
// points.update with no record of why.
export default function UsersPage() {
  const [query, setQuery] = useState('');
  const [searching, setSearching] = useState(false);
  const [searchError, setSearchError] = useState(null);
  const [profile, setProfile] = useState(null);
  const [data, setData] = useState(null); // { deeds, claims, skins, feedback, invites, membershipNumber, adjustments }
  const [tab, setTab] = useState('overview');
  const [actionModal, setActionModal] = useState(null); // 'complaint' | 'invite' | 'compensate' | null

  async function search() {
    const trimmed = query.trim();
    if (!trimmed) return;
    setSearching(true);
    setSearchError(null);
    setProfile(null);
    setData(null);

    let userId = null;
    if (trimmed.includes('@')) {
      const { data: row } = await supabase.from('profiles').select('id').ilike('email', trimmed).maybeSingle();
      userId = row?.id;
    } else {
      const { data: row } = await supabase.from('membership_numbers').select('user_id').eq('membership_number', trimmed).maybeSingle();
      userId = row?.user_id;
    }

    if (!userId) {
      setSearchError('No account found for that membership number or email.');
      setSearching(false);
      return;
    }

    await loadFullProfile(userId);
    setSearching(false);
  }

  async function loadFullProfile(userId) {
    const [profileRes, membershipRes, deedsRes, claimsRes, skinsRes, feedbackRes, invitesRes, adjustmentsRes, complaintsRes] = await Promise.all([
      supabase.from('profiles').select('*').eq('id', userId).single(),
      supabase.from('membership_numbers').select('membership_number').eq('user_id', userId).maybeSingle(),
      supabase.from('deeds').select('*').eq('user_id', userId).order('created_at', { ascending: false }),
      supabase.from('roadmap_claims').select('*, roadmap_stops(prize_name, campaign_id, campaigns(title))').eq('user_id', userId),
      supabase.from('user_vehicle_skins').select('*, vehicle_skins(name, icon, campaign_id)').eq('user_id', userId),
      supabase.from('feedback').select('*').eq('user_id', userId).order('created_at', { ascending: false }),
      supabase.from('invites').select('*').eq('user_id', userId).order('created_at', { ascending: false }),
      supabase.from('points_adjustments').select('*').eq('user_id', userId).order('created_at', { ascending: false }),
      supabase.from('complaints').select('*').eq('user_id', userId).order('created_at', { ascending: false }),
    ]);

    setProfile(profileRes.data);
    setData({
      membershipNumber: membershipRes.data?.membership_number ?? '—',
      deeds: deedsRes.data ?? [],
      claims: claimsRes.data ?? [],
      skins: skinsRes.data ?? [],
      feedback: feedbackRes.data ?? [],
      invites: invitesRes.data ?? [],
      adjustments: adjustmentsRes.data ?? [],
      complaints: complaintsRes.data ?? [],
    });
  }

  function refresh() {
    if (profile) loadFullProfile(profile.id);
  }

  return (
    <div style={{ height: 'calc(100vh - 100px)', display: 'flex', flexDirection: 'column' }}>
      <div style={{ marginBottom: 16, flexShrink: 0 }}>
        <h1 style={{ fontSize: 22 }}>User Management</h1>
        <p style={{ fontSize: 12, color: 'var(--text-soft)', marginTop: 4 }}>Search by membership number or email.</p>
      </div>

      <div style={{ display: 'flex', gap: 10, marginBottom: 20, flexShrink: 0 }}>
        <input
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          onKeyDown={(e) => e.key === 'Enter' && search()}
          placeholder="AK-142 or name@email.com"
          style={{ ...inputStyle, flex: 1, fontSize: 15, padding: '12px 16px' }}
        />
        <button onClick={search} disabled={searching} style={btnGold}>{searching ? 'Searching…' : 'Search'}</button>
      </div>

      {searchError && <div style={errorBoxStyle}>{searchError}</div>}

      {profile && data && (
        <div style={{ flex: 1, minHeight: 0, display: 'flex', flexDirection: 'column' }}>
          {/* Profile header */}
          <div style={{ ...panelStyle, height: 'auto', flexShrink: 0, marginBottom: 16 }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
              <div style={{ display: 'flex', gap: 14, alignItems: 'center' }}>
                <div style={avatarStyle}>{(profile.name || '?').charAt(0).toUpperCase()}</div>
                <div>
                  <div style={{ fontSize: 17, fontWeight: 700 }}>{profile.name}</div>
                  <div style={{ fontSize: 11.5, color: 'var(--text-soft)', marginTop: 2 }}>
                    {data.membershipNumber} · {profile.email ?? 'no email'} · {profile.phone ?? 'no phone'}
                  </div>
                  <div style={{ fontSize: 11.5, color: 'var(--text-soft)', marginTop: 2 }}>
                    {profile.city ?? '—'} · {profile.gender ?? '—'} · DOB {profile.dob ?? '—'} · role: {profile.role} · joined {profile.joined_at ? new Date(profile.joined_at).toLocaleDateString() : '—'}
                  </div>
                </div>
              </div>
              <div style={{ textAlign: 'right' }}>
                <div style={{ fontSize: 24, fontWeight: 700, fontFamily: 'Georgia, serif', color: 'var(--gold)' }}>{profile.points}</div>
                <div style={{ fontSize: 10, color: 'var(--text-soft)', textTransform: 'uppercase' }}>points · tier {profile.last_seen_tier}</div>
              </div>
            </div>
            <div style={{ display: 'flex', gap: 10, marginTop: 16 }}>
              <button onClick={() => setActionModal('complaint')} style={btnGhost}>📋 Raise Complaint</button>
              <button onClick={() => setActionModal('invite')} style={btnGhost}>✉️ Send Service Call Invite</button>
              <button onClick={() => setActionModal('compensate')} style={btnGold}>💰 Compensate</button>
            </div>
          </div>

          {/* Tabs */}
          <div style={{ display: 'flex', gap: 4, borderBottom: '1px solid var(--line)', flexShrink: 0, marginBottom: 16 }}>
            {['overview', 'complaints', 'deeds', 'roadmap', 'feedback', 'invites'].map((t) => (
              <div key={t} onClick={() => setTab(t)} style={t === tab ? tabActive : tabStyle}>{t.charAt(0).toUpperCase() + t.slice(1)}</div>
            ))}
          </div>

          <div style={{ overflowY: 'auto', flex: 1 }}>
            {tab === 'overview' && <OverviewTab profile={profile} data={data} />}
            {tab === 'complaints' && <ComplaintsTab complaints={data.complaints} onChanged={refresh} />}
            {tab === 'deeds' && <DeedsTab deeds={data.deeds} />}
            {tab === 'roadmap' && <RoadmapTab claims={data.claims} skins={data.skins} />}
            {tab === 'feedback' && <FeedbackTab feedback={data.feedback} />}
            {tab === 'invites' && <InvitesTab invites={data.invites} />}
          </div>
        </div>
      )}

      {actionModal === 'complaint' && <ComplaintModal userId={profile.id} onClose={() => setActionModal(null)} onDone={() => { setActionModal(null); refresh(); }} />}
      {actionModal === 'invite' && <ServiceInviteModal userId={profile.id} onClose={() => setActionModal(null)} onDone={() => { setActionModal(null); refresh(); }} />}
      {actionModal === 'compensate' && <CompensateModal userId={profile.id} currentPoints={profile.points} onClose={() => setActionModal(null)} onDone={() => { setActionModal(null); refresh(); }} />}
    </div>
  );
}

function OverviewTab({ profile, data }) {
  const approved = data.deeds.filter((d) => d.status === 'approved').length;
  const pending = data.deeds.filter((d) => d.status === 'pending').length;
  const rejected = data.deeds.filter((d) => d.status === 'rejected').length;
  const campaignsEngaged = new Set(data.claims.map((c) => c.roadmap_stops?.campaign_id).filter(Boolean)).size;
  const roadmapWins = data.claims.filter((c) => c.won).length;

  return (
    <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr 1fr', gap: 10 }}>
      <StatCard value={data.deeds.length} label="Deeds Total" />
      <StatCard value={approved} label="Approved" color="var(--olive)" />
      <StatCard value={pending} label="Pending" color="var(--gold)" />
      <StatCard value={rejected} label="Rejected" color="var(--rust)" />
      <StatCard value={campaignsEngaged} label="Campaigns" />
      <StatCard value={roadmapWins} label="Roadmap Wins" />
      <StatCard value={data.skins.length} label="Skins Owned" />
      <StatCard value={data.feedback.length} label="Feedback Sent" />
      <StatCard value={data.complaints.filter((c) => c.status === 'open').length} label="Open Complaints" color="var(--rust)" />
      {data.adjustments.length > 0 && (
        <div style={{ gridColumn: '1 / -1', marginTop: 10 }}>
          <div style={{ fontSize: 11.5, fontWeight: 700, color: 'var(--text-soft)', marginBottom: 8, textTransform: 'uppercase' }}>Point Adjustment History</div>
          {data.adjustments.map((a) => (
            <div key={a.id} style={{ ...rowCardStyle, display: 'flex', justifyContent: 'space-between' }}>
              <span style={{ fontSize: 12 }}>{a.reason}</span>
              <span style={{ fontSize: 12, fontWeight: 700, color: a.amount >= 0 ? 'var(--olive)' : 'var(--rust)' }}>{a.amount >= 0 ? '+' : ''}{a.amount} pts</span>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}

function ComplaintsTab({ complaints, onChanged }) {
  const [resolvingId, setResolvingId] = useState(null);
  const [note, setNote] = useState('');
  const [saving, setSaving] = useState(false);

  async function resolve(id) {
    setSaving(true);
    await supabase.from('complaints').update({ status: 'resolved', resolution_note: note, resolved_at: new Date().toISOString() }).eq('id', id);
    setSaving(false);
    setResolvingId(null);
    setNote('');
    onChanged();
  }

  if (complaints.length === 0) return <EmptyNote text="No complaints raised for this account." />;

  return complaints.map((c) => (
    <div key={c.id} style={rowCardStyle}>
      <div style={{ display: 'flex', justifyContent: 'space-between' }}>
        <span style={{ fontSize: 10.5, color: 'var(--text-soft)' }}>{new Date(c.created_at).toLocaleString()}</span>
        <span style={statusPillStyle(c.status === 'open' ? 'pending' : 'approved')}>{c.status.toUpperCase()}</span>
      </div>
      <p style={{ fontSize: 12.5, color: 'var(--text)', marginTop: 8 }}>{c.text}</p>
      {c.status === 'resolved' ? (
        <div style={{ marginTop: 10, padding: 10, background: 'rgba(159, 174, 110, 0.1)', border: '1px solid rgba(159, 174, 110, 0.3)', borderRadius: 10 }}>
          <p className="mono" style={{ fontSize: 9.5, color: 'var(--olive)', marginBottom: 4 }}>RESOLUTION</p>
          <p style={{ fontSize: 12, color: 'var(--text)' }}>{c.resolution_note || '(no note added)'}</p>
        </div>
      ) : resolvingId === c.id ? (
        <div style={{ marginTop: 10, display: 'flex', gap: 8 }}>
          <input value={note} onChange={(e) => setNote(e.target.value)} placeholder="How was this resolved?" style={{ ...inputStyle, flex: 1 }} />
          <button onClick={() => resolve(c.id)} disabled={saving} style={btnGold}>{saving ? '…' : 'Confirm'}</button>
        </div>
      ) : (
        <button onClick={() => setResolvingId(c.id)} style={{ ...btnGhost, marginTop: 10 }}>Mark Resolved</button>
      )}
    </div>
  ));
}

function DeedsTab({ deeds }) {
  if (deeds.length === 0) return <EmptyNote text="No deeds submitted yet." />;
  return deeds.map((d) => (
    <div key={d.id} style={rowCardStyle}>
      <div style={{ display: 'flex', justifyContent: 'space-between' }}>
        <strong style={{ fontSize: 13 }}>{d.type}</strong>
        <span style={statusPillStyle(d.status)}>{d.status?.toUpperCase()}</span>
      </div>
      <div style={{ fontSize: 10.5, color: 'var(--text-soft)', marginTop: 4 }}>{d.created_at ? new Date(d.created_at).toLocaleString() : ''} · +{d.points} pts</div>
    </div>
  ));
}

function RoadmapTab({ claims, skins }) {
  return (
    <div>
      <div style={{ fontSize: 11.5, fontWeight: 700, color: 'var(--text-soft)', marginBottom: 8, textTransform: 'uppercase' }}>Roadmap Claims</div>
      {claims.length === 0 ? <EmptyNote text="No roadmap activity yet." /> : claims.map((c) => (
        <div key={c.id} style={rowCardStyle}>
          <div style={{ display: 'flex', justifyContent: 'space-between' }}>
            <span style={{ fontSize: 13 }}>{c.roadmap_stops?.campaigns?.title ?? 'Unknown campaign'} — {c.roadmap_stops?.prize_name}</span>
            <span style={{ fontSize: 11, fontWeight: 700, color: c.won ? 'var(--olive)' : 'var(--text-soft)' }}>{c.won ? 'WON' : 'DID NOT WIN'}</span>
          </div>
        </div>
      ))}
      <div style={{ fontSize: 11.5, fontWeight: 700, color: 'var(--text-soft)', margin: '18px 0 8px', textTransform: 'uppercase' }}>Skins Owned</div>
      {skins.length === 0 ? <EmptyNote text="No skins owned yet." /> : skins.map((s) => (
        <div key={s.skin_id} style={{ ...rowCardStyle, display: 'flex', gap: 10, alignItems: 'center' }}>
          <span style={{ fontSize: 18 }}>{s.vehicle_skins?.icon?.startsWith('http') ? '🖼️' : s.vehicle_skins?.icon}</span>
          <span style={{ fontSize: 13 }}>{s.vehicle_skins?.name}</span>
        </div>
      ))}
    </div>
  );
}

function FeedbackTab({ feedback }) {
  if (feedback.length === 0) return <EmptyNote text="No feedback sent yet." />;
  return feedback.map((f) => (
    <div key={f.id} style={rowCardStyle}>
      <div style={{ display: 'flex', justifyContent: 'space-between' }}>
        <span style={{ color: 'var(--gold)', fontSize: 13 }}>{'★'.repeat(f.stars)}{'☆'.repeat(5 - f.stars)}</span>
        <span style={{ fontSize: 10.5, color: 'var(--text-soft)' }}>{f.responded ? 'Responded' : 'Awaiting response'}</span>
      </div>
      {f.text && <p style={{ fontSize: 12, color: 'var(--text-soft)', marginTop: 6 }}>{f.text}</p>}
    </div>
  ));
}

function InvitesTab({ invites }) {
  if (invites.length === 0) return <EmptyNote text="No invites sent yet." />;
  return invites.map((i) => (
    <div key={i.id} style={rowCardStyle}>
      <div style={{ display: 'flex', justifyContent: 'space-between' }}>
        <strong style={{ fontSize: 13 }}>{i.invite_type}</strong>
        <span style={{ fontSize: 10.5, color: 'var(--text-soft)' }}>{i.seen ? 'Seen' : 'Not seen yet'}</span>
      </div>
      <p style={{ fontSize: 12, color: 'var(--text-soft)', marginTop: 6 }}>{i.message}</p>
    </div>
  ));
}

// ============================================================================
// ACTION MODALS
// ============================================================================
function ComplaintModal({ userId, onClose, onDone }) {
  const [text, setText] = useState('');
  const [saving, setSaving] = useState(false);

  async function submit() {
    if (!text.trim()) return;
    setSaving(true);
    const { data: { user } } = await supabase.auth.getUser();
    // Real fix here: this used to insert into feedback, treating a complaint raised on someone's
    // behalf as if it were the same thing as feedback they sent themselves — genuinely different,
    // and needed its own real status and its own way to be closed out, not borrowed from
    // feedback's "responded" flag.
    await supabase.from('complaints').insert({ user_id: userId, raised_by: user?.id, text, status: 'open' });
    setSaving(false);
    onDone();
  }

  return (
    <SmallModal title="Raise Complaint on Behalf of Customer" onClose={onClose}>
      <Field label="What happened"><textarea value={text} onChange={(e) => setText(e.target.value)} style={{ ...inputStyle, minHeight: 90 }} /></Field>
      <ModalFooter onClose={onClose} onSubmit={submit} saving={saving} label="Raise Complaint" />
    </SmallModal>
  );
}

function ServiceInviteModal({ userId, onClose, onDone }) {
  const [message, setMessage] = useState('');
  const [formUrl, setFormUrl] = useState('');
  const [saving, setSaving] = useState(false);

  async function submit() {
    if (!message.trim()) return;
    setSaving(true);
    // Real reuse of the same invites mechanism already proven for KaroCast/co-create — a new
    // invite_type value, not a new table or new logic.
    await supabase.from('invites').insert({ user_id: userId, invite_type: 'service_call', message, form_url: formUrl || null });
    setSaving(false);
    onDone();
  }

  return (
    <SmallModal title="Send Service Call Invite" onClose={onClose}>
      <Field label="Message"><textarea value={message} onChange={(e) => setMessage(e.target.value)} style={{ ...inputStyle, minHeight: 90 }} placeholder="We'd like to schedule a call to resolve..." /></Field>
      <Field label="Scheduling Link (optional)"><input value={formUrl} onChange={(e) => setFormUrl(e.target.value)} style={inputStyle} placeholder="https://calendly.com/..." /></Field>
      <ModalFooter onClose={onClose} onSubmit={submit} saving={saving} label="Send Invite" />
    </SmallModal>
  );
}

function CompensateModal({ userId, currentPoints, onClose, onDone }) {
  const [amount, setAmount] = useState('');
  const [reason, setReason] = useState('');
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState(null);

  async function submit() {
    const amt = Number(amount);
    if (!amt || !reason.trim()) {
      setError('A real amount and reason are both required.');
      return;
    }
    setSaving(true);
    setError(null);
    const { data: { user } } = await supabase.auth.getUser();
    // Real audit trail first, then the actual credit — so there's always a record even if the
    // points update itself somehow fails.
    const { error: logError } = await supabase.from('points_adjustments').insert({ user_id: userId, amount: amt, reason, adjusted_by: user?.id });
    if (logError) {
      setSaving(false);
      setError(logError.message);
      return;
    }
    await supabase.from('profiles').update({ points: currentPoints + amt, last_points_activity: new Date().toISOString() }).eq('id', userId);
    setSaving(false);
    onDone();
  }

  return (
    <SmallModal title="Compensate Points" onClose={onClose}>
      {error && <div style={errorBoxStyle}>{error}</div>}
      <Field label="Points (use a negative number to deduct)"><input value={amount} onChange={(e) => setAmount(e.target.value)} style={inputStyle} placeholder="e.g. 50" /></Field>
      <Field label="Reason (kept as a real, permanent record)"><textarea value={reason} onChange={(e) => setReason(e.target.value)} style={{ ...inputStyle, minHeight: 70 }} placeholder="What went wrong, and why this amount" /></Field>
      <ModalFooter onClose={onClose} onSubmit={submit} saving={saving} label="Confirm Compensation" />
    </SmallModal>
  );
}

function SmallModal({ title, onClose, children }) {
  return (
    <div style={overlayStyle}>
      <div style={{ ...formCardStyle, maxWidth: 480, height: 'auto', maxHeight: '80vh' }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '20px 24px 0', flexShrink: 0 }}>
          <h3 style={{ fontSize: 16 }}>{title}</h3>
          <button onClick={onClose} style={btnGhost}>Close</button>
        </div>
        <div style={{ padding: '16px 24px', overflowY: 'auto', display: 'flex', flexDirection: 'column', gap: 14 }}>{children}</div>
      </div>
    </div>
  );
}

function ModalFooter({ onClose, onSubmit, saving, label }) {
  return (
    <div style={{ display: 'flex', justifyContent: 'flex-end', gap: 10, paddingTop: 6 }}>
      <button onClick={onClose} style={btnGhost}>Cancel</button>
      <button onClick={onSubmit} disabled={saving} style={btnGold}>{saving ? 'Saving…' : label}</button>
    </div>
  );
}

function Field({ label, children }) {
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 7 }}>
      <label style={{ fontSize: 12.5, fontWeight: 600, color: 'var(--text)' }}>{label}</label>
      {children}
    </div>
  );
}

function StatCard({ value, label, color }) {
  return (
    <div style={{ background: 'var(--olive-card-strong)', borderRadius: 10, padding: '10px 12px' }}>
      <div style={{ fontSize: 18, fontWeight: 700, fontFamily: 'Georgia, serif', color: color ?? 'var(--text)' }}>{value}</div>
      <div style={{ fontSize: 9.5, color: 'var(--text-soft)', textTransform: 'uppercase', letterSpacing: 0.3, marginTop: 2 }}>{label}</div>
    </div>
  );
}

function EmptyNote({ text }) {
  return <p style={{ fontSize: 13, color: 'var(--text-soft)' }}>{text}</p>;
}

function statusPillStyle(status) {
  const colors = { approved: 'var(--olive)', pending: 'var(--text-soft)', rejected: 'var(--rust)' };
  const color = colors[status] ?? 'var(--text-soft)';
  return { fontSize: 9.5, fontWeight: 700, color, background: `${color}22`, padding: '3px 9px', borderRadius: 100 };
}

const panelStyle = { background: 'var(--olive-card)', border: '1px solid var(--line)', borderRadius: 16, padding: 20 };
const avatarStyle = { width: 52, height: 52, borderRadius: 100, background: 'var(--gold)', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 22, fontWeight: 700, color: 'var(--ink-on-gold)', flexShrink: 0 };
const rowCardStyle = { background: 'var(--olive-card-strong)', border: '1px solid var(--line)', borderRadius: 12, padding: 12, marginBottom: 8 };
const tabStyle = { padding: '10px 16px', fontSize: 12.5, fontWeight: 600, color: 'var(--text-soft)', borderBottom: '2px solid transparent', cursor: 'pointer' };
const tabActive = { ...tabStyle, color: 'var(--gold)', borderBottomColor: 'var(--gold)' };
const btnGold = { background: 'var(--gold)', color: 'var(--ink-on-gold)', border: 'none', borderRadius: 100, padding: '10px 20px', fontWeight: 700, fontSize: 13 };
const btnGhost = { background: 'var(--olive-card-strong)', color: 'var(--text)', border: '1px solid var(--line)', borderRadius: 100, padding: '10px 20px', fontSize: 12.5 };
const errorBoxStyle = { background: 'rgba(193, 87, 61, 0.12)', border: '1px solid rgba(193, 87, 61, 0.4)', borderRadius: 10, padding: '10px 14px', fontSize: 12, color: '#E39B84', marginBottom: 16 };
const overlayStyle = { position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.6)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 100 };
const formCardStyle = { background: 'var(--bg2)', border: '1px solid var(--line)', borderRadius: 20, width: '90%', maxWidth: 900, height: '85vh', display: 'flex', flexDirection: 'column', overflow: 'hidden' };
const inputStyle = { background: '#1A2818', border: '1px solid rgba(246, 245, 236, 0.28)', borderRadius: 9, padding: '10px 12px', color: 'var(--text)', fontSize: 13.5, fontFamily: 'inherit' };
