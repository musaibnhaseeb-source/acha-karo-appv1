'use client';

import { useEffect, useState } from 'react';
import { useRouter, usePathname } from 'next/navigation';
import Link from 'next/link';
import { supabase } from '../../lib/supabaseClient';

// Grouped, left-sidebar navigation -- replaces the old single-row top toolbar. Every route from
// the old TABS list is still here, same hrefs and labels, just organized into a few related
// groups (Power BI-style left nav conventions: grouped items, most important content top-left,
// nothing removed or renamed). "Overview" is new -- it is just the entry point to the new
// one-pager summary route, not a change to any existing page.
const NAV_GROUPS = [
  {
    label: 'Overview',
    items: [
      { href: '/admin/one-pager', label: 'One-Pager', icon: '\ud83d\udcc8' },
      { href: '/admin/analytics', label: 'Analytics', icon: '\ud83d\udcca' },
    ],
  },
  {
    label: 'Engagement',
    items: [
      { href: '/admin/campaigns', label: 'Campaigns', icon: '\ud83d\udea9' },
      { href: '/admin/skins', label: 'Skins & Hall of Fame', icon: '\ud83c\udfa8' },
      { href: '/admin/badges', label: 'Badge Freeze', icon: '\ud83c\udfc5' },
    ],
  },
  {
    label: 'Community',
    items: [
      { href: '/admin/users', label: 'Users', icon: '\ud83d\udc64' },
      { href: '/admin/rewards', label: 'Rewards', icon: '\ud83c\udfc6' },
    ],
  },
  {
    label: 'Support',
    items: [
      { href: '/admin/moderation', label: 'Moderation', icon: '\ud83d\udee1\ufe0f' },
      { href: '/admin/feedback', label: 'Feedback', icon: '\ud83d\udcac' },
      { href: '/admin/contact', label: 'Contact Us', icon: '\u2709\ufe0f' },
    ],
  },
];
const ALL_ITEMS = NAV_GROUPS.flatMap((g) => g.items);

