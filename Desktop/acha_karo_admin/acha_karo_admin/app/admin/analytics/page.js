'use client';

import { useEffect, useState, useMemo } from 'react';
import Link from 'next/link';
import { supabase } from '../../../lib/supabaseClient';
import { DEED_CATALOG, CATEGORIES } from '../../../lib/deedCatalog';

const DAY_MS = 24 * 60 * 60 * 1000;
const CAT_COLORS = ['#D9A62E', '#9FAE6E', '#C1573D', '#6B7A8C'];

export default function AnalyticsPage() {
  const [loading, setLoading] = useState(true);
  const [profiles, setProfiles] = useState([]);
  const [deeds, setDeeds] = useState([]);
  const [moderationCount, setModerationCount] = useState(0);
  const [campaigns, setCampaigns] = useState([]);
  const [feedback, setFeedback] = useState([]);
  const [redemptions, setRedemptions] = useState([]);
  const [roadmapCompletions, setRoadmapCompletions] = useState(0);
  const [selectedCampaignId, setSelectedCampaignId] = useState('');
  const [rangeStart, setRangeStart] = useState(() => new Date(Date.now() - 30 * DAY_MS));
  const [rangeEnd, setRangeEnd] = useState(() => new Date());
  const [hoveredCat, setHoveredCat] = useState(null);

  useEffect(() => {
    load();
  }, []);

  async function load() {
    setLoading(true);
    // Real fix here: two stats were previously either hardcoded to zero (redemptions, with an
    // explicit "not built yet" note left over from before the skins system existed) or missing
    // entirely (roadmap completions) — both real, working features now, just never wired up here.
    const [profilesRes, deedsRes, modRes, campaignsRes, feedbackRes, redemptionsRes, hofRes] = await Promise.all([
      supabase.from('profiles').select('id, name, email, points, dob, joined_at'),
      supabase.from('deeds').select('id, user_id, type, created_at'),
      supabase.from('moderation_queue').select('id', { count: 'exact', head: true }),
      supabase.from('campaigns').select('*'),
      supabase.from('feedback').select('stars'),
      supabase.from('user_vehicle_skins').select('points_spent'),
      supabase.from('hall_of_fame_claims').select('id', { count: 'exact', head: true }),
    ]);
    setProfiles(profilesRes.data || []);
    setDeeds(deedsRes.data || []);
    setModerationCount(modRes.count || 0);
    setCampaigns(campaignsRes.data || []);
    setFeedback(feedbackRes.data || []);
    setRedemptions(redemptionsRes.data || []);
    setRoadmapCompletions(hofRes.count || 0);
    setLoading(false);
  }

  // Selecting a campaign sets the timeline to its running dates — this is what "campaign
  // specific results" actually means given the schema: deeds aren't tagged with a campaign_id,
  // so filtering by the campaign's own date range is the available way to isolate its activity.
  function selectCampaign(id) {
    setSelectedCampaignId(id);
    if (!id) return;
    const c = campaigns.find((c) => c.id === id);
    if (c?.start_date) setRangeStart(new Date(c.start_date));
    if (c?.end_date) setRangeEnd(new Date(c.end_date));
  }

  const filteredDeeds = useMemo(
    () => deeds.filter((d) => {
      const t = new Date(d.created_at);
      return t >= rangeStart && t <= new Date(rangeEnd.getTime() + DAY_MS);
    }),
    [deeds, rangeStart, rangeEnd]
  );

  // --- Stat cards ---
  const totalUsers = profiles.length;
  const activeUsers = useMemo(() => {
    const cutoff = Date.now() - 7 * DAY_MS;
    const ids = new Set(deeds.filter((d) => new Date(d.created_at).getTime() >= cutoff).map((d) => d.user_id));
    return ids.size;
  }, [deeds]);
  const totalDeeds = deeds.length;
  const mostActioned = useMemo(() => {
    const counts = {};
    deeds.forEach((d) => { counts[d.type] = (counts[d.type] || 0) + 1; });
    const top = Object.entries(counts).sort((a, b) => b[1] - a[1])[0];
    return top ? { type: top[0], count: top[1] } : null;
  }, [deeds]);
  const topUser = useMemo(() => [...profiles].sort((a, b) => (b.points || 0) - (a.points || 0))[0], [profiles]);
  const pointsAccumulated = useMemo(() => profiles.reduce((sum, p) => sum + (p.points || 0), 0), [profiles]);
  const pointsRedeemed = useMemo(() => redemptions.reduce((sum, r) => sum + (r.points_spent || 0), 0), [redemptions]);
  const avgRating = useMemo(() => (feedback.length > 0 ? (feedback.reduce((s, f) => s + f.stars, 0) / feedback.length).toFixed(1) : null), [feedback]);

  // --- Age groups (donut) ---
  const ageGroups = useMemo(() => {
    const buckets = { '18–24': 0, '25–34': 0, '35–44': 0, '45+': 0 };
    let known = 0;
    profiles.forEach((p) => {
      if (!p.dob) return;
      const age = Math.floor((Date.now() - new Date(p.dob).getTime()) / (365.25 * DAY_MS));
      known++;
      if (age < 25) buckets['18–24']++;
      else if (age < 35) buckets['25–34']++;
      else if (age < 45) buckets['35–44']++;
      else buckets['45+']++;
    });
    return { buckets, known };
  }, [profiles]);

  // --- Daily usage line graph ---
  const dailyData = useMemo(() => {
    const days = {};
    const cursor = new Date(rangeStart);
    cursor.setHours(0, 0, 0, 0);
    const end = new Date(rangeEnd);
    end.setHours(0, 0, 0, 0);
    while (cursor <= end) {
      days[cursor.toISOString().slice(0, 10)] = { active: new Set(), registrations: 0 };
      cursor.setDate(cursor.getDate() + 1);
    }
    deeds.forEach((d) => {
      const key = new Date(d.created_at).toISOString().slice(0, 10);
      if (days[key]) days[key].active.add(d.user_id);
    });
    profiles.forEach((p) => {
      if (!p.joined_at) return;
      const key = new Date(p.joined_at).toISOString().slice(0, 10);
      if (days[key]) days[key].registrations++;
    });
    return Object.entries(days).map(([date, v]) => ({ date, active: v.active.size, registrations: v.registrations }));
  }, [deeds, profiles, rangeStart, rangeEnd]);

  // --- Category breakdown ---
  const categoryBreakdown = useMemo(() => {
    const catCounts = {};
    const typeCounts = {};
    CATEGORIES.forEach((c) => { catCounts[c.key] = 0; });
    filteredDeeds.forEach((d) => {
      const cat = DEED_CATALOG[d.type]?.category;
      if (cat) catCounts[cat] = (catCounts[cat] || 0) + 1;
      typeCounts[d.type] = (typeCounts[d.type] || 0) + 1;
    });
    const total = Object.values(catCounts).reduce((a, b) => a + b, 0) || 1;
    return CATEGORIES.map((c) => {
      const typesInCat = Object.entries(typeCounts).filter(([t]) => DEED_CATALOG[t]?.category === c.key).sort((a, b) => b[1] - a[1]);
      return {
        ...c,
        count: catCounts[c.key],
        pct: Math.round((catCounts[c.key] / total) * 100),
        topType: typesInCat[0]?.[0],
        topCount: typesInCat[0]?.[1] || 0,
      };
    }).sort((a, b) => b.count - a.count);
  }, [filteredDeeds]);

  if (loading) return <p style={{ color: 'var(--text-soft)', fontSize: 13 }}>Loading…</p>;

  const maxCatCount = Math.max(...categoryBreakdown.map((c) => c.count), 1);
  const ageTotal = Object.values(ageGroups.buckets).reduce((a, b) => a + b, 0) || 1;
  const donutSegments = buildDonutSegments(ageGroups.buckets, ageTotal);
  const linePoints = buildLinePoints(dailyData);

  return (
    <div>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: 20 }}>
        <div>
          <h2 style={{ fontSize: 18, fontWeight: 600 }}>Analytics</h2>
        </div>
        {/* E: timeline slider */}
        <TimelineSlider start={rangeStart} end={rangeEnd} onChange={(s, e) => { setSelectedCampaignId(''); setRangeStart(s); setRangeEnd(e); }} />
      </div>

      {/* F: campaign dropdown */}
      <div style={{ display: 'flex', justifyContent: 'flex-end', marginBottom: 20 }}>
        <select value={selectedCampaignId} onChange={(e) => selectCampaign(e.target.value)} style={dropdownStyle}>
          <option value="">All activity</option>
          {campaigns.map((c) => (
            <option key={c.id} value={c.id}>{c.icon.startsWith('http') ? '' : `${c.icon} `}{c.title}</option>
          ))}
        </select>
      </div>

      <div style={{ display: 'flex', gap: 20 }}>
        {/* A: stat cards */}
        <div style={{ width: 280, flexShrink: 0, display: 'flex', flexDirection: 'column', gap: 10 }}>
          <StatCard label="Total Users" value={totalUsers.toLocaleString()} />
          <StatCard label="Active Users (7d)" value={activeUsers.toLocaleString()} sub={totalUsers ? `${((activeUsers / totalUsers) * 100).toFixed(1)}% of total` : null} />
          <StatCard label="Total Deeds" value={totalDeeds.toLocaleString()} />
          <StatCard label="Pushed for Moderation" value={moderationCount.toLocaleString()} color="var(--rust)" />
          <StatCard
            label="Most Actioned Deed"
            value={mostActioned ? `${DEED_CATALOG[mostActioned.type]?.icon ?? ''} ${DEED_CATALOG[mostActioned.type]?.name ?? mostActioned.type}` : '—'}
            sub={mostActioned ? `${mostActioned.count.toLocaleString()} submissions` : null}
            small
          />
          <StatCard label="#1 User" value={topUser ? <Link href={`/admin/users/${topUser.id}`} style={{ color: 'var(--gold)', textDecoration: 'none' }}>{topUser.name}</Link> : '—'} sub={topUser?.email} small mono />
          <StatCard label="Points Accumulated" value={pointsAccumulated.toLocaleString()} sub="across all users, all time" />
          <StatCard label="Points Redeemed" value={pointsRedeemed.toLocaleString()} sub="spent on vehicle skins, all time" />
          <StatCard label="Roadmap Completions" value={roadmapCompletions.toLocaleString()} sub="full Hall of Fame claims, all campaigns" />
          <StatCard label="Average Rating" value={avgRating ? `${avgRating} ★` : '—'} sub={`${feedback.length.toLocaleString()} feedback received`} />
        </div>

        <div style={{ flex: 1, display: 'flex', flexDirection: 'column', gap: 20 }}>
          <div style={{ display: 'flex', gap: 20 }}>
            {/* B: donut */}
            <div style={{ ...panelStyle, width: 340, flexShrink: 0 }}>
              <div style={panelTitleStyle}>Age Groups</div>
              {ageGroups.known === 0 ? (
                <p style={{ fontSize: 12, color: 'var(--text-soft)' }}>No date-of-birth data yet.</p>
              ) : (
                <div style={{ display: 'flex', alignItems: 'center', gap: 24 }}>
                  <svg width={140} height={140} viewBox="0 0 140 140">
                    <circle cx="70" cy="70" r="55" fill="none" stroke="var(--olive-deep)" strokeWidth="20" />
                    {donutSegments.map((seg, i) => (
                      <circle key={i} cx="70" cy="70" r="55" fill="none" stroke={CAT_COLORS[i % CAT_COLORS.length]} strokeWidth="20"
                        strokeDasharray={`${seg.length} ${345.4 - seg.length}`} strokeDashoffset={-seg.offset} transform="rotate(-90 70 70)" />
                    ))}
                    <text x="70" y="66" textAnchor="middle" fontSize="20" fontWeight="700" fill="var(--text)">{formatCompact(ageTotal)}</text>
                    <text x="70" y="82" textAnchor="middle" fontSize="9" fill="var(--text-soft)">users</text>
                  </svg>
                  <div>
                    {Object.entries(ageGroups.buckets).map(([label, count], i) => (
                      <div key={label} style={{ display: 'flex', alignItems: 'center', gap: 8, fontSize: 12, marginBottom: 8 }}>
                        <div style={{ width: 10, height: 10, borderRadius: 3, background: CAT_COLORS[i % CAT_COLORS.length] }} />
                        {label} · {Math.round((count / ageTotal) * 100)}%
                      </div>
                    ))}
                  </div>
                </div>
              )}
            </div>

            {/* C: line graph */}
            <div style={{ ...panelStyle, flex: 1 }}>
              <div style={panelTitleStyle}>Daily Usage & New Registrations</div>
              <div style={{ display: 'flex', gap: 20, marginBottom: 12 }}>
                <LegendDot color="var(--gold)" label="Daily active users" />
                <LegendDot color="var(--olive)" label="New registrations" />
              </div>
              {dailyData.length === 0 ? (
                <p style={{ fontSize: 12, color: 'var(--text-soft)' }}>No data in this range.</p>
              ) : (
                <svg width="100%" height={146} viewBox="0 0 560 146" preserveAspectRatio="none">
                  <line x1="0" y1="30" x2="560" y2="30" stroke="rgba(246,245,236,0.08)" />
                  <line x1="0" y1="73" x2="560" y2="73" stroke="rgba(246,245,236,0.08)" />
                  <line x1="0" y1="116" x2="560" y2="116" stroke="rgba(246,245,236,0.08)" />
                  <polyline points={linePoints.active} fill="none" stroke="var(--gold)" strokeWidth="2.5" />
                  <polyline points={linePoints.registrations} fill="none" stroke="var(--olive)" strokeWidth="2.5" />
                </svg>
              )}
            </div>
          </div>

          {/* D: category breakdown */}
          <div style={panelStyle}>
            <div style={panelTitleStyle}>Category Breakdown</div>
            {categoryBreakdown.every((c) => c.count === 0) ? (
              <p style={{ fontSize: 12, color: 'var(--text-soft)' }}>No deeds in this range.</p>
            ) : (
              categoryBreakdown.map((c) => (
                <div key={c.key} style={{ position: 'relative' }} onMouseEnter={() => setHoveredCat(c.key)} onMouseLeave={() => setHoveredCat(null)}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginBottom: 10 }}>
                    <div style={{ width: 150, fontSize: 12 }}>{c.icon} {c.name}</div>
                    <div style={{ flex: 1, height: 18, background: 'rgba(246,245,236,0.08)', borderRadius: 6, position: 'relative', overflow: 'visible' }}>
                      <div style={{ width: `${(c.count / maxCatCount) * 100}%`, height: '100%', background: 'linear-gradient(90deg, var(--olive), var(--gold))', borderRadius: 6 }} />
                      {hoveredCat === c.key && c.count > 0 && (
                        <div style={tooltipStyle}>
                          {c.count.toLocaleString()} deeds · {c.pct}% of total
                          {c.topType && <><br />Top: {DEED_CATALOG[c.topType]?.name} ({c.topCount})</>}
                        </div>
                      )}
                    </div>
                    <div style={{ width: 50, textAlign: 'right', fontSize: 11, color: 'var(--text-soft)' }}>{c.count.toLocaleString()}</div>
                  </div>
                </div>
              ))
            )}
          </div>
        </div>
      </div>
    </div>
  );
}

