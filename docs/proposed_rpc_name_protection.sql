-- =============================================================================================
-- PROPOSAL ONLY — NOT EXECUTED. Live-DB change: needs Supervisor review + Musa's explicit approval.
-- =============================================================================================
-- Goal: other users' names leave the server only as "First L." (e.g. "Ayesha K."), not full
-- names. Today get_public_profiles (and get_weekly_leaderboard) return the full `name` to any
-- caller; the app now shortens it for display (lib/utils/public_name.dart), but the full name is
-- still readable by anyone calling the RPC directly.
--
-- STATUS OF THIS DRAFT — please read:
-- The Worker could NOT read the current definitions of these two functions (the read-only
-- pg_proc lookup was blocked by this session's permission settings). So the function BODIES are
-- NOT reproduced here. What's known from the app's own code only:
--   get_public_profiles(ids?)   → rows with at least: id, name, city, points
--   get_weekly_leaderboard()    → rows with at least: user_id, name, city, weekly_points
-- Step 1 below is complete and self-contained. Steps 2–3 are a precise edit to apply to the real
-- definitions once someone with DB read access has pulled them (query in step 0).
--
-- Client compatibility: `name` stays a text column with the same name, so every existing app
-- version keeps working (it just receives "Ayesha K." instead of "Ayesha Khan"). The new app
-- build's own-row handling already uses the user's own profile name, not the RPC value.
-- =============================================================================================


-- ---------------------------------------------------------------------------------------------
-- STEP 0 (read-only — run first, paste the output into the review): current definitions.
-- ---------------------------------------------------------------------------------------------
-- select p.proname,
--        pg_get_function_identity_arguments(p.oid) as args,
--        pg_get_function_result(p.oid)            as returns,
--        p.prosecdef                              as security_definer,
--        pg_get_functiondef(p.oid)                as definition
-- from pg_proc p join pg_namespace n on n.oid = p.pronamespace
-- where n.nspname = 'public' and p.proname in ('get_public_profiles', 'get_weekly_leaderboard');


begin;

-- ---------------------------------------------------------------------------------------------
-- STEP 1: one shared formatter, same rules as the app's publicDisplayName():
--   * split on any whitespace, ignore extra spaces
--   * 1 word  → that word
--   * 2+ words → first word + ' ' + upper(first character of the LAST word) + '.'
--   * null / blank → null (the app already falls back to 'User' / 'Friend')
-- left(text, 1) is character-based, so Urdu script is handled correctly.
-- ---------------------------------------------------------------------------------------------
create or replace function public.public_display_name(full_name text)
returns text
language sql
immutable
set search_path = ''
as $$
  select case
           when cardinality(w) = 0 then null
           when cardinality(w) = 1 then w[1]
           else w[1] || ' ' || upper(left(w[cardinality(w)], 1)) || '.'
         end
  from (select array_remove(regexp_split_to_array(coalesce(full_name, ''), '\s+'), '') as w) t
$$;

-- Sanity checks (expected values in comments) — safe, pure function:
-- select public.public_display_name('Ayesha Khan');          -- Ayesha K.
-- select public.public_display_name('  Ayesha   Khan  ');    -- Ayesha K.
-- select public.public_display_name('Muhammad Ali Raza');    -- Muhammad R.
-- select public.public_display_name('Ayesha');               -- Ayesha
-- select public.public_display_name('عائشہ خان');             -- عائشہ خ.
-- select public.public_display_name('   ');                  -- null


-- ---------------------------------------------------------------------------------------------
-- STEP 2: get_public_profiles — re-create from the CURRENT definition (step 0 output) with
-- exactly ONE change: wherever the body selects the profile's name, e.g.
--     p.name
-- replace it with
--     public.public_display_name(p.name) as name
-- Keep everything else identical: same signature/arguments, same RETURNS clause, same
-- SECURITY DEFINER + search_path, same grants, same other columns (id, city, points …).
-- Do NOT widen the column list while doing this.
-- ---------------------------------------------------------------------------------------------
-- create or replace function public.get_public_profiles(<same args as today>)
-- returns <same as today>
-- language <same> security definer set search_path = <same>
-- as $$
--   select p.id,
--          public.public_display_name(p.name) as name,   -- ← the only change
--          p.city,
--          p.points
--          <…any other columns exactly as today…>
--   from public.profiles p
--   <…same where / order as today…>
-- $$;


-- ---------------------------------------------------------------------------------------------
-- STEP 3: get_weekly_leaderboard — same single change to its `name` column.
-- (It also returns other users' full names today, so it has the same exposure.)
-- ---------------------------------------------------------------------------------------------
-- create or replace function public.get_weekly_leaderboard(<same args as today>)
-- returns <same as today>
-- ... select <user_id>, public.public_display_name(p.name) as name, <city>, <weekly_points> ...


commit;


-- ---------------------------------------------------------------------------------------------
-- VERIFY after applying (as a normal signed-in user, not service role):
--   select name from public.get_public_profiles() limit 5;   -- every value is "First L." or one word
--   select name from public.get_weekly_leaderboard() limit 5;
-- ROLLBACK: re-run the step-0 definitions verbatim (keep that output with this review).
--   The helper function in step 1 can stay; it exposes nothing by itself.
-- ---------------------------------------------------------------------------------------------
