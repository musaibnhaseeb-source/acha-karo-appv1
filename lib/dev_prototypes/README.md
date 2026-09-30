# dev_prototypes — NOT SHIPPED, design sandbox

Nothing in the app imports anything in this folder, so none of it is compiled into the release
APK or the web build. It's kept for future design work only. Do not import these files from
shipped code; if something here is ever revived, move it back out and review it like new code.

| File | What it was |
|---|---|
| `simulator_screen.dart` | Internal test tool: advance "sim day", fake flagged deeds, client-side approve/reject. Its AppState helpers (`advanceDay`, `simulateAddTestFlaggedDeed`, `toggleDemoCampaignActive`, `approveQueueItem`, `rejectQueueItem`, `loadModerationQueue`) have no callers in shipped code. |
| `demo_app_state.dart` | In-memory fake Friends data for the old debug-only "Friends (Demo)" menu entry (removed). |
| `partners_screen.dart` | Blank placeholder screen for a future Redeem/Partners feature. |
| `edit_profile_screen.dart` | Older full-screen Edit Profile, superseded by `widgets/edit_profile_sheet.dart`. |
| `hero_band.dart`, `monuments.dart` | Scrolling monuments banner, not used on any screen. |
| `past_winners.dart` | Static sample "past winners" data. |
| `guddi_loading_preview.dart` | Dev preview of the cold-start Guddi loader (each line at 360 dp, several text scales). Own entry point, not imported. |
