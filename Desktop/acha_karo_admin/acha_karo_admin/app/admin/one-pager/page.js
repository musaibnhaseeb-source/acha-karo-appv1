'use client';

import { useEffect, useState } from 'react';
import { supabase } from '../../../lib/supabaseClient';
import { DEED_CATALOG, CATEGORIES } from '../../../lib/deedCatalog';

// One shareable snapshot of the headline numbers already surfaced elsewhere in this dashboard
// (Analytics, Campaigns, Badges) -- built for handing to a stakeholder outside the dashboard,
// not for exploring data. Every query here is either a plain count (head: true, no rows
// returned) or a single numeric/categorical column (points, type, stars, active) -- nothing
// that returns a name, email, or any other identifying field. "Download" is just
// window.print() against print-only CSS (see .one-pager rules in globals.css and the <style>
// block below) -- no PDF library needed for a page this simple.
export default function OnePagerPage() {
  const [loading, setLoading] = useState(true);
  const [errors, setErrors] = useState([]);
  const [stats, setStats] = useState({
    totalUsers: 0,
    totalDeeds: 0,
    activeCampaigns: 0,
    totalCampaigns: 0,
    badgesAwarded: 0,
    avgRating: null,
    feedbackCount: 0,
    pointsAccumulated: 0,
    pointsRedeemed: 0,
    categoryBreakdown: [],
  });

  useEffect(() => {
    load();
  }, []);

  async function load() {
    setLoading(true);

    const [profilesRes, deedsRes, campaignsRes, badgesRes, feedbackRes, skinsRes] = await Promise.all([
      supabase.from('profiles').select('points', { count: 'exact' }),
      supabase.from('deeds').select('type', { count: 'exact' }),
      supabase.from('campaigns').select('id, active'),
      supabase.from('user_badges').select('id', { count: 'exact', head: true }),
      supabase.from('feedback').select('stars'),
      supabase.from('user_vehicle_skins').select('points_spent'),
    ]);

    const profiles = profilesRes.data || [];
    const deedsRows = deedsRes.data || [];
    const campaigns = campaignsRes.data || [];
    const feedbackRows = feedbackRes.data || [];
    const skinRows = skinsRes.data || [];

    const catCounts = {};
    CATEGORIES.forEach((c) => { catCounts[c.key] = 0; });
    deedsRows.forEach((d) => {
      const cat = DEED_CATALOG[d.type]?.category;
      if (cat) catCounts[cat] = (catCounts[cat] || 0) + 1;
    });
    const totalCategorized = Object.values(catCounts).reduce((a, b) => a + b, 0) || 1;
    const categoryBreakdown = CATEGORIES.map((c) => ({
      ...c,
      count: catCounts[c.key],
      pct: Math.round((catCounts[c.key] / totalCategorized) * 100),
    })).sort((a, b) => b.count - a.count);

    setStats({
      totalUsers: profilesRes.count ?? profiles.length,
      totalDeeds: deedsRes.count ?? deedsRows.length,
      activeCampaigns: campaigns.filter((c) => c.active).length,
      totalCampaigns: campaigns.length,
      badgesAwarded: badgesRes.count ?? 0,
      avgRating: feedbackRows.length > 0 ? (feedbackRows.reduce((s, f) => s + (f.stars || 0), 0) / feedbackRows.length).toFixed(1) : null,
      feedbackCount: feedbackRows.length,
      pointsAccumulated: profiles.reduce((sum, p) => sum + (p.points || 0), 0),
      pointsRedeemed: skinRows.reduce((sum, r) => sum + (r.points_spent || 0), 0),
      categoryBreakdown,
    });

    setErrors([profilesRes, deedsRes, campaignsRes, badgesRes, feedbackRes, skinsRes].map((r) => r.error?.message).filter(Boolean));
    setLoading(false);
  }

  const redeemedPct = stats.pointsAccumulated > 0 ? Math.min(100, Math.round((stats.pointsRedeemed / stats.pointsAccumulated) * 100)) : 0;
  const generatedOn = new Date().toLocaleDateString(undefined, { year: 'numeric', month: 'long', day: 'numeric' });

  return (
    <div className="one-pager">
      <style>{`
        @media print {
          .one-pager, .one-pager * { color: #111111; }
          .one-pager { background: #ffffff !important; }
          .one-pager .panel, .one-pager .kpi-card {
            background: #ffffff !important;
            border: 1px solid #cccccc !important;
            box-shadow: none !important;
          }
          .one-pager .text-soft { color: #555555 !important; }
          .one-pager .accent { color: #8a6a10 !important; }
          .one-pager .bar-track { background: #e5e5e5 !important; }
          .one-pager .bar-fill { background: #9FAE6E !important; }
        }
      `}</style>

      <div className="no-print" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: 20, gap: 16 }}>
        <div>
          <h1 style={{ fontSize: 22 }}>One-Pager Summary</h1>
          <p style={{ fontSize: 12, color: 'var(--text-soft)', marginTop: 4, maxWidth: 520 }}>
            A single shareable snapshot of the headline numbers below, pulled from the same data the rest of the dashboard uses. Use Download to save or print a clean copy for a stakeholder.
          </p>
        </div>
        <button onClick={() => window.print()} style={btnGold}>Download / Print</button>
      </div>

      {errors.length > 0 && (
        <div className="no-print" style={errorBoxStyle}>Some figures may be incomplete: {errors.join('; ')}</div>
      )}

      <div style={sheetStyle}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-end', marginBottom: 22 }}>
          <div>
            <div className="text-soft" style={{ fontSize: 11, color: 'var(--text-soft)', textTransform: 'uppercase', letterSpacing: 1 }}>Acha Karo</div>
            <h1 style={{ fontSize: 24, marginTop: 4 }}>Executive Summary</h1>
          </div>
          <div className="text-soft" style={{ fontSize: 11, color: 'var(--text-soft)', textAlign: 'right' }}>Generated {generatedOn}</div>
        </div>

        {loading ? (
          <p style={{ color: 'var(--text-soft)', fontSize: 13 }}>Loading...</p>
        ) : (
          <>
            <div style={kpiGridStyle}>
              <KpiCard label="Total Users" value={stats.totalUsers.toLocaleString()} />
              <KpiCard label="Deeds Logged" value={stats.totalDeeds.toLocaleString()} />
              <KpiCard label="Active Campaigns" value={stats.activeCampaigns.toLocaleString()} sub={`of ${stats.totalCampaigns} total`} />
              <KpiCard label="Badges Awarded" value={stats.badgesAwarded.toLocaleString()} />
              <KpiCard label="Average Rating" value={stats.avgRating ? `${stats.avgRating} / 5` : '-'} sub={`${stats.feedbackCount} reviews`} />
            </div>

            <div style={sectionsRowStyle}>
              <div className="panel" style={panelStyle}>
                <div style={panelTitleStyle}>Deeds by Category</div>
                {stats.categoryBreakdown.every((c) => c.count === 0) ? (
                  <p className="text-soft" style={{ fontSize: 12, color: 'var(--text-soft)' }}>No deeds logged yet.</p>
                ) : (
                  stats.categoryBreakdown.map((c) => (
                    <div key={c.key} style={{ marginBottom: 12 }}>
                      <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: 12, marginBottom: 5 }}>
                        <span>{c.icon} {c.name}</span>
                        <span className="text-soft" style={{ color: 'var(--text-soft)' }}>{c.count.toLocaleString()} ({c.pct}%)</span>
                      </div>
                      <div className="bar-track" style={barTrackStyle}>
                        <div className="bar-fill" style={{ ...barFillStyle, width: `${c.pct}%` }} />
                      </div>
                    </div>
                  ))
                )}
              </div>

              <div className="panel" style={panelStyle}>
                <div style={panelTitleStyle}>Points Economy</div>
                <div style={{ display: 'flex', gap: 20, marginBottom: 16 }}>
                  <MiniStat label="Accumulated" value={stats.pointsAccumulated.toLocaleString()} />
                  <MiniStat label="Redeemed" value={stats.pointsRedeemed.toLocaleString()} />
                </div>
                <div className="bar-track" style={barTrackStyle}>
                  <div className="bar-fill" style={{ ...barFillStyle, width: `${redeemedPct}%`, background: 'var(--gold)' }} />
                </div>
                <div className="text-soft" style={{ fontSize: 10.5, color: 'var(--text-soft)', marginTop: 8 }}>
                  {redeemedPct}% of accumulated points have been redeemed on rewards, all time.
                </div>
              </div>
            </div>

            <div className="text-soft" style={{ marginTop: 26, paddingTop: 14, borderTop: '1px solid var(--line)', fontSize: 10, color: 'var(--text-soft)', textAlign: 'center' }}>
              Acha Karo Admin -- internal summary, not for public distribution.
            </div>
          </>
        )}
      </div>
    </div>
  );
}

