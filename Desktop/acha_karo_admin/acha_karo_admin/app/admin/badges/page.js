'use client';

import { useEffect, useState } from 'react';
import { supabase } from '../../../lib/supabaseClient';

// Real, corrected version — the actual, live policy on user_badges checks badge_definitions.frozen
// per badge, not a single global app_config flag (confirmed directly from the real policy
// definition, not assumed). This now manages the table that's genuinely enforced. The 40 badges
// themselves are still defined in the app's own code (lib/data/badges.dart), not the database,
// since their unlock logic is real Dart code — this list is a direct, programmatically-extracted
// mirror of that file's real id/name/icon/tier/category values, not hand-transcribed.
const BADGES = [
  { id: 'firstStep', name: 'First Step', icon: '🌱', req: 'Log your first deed', tier: 'bronze', category: 'streak' },
  { id: 'streak3', name: '3-Day Streak', icon: '🔥', req: '3 consecutive days', tier: 'bronze', category: 'streak' },
  { id: 'streak5', name: '5-Day Streak', icon: '🔥', req: '5 consecutive days', tier: 'silver', category: 'streak' },
  { id: 'streak7', name: '7-Day Streak', icon: '🔥🔥', req: '7 consecutive days', tier: 'gold', category: 'streak' },
  { id: 'streak14', name: '14-Day Streak', icon: '⚡', req: '14 consecutive days', tier: 'platinum', category: 'streak' },
  { id: 'streak30', name: '30-Day Streak', icon: '🌟', req: '30 consecutive days', tier: 'rainbow', category: 'streak' },
  { id: 'deeds100', name: '100 Deeds', icon: '💯', req: 'Log 100 total deeds', tier: 'gold', category: 'streak' },
  { id: 'litterPicker', name: 'Litter Picker', icon: '🗑️', req: '10 litter deeds', tier: 'bronze', category: 'env' },
  { id: 'cleanStreet', name: 'Clean Street', icon: '🧹', req: '25 litter deeds', tier: 'silver', category: 'env' },
  { id: 'zeroWaste', name: 'Zero Waste Hero', icon: '♻️', req: '50 litter deeds', tier: 'gold', category: 'env' },
  { id: 'treePlanter', name: 'Tree Planter', icon: '🌳', req: '5 saplings planted', tier: 'silver', category: 'env' },
  { id: 'urbanGardener', name: 'Urban Gardener', icon: '🌻', req: '3 green spaces created', tier: 'gold', category: 'env' },
  { id: 'waterGuardian', name: 'Water Guardian', icon: '💧', req: '20 plants watered', tier: 'silver', category: 'env' },
  { id: 'friendToStrays', name: 'Friend to Strays', icon: '🐕', req: '5 strays fed', tier: 'bronze', category: 'animal' },
  { id: 'animalProtector', name: 'Animal Protector', icon: '🛡️', req: '3 injured animals reported', tier: 'silver', category: 'animal' },
  { id: 'strayHero', name: 'Stray Hero', icon: '🐾', req: '20 strays fed', tier: 'gold', category: 'animal' },
  { id: 'birdLover', name: 'Bird Lover', icon: '🐦', req: '10 bird feeds', tier: 'silver', category: 'animal' },
  { id: 'fosterParent', name: 'Foster Parent', icon: '🏠', req: '2 rescue animals fostered', tier: 'gold', category: 'animal' },
  { id: 'neuterChampion', name: 'Neuter Champion', icon: '🐱', req: '3 strays neutered', tier: 'platinum', category: 'animal' },
  { id: 'civicReporter', name: 'Civic Reporter', icon: '📝', req: '5 issues reported', tier: 'bronze', category: 'civic' },
  { id: 'communityPainter', name: 'Community Painter', icon: '🎨', req: '3 benches painted', tier: 'silver', category: 'civic' },
  { id: 'goodNeighbor', name: 'Good Neighbor', icon: '🤝', req: '10 crossings helped', tier: 'silver', category: 'civic' },
  { id: 'schoolChampion', name: 'School Champion', icon: '🏫', req: '5 school clean-ups', tier: 'gold', category: 'civic' },
  { id: 'faithfulServant', name: 'Faithful Servant', icon: '🕌', req: '3 places of worship cleaned', tier: 'gold', category: 'civic' },
  { id: 'generousGiver', name: 'Generous Giver', icon: '🎒', req: '5 school supply donations', tier: 'bronze', category: 'social' },
  { id: 'mealProvider', name: 'Meal Provider', icon: '🍲', req: '10 meals shared', tier: 'silver', category: 'social' },
  { id: 'literacyChampion', name: 'Literacy Champion', icon: '📚', req: '10 book donations', tier: 'silver', category: 'social' },
  { id: 'bloodDonor', name: 'Blood Donor', icon: '🩸', req: '3 blood donations', tier: 'gold', category: 'social' },
  { id: 'elderFriend', name: 'Elder Friend', icon: '👴', req: '10 elderly visits', tier: 'gold', category: 'social' },
  { id: 'teacher', name: 'Teacher', icon: '🧑‍🏫', req: '5 skills taught', tier: 'gold', category: 'social' },
  { id: 'firstResponder', name: 'First Responder', icon: '🩹', req: '5 first aid donations', tier: 'silver', category: 'social' },
  { id: 'medicineDonor', name: 'Medicine Donor', icon: '💊', req: '5 medicine donations', tier: 'silver', category: 'health' },
  { id: 'healthChampion', name: 'Health Champion', icon: '🏥', req: '5 clinic clean-ups', tier: 'gold', category: 'health' },
  { id: 'townVoiceWinner', name: 'Town Voice Winner', icon: '🎙️', req: 'Win Town Voice', tier: 'platinum', category: 'special' },
  { id: 'advisor', name: 'Advisor', icon: '📣', req: 'Submit 3 feedbacks', tier: 'gold', category: 'special' },
  { id: 'mentor', name: 'Mentor', icon: '🌟', req: 'Teach 10 skills', tier: 'platinum', category: 'special' },
  { id: 'allRounder', name: 'All-Rounder', icon: '🎯', req: 'Log deeds in all 5 categories', tier: 'rainbow', category: 'special' },
  { id: 'top10', name: 'Top 10', icon: '🏅', req: 'Rank in top 10', tier: 'silver', category: 'special' },
  { id: 'top3', name: 'Top 3', icon: '🥉', req: 'Rank in top 3', tier: 'gold', category: 'special' },
  { id: 'top1', name: 'Ranked First', icon: '🏆', req: 'Reach rank #1 at least once', tier: 'platinum', category: 'special' },
];

