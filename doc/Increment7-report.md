# Increment 7 report

**Increment:** 7 — Full Application Integration

**Status:** Complete within the approved integration scope. Real MP3 and hardware acceptance remain unverified/unavailable as detailed below.

Verification date: November 17, 2026. Environment: Windows, existing Flutter/Dart SDK, SQLite FFI for host tests, SQLite WASM in real Chrome for browser checks. No physical Radxa, native mobile acceptance, or MP3 fixture is claimed.

## Implemented workflows

The production frontend now consumes the existing application controllers. Offline SQLite is usable without device connectivity. The four primary destinations, 17 routes, origin-aware details/back navigation, Midnight Crimson tokens, and approved omissions remain intact. Production startup does not seed music, playlists, history, or device telemetry.

- Library loads persisted records, searches title/artist through LibraryController, delegates sorting, refreshes, opens playlists, and selects songs. Recents and Date added both use the existing newest-first sort. Albums/Artists grouping remains unavailable rather than duplicating an unapproved grouping implementation.
- Playlist creation, ordered reads, rename, description update/clear, deletion, adding existing songs, individual occurrence removal, and reordering call PlaylistController. Rows use PlaylistEntry IDs; duplicate songs remain distinct. Reorder supports drag and accessible up/down actions. Controller positions remain zero-based. Removing playlists preserves songs.
- Playlist editing preserves the existing two-field form and existing controller APIs. Changed fields save sequentially. If rename commits and description fails, feedback explicitly says the name was saved; the description draft remains available for correction/retry. A combined atomic edit is not claimed.
- Song removal confirms deletion of the record, history, and playlist entries while preserving physical audio. LibraryController retains its existing atomic transaction. A queue containing the removed song is then stopped/cleared through PlaybackController. Database deletion, playback cleanup, and subsequent refresh outcomes are reported independently. A later cleanup failure never implies that the database deletion rolled back.
- Manual lyrics load/save/clear through LyricsController. Exact Unicode, punctuation, whitespace, empty strings, and multiline text are preserved. Explicit Clear stores null. Cancel discards unsaved text. Fullscreen lyrics uses the selected ID and current saved text.
- Now Playing, queue sheets, mini-player, and lyrics transport controls share PlaybackController. Library taps select the visible-song queue; playlist taps preserve ordered duplicate occurrences. Queue-sheet selection uses its actual index. Replacing a queue stops previous playback and does not autoplay; explicit playlist Play requests playback only after queue acceptance. Opening the player alone changes nothing.
- Play/pause/resume, stop, next/previous, seeking, loading, errors, position, and duration use real controller/engine state. Seeking requires a loaded duration. Metadata durations do not imply engine readiness. Missing/unsupported sources and initialization failures have distinct feedback. No simulated progress, playback, completion, or counted listening history is generated.
- Statistics uses the controller's All Time/Week/Month/Year calendar ranges, counted plays, exact duration including milliseconds, top tracks, recent records, and available song-level results. Current-period values are withheld while loading rather than relabeling stale totals. Returning to Statistics reloads global statistics without a stale detail selection.
- Chart mapping uses only up to 20 returned recent sessions, groups them by actual local date, and labels the subset explicitly. Full-period totals are unchanged. Date labels/chart content scroll horizontally when necessary. Artist ranking, streaks, and export remain unavailable; no unsupported totals are invented.
- Device screens consume sanitized saved trust, controller phases/failures, capabilities, and available verified telemetry. Saved trust is separate from authentication. Test-only sessions cannot populate verified telemetry or appear as authenticated hardware. Supported local settings updates, saved-summary reload, explicit guarded connection, disconnect, read-only status refresh, and local forgetting use DeviceController.
- Forget confirmation explains that local cleanup does not prove remote revocation or removal of an OS Bluetooth bond. Platform and cleanup failures are surfaced. HTTPS endpoint drafts receive local validation and retain controller validation; settings changes do not establish identity.
- Add Music and recording interfaces retain their drafts/navigation. Imports, downloads, recording, recording saves, transfers, remote file operations, headset management, and unsupported hardware settings remain unavailable.

## Full file inventory

Created:

```text
lib/frontend/widgets/application_binding.dart
test/browser/integrated_app.dart
test/browser/integrated_ui_verify.cjs
test/frontend_integration_test.dart
test/support/integrated_fixture.dart
doc/Increment7-report.md
```

Modified:

```text
README.md
lib/app.dart
lib/backend/app_dependencies.dart
lib/frontend/pages/device_pages.dart
lib/frontend/pages/frontend_page.dart
lib/frontend/pages/library_pages.dart
lib/frontend/pages/main_shell.dart
lib/frontend/pages/playback_pages.dart
lib/frontend/pages/statistics_page.dart
lib/frontend/routes/frontend_navigation.dart
lib/frontend/widgets/design_widgets.dart
lib/frontend/widgets/draft_editors.dart
lib/frontend/widgets/presentation.dart
test/browser/persistence_probe.dart
test/browser/verify.cjs
test/browser/visual_verify.cjs
```

Removed: none. No existing test was weakened or deleted. The schema/models, repository and domain controller implementations, audio services/harness, device security/services/protocol, dependency manifests, audio catalog, original WAVs, and main entry point are preserved. AppDependencies changes are composition/testing seams only.

## Architecture and interfaces

ApplicationBinding supplies the application's existing AppDependencies through an inherited frontend scope. Startup independently loads library, playlists, and statistics; device authentication is not started. BoundContent listens to relevant existing ChangeNotifiers, maps immutable ScreenPresentation inputs, and refreshes ID-based details on route return or selection changes. High-frequency audio state does not rebuild unrelated hardware pages.

FrontendActions is a narrow integration coordinator: it forwards requests and performs explicit cross-controller refreshes, without SQL, a repository cache, audio player, HTTP client, sorting implementation, listening-history writer, or global event bus. Statistics period/detail selection are UI context. Database writes and domain validation remain in existing controllers/services. SongRemovalOutcome records independent deletion/cleanup/refresh outcomes.

Public integration additions:

- FrontendRouteArguments carries optional songId/playlistId alongside the existing origin/preview input. Production resolves records by ID. NavigationOrigin optionally delegates tab selection back to its shell so Statistics can refresh while NavigationController retains ownership of tab state.
- ScreenPresentation adds read-only ordered entries, available library songs, actual playback/device state, period, and sanitized error inputs. No field grants device authorization.
- DraftEditor optionally accepts an asynchronous save callback. The absent-callback gallery/unsupported workflow retains its existing unavailable behavior. Confirmed actions share pending/error/completion feedback.
- Mp3ControllerApp optionally accepts a navigator key and explicit dependency ownership. Production owns and closes its dependencies. Tests can retain ownership to reopen SQLite. Changing dependencies replaces the binding and closes previously owned dependencies.
- AppDependencies.forTesting is an explicitly annotated composition seam for already constructed test dependencies. It imports no adapters from tests and has no production activation flag. The injected device controller, connections, pairing service, and Radxa client remain the same instances.

Controller generation/cancellation guards are unchanged. UI code additionally checks mounted/application lifetime, prevents duplicate submissions, suppresses superseded autoplay requests, and detaches listeners. Submitted persistence operations cannot be dismissed as though cancelled; cancellation before submission discards drafts. Failed saves retain drafts. A success message is not shown before persistence or engine acceptance. Not-found selections cannot render another song/playlist's stale data.

## Screen integration matrix

Widget coverage includes every destination with real SQLite/controller composition at 320/390/430 px and normal/200% text. Browser visual verification below is separate from workflow tests and hardware acceptance.

