'use client';

import { useEffect, useState } from 'react';
import { useRouter, usePathname } from 'next/navigation';
import Link from 'next/link';
import { supabase } from '../../lib/supabaseClient';

const TABS = [
  { href: '/admin/users', label: 'Users', icon: '👤' },
  { href: '/admin/campaigns', label: 'Campaigns', icon: '🚩' },
  { href: '/admin/moderation', label: 'Moderation', icon: '🛡️' },
  { href: '/admin/feedback', label: 'Feedback', icon: '💬' },
  { href: '/admin/rewards', label: 'Rewards', icon: '🏆' },
  { href: '/admin/analytics', label: 'Analytics', icon: '📊' },
];

export default function AdminLayout({ children }) {
  const [checking, setChecking] = useState(true);
  const [authorized, setAuthorized] = useState(false);
  const router = useRouter();
  const pathname = usePathname();

  useEffect(() => {
    checkAccess();
  }, []);

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
        <p style={{ color: 'var(--text-soft)', fontSize: 13 }}>Checking access…</p>
      </main>
    );
  }

  if (!authorized) return null; // mid-redirect

  return (
    <div style={{ minHeight: '100vh' }}>
      <header style={{ borderBottom: '1px solid var(--line)', padding: '16px 24px', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <h1 style={{ fontSize: 16, fontWeight: 600, color: 'var(--gold)' }}>Acha Karo Admin</h1>
        <button onClick={signOut} style={{ background: 'none', border: '1px solid var(--line)', borderRadius: 100, padding: '6px 14px', color: 'var(--text-soft)', fontSize: 12 }}>
          Sign out
        </button>
      </header>

      <nav style={{ display: 'flex', borderBottom: '1px solid var(--line)', padding: '0 24px' }}>
        {TABS.map((tab) => {
          const active = pathname.startsWith(tab.href);
          return (
            <Link
              key={tab.href}
              href={tab.href}
              style={{
                padding: '14px 20px',
                fontSize: 13.5,
                fontWeight: 600,
                color: active ? 'var(--gold)' : 'var(--text-soft)',
                borderBottom: active ? '2px solid var(--gold)' : '2px solid transparent',
                textDecoration: 'none',
              }}
            >
              {tab.icon} {tab.label}
            </Link>
          );
        })}
      </nav>

      <main style={{ maxWidth: 900, margin: '0 auto', padding: 24 }}>{children}</main>
    </div>
  );
}
