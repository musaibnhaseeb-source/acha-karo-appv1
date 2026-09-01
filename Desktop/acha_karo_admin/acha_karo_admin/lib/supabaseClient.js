import { createClient } from '@supabase/supabase-js';
import { supabaseUrl, supabasePublishableKey } from './supabaseConfig';

// Real fix here, needed before this could safely go to a public-ish place like GitHub: prefers
// real environment variables (which Supabase's own Vercel integration sets automatically once
// connected) over the hardcoded file, which was never actually being read from before this —
// the file existed, but nothing in the code checked for env vars at all.
//
// Honest caveat, worth verifying rather than trusting blindly: NEXT_PUBLIC_SUPABASE_URL and
// NEXT_PUBLIC_SUPABASE_ANON_KEY are the standard, documented names Supabase's Vercel integration
// uses — but confirm the exact names in your own Vercel dashboard (Settings → Environment
// Variables) after connecting the integration, since this wasn't something I could verify
// against your actual live setup.
const url = process.env.NEXT_PUBLIC_SUPABASE_URL || supabaseUrl;
const key = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY || supabasePublishableKey;

export const supabase = createClient(url, key);
