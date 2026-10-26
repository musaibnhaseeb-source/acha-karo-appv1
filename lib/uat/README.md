# UAT mode — journey-map screen only

Test the journey-map screen any time, on seeded in-memory data, without touching the real
database. Scope is this one screen; no other screen or AppState is involved.

## Launch

```
flutter run -t lib/uat/uat_main.dart        # emulator / desktop / chrome
```

A red **UAT** corner banner and a "UAT · seeded data · no network" bar are always visible. Tap the
sliders icon (top right) for the controls drawer: fake user switcher, **+1 acha kaam** (no photo,
no GPS), set deeds to 0 / each stop threshold, reset user+campaign, reset everything, and claim
result (Random / Win / Lose). Restarting the app restores the seed.

## Why it cannot ship or reach a real user

- Separate entry point. Release builds use `lib/main.dart`, which does not import `lib/uat`, so
  none of this is compiled in.
- `uat_main.dart` throws if run in a release build.
- Nothing in `lib/uat` imports Supabase, `supabase_config.dart`, `main.dart` or `AppState`, and
  it never calls `Supabase.initialize`. `test/uat_isolation_test.dart` checks this, and that
  nothing outside `lib/uat` / `lib/dev_prototypes` imports `lib/uat`.
- No real names, phone numbers, emails or ids: users are "UAT User A–E".

## Structure

| File | Role |
|---|---|
| `lib/data/journey_repository.dart` | The interface the screen uses |
| `lib/data/journey_models.dart` | `JourneyTheme`, `JourneyConfig`, `JourneyProgress`, `ClaimOutcome`, `JourneyException` |
| `lib/data/supabase_journey_repository.dart` | Real implementation (same queries + `claim-roadmap-stop` call as `roadmap_screen.dart`) |
| `lib/screens/journey_screen.dart` | The new screen (placeholder visuals; data wiring is final) |
| `lib/uat/uat_journey_repository.dart` | In-memory implementation + UAT-only controls |
| `lib/uat/uat_rules.dart` | Claim rules re-implemented in Dart |
| `lib/uat/uat_seed.dart` | 3 campaigns, 5 fake users |
| `lib/uat/uat_shell.dart`, `uat_main.dart` | Banner, campaign chips, controls drawer, entry point |

## Seed

Campaigns: **UAT Short Road** (3 stops, 2/4/6), **UAT Classic Road** (3 stops, 3/7/12, middle stop
is `guaranteed_with_discount`, mirrors the live shape), **UAT Long Road** (6 stops, 2/5/9/14/20/27,
mixed modes incl. a guaranteed stop with no skin). Users: A fresh, B one acha kaam, C mid-road
(Stop 1 claimed), D at a stop (reached, unclaimed), E finished (all claimed, Hall of Fame claimed).

## Rule drift table

Source of truth: `supabase/functions/claim-roadmap-stop/index.ts`. Test expectations:
`test/uat_rules_test.dart`.

| UAT rule (`uat_rules.dart` / repository) | Server rule mirrored |
|---|---|
| `hasReachedStop`: deeds >= threshold | step 2: `count < stop.threshold` -> 403 "You have not reached this stop yet." |
| Progress is per campaign (deeds counter keyed by campaign) | step 2: approved deeds filtered by `campaign_id` |
| `alreadyClaimed` -> "You have already claimed this stop." | step 3 (+ unique constraint) -> 409 |
| `pickedIndex` outside 0..total_boxes-1 -> "Invalid box." | step 1 bounds check -> 400 |
| Check order: invalid box, not reached, already claimed | same order on the server |
| `drawWinningIndices`: shuffle, first `winning_boxes` win | step 4 |
| standard: win -> `prize` (+points if `prize_points` truthy), lose -> `none` | step 6 tail |
| `guaranteed_with_discount` + `skin_id`: win -> `free_skin`, lose -> `discount` (`discount_percent`) | step 6 branch |
| guaranteed mode with no `skin_id` falls through to standard | `&& stop.skin_id` condition |
| Claim stored as `won` only | step 5 insert (`roadmap_claims`) |
| Hall of Fame flag is seeded, not claimable | `hall_of_fame_claims` read only |

> **Re-check UAT whenever `claim-roadmap-stop` changes** (or `roadmap_stops` / `roadmap_claims`
> columns change): update `uat_rules.dart`, the table above and `test/uat_rules_test.dart`
> together. Drift cannot be detected automatically.

## Known gaps

- Real deed approval (moderation, cooldown, duplicate-photo checks) is not simulated; "+1 acha
  kaam" just bumps a counter.
- Server randomness is a JS `Math.random` shuffle; UAT uses Dart `Random` (same distribution).
- `RoadmapStop` has no `prize_points`, so UAT keeps points in a seed map; points go to a UAT-local
  counter only. If the server returns `prize_points: 0` it is not filtered, UAT treats 0 as none.
- Skins and discounts are tracked as ids on the UAT user, not real skin inventory.
- The Hall of Fame claim flow, equipped-skin loading and profile reload are out of scope.
- Theme is a client-side data object (`JourneyTheme`) with placeholder fields; adapt to the design
  spec when it lands. No server-side theme columns.