| Screen | Real data source | Working actions | Intentionally unavailable / remaining dependencies | Verification |
| --- | --- | --- | --- | --- |
| Library | LibraryController, PlaylistController, SQLite; shared playback mini-player | Load, search, sort, refresh, create/open playlists, song selection/details, confirmed record deletion | Importing, album/artist grouping, downloads, device sync | Passed: widget workflows, Chrome UI/same-origin persistence, rendered comparison |
| Playlist Details | PlaylistController ordered entries/songs; library song picker | Rename, description update/clear, add, occurrence removal, drag/up/down reorder, delete, queue selection, explicit Play | Sharing, shuffle/mix, downloading, hardware synchronization | Passed: widget CRUD/duplicate occurrence tests, Chrome create/edit/add/reload, rendered comparison |
| Now Playing | Shared PlaybackController; latest library metadata | Queue, play/pause/resume/stop, next/previous, seek, actual state/timing, lyrics navigation | Real MP3 acceptance; sharing, shuffle/repeat; Radxa playback | Passed: explicitly simulated audio UI/queue tests and rendered comparison; real MP3 not tested |
| Lyrics & Song Details | LyricsController, library metadata, selected-song StatisticsController results, playback queue | Load/edit/save/clear/cancel lyrics, fullscreen/details navigation, queue | Automatic lyrics, synchronization, unsupported credits | Passed: exact-text/error/keyboard tests, Chrome Unicode save/reload, rendered comparison |
| Fullscreen Lyrics | Selected-ID LyricsController and shared playback | Saved-text scrolling, back/close, supported transport | Timed highlighting and karaoke seeking | Passed: saved-text/back/size tests and rendered comparison |
| Add Music | Existing local drafts and navigation; shared mini-player | URL input/paste/syntax feedback, recording navigation | Importing, downloading, yt-dlp, URL submission | Passed: preserved interactions, Chrome tab access and rendered comparison |
| Record Audio | DeviceController availability and existing presentation | Source/layout navigation to metadata form | Capture, timers/levels, actual splits, hardware operations | Passed: unavailable-state/size tests and rendered comparison |
| Save Recording | Existing draft form; no fabricated recording | Draft fields, validation/cancel, navigation | Recording-dependent saves, export, synchronization | Passed: preserved draft/form/keyboard tests and rendered comparison |
| Device | DeviceController saved summary, phases/failures, verified status | Device-settings navigation | Production authentication/pairing and unsupported hardware | Passed: trust/unavailable tests, Chrome restrictions and rendered comparison |
| Connections | DeviceController and existing secure services | Reload summary, guarded connect/disconnect/status refresh, supported settings, confirmed local forgetting | Discovery/pairing/provisioning, find-player, unsupported preferences, browser mobile trust | Passed: supported test adapters, auth errors, test-only boundaries, Chrome unavailable state and rendered comparison |
| Music Sync | DeviceController availability/verified telemetry | Local scope selection and navigation | Transfers, pause/cancel/sync, progress | Passed: unavailable-state/size tests and rendered comparison |
| Storage | Verified DeviceController status only | Capacity/free display when supplied; File Manager navigation | Unknown telemetry remains unavailable | Passed: controller mapper/state tests and rendered comparison; real telemetry unverified |
| File Manager | Actual device status; no unsupported listing request | Existing search/sort/category drafts, navigation | Remote listing/traversal, selection operations, deletion, transfer | Passed: unavailable-state/size tests and rendered comparison |
| Bluetooth Audio | DeviceController status; no invented headphones | Navigation and availability explanations | A2DP/headphone configuration/discovery, device BLE pairing | Passed: controller state/size tests and rendered comparison; hardware unverified |
| Battery & Display | Verified status battery/charging, if supplied | Read-only actual values and navigation | Unsupported battery/display/power settings | Passed: controller state/size tests and rendered comparison; hardware unverified |
| About Device | Verified identity/capabilities/firmware/storage, if supplied | Read-only information/navigation | Invented name/model/version, updates, restart/shutdown | Passed: controller state/size tests and rendered comparison; hardware unverified |
| Listening Statistics | StatisticsController and persisted history; library title lookup | Four calendar periods, exact totals, top tracks, recent activity/subset chart | History generation threshold, artist ranking, streaks, custom dates, export | Passed: period/count/duration/subset/empty tests, Chrome persisted totals and rendered comparison |

## Automated and browser verification

The suite contains **248 tests: all 217 original tests plus 31 new integration cases**. The new suite uses real isolated SQLite databases and explicit audio/device doubles; simulated engine events are never real MP3 evidence. Coverage includes successful/failed forms, duplicate playlist occurrences, safe deletion outcomes, partial playlist saves, reopened persistence, current-period filtering, the 20-record chart limit, missing records, unavailable sources versus initialization failures, device provenance, disposal, pending submission, keyboard-open lyrics, and all 17 responsive layouts.

| Check | Actual result |
| --- | --- |
| Formatting | Passed; 80 files, zero pending changes |
| `flutter analyze --no-pub` | Passed; no issues |
| Full `flutter test --no-pub --reporter expanded` | Passed; all 248 tests in the final run, including all 217 previous tests |
| Targeted timed-out playlist workflow | Passed on immediate rerun |
| Production web build | Passed; final source built successfully |
| Audio-development, frontend-preview, persistence-probe builds | Passed; all three final builds completed |
| Browser-script syntax | Passed for verify.cjs, visual_verify.cjs, and integrated_ui_verify.cjs |
| Real Chrome persistence/security and UI workflow | Passed; original checks and actual integrated UI changes persisted after same-origin reload; fresh production library empty and free of fixtures |
| All-screen rendered capture and qualitative comparison | Passed; 51 screen sets / 132 frames; all 17 integrated top views and selected lower/production/gallery views inspected |
| Protected source, WAV hashes, `git diff --check` | Passed; protected implementations unchanged; all six WAV SHA-256 hashes match |