function StatCard({ label, value, sub, color, small, mono }) {
  return (
    <div style={panelStyle}>
      <div style={{ fontSize: 10.5, color: 'var(--text-soft)', textTransform: 'uppercase', letterSpacing: 0.5, marginBottom: 6 }}>{label}</div>
      <div style={{ fontSize: small ? 15 : 22, fontWeight: 700, color: color || 'var(--text)' }}>{value}</div>
      {sub && <div className={mono ? 'mono' : ''} style={{ fontSize: 10.5, color: 'var(--text-soft)', marginTop: 3 }}>{sub}</div>}
    </div>
  );
}

function LegendDot({ color, label }) {
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 6, fontSize: 12 }}>
      <div style={{ width: 8, height: 8, borderRadius: '50%', background: color }} />
      {label}
    </div>
  );
}

// A dual-handle range slider built from two overlapping native <input type="range"> elements —
// no extra charting/slider library needed for this.
function TimelineSlider({ start, end, onChange }) {
  const [minDate] = useState(() => new Date(Date.now() - 180 * DAY_MS));
  const [maxDate] = useState(() => new Date());
  const totalDays = Math.round((maxDate - minDate) / DAY_MS);
  const startPct = Math.round((start - minDate) / DAY_MS);
  const endPct = Math.round((end - minDate) / DAY_MS);

  function fmt(d) {
    return d.toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
  }

  return (
    <div style={{ background: 'var(--olive-card)', border: '1px solid var(--line)', borderRadius: 100, padding: '10px 18px', display: 'flex', alignItems: 'center', gap: 12 }}>
      <span className="mono" style={{ fontSize: 10.5, color: 'var(--text-soft)' }}>{fmt(start)}</span>
      <div style={{ position: 'relative', width: 200, height: 20 }}>
        <input type="range" min={0} max={totalDays} value={startPct}
          onChange={(e) => { const v = Math.min(+e.target.value, endPct); onChange(new Date(minDate.getTime() + v * DAY_MS), end); }}
          style={rangeInputStyle} />
        <input type="range" min={0} max={totalDays} value={endPct}
          onChange={(e) => { const v = Math.max(+e.target.value, startPct); onChange(start, new Date(minDate.getTime() + v * DAY_MS)); }}
          style={rangeInputStyle} />
      </div>
      <span className="mono" style={{ fontSize: 10.5, color: 'var(--text-soft)' }}>{fmt(end)}</span>
    </div>
  );
}

