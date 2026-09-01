'use client';

import { useEffect, useState } from 'react';
import { supabase } from '../../../lib/supabaseClient';
import { displayIcon } from '../../../lib/displayIcon';

// Real, functional Campaigns management — replaces the earlier static mockup entirely. Layout
// is fixed to the viewport (no page-level scroll at all); the two 60/40 panels and the edit
// form each scroll independently within their own fixed-height card, per direction.
export default function CampaignsPage() {
  const [campaigns, setCampaigns] = useState([]);
  const [liveStats, setLiveStats] = useState({});
  const [loading, setLoading] = useState(true);
  const [loadError, setLoadError] = useState(null);
  const [editing, setEditing] = useState(null); // null = closed, {} = new campaign, {...} = existing

  useEffect(() => {
    load();
  }, []);

  async function load() {
    setLoading(true);
    const { data, error } = await supabase.from('campaigns').select('*').order('created_at', { ascending: false });
    if (error) {
      setLoadError(error.message);
      setLoading(false);
      return;
    }
    setLoadError(null);
    setCampaigns(data ?? []);
    // Real stats, fetched only for genuinely live campaigns — not computed for every campaign
    // up front, since that's real, avoidable query volume for campaigns nobody's currently
    // looking at the dashboard for.
    const live = (data ?? []).filter((c) => c.active);
    const stats = {};
    for (const c of live) {
      stats[c.id] = await fetchCampaignStats(c.id);
    }
    setLiveStats(stats);
    setLoading(false);
  }

  async function fetchCampaignStats(campaignId) {
    const [deedsRes, hofRes] = await Promise.all([
      supabase.from('deeds').select('user_id').eq('campaign_id', campaignId).eq('status', 'approved'),
      supabase.from('hall_of_fame_claims').select('id').eq('campaign_id', campaignId),
    ]);
    const deedRows = deedsRes.data ?? [];
    const uniqueUsers = new Set(deedRows.map((r) => r.user_id)).size;

    // Points redeemed — real spend on skins belonging to this specific campaign, not points
    // earned. Two-step query since Supabase's nested filter can't filter a joined table's own
    // column directly in one call reliably across versions.
    const { data: skinRows } = await supabase.from('vehicle_skins').select('id').eq('campaign_id', campaignId);
    const skinIds = (skinRows ?? []).map((s) => s.id);
    let pointsRedeemed = 0;
    if (skinIds.length > 0) {
      const { data: purchaseRows } = await supabase.from('user_vehicle_skins').select('points_spent').in('skin_id', skinIds);
      pointsRedeemed = (purchaseRows ?? []).reduce((sum, r) => sum + (r.points_spent ?? 0), 0);
    }

    return {
      uniqueUsers,
      deedsCompleted: deedRows.length,
      pointsRedeemed,
      roadmapCompletions: (hofRes.data ?? []).length,
    };
  }

  return (
    <div style={{ height: 'calc(100vh - 100px)', display: 'flex', flexDirection: 'column' }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 16, flexShrink: 0 }}>
        <h1 style={{ fontSize: 22 }}>Campaigns</h1>
        <button onClick={() => setEditing({})} style={btnGold}>+ New Campaign</button>
      </div>

      {loadError && (
        <div style={errorBoxStyle}>Could not load campaigns: {loadError}</div>
      )}

      {/* Fixed-height row — the 60/40 split is a real aspect ratio, not a requirement that the
          two panels touch. Each panel is its own independently-scrollable card. */}
      <div style={{ display: 'flex', gap: 20, flex: 1, minHeight: 0 }}>
        <div style={{ flex: 6, minHeight: 0 }}>
          <div style={panelStyle}>
            <div style={panelTitleStyle}>All Campaigns ({campaigns.length})</div>
            <div style={{ overflowY: 'auto', flex: 1 }}>
              {loading ? (
                <p style={{ color: 'var(--text-soft)', fontSize: 13 }}>Loading…</p>
              ) : campaigns.length === 0 ? (
                <p style={{ color: 'var(--text-soft)', fontSize: 13 }}>No campaigns yet.</p>
              ) : (
                campaigns.map((c) => (
                  <div key={c.id} style={campaignRowStyle}>
                    <div style={campaignIconStyle}>{displayIcon(c.icon)}</div>
                    <div style={{ flex: 1, fontWeight: 600, fontSize: 13.5 }}>{c.title}</div>
                    <span style={c.active ? pillActive : pillInactive}>{c.active ? 'Active' : 'Inactive'}</span>
                    <button onClick={() => setEditing(c)} style={btnGhost}>View / Edit</button>
                  </div>
                ))
              )}
            </div>
          </div>
        </div>

        <div style={{ flex: 4, minHeight: 0 }}>
          <div style={panelStyle}>
            <div style={panelTitleStyle}>Live Now</div>
            <div style={{ overflowY: 'auto', flex: 1 }}>
              {campaigns.filter((c) => c.active).length === 0 ? (
                <p style={{ color: 'var(--text-soft)', fontSize: 13 }}>No live campaigns right now.</p>
              ) : (
                campaigns.filter((c) => c.active).map((c) => {
                  const s = liveStats[c.id];
                  return (
                    <div key={c.id} style={{ marginBottom: 22 }}>
                      <div style={{ fontSize: 13, fontWeight: 700, color: 'var(--gold)', marginBottom: 10 }}>{displayIcon(c.icon)} {c.title}</div>
                      {!s ? (
                        <p style={{ fontSize: 11, color: 'var(--text-soft)' }}>Loading stats…</p>
                      ) : (
                        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 8 }}>
                          <StatCard value={s.uniqueUsers} label="Unique Users" />
                          <StatCard value={s.deedsCompleted} label="Deeds Completed" />
                          <StatCard value={s.pointsRedeemed} label="Points Redeemed" />
                          <StatCard value={s.roadmapCompletions} label="Roadmap Completions" />
                        </div>
                      )}
                    </div>
                  );
                })
              )}
              {/* Honest gap, found while building this rather than assumed away: feedback has
                  no campaign_id at all in the current schema, so a real per-campaign average
                  rating genuinely can't be computed right now — not shown here rather than
                  faked. Would need a real schema change (linking feedback to a campaign) to add. */}
            </div>
          </div>
        </div>
      </div>

      {editing !== null && (
        <CampaignForm
          campaign={editing}
          onClose={() => setEditing(null)}
          onSaved={() => { setEditing(null); load(); }}
        />
      )}
    </div>
  );
}