Development verification exposed a missing-time-label encoding error, a null/null selected-statistics check, and post-frame database timing in the new test driver. These were corrected without weakening old tests. The SQLite-backed widget tests run in real asynchronous timing to avoid fake-clock database locks. One full run had large wall-clock gaps and a ten-minute test timeout; its immediate targeted rerun passed, followed by a successful full 248-test run in approximately 41 seconds. Browser-driver retries exposed merged row semantics, disabled-control timing, and unreliable clearing through empty text insertion. The driver now targets interactive semantics and uses native select-all/Backspace events. Final browser assertions confirmed the cleared description is null and exact Unicode lyrics survived reload. No unresolved failure is counted as a pass.

The browser test-only entry adds an isolated integrated-app mode to the existing persistence-probe build. A unique `integrated-browser-<run>.db` holds fixture songs/history; actual production widgets/controller forms created a playlist, renamed it, cleared its description, added a song, and saved exact Unicode/multiline lyrics. Reload at `http://127.0.0.1:52842` returned `restored`, with the renamed playlist, null description, one entry, exact saved lyrics, and two fixture song records. Statistics displayed one counted play and 14,346 milliseconds, including the uncounted session's duration. All four tabs and period controls were exercised, and hardwareAuthenticated remained false. Test resources were cleaned.

Original browser checks again reported seeded then restored at that same origin, with four tables, close/reopen, lyrics, controllers, queue wrapping, HTTP/proposal codec, unavailable mobile trust, unavailable device controller/protected commands, and false hardware authentication. The separate fresh production origin rendered an empty Library with no browser/gallery fixtures. The unchanged audio harness remained idle and Awaiting MP3 File. These browser results are separate from audio-double widget tests and do not establish audible MP3, native storage, or hardware acceptance.

The visual runner retained 17 production and 17 isolated gallery views and added 17 real SQLite-integrated views through that test-only entry: **51 screen sets, 132 frames**. Evidence is under ignored `build/increment7-visual/`, with reference mappings in `manifest.json` and an HTML review index. All 17 integrated top views were inspected, plus lower playlist/duplicate rows, player controls/lyrics, connection utilities, and statistics chart/top-track sections. Production Library/Statistics empty states and the isolated gallery were also inspected.

The review retained the established navy/blue/crimson palette, gradients, cards, artwork frames, hierarchy, and navigation. Integration changes are the Library create/refresh actions, enabled supported actions, lyrics Clear, actual state/labels/errors, exact-duration wrapping, a date-labeled recent-session chart, and explicit device status panels. Long metadata wraps and content scrolls without observed overlap in reviewed frames. Diagnostic fixture banners exist only in test/gallery entry points. Enlarged text/keyboard behavior is checked by widget tests at 320/390/430 px and normal/200% text; Chrome captures use 390 × 844 at normal text. Comparison is qualitative rather than pixel-exact, and no native accessibility certification is claimed.

## Reproduce verification

```powershell
dart format --output=none --set-exit-if-changed lib test
flutter analyze --no-pub
flutter test --no-pub --reporter expanded
flutter build web --no-pub
flutter build web --no-pub --target lib/frontend/development/local_playback_harness.dart --output build/audio-development
flutter build web --no-pub --target lib/frontend/development/frontend_preview.dart --output build/frontend-preview
flutter build web --no-pub --target test/browser/persistence_probe.dart --output build/browser-verification
node --check test/browser/verify.cjs
node --check test/browser/visual_verify.cjs
node --check test/browser/integrated_ui_verify.cjs
node test/browser/verify.cjs
node test/browser/visual_verify.cjs
git diff --check
```

Node 22+ and Chrome are required; CHROME_PATH is supported. Browser workflow ports remain 52842/52843/52844. Visual capture uses 52845/52846 and adds the isolated test target on 52847. Servers and temporary profiles belong only to their test run. No user profile is used. Logs are ignored `build/increment7-*.log`; generated screenshots/build bundles are not committed. Wasm dry-run success is not separate Wasm runtime acceptance.

## Manual verification