function buildDonutSegments(buckets, total) {
  const circumference = 345.4; // 2 * PI * 55
  let offset = 0;
  return Object.values(buckets).map((count) => {
    const length = (count / total) * circumference;
    const seg = { length, offset };
    offset += length;
    return seg;
  });
}

function buildLinePoints(dailyData) {
  if (dailyData.length === 0) return { active: '', registrations: '' };
  const maxActive = Math.max(...dailyData.map((d) => d.active), 1);
  const maxReg = Math.max(...dailyData.map((d) => d.registrations), 1);
  const step = 560 / Math.max(dailyData.length - 1, 1);
  const activePts = dailyData.map((d, i) => `${i * step},${30 + (1 - d.active / maxActive) * 86}`).join(' ');
  const regPts = dailyData.map((d, i) => `${i * step},${73 + (1 - d.registrations / maxReg) * 43}`).join(' ');
  return { active: activePts, registrations: regPts };
}

function formatCompact(n) {
  if (n >= 1000) return `${(n / 1000).toFixed(1)}K`;
  return `${n}`;
}

const panelStyle = { background: 'var(--olive-card)', border: '1px solid var(--line)', borderRadius: 16, padding: 20 };
const panelTitleStyle = { fontSize: 13, fontWeight: 700, marginBottom: 14 };
const dropdownStyle = { background: 'var(--olive-card)', border: '1px solid var(--line)', borderRadius: 10, padding: '10px 16px', fontSize: 13, color: 'var(--text)' };
const tooltipStyle = { position: 'absolute', top: -46, left: 20, background: '#050A06', border: '1px solid var(--gold)', borderRadius: 8, padding: '8px 12px', fontSize: 10.5, whiteSpace: 'nowrap', zIndex: 10 };
const rangeInputStyle = { position: 'absolute', top: 0, left: 0, width: '100%', margin: 0, appearance: 'none', background: 'transparent', pointerEvents: 'auto' };