function StatCard({ value, label }) {
  return (
    <div style={{ background: 'var(--olive-card-strong)', borderRadius: 10, padding: '10px 12px' }}>
      <div style={{ fontSize: 18, fontWeight: 700, fontFamily: 'Georgia, serif' }}>{value?.toLocaleString?.() ?? value}</div>
      <div style={{ fontSize: 9.5, color: 'var(--text-soft)', textTransform: 'uppercase', letterSpacing: 0.3, marginTop: 2 }}>{label}</div>
    </div>
  );
}

// ============================================================================
// THE FORM — real create/edit, own fixed-height card, own internal scroll
// ============================================================================
function CampaignForm({ campaign, onClose, onSaved }) {
  const isNew = !campaign.id;
  const [tab, setTab] = useState('basic');
  const [saving, setSaving] = useState(false);
  const [saveError, setSaveError] = useState(null);
  const [showPreview, setShowPreview] = useState(false);

  const [form, setForm] = useState({
    id: campaign.id ?? '',
    title: campaign.title ?? '',
    description: campaign.description ?? '',
    icon: campaign.icon ?? '',
    active: campaign.active ?? false,
    start_date: campaign.start_date ?? '',
    end_date: campaign.end_date ?? '',
    cta_label: campaign.cta_label ?? '',
    cta_link: campaign.cta_link ?? '',
    youtube_video_id: campaign.youtube_video_id ?? '',
    cooldown_minutes_override: campaign.cooldown_minutes_override ?? '',
    terms_and_conditions: campaign.terms_and_conditions ?? '',
    teaser_active: campaign.teaser_active ?? false,
    teaser_description: campaign.teaser_description ?? '',
    default_vehicle_icon: campaign.default_vehicle_icon ?? '🚚',
    roadmap_bg_color_1: campaign.roadmap_bg_color_1 ?? '',
    roadmap_bg_color_2: campaign.roadmap_bg_color_2 ?? '',
    roadmap_road_color: campaign.roadmap_road_color ?? '',
    hof_badge_name: campaign.hof_badge_name ?? '',
    hof_badge_icon: campaign.hof_badge_icon ?? '',
    hof_sticker_name: campaign.hof_sticker_name ?? '',
    hof_sticker_icon: campaign.hof_sticker_icon ?? '',
    hof_youtube_video_id: campaign.hof_youtube_video_id ?? '',
  });

  const [stops, setStops] = useState([]);
  const [skins, setSkins] = useState([]);
  const [loadingChildren, setLoadingChildren] = useState(!isNew);

  useEffect(() => {
    if (isNew) return;
    (async () => {
      const [stopsRes, skinsRes] = await Promise.all([
        supabase.from('roadmap_stops').select('*').eq('campaign_id', campaign.id).order('threshold'),
        supabase.from('vehicle_skins').select('*').eq('campaign_id', campaign.id),
      ]);
      setStops((stopsRes.data ?? []).map((s) => ({ ...s, _existing: true })));
      setSkins((skinsRes.data ?? []).map((s) => ({ ...s, _existing: true })));
      setLoadingChildren(false);
    })();
  }, [campaign.id, isNew]);

  function updateField(key, value) {
    setForm((f) => ({ ...f, [key]: value }));
  }

  function addStop() {
    setStops((s) => [...s, { _localId: crypto.randomUUID(), threshold: '', label: '', total_boxes: 9, winning_boxes: 3, prize_name: '', prize_icon: '', reward_mode: 'standard', skin_id: '', discount_percent: 50, prize_points: '' }]);
  }
  function updateStop(idx, key, value) {
    setStops((s) => s.map((st, i) => (i === idx ? { ...st, [key]: value } : st)));
  }
  function removeStop(idx) {
    setStops((s) => s.filter((_, i) => i !== idx));
  }

  function addSkin() {
    setSkins((s) => [...s, { _localId: crypto.randomUUID(), id: '', name: '', icon: '', points_cost: '' }]);
  }
  function updateSkin(idx, key, value) {
    setSkins((s) => s.map((sk, i) => (i === idx ? { ...sk, [key]: value } : sk)));
  }
  function removeSkin(idx) {
    setSkins((s) => s.filter((_, i) => i !== idx));
  }

  async function save() {
    if (!form.id || !form.title) {
      setSaveError('Campaign ID and Title are both required.');
      return;
    }
    setSaving(true);
    setSaveError(null);

    const payload = {
      ...form,
      cooldown_minutes_override: form.cooldown_minutes_override === '' ? null : Number(form.cooldown_minutes_override),
    };

    const { error: campaignError } = isNew
      ? await supabase.from('campaigns').insert(payload)
      : await supabase.from('campaigns').update(payload).eq('id', form.id);

    if (campaignError) {
      setSaving(false);
      setSaveError(campaignError.message);
      return;
    }

    // Skins saved first — stops can reference a skin's id, so skins need real ids to exist
    // before stops try to point at them.
    const localIdToRealId = {};
    for (const skin of skins) {
      const skinPayload = { id: skin.id, name: skin.name, icon: skin.icon, points_cost: Number(skin.points_cost) || 0, campaign_id: form.id };
      if (skin._existing) {
        await supabase.from('vehicle_skins').update(skinPayload).eq('id', skin.id);
      } else {
        await supabase.from('vehicle_skins').insert(skinPayload);
        if (skin._localId) localIdToRealId[skin._localId] = skin.id;
      }
    }

    for (const stop of stops) {
      // Real fix here: a stop pointing at a skin created in this same session was referencing
      // that skin's temporary local id, not its real, user-chosen one — remapped here now that
      // every skin has genuinely been saved.
      const resolvedSkinId = localIdToRealId[stop.skin_id] ?? stop.skin_id;
      const stopPayload = {
        campaign_id: form.id,
        threshold: Number(stop.threshold) || 0,
        label: stop.label,
        total_boxes: Number(stop.total_boxes) || 9,
        winning_boxes: Number(stop.winning_boxes) || 3,
        prize_name: stop.prize_name,
        prize_icon: stop.prize_icon,
        reward_mode: stop.reward_mode,
        skin_id: stop.reward_mode === 'guaranteed_with_discount' ? (resolvedSkinId || null) : null,
        discount_percent: stop.reward_mode === 'guaranteed_with_discount' ? Number(stop.discount_percent) || 50 : 50,
        prize_points: stop.prize_points === '' ? null : Number(stop.prize_points),
      };
      if (stop._existing) {
        await supabase.from('roadmap_stops').update(stopPayload).eq('id', stop.id);
      } else {
        await supabase.from('roadmap_stops').insert(stopPayload);
      }
    }

    setSaving(false);
    onSaved();
  }

  const TABS = [
    { key: 'basic', label: 'Basic Info' },
    { key: 'visuals', label: 'Visuals' },
    { key: 'stops', label: 'Roadmap Stops' },
    { key: 'skins', label: 'Skins' },
    { key: 'hof', label: 'Hall of Fame' },
  ];

  return (
    <div style={overlayStyle}>
      <div style={formCardStyle}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '20px 24px 0', flexShrink: 0 }}>
          <h2 style={{ fontSize: 18 }}>{isNew ? 'New Campaign' : `${form.icon} ${form.title}`}</h2>
          <button onClick={onClose} style={btnGhost}>Close</button>
        </div>

        <div style={{ display: 'flex', gap: 4, borderBottom: '1px solid var(--line)', padding: '12px 24px 0', flexShrink: 0 }}>
          {TABS.map((t) => (
            <div key={t.key} onClick={() => setTab(t.key)} style={t.key === tab ? formTabActive : formTab}>{t.label}</div>
          ))}
        </div>

        {/* The only part of the form that scrolls — header and footer stay fixed */}
        <div style={{ overflowY: 'auto', flex: 1, padding: '20px 24px' }}>
          {saveError && <div style={errorBoxStyle}>{saveError}</div>}

          {tab === 'basic' && (
            <div style={formGrid}>
              <Field label={`Campaign ID ${!isNew ? '(permanent, cannot be changed)' : '(short, unique, e.g. army_2026)'}`}>
                <input value={form.id} disabled={!isNew} onChange={(e) => updateField('id', e.target.value)} style={inputStyle} />
              </Field>
              <Field label="Icon (emoji or image URL)"><input value={form.icon} onChange={(e) => updateField('icon', e.target.value)} style={inputStyle} /></Field>
              <Field label="Title" full><input value={form.title} onChange={(e) => updateField('title', e.target.value)} style={inputStyle} /></Field>
              <Field label="Description" full><textarea value={form.description} onChange={(e) => updateField('description', e.target.value)} style={textareaStyle} /></Field>
              <Field label="Active">
                <select value={form.active ? 'true' : 'false'} onChange={(e) => updateField('active', e.target.value === 'true')} style={inputStyle}>
                  <option value="false">Inactive</option>
                  <option value="true">Active</option>
                </select>
              </Field>
              {/* New — real "coming soon" teaser, independent of active. Only ever shown on
                  Home while the campaign isn't active yet — the real card takes over
                  automatically once it is. */}
              <Field label="Teaser (Coming Soon card on Home)">
                <select value={form.teaser_active ? 'true' : 'false'} onChange={(e) => updateField('teaser_active', e.target.value === 'true')} style={inputStyle}>
                  <option value="false">Off</option>
                  <option value="true">On</option>
                </select>
              </Field>
              <Field label={`Teaser Description (${(form.teaser_description || '').length}/90 — kept short so it fits cleanly in the existing 2-line card without truncating)`} full>
                <textarea value={form.teaser_description} maxLength={90} onChange={(e) => updateField('teaser_description', e.target.value)} style={{ ...textareaStyle, minHeight: 50 }} placeholder="Something big is coming..." />
              </Field>
              <Field label="Cooldown Override (minutes, optional)"><input value={form.cooldown_minutes_override} onChange={(e) => updateField('cooldown_minutes_override', e.target.value)} style={inputStyle} placeholder="Leave blank for normal 60 min" /></Field>
              <Field label="Start Date"><input type="date" value={form.start_date ?? ''} onChange={(e) => updateField('start_date', e.target.value)} style={inputStyle} /></Field>
              <Field label="End Date"><input type="date" value={form.end_date ?? ''} onChange={(e) => updateField('end_date', e.target.value)} style={inputStyle} /></Field>
              <Field label="CTA Label (not currently used anywhere in the app — safe to leave blank)"><input value={form.cta_label} onChange={(e) => updateField('cta_label', e.target.value)} style={inputStyle} /></Field>
              <Field label="CTA Link (not currently used anywhere in the app — safe to leave blank)"><input value={form.cta_link} onChange={(e) => updateField('cta_link', e.target.value)} style={inputStyle} /></Field>
              {/* Real fix here: this was genuinely missing from the form entirely — this is the
                  actual field the app's campaign detail screen uses for its video button.
                  cta_link, which the form previously only had, is confirmed unused in the app
                  right now (there's even an existing code comment saying so) — kept above with a
                  clear note rather than removed, since the column still exists either way. */}
              <Field label="Campaign YouTube Video (this is the one the app actually uses)" full>
                <input value={form.youtube_video_id} onChange={(e) => updateField('youtube_video_id', e.target.value)} style={inputStyle} placeholder="Full link or just the video ID" />
              </Field>
              <Field label="Campaign Terms & Conditions" full>
                <textarea value={form.terms_and_conditions} onChange={(e) => updateField('terms_and_conditions', e.target.value)} style={textareaStyle} placeholder="Leave blank to use the app's default placeholder terms" />
              </Field>
            </div>
          )}

          {tab === 'visuals' && (
            <div style={formGrid}>
              <Field label="Default Vehicle Icon"><input value={form.default_vehicle_icon} onChange={(e) => updateField('default_vehicle_icon', e.target.value)} style={inputStyle} /></Field>
              <Field label="Preview">
                <div style={{ height: 60, borderRadius: 10, background: `linear-gradient(135deg, ${form.roadmap_bg_color_1 || '#2B3A1D'}, ${form.roadmap_bg_color_2 || '#0F2016'})` }} />
              </Field>
              <Field label="Background Color 1 (hex)"><input value={form.roadmap_bg_color_1} onChange={(e) => updateField('roadmap_bg_color_1', e.target.value)} style={inputStyle} placeholder="#2B3A1D" /></Field>
              <Field label="Background Color 2 (hex)"><input value={form.roadmap_bg_color_2} onChange={(e) => updateField('roadmap_bg_color_2', e.target.value)} style={inputStyle} placeholder="#0F2016" /></Field>
              <Field label="Road Color (hex)"><input value={form.roadmap_road_color} onChange={(e) => updateField('roadmap_road_color', e.target.value)} style={inputStyle} placeholder="#8C9A5C" /></Field>
            </div>
          )}

          {tab === 'stops' && (
            <div>
              {loadingChildren ? <p style={{ color: 'var(--text-soft)', fontSize: 12 }}>Loading…</p> : stops.map((stop, idx) => (
                <div key={stop.id ?? stop._localId} style={stopCardStyle}>
                  <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 12 }}>
                    <span style={{ fontSize: 11, fontWeight: 700, color: 'var(--gold)', textTransform: 'uppercase' }}>Stop {idx + 1}</span>
                    <span onClick={() => removeStop(idx)} style={{ fontSize: 11, color: 'var(--rust)', cursor: 'pointer' }}>Remove</span>
                  </div>
                  <div style={formGrid}>
                    <Field label="Threshold (deeds needed)"><input value={stop.threshold} onChange={(e) => updateStop(idx, 'threshold', e.target.value)} style={inputStyle} /></Field>
                    <Field label="Label"><input value={stop.label} onChange={(e) => updateStop(idx, 'label', e.target.value)} style={inputStyle} /></Field>
                    <Field label="Total Boxes"><input value={stop.total_boxes} onChange={(e) => updateStop(idx, 'total_boxes', e.target.value)} style={inputStyle} /></Field>
                    <Field label="Winning Boxes">
                      <input value={stop.winning_boxes} onChange={(e) => updateStop(idx, 'winning_boxes', e.target.value)} style={inputStyle} disabled={stop.reward_mode === 'guaranteed_with_discount'} />
                      {stop.reward_mode === 'guaranteed_with_discount' && <div style={hintStyle}>Not used in this mode — every box wins something</div>}
                    </Field>
                    <Field label="Prize Name"><input value={stop.prize_name} onChange={(e) => updateStop(idx, 'prize_name', e.target.value)} style={inputStyle} /></Field>
                    <Field label="Prize Icon"><input value={stop.prize_icon} onChange={(e) => updateStop(idx, 'prize_icon', e.target.value)} style={inputStyle} /></Field>
                    <Field label="Reward Mode" full>
                      <select value={stop.reward_mode} onChange={(e) => updateStop(idx, 'reward_mode', e.target.value)} style={inputStyle}>
                        <option value="standard">Standard (win the prize, or nothing)</option>
                        <option value="guaranteed_with_discount">Guaranteed with Discount (win a skin free, or a discount on it)</option>
                      </select>
                    </Field>
                    {stop.reward_mode === 'standard' ? (
                      <Field label="Real Points to Credit on Win (optional)">
                        <input value={stop.prize_points} onChange={(e) => updateStop(idx, 'prize_points', e.target.value)} style={inputStyle} placeholder="Leave blank if prize isn't points" />
                      </Field>
                    ) : (
                      <>
                        <Field label="Which Skin Does This Unlock">
                          {/* Real fix here: a brand-new, not-yet-saved skin has no real id yet,
                              only a temporary local one — falling back to that so it can still
                              be selected and correctly linked once everything actually saves. */}
                          <select value={stop.skin_id ?? ''} onChange={(e) => updateStop(idx, 'skin_id', e.target.value)} style={inputStyle}>
                            <option value="">Select a skin…</option>
                            {skins.map((sk) => <option key={sk.id ?? sk._localId} value={sk.id ?? sk._localId}>{sk.name}</option>)}
                          </select>
                        </Field>
                        <Field label="Discount % (if not the winning box)">
                          <input value={stop.discount_percent} onChange={(e) => updateStop(idx, 'discount_percent', e.target.value)} style={inputStyle} />
                        </Field>
                      </>
                    )}
                  </div>
                </div>
              ))}
              <button onClick={addStop} style={addRowBtn}>+ Add Stop</button>
              {stops.length > 0 && (
                <button onClick={() => setShowPreview(true)} style={{ ...btnGhost, width: '100%', marginTop: 10 }}>👁️ Preview Roadmap</button>
              )}
            </div>
          )}

          {tab === 'skins' && (
            <div>
              {loadingChildren ? <p style={{ color: 'var(--text-soft)', fontSize: 12 }}>Loading…</p> : skins.map((skin, idx) => (
                <div key={skin.id ?? skin._localId} style={{ ...stopCardStyle, display: 'flex', gap: 16, alignItems: 'flex-start' }}>
                  {/* Real fix here: 4 columns in one row was genuinely too tight for this form
                      width, especially the ID field's longer label/placeholder — flex/grid items
                      don't shrink below their own content's natural size unless explicitly told
                      to (minWidth: 0), which is what was actually causing the overflow, not just
                      a spacing issue. Restructured to a real 2x2 grid with that fix applied. */}
                  <div style={{ flex: 1, minWidth: 0, display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
                    <Field label={`ID ${skin._existing ? '(permanent)' : '(short, unique, e.g. army_tank_gold)'}`}>
                      <input value={skin.id} disabled={!!skin._existing} onChange={(e) => updateSkin(idx, 'id', e.target.value)} style={inputStyle} />
                    </Field>
                    <Field label="Name"><input value={skin.name} onChange={(e) => updateSkin(idx, 'name', e.target.value)} style={inputStyle} /></Field>
                    <Field label="Icon (emoji or image URL)"><input value={skin.icon} onChange={(e) => updateSkin(idx, 'icon', e.target.value)} style={inputStyle} /></Field>
                    <Field label="Points Cost"><input value={skin.points_cost} onChange={(e) => updateSkin(idx, 'points_cost', e.target.value)} style={inputStyle} /></Field>
                  </div>
                  <span onClick={() => removeSkin(idx)} style={{ fontSize: 11, color: 'var(--rust)', cursor: 'pointer', flexShrink: 0, marginTop: 8 }}>Remove</span>
                </div>
              ))}
              <button onClick={addSkin} style={addRowBtn}>+ Add Skin</button>
            </div>
          )}

          {tab === 'hof' && (
            <div style={formGrid}>
              <Field label="Badge Name"><input value={form.hof_badge_name} onChange={(e) => updateField('hof_badge_name', e.target.value)} style={inputStyle} /></Field>
              <Field label="Badge Icon"><input value={form.hof_badge_icon} onChange={(e) => updateField('hof_badge_icon', e.target.value)} style={inputStyle} /></Field>
              <Field label="Sticker Name"><input value={form.hof_sticker_name} onChange={(e) => updateField('hof_sticker_name', e.target.value)} style={inputStyle} /></Field>
              <Field label="Sticker Icon"><input value={form.hof_sticker_icon} onChange={(e) => updateField('hof_sticker_icon', e.target.value)} style={inputStyle} /></Field>
              <Field label="YouTube Video Link" full><input value={form.hof_youtube_video_id} onChange={(e) => updateField('hof_youtube_video_id', e.target.value)} style={inputStyle} /></Field>
              <p style={{ fontSize: 11, color: 'var(--text-soft)', gridColumn: '1 / -1' }}>Leaving any of these blank simply means that card doesn't show in the Hall of Fame reveal — nothing breaks.</p>
            </div>
          )}
        </div>

        <div style={{ display: 'flex', justifyContent: 'flex-end', gap: 10, padding: '16px 24px', borderTop: '1px solid var(--line)', flexShrink: 0 }}>
          <button onClick={onClose} style={btnGhost}>Cancel</button>
          <button onClick={save} disabled={saving} style={btnGold}>{saving ? 'Saving…' : 'Save Campaign'}</button>
        </div>
      </div>

      {showPreview && <RoadmapPreview stops={stops} form={form} onClose={() => setShowPreview(false)} />}
    </div>
  );
}

