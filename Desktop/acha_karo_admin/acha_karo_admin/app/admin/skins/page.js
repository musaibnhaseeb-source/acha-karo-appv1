'use client';

import { useEffect, useState } from 'react';
import { supabase } from '../../../lib/supabaseClient';
import { displayIcon } from '../../../lib/displayIcon';

// New — a real, dedicated place to manage vehicle skins and each campaign's Hall of Fame
// badge/sticker content, rather than these being buried inside each individual campaign's own
// edit form. Skins and badges/stickers are genuinely different underlying tables (vehicle_skins
// vs. fields directly on campaigns) — kept as two real tabs here rather than forced into one
// list, since they don't share a shape.
export default function SkinsAdminPage() {
  const [tab, setTab] = useState('skins');
  const [skins, setSkins] = useState([]);
  const [campaigns, setCampaigns] = useState([]);
  const [loading, setLoading] = useState(true);
  const [loadError, setLoadError] = useState(null);
  const [editingSkin, setEditingSkin] = useState(null);
  const [editingBadges, setEditingBadges] = useState(null);

  useEffect(() => {
    load();
  }, []);

  async function load() {
    setLoading(true);
    const [skinsRes, campaignsRes] = await Promise.all([
      supabase.from('vehicle_skins').select('*, campaigns(title)').order('campaign_id'),
      supabase.from('campaigns').select('id, title, icon, hof_badge_name, hof_badge_icon, hof_sticker_name, hof_sticker_icon').order('title'),
    ]);
    if (skinsRes.error) {
      setLoadError(skinsRes.error.message);
      setLoading(false);
      return;
    }
    setLoadError(null);
    setSkins(skinsRes.data ?? []);
    setCampaigns(campaignsRes.data ?? []);
    setLoading(false);
  }

  async function toggleVisible(skin) {
    await supabase.from('vehicle_skins').update({ visible: !skin.visible }).eq('id', skin.id);
    load();
  }

  return (
    <div style={{ height: 'calc(100vh - 100px)', display: 'flex', flexDirection: 'column' }}>
      <div style={{ marginBottom: 16, flexShrink: 0 }}>
        <h1 style={{ fontSize: 22 }}>Skins, Badges & Stickers</h1>
      </div>

      <div style={{ display: 'flex', gap: 4, borderBottom: '1px solid var(--line)', marginBottom: 16, flexShrink: 0 }}>
        <div onClick={() => setTab('skins')} style={tab === 'skins' ? tabActive : tabStyle}>Vehicle Skins</div>
        <div onClick={() => setTab('badges')} style={tab === 'badges' ? tabActive : tabStyle}>Badges & Stickers</div>
      </div>

      {loadError && <div style={errorBoxStyle}>Could not load: {loadError}</div>}

      <div style={{ overflowY: 'auto', flex: 1 }}>
        {loading ? (
          <p style={{ color: 'var(--text-soft)', fontSize: 13 }}>Loading…</p>
        ) : tab === 'skins' ? (
          skins.length === 0 ? <p style={{ color: 'var(--text-soft)', fontSize: 13 }}>{loadError ? '' : 'No skins yet.'}</p> : skins.map((skin) => (
            <div key={skin.id} style={{ ...rowStyle, opacity: skin.visible === false ? 0.55 : 1 }}>
              <div style={iconBoxStyle}>{displayIcon(skin.icon)}</div>
              <div style={{ flex: 1 }}>
                <div style={{ fontWeight: 600, fontSize: 13.5 }}>{skin.name}</div>
                <div style={{ fontSize: 11, color: 'var(--text-soft)' }}>{skin.campaigns?.title ?? skin.campaign_id} · {skin.points_cost} pts{skin.visible === false ? ' · Paused' : ''}</div>
              </div>
              <button onClick={() => setEditingSkin(skin)} style={btnGhost}>Edit</button>
              <button onClick={() => toggleVisible(skin)} style={skin.visible === false ? unpauseButtonStyle : pauseButtonStyle}>
                {skin.visible === false ? 'Unpause' : 'Pause'}
              </button>
            </div>
          ))
        ) : (
          campaigns.map((c) => (
            <div key={c.id} style={rowStyle}>
              <div style={iconBoxStyle}>{displayIcon(c.icon)}</div>
              <div style={{ flex: 1 }}>
                <div style={{ fontWeight: 600, fontSize: 13.5 }}>{c.title}</div>
                <div style={{ fontSize: 11, color: 'var(--text-soft)' }}>
                  {c.hof_badge_name ? `Badge: ${c.hof_badge_name}` : 'No badge set'} · {c.hof_sticker_name ? `Sticker: ${c.hof_sticker_name}` : 'No sticker set'}
                </div>
              </div>
              <button onClick={() => setEditingBadges(c)} style={btnGhost}>Edit</button>
            </div>
          ))
        )}
      </div>

      {editingSkin && <SkinEditModal skin={editingSkin} onClose={() => setEditingSkin(null)} onSaved={() => { setEditingSkin(null); load(); }} />}
      {editingBadges && <BadgeEditModal campaign={editingBadges} onClose={() => setEditingBadges(null)} onSaved={() => { setEditingBadges(null); load(); }} />}
    </div>
  );
}