function KpiCard({ label, value, sub }) {
  return (
    <div className="kpi-card" style={kpiCardStyle}>
      <div className="text-soft" style={{ fontSize: 10.5, color: 'var(--text-soft)', textTransform: 'uppercase', letterSpacing: 0.5, marginBottom: 8 }}>{label}</div>
      <div className="accent" style={{ fontSize: 26, fontWeight: 700, fontFamily: 'Georgia, serif', color: 'var(--gold)' }}>{value}</div>
      {sub && <div className="text-soft" style={{ fontSize: 10.5, color: 'var(--text-soft)', marginTop: 4 }}>{sub}</div>}
    </div>
  );
}

function MiniStat({ label, value }) {
  return (
    <div>
      <div className="accent" style={{ fontSize: 20, fontWeight: 700, fontFamily: 'Georgia, serif', color: 'var(--gold)' }}>{value}</div>
      <div className="text-soft" style={{ fontSize: 10.5, color: 'var(--text-soft)', marginTop: 2 }}>{label}</div>
    </div>
  );
}

const sheetStyle = { background: 'var(--olive-card)', border: '1px solid var(--line)', borderRadius: 16, padding: 28 };
const kpiGridStyle = { display: 'grid', gridTemplateColumns: 'repeat(5, 1fr)', gap: 14, marginBottom: 24 };
const kpiCardStyle = { background: 'var(--olive-card-strong)', border: '1px solid var(--line)', borderRadius: 14, padding: '16px 14px' };
const sectionsRowStyle = { display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 18 };
const panelStyle = { background: 'var(--olive-card-strong)', border: '1px solid var(--line)', borderRadius: 14, padding: 18 };
const panelTitleStyle = { fontSize: 13, fontWeight: 700, marginBottom: 14 };
const barTrackStyle = { width: '100%', height: 10, borderRadius: 6, background: 'rgba(246,245,236,0.1)', overflow: 'hidden' };
const barFillStyle = { height: '100%', borderRadius: 6, background: 'linear-gradient(90deg, var(--olive), var(--gold))' };
const btnGold = { background: 'var(--gold)', color: 'var(--ink-on-gold)', border: 'none', borderRadius: 100, padding: '10px 20px', fontWeight: 700, fontSize: 13, flexShrink: 0 };
const errorBoxStyle = { background: 'rgba(193, 87, 61, 0.12)', border: '1px solid rgba(193, 87, 61, 0.4)', borderRadius: 10, padding: '10px 14px', fontSize: 12, color: '#E39B84', marginBottom: 16 };