1. Run `flutter run -d chrome`. A fresh normal database should show an empty Library and allow playlist creation without Radxa. It must not contain browser/gallery sample records. Imports/downloads/recording/sync stay unavailable. Device storage/authentication failures must not disable offline playlists.
2. Create a playlist, rename it, edit/clear its description, and reload at the same scheme/host/port. With existing registered songs, add duplicates, reorder them, remove just one occurrence, and delete the playlist. Song records must remain.
3. Select a song, open Lyrics & Song Details, save multiline Unicode/whitespace text, reopen fullscreen, cancel an unsaved edit, explicitly clear lyrics, and reload. Check saved text rather than assuming a toast proves persistence.
4. Inspect Now Playing/mini-player/queue. Without MP3, readiness/progress/playback must not be fabricated. When an independently supplied valid source exists, controls must follow actual controller state; this does not complete the still-pending real playback acceptance checklist.
5. Inspect all four statistics filters. Existing records should produce controller totals; empty history should produce zeros/empty chart. The chart must identify its latest-20-session subset. Playing a song must not create history automatically.
6. Remove a library song after confirmation. Its record/entries/history should disappear, physical audio stay untouched, and any affected queue stop/clear. If cleanup fails, the confirmation must separately state that the database deletion succeeded and playback cleanup failed.
7. Inspect Connections and all hardware details. Saved local trust must not imply connection or authentication. Forget confirmation must explain local-only effects. Chrome must not claim validated mobile secure storage or successful hardware authentication.
8. Test narrow widths, enlarged text, keyboard-open forms, scrolling, return paths, all tabs, and repeated detail navigation. Keep the independently launched design gallery free of live services.

For a reproducible isolated browser UI fixture without importing audio:

```powershell
flutter run -d chrome -t test/browser/persistence_probe.dart --web-port=52842
```

Open `http://localhost:52842/?integrationApp=true&run=2026111707` and retain that exact origin for reloads. Only this test entry seeds two metadata-only songs and two history rows. Create/edit playlists and lyrics through the UI. Afterwards navigate to the same URL with `&cleanup=true` to remove the isolated database. Do not confuse this test database with production storage or the labeled visual gallery.

## Limitations and preserved boundaries

- Increment 4 remains **Partial — Awaiting MP3 File**. Real loading/readiness/play-pause/progress/seeking/completion/audibility and Android/iOS playback remain **Not Tested — Awaiting MP3 File**. No audio was generated, downloaded, converted, renamed, or changed; no MP3 was added.
- Physical Radxa communication, identity verification, authorization/provisioning/BLE pairing, pinned-device acceptance, native secure storage, and OS bonding are unverified. Production authenticated connections remain unavailable. The proposal protocol, one-device policy, HTTPS restrictions, Wi-Fi bulk-transfer boundary, retry policy, cancellation, and command allowlist remain unchanged.
- Music importing, downloading/yt-dlp, recording, synchronization, remote file operations, hardware command execution, and headset configuration remain unavailable. Recording album/year/genre remain draft-only and do not alter the schema.
- No listening-history generation threshold was invented. Chart mapping does not expand the controller's history query or invent complete daily totals. Unsupported statistics remain unavailable.
- Native builds, native screen readers, physical headphone output, and owner hands-on acceptance are not claimed from Windows widget/browser checks. Neutral artwork, existing typography, manual lyrics, responsive wrapping, and approved social/merch/video omissions remain accepted wireframe differences.

**Suggested Git Commit Message:** `feat: integrate Flutter frontend with application controllers`

**Next Increment:** 8 — Testing, Stabilization & Final Demonstration. Not started.

Stopped after Increment 7 implementation, verification, and reporting. No commit, push, or Increment 8 work has been performed.

## Owner-requested WAV testing correction

The owner subsequently requested using the six supplied WAVs as actual test songs.
The empty MP3-only fixture catalog is superseded by real WAV metadata and an opt-in
launcher that stages byte-identical, ignored asset copies. Original recordings
remain untouched. See [WAV-testing.md](WAV-testing.md) for correction verification
and remaining MP3/native/audibility limitations. Increment 8 is not started.
The correction's final suite passed 251 tests, and real Chrome verified the six
WAVs through the integrated app and audio harness. No real MP3 acceptance is claimed.
The subsequent empty-library screenshot was traced to the special-flag launch
requirement and initial Playlists category. Normal debug startup now enables the
existing test catalog automatically, and a songs-only library opens on Songs.
Release/profile registration stays off by default; explicit category choices
persist. The full suite now contains 252 passing tests; see the WAV report for
the ordinary no-flag debug Chrome check and restart instructions.
