# Handoff / next session (from 2026-09-30, end of day)

Worker = the Flutter app agent for `acha_karo_app/`. Supervisor is the single point of contact;
Musa gives final approval. Live pilot, live DB: no pushes, uploads or DB access unless approved.

## Live state

- **Website (PWA + sideload APK): v1.3.1 is LIVE** (released by Supervisor/Musa).
  - APK `Desktop\Acha Karo\releases\v1.3.1-play\acha-karo-v1.3.1.apk`, versionCode 7, built from
    `play-store-prep` @ `3c1b9ed`.
  - AAB sha256 `3276c80124a0e71735694363254a68cf8dfdf610a98a7105a99a4d770c4afc6f`.
  - APK sha256 `75a1ee759e40671a9aa8f300357bece9277c94ce4a6201adb450d14c0cbdeeac`.
  - `app_updates`: "v1.3.1" active, "v1.3" inactive (Supervisor did this with Musa's OK).
- **Google Play: v1.3.2 is the release build, ON HOLD** until Musa's Play developer verification
  arrives. It passed Musa's device test (including the live duplicate-photo 409 behaviour).
  - `Desktop\Acha Karo\releases\v1.3.2-play\` (AAB + universal APK), versionCode 8, 1.3.2, built
    from `dup-photo` @ `cca962e`.
  - AAB sha256 `c6687cdc012c45a788bbb57d91597559858afcff86316c43dd062192980cb235`.
  - APK sha256 `496caf932351b1ac5e371285bcbdc445cd16afda15da1f9537f6b3b04d5ac7e3`.
- **Signing:** every build is signed with the existing prod key (`android/key.properties` points to
  `C:\Users\HP\acha-karo-release-key.jks`; never copy, move, print or commit either).
  - Cert SHA-256 `1D:00:5D:8F:96:C5:D8:AA:90:32:9F:0E:75:25:F8:A0:50:8C:FC:E8:A3:39:C2:EA:F3:84:15:5C:55:56:DF:60`.
  - Musa chose Play's **"use existing app signing key"**, so Play builds can install over the
    sideloaded APKs. If Play re-signed with its own key, users couldn't upgrade in place.
- **Branches (local only, nothing pushed):**
  - `play-store-prep` (`3c1b9ed`) = v1.3.1.
  - `dup-photo` (`cca962e`, off `play-store-prep`) = v1.3.2 plus this doc.
  - Whether `main` / `pwa-origin` has been updated for the website release is the Supervisor's
    record: check `git log` before assuming. Never push to `origin` (it carries admin commits).

## Next

1. **PEPK key export when Musa creates the Play app.** Play Console → "Use existing app signing
   key" → export the key with Google's PEPK tool and upload it together with the AAB. The keystore
   and passwords stay Musa's. Don't copy the .jks anywhere, don't echo passwords, and propose the
   exact command to the Supervisor before running anything.
2. **At each release:** activate a matching `app_updates` row ("v1.3.2" when 1.3.2 ships).
   Otherwise users whose profile predates the active row and who never acknowledged it get an
   "update" prompt for the older version. `checkForUpdate()` compares the label with
   `kAppVersionLabel` (`lib/utils/app_version.dart`).

## What changed since v1.3 (Play prep, all reviewed and approved)

- **Location disclosure** (`lib/widgets/location_disclosure.dart`): shown before any OS prompt.
  - It says what is collected (about 100 m), why, and who can see it: only you and moderators
    (confirmed against the live policies).
  - "Submit without location" skips GPS and sends the deed to review with its own reason.
- **Photo metadata strip** (`lib/utils/image_metadata.dart`), in pure Dart:
  - JPEG and PNG are cleaned; other formats are re-encoded to PNG.
  - Only the Orientation tag is kept (the Android resizer relies on it).
  - Existing stored photos still carry EXIF; cleaning them is a separate storage task, not ours.
- **Manifest:** camera and location are `required="false"`. The reminder uses inexact alarms
  only (no exact-alarm permission). targetSdk 36.
- **Guddi cold-start loader** (`lib/widgets/guddi_loading.dart`) replaces the spinner. The copy
  lives in `GuddiLoadingLines`.
  - **M1 fixed** with `lib/utils/startup_loader.dart`: on error, or after 15 s, the offline state
    shows "Try again". A late success still goes into the app, and it retries on resume.
- **Terms v1.3.1** (Last updated 30 Sep 2026):
  - Location is optional.
  - Partners (e.g. NGOs) get anonymous area-level totals only, with at least 5 members per area.
  - Review "usually within 48 hours; up to 2 more days when busy".
  - The Urdu summary was kept in step; the Urdu is my translation, so Marketing should check it.
- **Account deletion:** completed "within 30 days", in Settings and in the Terms.
- **v1.3.2 duplicate photos** (`lib/utils/deed_photo_upload.dart`):
  - Objects are named `uid/<sha256 of cleaned bytes>.<ext>` and uploaded with upsert off.
    Storage's 409 means a duplicate, but only if one of the user's own deeds uses that photo.
    Otherwise the orphan object is reused.
  - On a duplicate, Guddi's message and a "New photo" button appear. The next submit from the
    same form is forced to review ("Resubmitted after a duplicate photo was rejected.").
  - The picker's resize was verified deterministic on Android (emulator) and in Chrome
    (`lib/dev_prototypes/dup_hash_probe.dart`).

## Still open / queued

- **H2** (the client decides deed approval and points; needs a server-side fix, which is DB
  work and a hard stop until approved).
- Queued from v1.3, not started:
  - bottom-nav redesign (mockups first)
  - streak badges on the real streak (needs sign-off)
  - FCM push for approve/reject (DB/Firebase, needs approval)
  - community cards (needs a new aggregate RPC; propose it first)
- **Small follow-ups the Supervisor has noted:**
  - Home's comeback nudge uses the worried pose, which is a bust cut flat at the bottom. It's
    faded in the offline loader but not on Home.
  - Bundle the fonts instead of google_fonts runtime fetching (which exposes the user's IP to
    Google).
  - `docs/SUPABASE_SETUP.md` is stale (its moderator policy snippet doesn't match live).
  - Check that the website Terms/Help got the same v1.3.1 changes; that's not in this repo.

## Copy rules (firm, enforced by tests)

- No religious framing (no neki / sawab / deen / نیکی). Say "acha kaam".
- Deeds are DONE: never log / likhein / لکھیں / لاگ کریں. Only the existing "Log a good deed" keeps
  "Log". `test/copy_rules_source_test.dart` fails on any other "Log …" string literal.
- Never a bare "karein" / "کریں": always "acha kaam karein" / "اچھا کام کریں", otherwise use a
  different verb ("kijiye" / "کیجیے", "soyein"). A source-wide test enforces it.
- Never a "small / chhota sa / چھوٹا" acha kaam.
- Roman Urdu first for Guddi lines, English subtitle optional.
- Other users' names are "First L." only. Proof photos: "Kaam ki tasveer lein, insaan ki nahi".
- Every privacy claim in the UI must be provably true (a file:line or a verified policy). The
  Supervisor rejects unverifiable promises.

## Build / verify gotchas

- **After `flutter pub get` or any build:** run `git checkout -- windows/flutter/` (the plugin
  files get regenerated).
- **Don't use `git stash`** for before/after checks. The pop gets blocked by those regenerated
  files, and your edits stay stuck in the stash. If it happens: `git checkout -- windows/flutter/`,
  then `git stash pop`.
- **Build outputs stay inside `build/`.** Never `flutter build web -o ../…`, because it writes
  outside this folder.
- **Release build:** `flutter build appbundle --release` and `flutter build apk --release`
  (universal; no `--split-per-abi`, because many phones are 32-bit armv7). Release builds need
  `android/app/proguard-rules.pro` (Gson/TypeToken), or the reminder silently dies.
- **Verify:**
  - `aapt2 dump badging` for version and permissions.
  - `apksigner verify --print-certs`. Export `JAVA_HOME="/c/Program Files/Android/Android Studio/jbr"`
    in the SAME shell, or it fails silently with exit 1.
  - For the AAB: `jarsigner -verify` ("jar verified.") and `keytool -printcert -jarfile`.
    bundletool isn't installed.
- **String check:** scan `lib/*/libapp.so` from both the APK and the AAB. Search latin1 and
  UTF-16LE, since Urdu and emoji are stored as UTF-16. Check that the new copy is present and the
  removed copy, placeholders and dev_prototypes symbols are absent. In the node check script,
  avoid apostrophes inside the quoted strings.
- **Emulator:** Pixel_6 AVD (Android 14).
  - Start it with `emulator -avd Pixel_6 -no-window -gpu swiftshader_indirect`.
  - In Git Bash set `MSYS_NO_PATHCONV=1`, or `/sdcard/...` paths get rewritten.
  - Tap "Wait" on the "System UI isn't responding" dialog.
  - Install debug probe builds only on the emulator.
- **Dev-only entry points** (never imported by the app): `lib/dev_prototypes/*_preview.dart` and
  `dup_hash_probe.dart`.
  - Build with `flutter build web -t <file>` and screenshot headlessly with puppeteer-core and the
    installed Chrome.
  - Supabase is either not used or points at a dead localhost address.
- Musa decides from screenshots: show options before building visual changes.