// Static visual preview only — per direction, this doesn't need to be a working, scrollable
// replica of the real in-app roadmap, just a design view of how the stops/colors look together.
function RoadmapPreview({ stops, form, onClose }) {
  const sorted = [...stops].sort((a, b) => (Number(a.threshold) || 0) - (Number(b.threshold) || 0));
  return (
    <div style={overlayStyle} onClick={onClose}>
      <div onClick={(e) => e.stopPropagation()} style={{ ...formCardStyle, maxWidth: 420, alignItems: 'center', padding: 24 }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', width: '100%', marginBottom: 16 }}>
          <h3 style={{ fontSize: 15 }}>Roadmap Preview</h3>
          <button onClick={onClose} style={btnGhost}>Close</button>
        </div>
        <div style={{
          width: '100%', height: 420, borderRadius: 16, position: 'relative', overflow: 'hidden',
          background: `linear-gradient(135deg, ${form.roadmap_bg_color_1 || '#2B3A1D'}, ${form.roadmap_bg_color_2 || '#0F2016'})`,
        }}>
          {sorted.map((s, i) => (
            <div key={i} style={{
              position: 'absolute', left: `${20 + (i % 2) * 50}%`, top: `${85 - i * (70 / Math.max(sorted.length - 1, 1))}%`,
              display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 4,
            }}>
              <div style={{ width: 40, height: 40, borderRadius: 100, background: 'var(--gold)', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 16 }}>{s.prize_icon || '🎁'}</div>
              <span style={{ fontSize: 9, color: 'var(--text)' }}>{s.threshold || '?'} deeds</span>
            </div>
          ))}
          <div style={{ position: 'absolute', left: '50%', bottom: 20, transform: 'translateX(-50%)', fontSize: 28 }}>{form.default_vehicle_icon || '🚚'}</div>
        </div>
      </div>
    </div>
  );
}

function Field({ label, full, children }) {
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 7, gridColumn: full ? '1 / -1' : undefined }}>
      {/* Real fix here too — labels were low-contrast and small, easy to lose against the dark
          background, same underlying readability issue as the inputs themselves. */}
      <label style={{ fontSize: 12.5, fontWeight: 600, color: 'var(--text)' }}>{label}</label>
      {children}
    </div>
  );
}

