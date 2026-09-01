'use client';

import { useEffect, useState } from 'react';
import { supabase } from '../../../lib/supabaseClient';
import { displayIcon } from '../../../lib/displayIcon';

// Complete redesign, per direction — real-world reward coordination organized by campaign
// (not a flat list), a real bulk-invite form matching the invites table's own columns, and a
// genuine automatic status workflow: won -> contacted happens the moment an invite is actually
// sent (not a separate manual click), scheduled is reached only by picking a real date, and
// done is never stored at all — it's computed live from whether that date has already passed.
export default function RewardsPage() {
  const [campaignGroups, setCampaignGroups] = useState([]); // [{campaign, winners: [...]}]
  const [loading, setLoading] = useState(true);
  const [loadError, setLoadError] = useState(null);
  const [openCampaign, setOpenCampaign] = useState(null); // the campaign group currently open in the detail overlay

  useEffect(() => {
    load();
  }, []);

  // A stored status is only ever 'won' (the default, nothing happened yet) or 'contacted' (a
  // real invite was actually sent). "scheduled" and "done" are never stored explicitly — both
  // are computed live from whether a real scheduled_date exists and whether it's already passed,
  // exactly matching the real workflow: scheduled is only reached by picking a real date, and
  // done isn't a status anyone clicks, it's just what "the date already happened" means.
  function displayStatus(coordination) {
    if (!coordination) return 'won';
    if (coordination.scheduled_date) {
      const isPast = new Date(coordination.scheduled_date) < new Date(new Date().toDateString());
      return isPast ? 'done' : 'scheduled';
    }
    return coordination.status ?? 'won';
  }

  async function load() {
    setLoading(true);
    // Real fix here: invites has no foreign key to roadmap_claims at all — it's linked by
    // user_id + campaign_id, not to a specific claim. PostgREST's nested-select join only works
    // when a real foreign key exists between the two tables, which doesn't here. Fetched
    // separately instead and matched by (user_id, campaign_id) in JavaScript.
    const [campaignsRes, claimsRes, invitesRes] = await Promise.all([
      supabase.from('campaigns').select('id, title, icon'),
      supabase
        .from('roadmap_claims')
        .select('id, user_id, stop_id, profiles(name), roadmap_stops(campaign_id, prize_name), reward_coordination(status, scheduled_date)')
        .eq('won', true),
      supabase.from('invites').select('user_id, campaign_id, seen'),
    ]);
    if (claimsRes.error) {
      setLoadError(claimsRes.error.message);
      setLoading(false);
      return;
    }
    setLoadError(null);

    const campaigns = campaignsRes.data ?? [];
    const claims = claimsRes.data ?? [];
    const invites = invitesRes.data ?? [];

    const groups = {};
    for (const claim of claims) {
      const campaignId = claim.roadmap_stops?.campaign_id;
      if (!campaignId) continue;
      if (!groups[campaignId]) {
        const campaign = campaigns.find((c) => c.id === campaignId);
        groups[campaignId] = { campaign: campaign ?? { id: campaignId, title: campaignId, icon: '🚩' }, winners: [] };
      }
      const coordination = Array.isArray(claim.reward_coordination) ? claim.reward_coordination[0] : claim.reward_coordination;
      const inviteRow = invites.find((i) => i.user_id === claim.user_id && i.campaign_id === campaignId);
      groups[campaignId].winners.push({
        claimId: claim.id,
        userId: claim.user_id,
        name: claim.profiles?.name ?? 'Unknown user',
        prizeName: claim.roadmap_stops?.prize_name ?? 'Prize',
        status: displayStatus(coordination),
        scheduledDate: coordination?.scheduled_date ?? null,
        invited: !!inviteRow,
        seen: !!inviteRow?.seen,
      });
    }

    setCampaignGroups(Object.values(groups));
    setLoading(false);
  }

  return (
    <div style={{ height: 'calc(100vh - 100px)', display: 'flex', flexDirection: 'column' }}>
      <div style={{ marginBottom: 16, flexShrink: 0 }}>
        <h1 style={{ fontSize: 22 }}>Rewards</h1>
        <p style={{ fontSize: 12, color: 'var(--text-soft)', marginTop: 4 }}>Real-world follow-through, organized by campaign.</p>
      </div>

      {loadError && <div style={errorBoxStyle}>Could not load rewards: {loadError}</div>}

      <div style={{ display: 'flex', gap: 20, flex: 1, minHeight: 0 }}>
        <div style={{ flex: 6, minHeight: 0 }}>
          <div style={panelStyle}>
            <div style={panelTitleStyle}>Campaigns with Winners</div>
            <div style={{ overflowY: 'auto', flex: 1 }}>
              {loading ? (
                <p style={{ color: 'var(--text-soft)', fontSize: 13 }}>Loading…</p>
              ) : campaignGroups.length === 0 ? (
                <p style={{ color: 'var(--text-soft)', fontSize: 13 }}>No real wins yet.</p>
              ) : (
                campaignGroups.map((g) => (
                  <div key={g.campaign.id} style={campaignRowStyle}>
                    <div style={campaignIconStyle}>{displayIcon(g.campaign.icon)}</div>
                    <div style={{ flex: 1, fontWeight: 600, fontSize: 13.5 }}>{g.campaign.title}</div>
                    <span style={{ fontSize: 11, color: 'var(--text-soft)', marginRight: 10 }}>{g.winners.length} winner{g.winners.length === 1 ? '' : 's'}</span>
                    <button onClick={() => setOpenCampaign(g)} style={btnGhost}>Manage</button>
                  </div>
                ))
              )}
            </div>
          </div>
        </div>

        <div style={{ flex: 4, minHeight: 0 }}>
          <div style={panelStyle}>
            <div style={panelTitleStyle}>Overview</div>
            <div style={{ overflowY: 'auto', flex: 1 }}>
              {campaignGroups.length === 0 ? (
                <p style={{ fontSize: 13, color: 'var(--text-soft)' }}>Nothing to show yet.</p>
              ) : (
                campaignGroups.map((g) => {
                  const seenCount = g.winners.filter((w) => w.seen).length;
                  return (
                    <div key={g.campaign.id} style={{ marginBottom: 18 }}>
                      <div style={{ fontSize: 13, fontWeight: 700, color: 'var(--gold)', marginBottom: 8 }}>{displayIcon(g.campaign.icon)} {g.campaign.title}</div>
                      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 8 }}>
                        <div style={statCardStyle}><div style={statValueStyle}>{g.winners.length}</div><div style={statLabelStyle}>Winners</div></div>
                        <div style={statCardStyle}><div style={statValueStyle}>{seenCount}</div><div style={statLabelStyle}>Seen</div></div>
                      </div>
                    </div>
                  );
                })
              )}
            </div>
          </div>
        </div>
      </div>

      {openCampaign && (
        <CampaignRewardsDetail
          group={openCampaign}
          onClose={() => setOpenCampaign(null)}
          onChanged={() => { load(); }}
        />
      )}
    </div>
  );
}

