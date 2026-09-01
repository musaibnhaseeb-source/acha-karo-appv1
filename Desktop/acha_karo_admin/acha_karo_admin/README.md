# Acha Karo Admin

Real moderation + feedback tools, connected to the same Supabase project as the Flutter app.

## Setup

1. Paste your Project URL and Publishable key into `lib/supabaseConfig.js` — same two values used in the Flutter app's `supabase_config.dart`.
2. `npm install`
3. `npm run dev`
4. Open `http://localhost:3000` in your browser — no emulator, no Android Studio needed.

## Access

Sign in with an email that already has an account (signed up through the Flutter app) with `role` set to `moderator` or `owner` in the `profiles` table. This site deliberately does NOT let new accounts sign up — only existing, already-promoted accounts can get in.

## Tabs

- **Moderation** — real pending queue, approve/reject with real writes to `deeds`/`moderation_queue`/`profiles`
- **Feedback** — view all feedback, respond to it (writes `responded`/`response`/`responded_by`/`responded_at`) — a capability that didn't exist anywhere before this
- **Analytics** — parked placeholder, per current direction

## Notes

- Uses the exact same brand colors/fonts as the Flutter app and original HTML prototype
- No new SQL needed — uses tables and RLS policies already set up for the Flutter app

## Analytics tab — now real

Built from your final layout: 8 stat cards on the left (including Points Accumulated/Redeemed — the latter shows 0 with a note, since no redemption feature exists yet), age-group donut and daily-usage line graph side by side at equal height, category breakdown with hover tooltips, a real dual-handle timeline slider, and a campaign dropdown.

**Real decisions made while building this:**
- "Active users" = logged a deed in the last 7 days (confirmed)
- Age groups computed live from each profile's date of birth
- Selecting a campaign sets the timeline to that campaign's running dates — deeds aren't tagged with a campaign_id in the schema, so this is how "campaign specific results" works given what's actually stored
- No new SQL needed — every query relies on RLS policies already set up for the Flutter app and the other two admin tabs

## User Profile view (new)

Reachable by clicking the "#1 User" name on the Analytics tab. Shows:
- Points earned, registered since, total deeds (approved/pending breakdown)
- Full activity history (every deed, status, date)
- Friends of (their approved friend list) and Friends added (successful invite redemptions)
- Feedback given, with their average rating
- Redemptions and Assigned voucher codes — honest placeholders, no redemption feature exists yet

Analytics also gained an **Average Rating** card (with total feedback count in its subtitle) — the same rating data, aggregated across everyone.

**New SQL required:** `moderator_profile_access.sql` — friendships and invite_codes previously only let a user see their own rows, which would have silently blocked a moderator from seeing anyone else's friends/invite history on this new profile page. Same gap deeds/moderation_queue already had fixed; these two were missed at the time since nothing needed cross-user access yet.

**Note on "Friends of" vs "Friends added":** interpreted as your full approved friend list (Friends of) vs. specifically how many people joined through your invite links (Friends added) — these can differ, since a friend connection can also happen from the other direction. Worth confirming this matches what you meant.
