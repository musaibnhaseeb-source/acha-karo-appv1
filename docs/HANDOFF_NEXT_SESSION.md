# Handoff / next session (from 2026-09-25, end of day)

## Live state — v1.3 is SHIPPED

- **Git:** `main` = `3f6d6f9` = `pwa-origin/main` (PWA repo, deployed by Vercel from `vercel.json`).
  Do NOT push `main` to `origin` — `origin/main` carries admin-dashboard commits.
  Push flow used: `git checkout main && git merge --ff-only <branch> && git push pwa-origin main`.
  `v1.3-wip` / `pwa-icon-fix` are fully merged into `main`.
- **Android APK:** v1.3.0, versionCode 6 (1.3.0+6), universal (arm64 + armv7 + x86_64 — no
  split-per-abi: many phones in Pakistan are still 32-bit armv7).
  `Desktop\Acha Karo\releases\v1.3-final\acha-karo-v1.3.0.apk`
  APK sha256 `6bd4d8efb4c9646edce0a675e2fb355d970c1ec5121bc9b06f3b97b138bdf351`
  Signing cert SHA-256 `1d005d8f96c5d8aa90329f0e7525f8a0508cfce8a339c2eaf384155c5556df60`
  (prod key, DN `CN=Musa Bin Haseeb, OU=Acha Karo, O=Acha Karo, L=Lahore, ST=Punjab, C=PK`).
- **PWA:** acha-karo-pwa.vercel.app, built from `main`. Icons now use the current green
  "اچھا کرو" scribble (`3f6d6f9`); users who installed earlier must remove + re-add to Home Screen.
- **DB:** server-side name protection (other users' names returned as "First L.") was applied by
  Musa and verified by the Supervisor. The app also formats names client-side (`publicDisplayName`).

## What v1.3 contains (for orientation)

- Guddi on Home: open speech-bubble header whose mood/line follows time of day + the user's own
  deed history; night treatment; Mon–Sun week row with a REAL streak (`lib/utils/deed_streak.dart`,
  approved + pending count, rejected don't); compact "Today's acha kaam idea" card.
- Pose POOLS + tap/swipe carousel (`GuddiPoses` in `lib/widgets/guddi_home.dart`): random but
  stable per app open; fixed poses only where the emotion matters (worried, frown, power = top tier
  only; strong also fixed on milestones/tier-up).
- All swappable Guddi lines + idea cards in ONE file: `lib/data/guddi_content.dart`.
- Guddi in thank-you / milestone / tier-up animations and on the campaign roadmap (guide beside the
  truck, "Bas N aur!").
- Profile tier banner (tier colour, next-tier bar, 3 best badges) — `lib/widgets/profile_tier_banner.dart`.
- Floating bottom nav (`lib/screens/main_tab_screen.dart`).
- Notifications: R8/Gson keep rules (`android/app/proguard-rules.pro` — REQUIRED, without them the
  reminder silently dies in release builds), monochrome status-bar icon, pickable reminder time,
  "not arriving?" battery tips, one-time "get told when it's approved?" ask.
- Terms of Use = website Terms v3 (14+, under-18 guardian line, Urdu summary, Contact us link).

## v1.3.1 queue (agreed with the Supervisor)

1. **Bottom nav redesign — design FIRST.** Musa still reads the floating bar as a 2D box. Produce
   mockup screenshots of 2–3 directions for Musa's pick BEFORE writing any code.
2. **Streak badges** (badges.dart streak3…streak30) still read the old in-memory `user.streak`, so
   they're effectively unearnable. Switching them to the real streak writes badges/tier-ups for
   live users — needs Supervisor + Musa sign-off first.
3. **FCM push** for "deed approved / rejected" (today those only appear when the app is next
   opened). Needs a Firebase project + server trigger (edge function / DB) — DB work is a hard stop
   until approved.
4. **Community cards** from mockup screens 10/11 ("this week across Pakistan", "Recently on Acha
   Karo", city nudges with the 5+ users rule) — need a new aggregate RPC; propose to the
   Supervisor before any DB work.

Still open from the 2026-09-23 review: H2 (client decides deed approval/points — server-side fix),
M1 (offline cold start hangs on the spinner), P1 (donation deeds lack the location disclosure),
P2 (photo EXIF not stripped before upload).

## Copy rules (firm — enforced by tests)

- No religious framing (no neki / sawab / deen / نیکی). Say "acha kaam".
- Deeds are DONE: never log / likhein / لکھیں / لاگ کریں. Only the existing "Log a good deed" keeps "Log"
  (`test/copy_rules_source_test.dart` fails on any other "Log …" string literal).
- Never a bare "karein" / "کریں" — always "acha kaam karein" / "اچھا کام کریں", otherwise use a
  different verb ("kijiye" / "کیجیے", "soyein"). Source-wide test enforces it.
- Never a "small / chhota sa / چھوٹا" acha kaam.
- Roman Urdu first for Guddi lines, English subtitle optional.
- Other users' names: "First L." only. Proof photos: "Kaam ki tasveer lein, insaan ki nahi".

## Build / verify gotchas

- After `flutter pub get` / any build: `git checkout -- windows/flutter/` (regenerated plugin files).
- A stale `.dart_tool/flutter_build` cache once broke `flutter build web` (a phantom
  `permission_handler_html` import). Fix: `rm -rf .dart_tool/flutter_build && flutter pub get`.
- Release checks that were used: `aapt2 dump badging` (versionCode), `apksigner verify -v
  --print-certs` (needs `JAVA_HOME=/c/Program Files/Android/Android Studio/jbr`, build-tools 36.0.0),
  and a compiled-string scan of `lib/*/libapp.so` in ASCII + UTF-16 (Urdu/emoji are UTF-16).
- Dev-only previews (never imported by the app): `lib/dev_prototypes/guddi_home_preview.dart`
  (`?screen=tabs|profile&h=&deed=&prior=&w=&h2=`), `pose_pools_preview.dart` (`?pool=all`),
  `roadmap_preview.dart`. Build with `flutter build web -t <file>` to a scratch folder and screenshot
  headlessly (puppeteer-core + installed Chrome); Supabase points at a dead localhost address.
- Musa decides from screenshots: show options before building visual changes.