// ============================================================================
// STYLES
// ============================================================================
const panelStyle = { background: 'var(--olive-card)', border: '1px solid var(--line)', borderRadius: 16, padding: 20, height: '100%', display: 'flex', flexDirection: 'column' };
const panelTitleStyle = { fontSize: 13, fontWeight: 700, textTransform: 'uppercase', letterSpacing: 0.5, color: 'var(--text-soft)', marginBottom: 14, flexShrink: 0 };
const campaignRowStyle = { display: 'flex', alignItems: 'center', gap: 12, padding: 12, borderRadius: 12, marginBottom: 8, background: 'var(--olive-card-strong)' };
const campaignIconStyle = { width: 48, height: 48, borderRadius: 10, background: 'var(--gold)', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 20, flexShrink: 0 };
const pillActive = { fontSize: 9.5, fontWeight: 700, padding: '3px 9px', borderRadius: 100, background: 'rgba(159, 174, 110, 0.25)', color: 'var(--olive)' };
const pillInactive = { fontSize: 9.5, fontWeight: 700, padding: '3px 9px', borderRadius: 100, background: 'rgba(201, 205, 188, 0.15)', color: 'var(--text-soft)' };
const btnGold = { background: 'var(--gold)', color: 'var(--ink-on-gold)', border: 'none', borderRadius: 100, padding: '10px 20px', fontWeight: 700, fontSize: 13 };
const btnGhost = { background: 'var(--olive-card-strong)', color: 'var(--text)', border: '1px solid var(--line)', borderRadius: 100, padding: '8px 16px', fontSize: 12 };
const errorBoxStyle = { background: 'rgba(193, 87, 61, 0.12)', border: '1px solid rgba(193, 87, 61, 0.4)', borderRadius: 10, padding: '10px 14px', fontSize: 12, color: '#E39B84', marginBottom: 16 };
const overlayStyle = { position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.6)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 100 };
const formCardStyle = { background: 'var(--bg2)', border: '1px solid var(--line)', borderRadius: 20, width: '90%', maxWidth: 900, height: '85vh', display: 'flex', flexDirection: 'column', overflow: 'hidden' };
const formTab = { padding: '10px 16px', fontSize: 12.5, fontWeight: 600, color: 'var(--text-soft)', borderBottom: '2px solid transparent', cursor: 'pointer' };
const formTabActive = { ...formTab, color: 'var(--gold)', borderBottomColor: 'var(--gold)' };
const formGrid = { display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 16 };
// Real fix here: inputs previously used a very low-opacity dark background against an already-
// dark card, which made them barely distinguishable as actual editable fields rather than part
// of the background — genuinely hard to read, not just a minor polish issue. Now a real, solid,
// visibly lighter surface with a clearer border, and labels bumped up in size/weight/contrast.
const inputStyle = { background: '#1A2818', border: '1px solid rgba(246, 245, 236, 0.28)', borderRadius: 9, padding: '10px 12px', color: 'var(--text)', fontSize: 13.5, fontFamily: 'inherit' };
const textareaStyle = { ...inputStyle, minHeight: 70, resize: 'vertical' };
const stopCardStyle = { background: 'var(--olive-card-strong)', border: '1px solid var(--line)', borderRadius: 14, padding: 16, marginBottom: 14 };
const addRowBtn = { width: '100%', border: '1px dashed var(--line)', background: 'transparent', color: 'var(--text-soft)', borderRadius: 12, padding: 14, fontSize: 12.5 };
const hintStyle = { fontSize: 10, color: 'var(--text-soft)', marginTop: 3 };