const CATEGORY_LABELS = { streak: 'Streak', env: 'Environment', animal: 'Animal', civic: 'Civic', social: 'Social', health: 'Health', special: 'Special' };

export default function BadgesPage() {
  const [frozenIds, setFrozenIds] = useState(new Set());
  const [loading, setLoading] = useState(true);
  const [loadError, setLoadError] = useState(null);
  const [saving, setSaving] = useState(null);

  useEffect(() => {
    load();
  }, []);

  async function load() {
    setLoading(true);
    const { data, error } = await supabase.from('badge_definitions').select('id, frozen').eq('frozen', true);
    if (error) {
      setLoadError(error.message);
      setLoading(false);
      return;
    }
    setLoadError(null);
    setFrozenIds(new Set((data ?? []).map((r) => r.id)));
    setLoading(false);
  }

  async function toggle(badge, currentlyFrozen) {
    setSaving(badge.id);
    setLoadError(null);
    // Real fix here, now against the complete, confirmed schema: badge_definitions also
    // requires a real name value on insert, which the upsert never provided before — using the
    // same real name already sitting in this file's own BADGES list, extracted from the app's
    // actual badge definitions.
    const { error } = await supabase.from('badge_definitions').upsert({ id: badge.id, name: badge.name, frozen: !currentlyFrozen }, { onConflict: 'id' });
    setSaving(null);
    if (error) {
      setLoadError(`Could not update this badge: ${error.message}`);
      return;
    }
    load();
  }

  const categories = [...new Set(BADGES.map((b) => b.category))];

  return (
    <div style={{ height: 'calc(100vh - 100px)', display: 'flex', flexDirection: 'column' }}>
      <div style={{ marginBottom: 16, flexShrink: 0 }}>
        <h1 style={{ fontSize: 22 }}>Badges</h1>
        <p style={{ fontSize: 12, color: 'var(--text-soft)', marginTop: 4 }}>
          {frozenIds.size} of {BADGES.length} currently frozen — a frozen badge genuinely cannot be earned by anyone until unfrozen. Already-earned badges are never taken away.
        </p>
      </div>

      {loadError && <div style={errorBoxStyle}>Could not load freeze state: {loadError}</div>}

      <div style={{ overflowY: 'auto', flex: 1 }}>
        {loading ? (
          <p style={{ color: 'var(--text-soft)', fontSize: 13 }}>Loading…</p>
        ) : (
          categories.map((cat) => (
            <div key={cat} style={{ marginBottom: 24 }}>
              <div style={{ fontSize: 13, fontWeight: 700, color: 'var(--gold)', marginBottom: 10, textTransform: 'uppercase', letterSpacing: 0.5 }}>
                {CATEGORY_LABELS[cat] ?? cat}
              </div>
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10 }}>
                {BADGES.filter((b) => b.category === cat).map((b) => {
                  const frozen = frozenIds.has(b.id);
                  return (
                    <div key={b.id} style={{ ...rowStyle, opacity: frozen ? 0.7 : 1 }}>
                      <span style={{ fontSize: 22 }}>{b.icon}</span>
                      <div style={{ flex: 1 }}>
                        <div style={{ fontWeight: 600, fontSize: 13 }}>{b.name}</div>
                        <div style={{ fontSize: 10.5, color: 'var(--text-soft)' }}>{b.req} · {b.tier}</div>
                      </div>
                      <button
                        onClick={() => toggle(b, frozen)}
                        disabled={saving === b.id}
                        style={frozen ? unfreezeButtonStyle : freezeButtonStyle}
                      >
                        {saving === b.id ? '…' : frozen ? '❄️ Frozen — Unfreeze' : 'Freeze'}
                      </button>
                    </div>
                  );
                })}
              </div>
            </div>
          ))
        )}
      </div>
    </div>
  );
}

const rowStyle = { display: 'flex', alignItems: 'center', gap: 10, padding: 12, borderRadius: 12, background: 'var(--olive-card-strong)', border: '1px solid var(--line)' };
const freezeButtonStyle = { background: 'var(--olive-card)', border: '1px solid var(--line)', borderRadius: 100, padding: '7px 12px', fontSize: 11, color: 'var(--text-soft)', flexShrink: 0 };
const unfreezeButtonStyle = { background: 'rgba(91, 143, 168, 0.2)', border: '1px solid #5B8FA8', borderRadius: 100, padding: '7px 12px', fontSize: 11, color: '#9BC4DA', flexShrink: 0 };
const errorBoxStyle = { background: 'rgba(193, 87, 61, 0.12)', border: '1px solid rgba(193, 87, 61, 0.4)', borderRadius: 10, padding: '10px 14px', fontSize: 12, color: '#E39B84', marginBottom: 16 };