function SkinEditModal({ skin, onClose, onSaved }) {
  const [name, setName] = useState(skin.name);
  const [icon, setIcon] = useState(skin.icon);
  const [pointsCost, setPointsCost] = useState(skin.points_cost);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState(null);

  async function save() {
    setSaving(true);
    const { error } = await supabase.from('vehicle_skins').update({ name, icon, points_cost: Number(pointsCost) || 0 }).eq('id', skin.id);
    setSaving(false);
    if (error) { setError(error.message); return; }
    onSaved();
  }

  // Real fix here: the "Remove" option inside the Campaigns form's Skins tab only ever removed
  // a skin from that form's own local view — saving never actually deleted it from the
  // database. A genuine delete is offered here instead, with a real, honest warning about why
  // it's very likely to fail (foreign key references from anyone who already owns it, or from
  // a roadmap stop still pointing at it) — pausing is offered as the real, safer default action.
  async function tryDelete() {
    if (!confirm(`Delete "${skin.name}" permanently? This will fail if anyone already owns it or a roadmap stop still references it — Pause is the safer option in that case.`)) return;
    setSaving(true);
    const { error } = await supabase.from('vehicle_skins').delete().eq('id', skin.id);
    setSaving(false);
    if (error) { setError(`Could not delete: ${error.message}`); return; }
    onSaved();
  }

  return (
    <SmallModal title={`Edit "${skin.name}"`} onClose={onClose}>
      {error && <div style={errorBoxStyle}>{error}</div>}
      <Field label="Name"><input value={name} onChange={(e) => setName(e.target.value)} style={inputStyle} /></Field>
      <Field label="Icon (emoji or image URL)"><input value={icon} onChange={(e) => setIcon(e.target.value)} style={inputStyle} /></Field>
      <Field label="Points Cost"><input value={pointsCost} onChange={(e) => setPointsCost(e.target.value)} style={inputStyle} /></Field>
      <div style={{ display: 'flex', justifyContent: 'space-between', paddingTop: 6 }}>
        <button onClick={tryDelete} disabled={saving} style={deleteButtonStyle}>Delete Permanently</button>
        <div style={{ display: 'flex', gap: 10 }}>
          <button onClick={onClose} style={btnGhost}>Cancel</button>
          <button onClick={save} disabled={saving} style={btnGold}>{saving ? 'Saving…' : 'Save'}</button>
        </div>
      </div>
    </SmallModal>
  );
}

