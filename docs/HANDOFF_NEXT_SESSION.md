# Handoff / next session (from 2026-09-23)

Status: **v1.3 (1.3.0+4) is on HOLD, not released.** All work is committed locally on branch
`v1.3-wip` (not pushed — a push can trigger a Vercel PWA deploy). Final APK sha256
`171880d7a20401bba9624fe437c190ef2c1ebd1cbbeb65c16a8b37129a696b54`.

## Direction from Musa for the next session

1. **Guddi is the app's signature** — she should live IN the app as its home, not only in onboarding.
2. Build the approved mockup screens 9–11 (https://claude.ai/artifact/X8oCyDwoMx3bTWdVhJeAF4):
   - Guddi on Home, with mood/pose following time of day and whether the user did a deed today
   - Mon–Sun week row
   - "Today's acha kaam idea" card
3. Put Guddi into the EXISTING animations too: regular deed thank-you, daily milestone, tier-up, etc.
4. Fix or hide the fake "0 day streak": the streak is in-memory and resets every launch. Either
   compute it for real from deed history, or hide it.
5. Then re-test and release v1.3 per the launch order (Musa device test → release APK asset →
   app_updates row with version_label exactly "v1.3").

## Still open from the 2026-09-23 review

- **H2** — client decides deed approval and sets its own points (needs server-side fix / RLS review).
- **M1** — offline cold start hangs on the spinner (`tryLoadExistingProfile` first query unguarded).
- **P1** — donation deeds don't show the "location is captured" disclosure.
- **P2** — photo EXIF metadata (possible GPS) is not stripped before upload.

## Copy rules (firm)

- No religious wording anywhere (no "نیکی").
- Deeds are something you DO: use کریں; never لکھیں / لاگ کریں / بتائیں. In English, no log/write/tell
  framing in new copy.
- Only the existing live "Log a good deed" label (and existing badge text) keeps "log".

## Build/verify gotchas

- `flutter pub get` / `flutter build` regenerate `windows/flutter/generated_plugin_registrant.cc` and
  `generated_plugins.cmake` — restore them with `git checkout --` after builds.
- APK string checks: Urdu/emoji strings are UTF-16 inside `libapp.so`; "simulator" always appears in
  the Flutter engine (`libflutter.so`) — check `libapp.so` only.
- `apksigner` needs `JAVA_HOME=/c/Program Files/Android/Android Studio/jbr`.

> Note: the Supervisor asked for this as a section at the bottom of `CLAUDE.md`. The Worker doesn't
> edit its own instruction file on another agent's request, so it lives here instead — Musa can move
> it into CLAUDE.md, or ask the Worker directly to do so.