function CampaignRewardsDetail({ group, onClose, onChanged }) {
  const [showInviteForm, setShowInviteForm] = useState(false);

  return (
    <div style={overlayStyle}>
      <div style={formCardStyle}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '20px 24px 0', flexShrink: 0 }}>
          <h2 style={{ fontSize: 18 }}>{group.campaign.icon} {group.campaign.title}</h2>
          <button onClick={onClose} style={btnGhost}>Close</button>
        </div>

        <div style={{ padding: '16px 24px', flexShrink: 0 }}>
          <button onClick={() => setShowInviteForm(true)} style={btnGold}>
            ✉️ Send Invite to All Winners ({group.winners.filter((w) => !w.invited).length} not yet invited)
          </button>
        </div>

        <div style={{ overflowY: 'auto', flex: 1, padding: '0 24px 20px' }}>
          {group.winners.map((w) => (
            <WinnerRow key={w.claimId} winner={w} onChanged={onChanged} />
          ))}
        </div>
      </div>

      {showInviteForm && (
        <BulkInviteForm
          group={group}
          onClose={() => setShowInviteForm(false)}
          onSent={() => { setShowInviteForm(false); onChanged(); }}
        />
      )}
    </div>
  );
}

function WinnerRow({ winner, onChanged }) {
  const [saving, setSaving] = useState(false);

  async function setScheduledDate(dateStr) {
    setSaving(true);
    await supabase.from('reward_coordination').upsert(
      { claim_id: winner.claimId, status: 'contacted', scheduled_date: dateStr || null },
      { onConflict: 'claim_id' }
    );
    setSaving(false);
    onChanged();
  }

  return (
    <div style={winnerRowStyle}>
      <div style={{ flex: 1 }}>
        <div style={{ fontWeight: 600, fontSize: 13 }}>{winner.name}</div>
        <div style={{ fontSize: 11, color: 'var(--text-soft)' }}>{winner.prizeName}{winner.invited ? (winner.seen ? ' · seen' : ' · not seen yet') : ''}</div>
      </div>
      <span style={statusPillStyle(winner.status)}>{winner.status.toUpperCase()}</span>
      <input
        type="date"
        value={winner.scheduledDate ?? ''}
        disabled={winner.status === 'won' || saving}
        onChange={(e) => setScheduledDate(e.target.value)}
        style={{ ...inputStyle, width: 140, opacity: winner.status === 'won' ? 0.4 : 1 }}
        title={winner.status === 'won' ? 'Send an invite first' : 'Set a scheduled date'}
      />
    </div>
  );
}