function BadgeEditModal({ campaign, onClose, onSaved }) {
  const [badgeName, setBadgeName] = useState(campaign.hof_badge_name ?? '');
  const [badgeIcon, setBadgeIcon] = useState(campaign.hof_badge_icon ?? '');
  const [stickerName, setStickerName] = useState(campaign.hof_sticker_name ?? '');
  const [stickerIcon, setStickerIcon] = useState(campaign.hof_sticker_icon ?? '');
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState(null);

  async function save() {
    setSaving(true);
    const { error } = await supabase.from('campaigns').update({
      hof_badge_name: badgeName || null, hof_badge_icon: badgeIcon || null,
      hof_sticker_name: stickerName || null, hof_sticker_icon: stickerIcon || null,
    }).eq('id', campaign.id);
    setSaving(false);
    if (error) { setError(error.message); return; }
    onSaved();
  }

  return (
    <SmallModal title={`${campaign.title} — Badge & Sticker`} onClose={onClose}>
      {error && <div style={errorBoxStyle}>{error}</div>}
      <Field label="Badge Name"><input value={badgeName} onChange={(e) => setBadgeName(e.target.value)} style={inputStyle} /></Field>
      <Field label="Badge Icon"><input value={badgeIcon} onChange={(e) => setBadgeIcon(e.target.value)} style={inputStyle} /></Field>
      <Field label="Sticker Name"><input value={stickerName} onChange={(e) => setStickerName(e.target.value)} style={inputStyle} /></Field>
      <Field label="Sticker Icon"><input value={stickerIcon} onChange={(e) => setStickerIcon(e.target.value)} style={inputStyle} /></Field>
      <p style={{ fontSize: 11, color: 'var(--text-soft)' }}>Leaving a field blank means that specific card just doesn't show in the Hall of Fame reveal — nothing breaks.</p>
      <div style={{ display: 'flex', justifyContent: 'flex-end', gap: 10, paddingTop: 6 }}>
        <button onClick={onClose} style={btnGhost}>Cancel</button>
        <button onClick={save} disabled={saving} style={btnGold}>{saving ? 'Saving…' : 'Save'}</button>
      </div>
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

function Field({ label, children }) {
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 7 }}>
      <label style={{ fontSize: 12.5, fontWeight: 600, color: 'var(--text)' }}>{label}</label>
      {children}
    </div>
  );
}

const rowStyle = { display: 'flex', alignItems: 'center', gap: 12, padding: 12, borderRadius: 12, marginBottom: 8, background: 'var(--olive-card-strong)' };
const iconBoxStyle = { width: 40, height: 40, borderRadius: 8, background: 'var(--gold)', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 18, flexShrink: 0 };
const tabStyle = { padding: '10px 16px', fontSize: 12.5, fontWeight: 600, color: 'var(--text-soft)', borderBottom: '2px solid transparent', cursor: 'pointer' };
const tabActive = { ...tabStyle, color: 'var(--gold)', borderBottomColor: 'var(--gold)' };
const btnGold = { background: 'var(--gold)', color: 'var(--ink-on-gold)', border: 'none', borderRadius: 100, padding: '10px 20px', fontWeight: 700, fontSize: 13 };
const btnGhost = { background: 'var(--olive-card-strong)', color: 'var(--text)', border: '1px solid var(--line)', borderRadius: 100, padding: '8px 16px', fontSize: 12 };
const pauseButtonStyle = { background: 'rgba(193, 87, 61, 0.16)', border: '1px solid rgba(193, 87, 61, 0.4)', borderRadius: 100, padding: '8px 16px', fontSize: 12, color: '#E39B84' };
const unpauseButtonStyle = { background: 'rgba(91, 143, 168, 0.2)', border: '1px solid #5B8FA8', borderRadius: 100, padding: '8px 16px', fontSize: 12, color: '#9BC4DA' };
const deleteButtonStyle = { background: 'transparent', border: 'none', color: 'var(--rust)', fontSize: 12, cursor: 'pointer' };
const errorBoxStyle = { background: 'rgba(193, 87, 61, 0.12)', border: '1px solid rgba(193, 87, 61, 0.4)', borderRadius: 10, padding: '10px 14px', fontSize: 12, color: '#E39B84', marginBottom: 16 };
const overlayStyle = { position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.6)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 100 };
const formCardStyle = { background: 'var(--bg2)', border: '1px solid var(--line)', borderRadius: 20, width: '90%', maxWidth: 900, display: 'flex', flexDirection: 'column', overflow: 'hidden' };
const inputStyle = { background: '#1A2818', border: '1px solid rgba(246, 245, 236, 0.28)', borderRadius: 9, padding: '10px 12px', color: 'var(--text)', fontSize: 13.5, fontFamily: 'inherit' };