export default function AdminLayout({ children }) {
  const [checking, setChecking] = useState(true);
  const [authorized, setAuthorized] = useState(false);
  const [deedCount, setDeedCount] = useState(0);
  const [flagCount, setFlagCount] = useState(0);
  const router = useRouter();
  const pathname = usePathname();

  useEffect(() => {
    checkAccess();
  }, []);

  // Live-ish pending counts for the Moderation nav item, so both queues are glanceable
  // without opening either tab. Polled rather than a Realtime subscription -- nothing
  // else in this app uses Supabase Realtime, and a 30s-fresh count is plenty for an
  // internal moderation tool.
  useEffect(() => {
    if (!authorized) return;
    loadModerationCounts();
    const interval = setInterval(loadModerationCounts, 30000);
    return () => clearInterval(interval);
  }, [authorized]);

  async function loadModerationCounts() {
    const [deedRes, flagRes] = await Promise.all([
      supabase.from('moderation_queue').select('id', { count: 'exact', head: true }).is('outcome', null),
      supabase.from('friendship_safety_flags').select('id', { count: 'exact', head: true }).eq('resolved', false),
    ]);
    setDeedCount(deedRes.count ?? 0);
    setFlagCount(flagRes.count ?? 0);
  }

  async function checkAccess() {
    const { data: { session } } = await supabase.auth.getSession();
    if (!session) {
      router.replace('/');
      return;
    }
    const { data: profile } = await supabase.from('profiles').select('role').eq('id', session.user.id).single();
    if (!profile || (profile.role !== 'moderator' && profile.role !== 'owner')) {
      await supabase.auth.signOut();
      router.replace('/');
      return;
    }
    setAuthorized(true);
    setChecking(false);
  }

  async function signOut() {
    await supabase.auth.signOut();
    router.replace('/');
  }

  if (checking) {
    return (
      <main style={{ minHeight: '100vh', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
        <p style={{ color: 'var(--text-soft)', fontSize: 13 }}>Checking access...</p>
      </main>
    );
  }

  if (!authorized) return null; // mid-redirect

  const activeItem = ALL_ITEMS.find((item) => pathname.startsWith(item.href));

  return (
    <div style={{ minHeight: '100vh', display: 'flex' }}>
      {/* Sidebar -- hidden on print via the .admin-shell-sidebar hook in globals.css, so a
          one-pager (or any page) prints without the app chrome around it. */}
      <aside className="admin-shell-sidebar" style={sidebarStyle}>
        <div style={brandRowStyle}>
          <div style={brandMarkStyle}>AK</div>
          <div>
            <div style={{ fontSize: 14.5, fontWeight: 700, color: 'var(--gold)', fontFamily: 'var(--font-fraunces), serif' }}>Acha Karo</div>
            <div style={{ fontSize: 10.5, color: 'var(--text-soft)', letterSpacing: 0.4 }}>Admin Dashboard</div>
          </div>
        </div>

        <nav style={{ flex: 1, overflowY: 'auto', padding: '4px 12px 12px' }}>
          {NAV_GROUPS.map((group, gi) => (
            <div key={group.label} style={{ marginTop: gi === 0 ? 4 : 20 }}>
              <div style={groupLabelStyle}>{group.label}</div>
              {group.items.map((item) => {
                const active = pathname.startsWith(item.href);
                return (
                  <Link
                    key={item.href}
                    href={item.href}
                    className="nav-link"
                    style={{
                      ...navItemStyle,
                      color: active ? 'var(--gold)' : 'var(--text-soft)',
                      fontWeight: active ? 700 : 600,
                      borderLeft: active ? '3px solid var(--gold)' : '3px solid transparent',
                      ...(active ? { background: 'var(--olive-card-strong)' } : {}),
                    }}
                  >
                    <span style={{ fontSize: 15, width: 18, textAlign: 'center', flexShrink: 0 }}>{item.icon}</span>
                    <span style={{ flex: 1 }}>{item.label}</span>
                    {item.href === '/admin/moderation' && (deedCount > 0 || flagCount > 0) && (
                      <span style={{ display: 'flex', gap: 4, flexShrink: 0 }}>
                        {deedCount > 0 && <span style={badgeActiveStyle} title="Deed Reviews pending">{deedCount}</span>}
                        {flagCount > 0 && <span style={badgeActiveStyle} title="Safety Flags pending">{flagCount}</span>}
                      </span>
                    )}
                  </Link>
                );
              })}
            </div>
          ))}
        </nav>

        <div style={sidebarFooterStyle}>
          <button onClick={signOut} className="nav-link" style={signOutButtonStyle}>
            <span style={{ fontSize: 15 }}>&#8617;</span> Sign out
          </button>
        </div>
      </aside>

      <div className="admin-shell-body" style={{ flex: 1, minWidth: 0, display: 'flex', flexDirection: 'column' }}>
        <header className="admin-shell-topbar" style={topbarStyle}>
          <span style={{ fontSize: 14.5, fontWeight: 700 }}>
            {activeItem ? `${activeItem.icon} ${activeItem.label}` : 'Acha Karo Admin'}
          </span>
        </header>

        <main className="admin-shell-main" style={{ maxWidth: 900, width: '100%', margin: '0 auto', padding: 24, flex: 1, minWidth: 0 }}>
          {children}
        </main>
      </div>
    </div>
  );
}

const sidebarStyle = {
  width: 224,
  flexShrink: 0,
  position: 'sticky',
  top: 0,
  height: '100vh',
  display: 'flex',
  flexDirection: 'column',
  borderRight: '1px solid var(--line)',
  background: 'rgba(5, 12, 6, 0.45)',
  backdropFilter: 'blur(6px)',
};
const brandRowStyle = { display: 'flex', alignItems: 'center', gap: 10, padding: '20px 16px 16px', borderBottom: '1px solid var(--line)' };
const brandMarkStyle = { width: 34, height: 34, borderRadius: 10, background: 'var(--gold)', color: 'var(--ink-on-gold)', display: 'flex', alignItems: 'center', justifyContent: 'center', fontWeight: 700, fontSize: 13, flexShrink: 0 };
const groupLabelStyle = { fontSize: 10, fontWeight: 700, color: 'var(--text-soft)', textTransform: 'uppercase', letterSpacing: 0.8, padding: '0 12px 6px' };
const navItemStyle = { display: 'flex', alignItems: 'center', gap: 10, padding: '9px 12px', margin: '2px 0', borderRadius: 8, fontSize: 13, textDecoration: 'none' };
const sidebarFooterStyle = { padding: 12, borderTop: '1px solid var(--line)' };
const signOutButtonStyle = { width: '100%', display: 'flex', alignItems: 'center', gap: 8, background: 'none', border: 'none', borderRadius: 8, padding: '9px 12px', color: 'var(--text-soft)', fontSize: 13, fontWeight: 600, textAlign: 'left' };
const topbarStyle = { height: 56, flexShrink: 0, display: 'flex', alignItems: 'center', padding: '0 28px', borderBottom: '1px solid var(--line)' };
const badgeStyle = { display: 'inline-block', padding: '1px 6px', borderRadius: 100, fontSize: 10, fontWeight: 700, background: 'var(--olive-card-strong)', color: 'var(--text-soft)' };
const badgeActiveStyle = { ...badgeStyle, background: 'rgba(193, 87, 61, 0.2)', color: '#E39B84' };