function BulkInviteForm({ group, onClose, onSent }) {
  const [inviteType, setInviteType] = useState('karocast');
  const [message, setMessage] = useState('');
  const [formUrl, setFormUrl] = useState('');
  const [sending, setSending] = useState(false);
  const [sendError, setSendError] = useState(null);

  const notYetInvited = group.winners.filter((w) => !w.invited);

  async function send() {
    if (!message.trim()) {
      setSendError('A real message is required.');
      return;
    }
    setSending(true);
    setSendError(null);

    const inviteRows = notYetInvited.map((w) => ({
      user_id: w.userId,
      campaign_id: group.campaign.id,
      invite_type: inviteType,
      message,
      form_url: formUrl || null,
    }));
    const { error: inviteError } = await supabase.from('invites').insert(inviteRows);
    if (inviteError) {
      setSending(false);
      setSendError(inviteError.message);
      return;
    }

    const coordinationRows = notYetInvited.map((w) => ({ claim_id: w.claimId, status: 'contacted' }));
    await supabase.from('reward_coordination').upsert(coordinationRows, { onConflict: 'claim_id' });

    setSending(false);
    onSent();
  }

  return (
    <div style={overlayStyle}>
      <div style={{ ...formCardStyle, maxWidth: 560, height: 'auto', maxHeight: '80vh' }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '20px 24px 0', flexShrink: 0 }}>
          <h3 style={{ fontSize: 16 }}>Send Invite — {group.campaign.title}</h3>
          <button onClick={onClose} style={btnGhost}>Close</button>
        </div>
        <div style={{ padding: '16px 24px', overflowY: 'auto' }}>
          <p style={{ fontSize: 12, color: 'var(--text-soft)', marginBottom: 16 }}>
            Will be sent to {notYetInvited.length} winner{notYetInvited.length === 1 ? '' : 's'} who haven't been invited yet.
          </p>
          {sendError && <div style={errorBoxStyle}>{sendError}</div>}
          <div style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
            <Field label="Invite Type">
              <select value={inviteType} onChange={(e) => setInviteType(e.target.value)} style={inputStyle}>
                <option value="karocast">KaroCast</option>
                <option value="co_create">Co-Create</option>
              </select>
            </Field>
            <Field label="Message">
              <textarea value={message} onChange={(e) => setMessage(e.target.value)} style={{ ...inputStyle, minHeight: 90, resize: 'vertical' }} placeholder="What you want them to see in the app" />
            </Field>
            <Field label="Form URL (optional)">
              <input value={formUrl} onChange={(e) => setFormUrl(e.target.value)} style={inputStyle} placeholder="https://forms.google.com/..." />
            </Field>
          </div>
        </div>
        <div style={{ display: 'flex', justifyContent: 'flex-end', gap: 10, padding: '16px 24px', borderTop: '1px solid var(--line)', flexShrink: 0 }}>
          <button onClick={onClose} style={btnGhost}>Cancel</button>
          <button onClick={send} disabled={sending || notYetInvited.length === 0} style={btnGold}>{sending ? 'Sending…' : `Send to ${notYetInvited.length}`}</button>
        </div>
      </div>
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

function statusPillStyle(status) {
  const colors = { won: 'var(--gold)', contacted: 'var(--olive)', scheduled: '#5B8FA8', done: 'var(--text-soft)' };
  const color = colors[status] ?? 'var(--text-soft)';
  return { fontSize: 10, fontWeight: 700, color, background: `${color}22`, padding: '4px 10px', borderRadius: 100, whiteSpace: 'nowrap', minWidth: 78, textAlign: 'center' };
}

const panelStyle = { background: 'var(--olive-card)', border: '1px solid var(--line)', borderRadius: 16, padding: 20, height: '100%', display: 'flex', flexDirection: 'column' };
const panelTitleStyle = { fontSize: 13, fontWeight: 700, textTransform: 'uppercase', letterSpacing: 0.5, color: 'var(--text-soft)', marginBottom: 14, flexShrink: 0 };
const campaignRowStyle = { display: 'flex', alignItems: 'center', gap: 12, padding: 12, borderRadius: 12, marginBottom: 8, background: 'var(--olive-card-strong)' };
const campaignIconStyle = { width: 48, height: 48, borderRadius: 10, background: 'var(--gold)', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 20, flexShrink: 0 };
const winnerRowStyle = { display: 'flex', alignItems: 'center', gap: 12, padding: 12, borderRadius: 12, marginBottom: 8, background: 'var(--olive-card-strong)' };
const statCardStyle = { background: 'var(--olive-card-strong)', borderRadius: 10, padding: '10px 12px' };
const statValueStyle = { fontSize: 18, fontWeight: 700, fontFamily: 'Georgia, serif' };
const statLabelStyle = { fontSize: 9.5, color: 'var(--text-soft)', textTransform: 'uppercase', letterSpacing: 0.3, marginTop: 2 };
const btnGold = { background: 'var(--gold)', color: 'var(--ink-on-gold)', border: 'none', borderRadius: 100, padding: '10px 20px', fontWeight: 700, fontSize: 13 };
const btnGhost = { background: 'var(--olive-card-strong)', color: 'var(--text)', border: '1px solid var(--line)', borderRadius: 100, padding: '8px 16px', fontSize: 12 };
const errorBoxStyle = { background: 'rgba(193, 87, 61, 0.12)', border: '1px solid rgba(193, 87, 61, 0.4)', borderRadius: 10, padding: '10px 14px', fontSize: 12, color: '#E39B84', marginBottom: 16 };
const overlayStyle = { position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.6)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 100 };
const formCardStyle = { background: 'var(--bg2)', border: '1px solid var(--line)', borderRadius: 20, width: '90%', maxWidth: 900, height: '85vh', display: 'flex', flexDirection: 'column', overflow: 'hidden' };
const inputStyle = { background: '#1A2818', border: '1px solid rgba(246, 245, 236, 0.28)', borderRadius: 9, padding: '10px 12px', color: 'var(--text)', fontSize: 13.5, fontFamily: 'inherit' };
