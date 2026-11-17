# MP3 Controller

Flutter/Dart companion application for a standalone Radxa MP3 player. Development follows MVC and one reviewed increment at a time.

Run the normal debug app with the six existing WAV test songs:

```powershell
flutter run -d chrome --web-port=52848
```

Debug startup automatically registers the existing bundled test audio. With no playlists, the Library initially shows **Songs**, including **Track 1–6**; select a track, then press **Play**. VS Code also has a **CTA2000 Chrome** launch configuration. Fully stop/restart after updating startup code; hot reload does not rerun registration. Port 52848 stays fixed for persistence.

If the WAVs have not been staged on this computer, use `.\run_test_music.cmd` to copy the unchanged local `Music/` files into ignored Flutter assets and launch. Release/profile builds keep registration off by default; an explicit `ENABLE_DEVELOPMENT_AUDIO` define overrides the startup default. No audio is pushed to Git. See [WAV testing](doc/WAV-testing.md).

## Increment 1: verified screen inventory

Verified against all 22 PNGs in `doc/WireFrame/`. Alternate Library, Playlist Details, Add Music, and Now Playing images represent the same destinations. The combined download/record design is also an Add Music variant. There are **17 distinct screens**.

| Screen | Named route | Navigation path |
| --- | --- | --- |
| Library | `/library` | Main navigation → Library |
| Playlist Details | `/playlist` | Library → Playlist Details preview |
| Now Playing | `/now-playing` | Library or mini-player preview → Now Playing |
| Lyrics & Song Details | `/song-details` | Now Playing → Lyrics & Song Details |
| Fullscreen Lyrics | `/lyrics` | Lyrics & Song Details → Fullscreen Lyrics |
| Add Music | `/add-music` | Main navigation → Add Music |
| Record Audio / Vinyl & CD Digitization | `/record` | Add Music → Record Audio |
| Save Recording / Track Information | `/save-recording` | Record Audio → Save Recording preview |
| Device / Main Settings | `/device` | Main navigation → Device |
| Connections | `/connections` | Device → Connections |
| Music Sync | `/sync` | Device or Library → Music Sync |
| Storage | `/storage` | Device → Storage |
| File Manager | `/files` | Device or Storage → File Manager |
| Bluetooth Audio | `/bluetooth-audio` | Device → Bluetooth Audio |
| Battery & Display | `/battery-display` | Device → Battery & Display |
| About Device | `/about-device` | Device → About Device |
| Listening Statistics | `/statistics` | Main navigation → Statistics |

Main navigation follows the red/navy variants: Library, Add Music, Device, Statistics. Search belongs within Library. Detail routes use Navigator push/pop and return to their origin. Fullscreen Lyrics omits bottom navigation. Data-dependent navigation is explicitly labeled as a preview.

## Architecture and increment boundaries

### Project organization

Unlike MatchLens, where the React client and Express server were separate applications, this project contains frontend presentation and local backend logic within **one Flutter application**. The folders organize MVC responsibilities; there is no standalone backend server or HTTP API for application navigation.

```text
lib/
  main.dart                         # Application entry point
  app.dart                          # Root widget and configuration
  frontend/
    pages/                          # Approved Flutter screens
    widgets/                        # Reusable presentation components
    theme/                          # Midnight Crimson colors and component themes
    routes/                         # Centralized Flutter Navigator definitions
    development/                    # Isolated audio harness and frontend design gallery
  backend/
    app_dependencies.dart           # Service composition and lifecycle
    controllers/                    # Navigation, music management, local playback and device state
    models/                         # Approved entities, statistics results and device DTOs
    services/
      database/                     # SQLite lifecycle and typed CRUD
      audio/                        # Injectable local audio, source resolution and dev catalog
      device/                       # HTTP, trust storage and connection workflow
assets/audio/                       # Tracked documentation/catalog; actual audio ignored
test/                               # Database, HTTP, workflow and UI verification
```

Frontend pages render state and receive user interactions; backend controllers coordinate behavior and notify views. Backend models and infrastructure are organized as follows:

- `models/`: Song, Playlist, PlaylistEntry, and ListeningHistory (implemented in Increment 2).
- `services/database/`: SQLite initialization, queries, and persistence (implemented in Increment 2).
- `services/audio/`: Injectable local playback through just_audio, explicit source resolution, and opt-in development registration (Increment 4; real MP3 acceptance pending).
- `services/device/`: Real HTTP infrastructure, mobile trust storage, pairing/reconnect orchestration, typed Radxa commands, and a proposal codec. Production BLE/provisioning and authenticated hardware operations remain unavailable.

All application code belongs under `lib/frontend/` or `lib/backend/`, except the entry points `main.dart` and `app.dart` directly under `lib/`. Routing lives in `lib/frontend/routes/`, preserving `app_router.dart` and `app_screen.dart`. The development harness has a separate entry point under `frontend/development/` and adds no production route. Device HTTP/BLE services are separate from Flutter Navigator routing.

### Increment boundaries

- The entry point starts MaterialApp; centralized routes and theme configure the application. A ChangeNotifier controller owns main-tab selection. Views display state and request navigation.
- Midnight Crimson uses navy backgrounds, blue surfaces, crimson accents, and white/gray text, with no green UI accents.
- Increment 2 provides the approved models, SQLite services, and networking foundations; Increment 3 adds independently testable business controllers. Importing, audio playback, and full UI integration remain in later increments. Song retains optional `lyrics_text`.
- The newer master prompt permits local development playback in Increment 4, superseding older Radxa-only playback notes. Increment 1 implements no playback.
- Hardware values are unavailable; controls cannot claim connections, downloads, recording, or transfer success. Wireframe sample music, accounts, synced lyrics, commerce, and social content are not live data.
- The six supplied `Music/` files are WAV files and remain unchanged. Audio registration and the missing MP3 requirement belong to Increment 4.

## Increment 1 verification

Run formatting checks, `flutter analyze`, `flutter test`, and `flutter build web`. Launch with `flutter run -d chrome` for manual review on Windows. Existing targets are web and iOS; adding Android scaffolding is outside this increment.

Visit every path above, return from every detail screen, and check the nested lyrics flow and both entry paths to Sync and File Manager. Review narrow mobile layouts and enlarged text. The mini-player is a labeled navigation preview without functional playback controls.

Verified for Increment 1 on November 16, 2026:

- Dart formatting check: passed (10 files, no remaining changes).
- `flutter analyze --no-pub`: passed, no issues.
- `flutter test --no-pub`: passed, 16 tests; all 17 screens, detail return paths, alternate Sync/File Manager entries, and 320/390 px layouts at 200% text.
- `flutter build web --no-pub`: passed, output in `build/web`.
- Release app launched in headless Chrome. Local browser inspection confirmed Flutter rendered the Library; its 390 × 844 screenshot was visually inspected. Full interactive navigation is covered by widget tests; owner hands-on review remains recommended.
- `git diff --check`: passed.

Flutter and Dart required permission to access SDK/cache and telemetry files outside the workspace. Verification succeeded after that access was granted. No iOS build was attempted on Windows.

Stop after the increment report for owner review and manual commit/push. Increment 2 requires explicit authorization.

## Increment 1 structural correction verification

Reorganized the existing files under `frontend/` and `backend/` without adding functionality. Source comparison confirmed all Dart content except imports, the existing test suite, route definitions, theme values, and dependency manifests were preserved.

- Formatting: `dart format --output=none --set-exit-if-changed lib test` passed (10 files, no changes).
- Analysis: `flutter analyze --no-pub` passed with no issues.
- Tests: `flutter test --no-pub` passed all 16 tests, including all 17 screens, nested navigation, detail return paths, and enlarged-text layouts.
- Web build: `flutter build web --no-pub` passed; output is in `build/web`.
- Import audit: no stale location references or missing relative imports; old directories removed after becoming empty.
- Whitespace: `git diff --check` passed.

Browser launch was not repeated for this structural correction; the original launch result above belongs to the original Increment 1 verification. No Increment 2 functionality, models, services, or dependencies were added.

Suggested correction commit message: `refactor: organize Flutter frontend and backend structure`.

## Increment 1 final routing-location correction

Moved both route files into `lib/frontend/routes/`, updated imports in application configuration, the navigation controller, frontend pages/widgets, and navigation tests, and removed the empty old route directory. Only `main.dart` and `app.dart` remain directly under `lib/`; all other application code is under `frontend/` or `backend/`.

Verification for this final correction (separate from the previous results):

- Formatting: `dart format --output=none --set-exit-if-changed lib test` passed (10 files, no changes).
- `flutter analyze --no-pub`: passed, no issues.
- `flutter test --no-pub`: passed all 16 tests, covering all 17 screens, nested navigation, detail return paths, and enlarged-text layouts.
- `flutter build web --no-pub`: passed; output is in `build/web`.
- Import/location audit: no missing relative imports, stale package imports, or application code outside the required boundaries; the old route directory no longer exists.
- Source comparison: no changes outside Dart import lines; route definitions, behavior, screen content, theme values, and dependency manifests preserved.
- `git diff --check`: passed.

Browser launch was not repeated for this move. This remains an Increment 1 correction; no later-increment functionality was added. Stop for owner review and manual commit/push.

## Increment 2 — SQLite and networking foundations

The owner expanded Increment 2 to include real HTTP infrastructure and testable pairing/reconnection orchestration. Importing, local playback, core music-management controllers, and final frontend integration remain in their original later increments. The 17 screens and Midnight Crimson theme are preserved. No audio files are seeded or downloaded by this increment.

### SQLite and repository API

`MusicDatabase` owns version-1 initialization and closing; an injected factory isolates platform setup. `LocalMusicRepository` exposes typed `songs`, `playlists`, `entries`, and `history` stores with `insert`, `find`, `list`, `update`, and `delete`. `getEntries` returns playlist order; `getLyrics` and `updateLyrics` support saving, editing, and clearing optional lyrics. `transaction` provides a transaction-bound repository; nested transactions are rejected.

The only application tables are `SONG`, `PLAYLIST`, `PLAYLIST_ENTRY`, and `LISTENING_HISTORY`, with exactly the approved columns. IDs are caller-supplied strings; dates use UTC epoch milliseconds; booleans use 0/1. Foreign keys are enabled. Deleting a song removes its playlist entries and history; deleting a playlist removes its entries without deleting songs. Repeated songs are allowed as separate entries. Lyrics are nullable text in `SONG.lyrics_text`; audio is stored by reference. Initialization does not seed sample data, and opening a newer schema is rejected rather than erasing it. Future schema upgrades require explicit versioned migrations.

Mobile uses the native sqflite factory and `cta2000.db` in the application database directory. Browser development uses the same repository API with SQLite WASM/IndexedDB and a separate `cta2000-development.db`. Browser data belongs to its origin and can be removed by browser storage clearing; changing the local port creates a different origin. Keep `web/sqlite3.wasm` and `web/sqflite_sw.js` with the project. To regenerate them after dependency changes, run `dart run sqflite_common_ffi_web:setup` and repeat browser verification.

### HTTP, configuration, and trust

`JsonHttpClient` performs real JSON HTTP requests with an injectable `http.Client`, configurable base URI (including host/IP, port, and API prefix), relative endpoint paths, query parameters, headers, and timeout (10 seconds by default). `probe()` requires a configured probe path. Failures distinguish configuration, transport, timeout, cancellation, response status, and malformed JSON. Redirects are rejected; commands are not automatically retried. Requests use `AbortableRequest`; a separate cancellation/timeout race also handles clients that ignore cancellation.

The app composition root (`AppDependencies`) opens local storage independently of networking. Build-time `DEVICE_BASE_URL`, `DEVICE_PROBE_PATH`, and `DEVICE_LOCAL_DEVELOPMENT` configure an optional HTTP client; there is no default device address or assumed hardware API. HTTP reachability never establishes hardware authentication. Invalid HTTP configuration disables that client and displays a warning while local storage still initializes. Database initialization failure preserves the navigation shell with an error banner, without resetting saved data.

HTTPS is required for device targets. Explicit local development can use plain HTTP only at localhost/loopback; authorization and cookie headers are rejected there. Never pass device secrets to test servers. Generic probe/client behavior is implemented now; authenticated Radxa endpoint mappings and identity verification are deliberately unavailable.

`PairingService` orchestrates six-digit-passkey bonding/provisioning and verifies both identity and phone authorization before saving trust. Only test constructors currently accept those adapters. Exactly one device can be remembered, and a different device requires forgetting the existing record first. Cleanup failures are reported, and reconnection requires matching settings and credential records.

`MobileDeviceSettingsStore` uses app preferences for non-secret settings. `MobileCredentialStore` delegates credentials and pinned identity material to native secure storage. Both reject browser and unsupported desktop use. iOS Keychain entitlements and a local-network usage description are configured, but native signing, Keychain behavior, and Android/iOS persistence have not been validated on this Windows host. Android scaffolding is not added in this increment.

`ConnectionManager` prefers authenticated Wi-Fi, with BLE fallback only for supported commands after transient Wi-Fi failures. Identity/authorization failures are terminal; large transfers cannot use BLE. Reconnection means **one initial attempt plus up to three retries**, waiting **1, 2, and 4 seconds**. Cancellation, disposal, and superseding reconnects prevent stale completions from changing state. Local forgetting disconnects and clears records; it does not claim remote trust revocation or OS bond removal.

Production composition has no BLE/provisioning, identity-verification, or authorization adapter. Production pairing and authenticated connections therefore remain unavailable, even when a local HTTP probe succeeds. Test sessions are always labeled `testOnly`, and `hardwareAuthenticated` stays false. Test adapters are located under `test/` and never imported into production. There is no production capability flag to promote mocks into hardware authentication.

### Reproducing verification

```powershell
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze --no-pub
flutter test --no-pub
flutter build web --no-pub
flutter build web --no-pub --target test/browser/persistence_probe.dart --output build/browser-verification
flutter build web --no-pub --target lib/frontend/development/local_playback_harness.dart --output build/audio-development
node test/browser/verify.cjs
git diff --check
```

The browser runner requires Node 22+ and Chrome. Set `CHROME_PATH` if Chrome is installed elsewhere. It starts isolated servers on ports 52842 (persistence), 52843 (production), and 52844 (development audio harness) and an isolated headless Chrome profile. It writes all four entities and lyrics through the shared repository, verifies close/reopen, reloads at the same origin and requires restored data, checks browser HTTP and mobile-trust isolation, then verifies the production Library launches without an initialization error. Increment 4 also checks the empty-catalog harness stays idle and displays Awaiting MP3 File. It cleans its test database, browser, and servers. Host-side SQLite tests are separate and do not substitute for this browser check. This runner does not verify real audio playback.

For an interactive test-only HTTP server, run `node test/support/http_server.cjs`. It exposes `GET /health` and `POST /echo` on `127.0.0.1:8765`; these are fixture endpoints, not a promised Radxa protocol. Configure `MOCK_PORT` and `MOCK_ORIGIN` if necessary. For example, `flutter run -d chrome --web-port=52841 --dart-define=DEVICE_BASE_URL=http://127.0.0.1:8765 --dart-define=DEVICE_PROBE_PATH=health --dart-define=DEVICE_LOCAL_DEVELOPMENT=true` composes the development HTTP client. Calling it remains a backend-service operation; wiring device controls into the screens belongs to later integration. Automated request behavior is demonstrated by `flutter test --no-pub test/http_networking_test.dart`.

Mobile secure-storage tests in this increment mock the platform channel or preferences API. They validate adapter behavior and secret separation, not actual OS encryption, persistence, bonding, or hardware authorization. Real BLE, identity provisioning, secure reconnection, and device commands require later native/hardware tests.

### Increment 2 verification results — November 17, 2026

| Check | Actual result |
| --- | --- |
| Dependency resolution and SQLite browser asset setup | Passed |
| Dart format check | Passed; 28 Dart files, no changes needed |
| `flutter analyze --no-pub` | Passed; no issues |
| `flutter test --no-pub --reporter expanded` | Passed; 48 tests (SQLite/models, real loopback HTTP, device workflows, mocked mobile storage contracts, and all 17 screens) |
| `flutter build web --no-pub` | Passed |
| Browser harness web build | Passed |
| `node test/browser/verify.cjs` | Passed in real Chrome; all four entities and lyrics restored after close/reopen AND same-origin reload at `http://127.0.0.1:52842` |
| Browser HTTP and trust separation | Passed; HTTP requests succeeded, mobile trust stores remained unavailable, hardware authentication stayed false |
| Production app startup in Chrome | Passed; Library rendered without initialization error |
| JavaScript syntax checks | Passed for the browser runner and development HTTP fixture |
| Standalone development HTTP fixture | Passed; health, JSON echo, and unknown-endpoint 404 checked on loopback |
| iOS configuration XML parsing | Passed; syntax only, not an iOS build or signing test |
| Existing screens/routes/theme/controller source comparison | Unchanged |
| `git diff --check` | Passed |
| Native Android/iOS secure storage, signing, OS bonding, BLE, Radxa identity/authentication | Not validated on this Windows host; production pairing and authenticated hardware connection remain unavailable |

Suggested commit message: `feat: add SQLite persistence and device networking foundations`.

Stop after this increment for owner review and manual commit/push. Increment 3 is not started.

## Increment 3 — Controllers and business logic

The shared `MusicController<T>` base extends `ChangeNotifier`. Each controller exposes an immutable `state` containing `data`, `status` (`idle`, `loading`, `success`, `empty`, or `error`), and an optional typed `ControllerFailure`. Async methods also throw failures to their callers: validation, not-found, storage, unavailable, or disposed. Callers must await/catch those futures. Collections exposed by controller data are unmodifiable.

`AppDependencies` owns the five controllers and disposes them before closing the database. Controllers reuse the same `LocalMusicRepository`; all SQL remains in database services. The existing frontend remains unchanged; controller-to-screen binding belongs to Increment 7.

### Controller operations

- `LibraryController`: `loadCachedSongs`, local-only `refreshLibrary`, `loadSong`, cached `search`, `sortBy`, `updateMetadata`, and `removeSong`. Search matches title/artist case-insensitively. Title/artist sorts are ascending, date-added is newest-first, and ties use song ID. `SongMetadataUpdate` distinguishes omitted artwork from `clearArtwork`; identity, file reference, date added, and lyrics are preserved. Titles/names are trimmed and cannot be blank. Blank artist text remains allowed by the existing schema. No song importing or audio-file deletion is performed.
- `PlaylistController`: `createPlaylist`, `loadPlaylists`, `showPlaylist`, `renamePlaylist`, `updateDescription`, `deletePlaylist`, `addSong`, `removeEntry`, and `reorder`. `showPlaylist` exposes ordered entries and corresponding songs through its state. Duplicate occurrences retain distinct entry IDs. New songs append; reorder uses a zero-based final index. Description null clears it. Mutations preserve playlist creation dates and update modification timestamps.
- `LyricsController`: `loadManualLyrics`, `saveManualLyrics`, and `clearManualLyrics`. A valid song with null lyrics differs from a missing song. Empty strings, leading/trailing whitespace, multiline text, punctuation, and Unicode are preserved exactly; clear writes null.
- `StatisticsController`: `load` provides global counted plays, exact `Duration`, top tracks, recent history, and optional song-level statistics. `rangeFor` resolves all-time, explicit dates, and current calendar week/month/year. Weeks start Monday. Local calendar boundaries are calculated before conversion to UTC; ranges are inclusive-start/exclusive-end and use session `startedAt`. Sessions are not prorated across boundaries. Only `countedPlay` contributes to play counts; all included `listenedMs` contributes to duration, including uncounted sessions. Top tracks omit zero-play songs and sort by count descending then song ID ascending. Recent history defaults to 20, uses a positive supplied limit, and sorts by start descending then history ID ascending. Existing songs with no history return zeros. No history or play thresholds are generated.
- `PlaybackController`: `setQueue`, `selectSong`, `selectAt`, `clearQueue`, `next`, and `previous` manage selection only. Duplicate occurrences are preserved, next/previous wrap, a single-track queue stays selected, and an empty queue has no selection. Navigation revalidates the chosen song and reports not-found without skipping missing tracks. `play`, `pause`, and `setVolume` report unavailable; `isPlaying` always remains false. No engine, audio package, seeking, decoding, position tracking, or listening-history generation is added.

### Transactions and asynchronous safety

Song deletion, its cascades, normalization of every affected playlist to contiguous positions, and affected timestamps execute inside **one SQLite transaction**. A failure anywhere rolls back all changes. Physical audio files are never accessed. Playlist addition, occurrence removal, and reordering also use transactions and normalize positions. The schema and its version remain unchanged.

Each controller serializes its submitted writes. Reads submitted after those writes wait for their completion. Every stateful request gets a generation token; late success or error cannot overwrite a newer state, and disposed controllers cannot notify listeners. Queued writes cannot start after disposal. Already-running transactions may finish atomically, but their late results cannot publish state. Cached search/sort and queue clearing supersede pending loads; refresh again when new data is needed after a cached-only action. Independently cached controllers observe another controller's changes through explicit refresh, without an event bus.

Clocks and identifier factories are injectable for tests. Production playlist/entry IDs use 128 bits from Dart secure randomness; no dependencies were added. Invalid IDs, names, positions, durations, ranges, and references are rejected. Repository failures are surfaced rather than silently swallowed.

### Increment 3 verification — November 17, 2026

| Check | Actual result |
| --- | --- |
| `flutter analyze` | Passed; no issues |
| `flutter test --reporter expanded` | Passed; all 98 tests |
| Dart formatting check | Passed; 39 files, no changes needed |
| `git diff --check` | Passed |
| Controller SQL audit | Passed; queries remain in repository services |
| Controller/database integration | Passed; isolated SQLite, file preservation, exact lyrics reopen persistence, stats and queue behavior |
| Forced transaction failures | Passed; song deletion/cascades/all affected playlists roll back together; reorder rollback also verified |
| Controller lifecycle tests | Passed; deferred success/failure after disposal or newer requests tested for every controller, plus queued-write disposal |
| `flutter build web` | Passed |
| Browser harness build and `node test/browser/verify.cjs` | Passed in real Chrome; controller results restored after close/reopen and same-origin page reload, queue wrap verified |
| Browser HTTP/trust checks and production startup | Passed; mobile trust unavailable, hardware authentication false, Library launches |
| Protected frontend, schema, original models, and networking comparison | Unchanged |

Reproduce controller tests with `flutter test test/music_controllers_test.dart test/statistics_controller_test.dart test/controller_lifecycle_test.dart`. Run the full verification sequence above, including rebuilding the browser probe and running `node test/browser/verify.cjs`. Tests use isolated databases and test-only metadata, never production music data. Full file inventory and verification details are in `doc/Increment3-report.md`.

Native mobile builds, OS secure storage, and real hardware are not newly validated by this increment. Importing and audio playback remain deferred to Increment 4 and later; frontend integration remains deferred. No new screens, route changes, theme changes, networking behavior changes, schema changes, or hardware operations were introduced.

Suggested commit message: `feat: implement music management controllers and business logic`.

Stop after Increment 3 for owner review and manual commit/push. Do not begin Increment 4 without explicit authorization.

## Increment 4 — Local MP3 playback (Partial)

Local audio support and queue integration are implemented and tested with injected doubles. **Real MP3 playback: Not Tested — Awaiting MP3 File.** There is no MP3 fixture in the project; no audio was generated, downloaded, converted, or modified. Earlier increment sections describe their historical behavior; the policies below describe the current playback API.

`LocalAudioService` implements an injectable `AudioService`, resolves a Song's explicit source, and lazily owns one `JustAudioEngine`. The adapter delegates decoding, position, duration, processing states, completion, and errors to [just_audio](https://pub.dev/packages/just_audio) 0.10.6. [audio_session](https://pub.dev/packages/audio_session) 0.2.4 configures a music session on Android/iOS; just_audio retains its interruption handling. Both installed packages require Dart ^3.6.0 and Flutter >=3.27.0, compatible with the verified Flutter 3.47.2 / Dart 3.13.2 toolchain. No background audio, lock-screen integration, remote streaming, or desktop-native audio adapter is added. Web compilation passed; native playback and interruption behavior still require platform tests.

`AppDependencies` injects the local service into the existing `PlaybackController` and awaits its disposal before closing SQLite. Tests can inject the entire service or its engine/resolver, and metadata-only queue clients can explicitly use `enableLocalPlayback: false`. The UI calls controllers, never just_audio. The four database tables, fields, schema version, original 17 screens, routes, theme, and device services are preserved. Production screen binding remains deferred; only the separate development entry point exposes audio controls.

### Playback policy and state

- `setQueue` and `selectSong` replace the queue, stop prior playback, reset play intent, and prepare the selected song paused. `selectAt`, `next`, and `previous` preserve intent: a playing selection continues on the new occurrence; a paused selection remains paused. Duplicate occurrences and manual wraparound remain intact. Empty queues do not play. Missing records/sources fail explicitly without silently removing or skipping entries.
- `play`/`resume`, `pause`, `stop`, `seek`, and `setVolume` delegate to the engine. Stop resets progress and intent; a later play reloads the selected song. Replacing/clearing a queue stops its old source. Async controller calls return futures which callers must await and handle.
- Natural completion advances once per source session and wraps by default (`continuousPlayback: true`), including restarting a one-song queue. With continuous playback disabled, natural completion stops at the last occurrence; manual next/previous still wrap. Explicit stop and load failures never advance automatically.
- Immutable state separates requested play intent, engine `playing`, and processing (`idle`, `loading`, `ready`, `buffering`, `completed`, `error`). `isPlaying` requires a ready engine reporting playing with no error. Buffering may retain engine play intent without claiming audible playback. Ready/paused, position, known/unknown duration, queue index, and typed error are available to future views.
- Negative seeks and seeks without a known ready duration are rejected. Positions beyond duration clamp to the end; state reflects the engine's accepted position rather than an optimistic timer. Volume must be finite and in [0, 1]. Initialization/load timeouts bound pending operations; they do not simulate progress.
- Controller generations, serialized commands, source-session tags, stale-event filtering, and disposal guards protect rapid switching, pause during load, late failures, completion, and shutdown. No competing player is created for each track.
- `AudioFailure` distinguishes `missingSource`, `unsupportedSource`, `engineInitialization`, `playback`, `invalidPosition`, `invalidCatalog`, `cancelled`, and `disposed`. `PlaybackFailure` exposes the underlying audio error through controller state/caller failures. A missing asset differs from a missing platform plugin or session initialization failure.

Playback position and completion remain available as real engine events. No approved rule defines when a play counts, so this increment writes **no listening history**, introduces no threshold, and does not count mocked or development playback.

### Sources and development registration

SQLite stores references only in the existing `Song.filePath`; it never stores audio blobs. Bundled sources use `asset:///assets/audio/owner-test.mp3`. Future native local sources may use absolute `file:///...` URIs, with existence checking. Bare paths, remote URLs, traversal, and arbitrary browser file URIs are rejected; importing/browser file picking is outside this increment.

`assets/audio/` contains tracked documentation and `development_songs.json`, initially `[]`. The asset directory is registered in `pubspec.yaml`; actual audio remains ignored by Git. `DevelopmentAudioRegistrar` is disabled unless `--dart-define=ENABLE_DEVELOPMENT_AUDIO=true` is supplied. It validates stable IDs and paths, checks asset existence, skips/report missing files, and transactionally inserts only absent song IDs. Repeated registration preserves every existing metadata field, lyrics, and unrelated record. An edited catalog intentionally does not overwrite previously registered songs.

### Provide an MP3 and exercise the harness later

1. Place an owner-supplied, legitimately usable MP3 at `assets/audio/owner-test.mp3`. Do not move or convert the supplied WAVs. Actual MP3 files stay ignored.
2. Replace the empty catalog with the following entry (add a second distinct ID/path to test navigation). Keep each ID stable. `duration_ms: 0` means unknown stored metadata; the playback display uses engine duration.

   ```json
   [{
     "song_id": "dev-owner-test",
     "title": "My test track",
     "artist_name": "My artist",
     "asset_path": "assets/audio/owner-test.mp3",
     "duration_ms": 0
   }]
   ```

3. Fully restart/rebuild to refresh the asset bundle; hot reload alone is insufficient for a newly added asset. Run:

   ```powershell
   flutter run -d chrome -t lib/frontend/development/local_playback_harness.dart --web-port=52841 --dart-define=ENABLE_DEVELOPMENT_AUDIO=true
   ```

4. Click **Load queue**, then **Play** as a user interaction. Listen, confirm ready/playing and increasing position, pause/resume, enter a nonnegative seek in seconds, stop, and test next/previous and natural completion. Browser autoplay restrictions remain in force; rejected playback is an error, never success. Retest using a fresh click if the browser blocks playback. Check audio audibly yourself; rendered pages and ready flags alone cannot establish audibility.
5. With no registered fixtures, the harness says **Awaiting MP3 File**, keeps controls disabled, and initializes no audio engine. It is isolated from the 17 production screens and is not a replacement Now Playing screen.

The six untouched files `Music/01 Track 1.wav` through `Music/06 Track 6.wav` are stereo 16-bit PCM WAV at 44.1 kHz. This is a candidate format for the engine/browser's native decoding; actual decoding on this host was not exercised. They are outside the asset bundle and development catalog. Format/container support depends on each browser/OS backend; no WAV or MP3 compatibility across platforms is claimed without playback tests.

### Increment 4 verification — November 17, 2026

| Check | Actual result |
| --- | --- |
| Dart formatting check | Passed; 53 Dart files |
| `flutter analyze --no-pub` | Passed; no issues |
| `flutter test --no-pub --reporter expanded` | Passed; 127 tests, including all prior 98 tests |
| Production, development harness, persistence probe web builds | Passed |
| Existing browser verification in real Chrome | Passed; close/reopen and same-origin reload persistence, controllers, HTTP, mobile-trust isolation, production startup |
| Empty-catalog development harness in Chrome | Passed; Awaiting MP3 File, idle, no active playback |
| Protected source comparison, six WAV hashes, `git diff --check` | Passed; protected files/audio unchanged |
| MP3 load, actual engine ready, real play/pause, advancing position, seeking, completion, audible audio | **Not Tested — Awaiting MP3 File** |
| Android playback | **Not Tested — Awaiting MP3 File**; Android scaffolding/platform verification also unavailable |
| iOS playback | **Not Tested — Awaiting MP3 File**; native build/signing unavailable on this Windows host |

New tests distinguish eight audio-service tests with a scripted engine, three real adapter tests with a mocked package player, four catalog/SQLite integration tests, twelve playback-controller/SQLite tests, and two empty-catalog harness widget tests. They require no MP3 or generated audio. Run all checks using the reproduction commands above, or run the new audio suites with:

```powershell
flutter test --no-pub test/local_audio_service_test.dart test/just_audio_adapter_test.dart test/development_audio_registration_test.dart test/playback_audio_controller_test.dart test/local_playback_harness_test.dart
```

See [the full Increment 4 report](doc/Increment4-report.md) for the inventory, exact commands, acceptance matrix, and limitations. Local playback remains separate from Radxa commands: production pairing/authentication stays unavailable, and test adapters cannot establish hardware authentication. Music importing, recording, downloads, final frontend binding, and hardware operations are not part of this increment.

Remaining increments require separate authorization: 5 reviews device communication architecture, 6 implements approved screen layouts, 7 binds the application frontend, and 8 covers stabilization/demonstration. Real MP3 acceptance must still be completed when the owner provides a fixture.

Suggested commit message: `feat: implement local MP3 playback and queue integration`.

Stopped after Increment 4. No commit, push, or Increment 5 work was performed.

## Increment 5 — Device communication and integration preparation

Increment 5 adds the UML's `DeviceController` and `RadxaClient` responsibilities to the existing services. It is complete within the hardware-free preparation scope; it does **not** establish actual Radxa connectivity. See [the protocol contract](doc/device-protocol.md) and [the full increment report](doc/Increment5-report.md).

### MVC and public behavior

`DeviceController` extends the shared controller foundation and exposes `loadSavedDevice`, `scanForDevices`, `pairWithCode`, `connect`, `autoReconnect`, `disconnect`, `refreshDeviceInfo`, `readCapabilities`, `forgetDevice`, and `updateConnectionSettings`. Headphone selection is explicitly unsupported; headphone audio is separate from BLE control. No frontend screen is wired to these APIs in this increment.

Immutable `DeviceData` distinguishes no trusted device, discovered/untrusted, pairing, saved trust, connecting, authenticated, disconnected, reconnecting, forgetting, error, and unavailable. Test connections use a separate `testConnected` phase and always retain `hardwareAuthenticated: false`. A saved summary contains only device ID, HTTPS endpoint, reconnect preference, and provenance—not passkeys, credentials, or pinned material. Device telemetry stays null until received; no battery/storage defaults are fabricated.

`RadxaClient` prepares typed remote playback, recording, file-list/removal, and download-job contracts over the existing `ConnectionManager`/`DeviceTransport`. Commands require an authorized session, advertised capability, and transport support. Status/capability reads bootstrap capabilities only within that session. Old concurrent responses cannot widen newer capability results. Production client constructors reject test sessions. Actual transfer methods remain unavailable, and bulk transfer requires authenticated Wi-Fi; no file is read, written, or transferred by these contracts.

`AppDependencies` owns the new controller/client, loads saved metadata without requiring connectivity, contains device initialization failures, and awaits pairing cleanup on shutdown. Offline SQLite/music management remains independent. The original 17 screens, routes, Midnight Crimson theme, four-table schema/models, local audio service, and PlaybackController source are unchanged.

### Trust, cancellation, and reconnection

Production discovery, pairing, identity verification, provisioning, authenticated connection, and protected commands remain unavailable. Test adapters are confined to test support and never imported into production. A reachable HTTP endpoint, expected name/ID, OS bond, or mocked verifier cannot authenticate hardware.

Pairing now inspects an open, unexpired pairing window before secured provisioning and independent identity/authorization verification. Discovery hints/window observations do not establish trust. The UML's physical three-second hold, two-minute window, and six-digit OLED passkey are documented hardware requirements, not simulated device behavior. UUIDs, trust roots, credential schemes, and BLE/security protocols remain unspecified and unimplemented.

Generation/cancellation guards cover service and controller requests, commands, connection events, and disposal. New controller requests supersede pending connection/enrollment work. Forgetting can cancel pairing; it drains in-flight credential/settings writes and clears incomplete enrollment before reporting success. Cleanup failures are surfaced, and incomplete records do not grant trust. Local forgetting still does not claim remote revocation or native bond removal.

Connection retry policy remains **one initial attempt plus up to three retries after 1, 2, and 4 seconds**. Trust/configuration are revalidated before retries, accepting a session, and commands. Identity/authentication/authorization failures are terminal, invalidate cached capabilities, and cannot be cleared by metadata reload or HTTP reachability. No insecure BLE fallback is allowed. Authentication and command limits default to 10 seconds; supported adapters receive cancellation and late responses are rejected independently.

Submitted commands are never replayed automatically. A changing command whose response is lost or malformed may have `DeviceCommandFailure.outcomeUnknown: true`; callers must not assume it failed to execute or blindly resend it. Device errors distinguish authentication, authorization, identity, protocol, unsupported, unavailable, transient, storage, invalid input, and cancellation. Low-level `JsonHttpClient` behavior remains unchanged.

### Proposed protocol and testing boundaries

`DeviceProtocol` implements a **proposal v1** envelope with `protocol_version`, `request_id`, `operation`, and object `payload`. Responses must match version/ID and contain exactly one of `result`/`error`; operation results are typed and validated. Identifiers correlate replies, never prove identity. Candidate routes, device-side deduplication, credential handling, compatibility negotiation, and hardware acceptance requirements are documented in the protocol file as proposals or open decisions.

Real loopback HTTP tests exercise GET/POST, candidate JSON validation, 401/403 and other errors, malformed data, missing fields, interruptions, timeouts/cancellation, and blocked credential transmission. Candidate messages are nested as synthetic validation data; fixtures never execute protected commands or establish hardware authentication. Typed command orchestration uses separate explicit test transports. No Radxa server, Linux simulator, BLE plugin, general remote shell, music download, importing, recording, or sync workflow was added.

### Reproduce verification

Run the full formatting/analysis/test/build/browser sequence above, preparing all three web targets before `node test/browser/verify.cjs`. For the new suites:

```powershell
flutter test --no-pub test/device_controller_test.dart test/pairing_lifecycle_test.dart test/device_commands_test.dart test/device_connection_safety_test.dart test/device_protocol_http_test.dart
```

The browser runner preserves prior close/reopen and same-origin SQLite reload checks, HTTP, queue/controllers, mobile-trust isolation, production startup, and the Awaiting MP3 File harness. New assertions require `deviceControllerUnavailable`, `protectedCommandsUnavailable`, and `proposalCodecHttp` to be true before and after reload. These are hardware-free checks; browser storage does not establish mobile secure trust.

Final verification on November 17, 2026:

| Check | Actual result |
| --- | --- |
| Dart formatting | Passed; 63 files, no pending changes |
| `flutter analyze --no-pub` | Passed; no issues |
| `flutter test --no-pub --reporter expanded` | Passed; 188 tests (all 127 earlier tests plus 61 device tests) |
| Production, audio-development, and persistence-probe web builds | Passed |
| Real Chrome browser verification | Passed; same-origin reload persistence, device restrictions, proposal JSON/HTTP, production startup, awaiting-MP3 harness |
| `node --check test/browser/verify.cjs` and `git diff --check` | Passed |
| Protected source and original WAV comparison | Unchanged |

The full inventory and results are recorded in `doc/Increment5-report.md`. Native Android/iOS secure storage, pairing, pinned HTTPS/authentication, hardware telemetry/commands, recording, synchronization, and physical revocation remain unverified. Increment 4 remains **Partial — Awaiting MP3 File**, with real playback **Not Tested — Awaiting MP3 File**. No audio fixture was added or modified; all six original WAV hashes remain unchanged. One existing playback test now waits for its expected fake-engine state instead of a fixed number of event-loop turns; its assertions and production playback code are preserved.

Suggested commit message: `feat: prepare secure Radxa device communication integration`.

Stopped after Increment 5. No commit, push, or Increment 6 work was performed. Increment 6 requires owner review and explicit authorization.

## Increment 6 — Flutter frontend

All 17 approved destinations now use designed frontend pages instead of the Increment 1 placeholder content. The 22 reference PNGs were reviewed; the red/navy Library, Playlist Details, Add Music, and Midnight Crimson Now Playing variants determine styling. Other references supply their screen layouts, with the already-approved Midnight Crimson colors and four primary destinations retained. Green accents and legacy Search navigation are not reintroduced.

The owner chose to omit artist chat, Follow, merchandise, and video extras. Artwork/profile photos are not separate project assets, so the implementation uses neutral artwork frames and a music emblem rather than invented accounts or downloaded covers. Exact font metadata was not supplied; the existing bundled sans-serif foundation is retained. The full source-to-screen mapping, visual comparison notes, coverage, inventory, and results are in [Increment6-report.md](doc/Increment6-report.md).

### Presentation and navigation boundaries

Pages and reusable widgets live under `frontend/`. Shared components cover artwork, cards, status pills, search/category/sort controls, song rows, playback controls, meters, settings rows, dialogs, chart presentation, mini-player, and the four-tab navigation. `AppTheme.frontend` adds frontend component styling to the unchanged Midnight Crimson base; the existing audio harness still uses its original base theme.

`ScreenPresentation` is an immutable rendering input using existing Song, Playlist, statistics, recording, device-status, and remote-file DTOs where applicable. Its default is unconnected with no song/device/statistics. `PresentationMode` exposes unconnected, ready, loading, empty, error, and unavailable layouts. It does not fetch data, create domain controllers, or grant hardware capabilities. No page receives `AppDependencies` or calls a database/audio/device service. Live binding remains Increment 7.

Search input, category/sort choices, list/grid layout, sync-scope selection, period filters, form fields, and dialogs affect local presentation only. Sort/search choices do not execute duplicate music-management logic. Clipboard paste fills only the URL field; local URL syntax validation performs no network request. Draft saves validate and explicitly report unavailable persistence; they never apply a saved change. Cancel discards the draft. Root-tab UI state survives tab switches within the shell; app reload resets it. Actual imports, recording, playback, sync, settings changes, file operations, and trust removal remain unavailable.

Unknown values use unavailable labels or neutral meters, not invented telemetry/progress. Manual lyrics preserve multiline text without synchronized highlighting or line-to-audio seeking. The statistics selector follows the four reference periods; no custom-date UI was invented. Recording album/year/genre fields and folder names are presentation inputs only and do not change the approved database schema or imply implemented persistence.

Existing route names and NavigationController are preserved. Detail routes receive their originating shell context; tapping a primary tab returns to that shell and selects the destination without adding duplicate shells. Direct-entry detail routes replace their stack when selecting a primary destination. Back returns to the previous screen. Fullscreen Lyrics and Now Playing omit primary navigation; other pages share the mini-player and four tabs. The mini-player is navigational and never starts audio.

### Isolated visual gallery

Run the gallery independently:

```powershell
flutter run -d chrome -t lib/frontend/development/frontend_preview.dart --web-port=52845
```

The banner says **DESIGN PREVIEW · SAMPLE DATA · NO SERVICES**. Its menus select screens and presentation states. A direct gallery example is `http://localhost:52845/?screen=playlist&state=ready`; selectors use AppScreen enum names and PresentationMode names. Sample songs, lyrics, telemetry, charts, folders and recording metadata exist only in this separate entry point/test fixtures. No SQLite, networking, pairing, audio engine, or real audio file is initialized. The production app has no route or flag enabling these fixtures.

### Verification and visual review

Run the established checks plus the gallery build and screenshot runner:

```powershell
dart format --output=none --set-exit-if-changed lib test
flutter analyze --no-pub
flutter test --no-pub --reporter expanded
flutter build web --no-pub
flutter build web --no-pub --target lib/frontend/development/local_playback_harness.dart --output build/audio-development
flutter build web --no-pub --target test/browser/persistence_probe.dart --output build/browser-verification
flutter build web --no-pub --target lib/frontend/development/frontend_preview.dart --output build/frontend-preview
node --check test/browser/verify.cjs
node --check test/browser/visual_verify.cjs
node test/browser/verify.cjs
node test/browser/visual_verify.cjs
git diff --check
```

The visual runner requires Node 22+ and Chrome (`CHROME_PATH` supported). It captures all 17 production screens and 17 populated previews at 390 × 844, including successive scroll positions. It writes screenshots, a manifest mapping screens to wireframes, and a review index to ignored `build/increment6-visual/`. Capturing images is distinct from visual inspection; see the report for actual inspection findings and accepted differences.

Increment 6 verification completed on November 17, 2026:

| Check | Actual result |
| --- | --- |
| Formatting and analysis | Passed; 76 formatted files, zero changes; no analysis issues |
| Full Flutter test suite | Passed; 217 tests, including all 188 existing tests |
| Production, frontend-preview, audio-harness, and persistence-probe web builds | Passed |
| Existing real-Chrome browser verification | Passed; same-origin reload persistence, controller/HTTP/security checks, production startup, idle audio harness |
| Frontend browser capture and visual review | 34 screen sets, 86 frames; all 17 production and 17 preview top views plus selected lower sections inspected against references |
| Both browser-script syntax checks and `git diff --check` | Passed |
| Protected source and six original WAV hashes | Unchanged |

Increment 6 is complete within its presentation-only scope. Visual comparison is qualitative rather than pixel-exact; accepted artwork, unavailable-value, manual-lyrics, and responsive differences are documented in the report. Native builds, platform screen readers, real hardware, and real MP3 acceptance are not claimed.

Responsive tests cover 320/390/430 px at normal and 200% text, populated and unconnected states, scrollable dialogs, and keyboard-open lyric/recording forms. Text scaling stays enabled. Important controls remain reachable; the mini-player is hidden while the keyboard is open. Icon controls have labels/tooltips and 48 px targets; forms expose validation feedback. Automated semantics-label, Android touch-target, and text-contrast guidelines are checked on the Library; this is not a native screen-reader certification.

Increment 4 remains **Partial — Awaiting MP3 File**; actual playback stays **Not Tested — Awaiting MP3 File**. Increment 5 production authentication and hardware commands remain unavailable. Backend code, schema, models, entry points, dependencies, MP3 configuration, and the audio harness are preserved. No audio was generated, downloaded, converted, renamed, or changed.

Suggested commit message: `feat: implement approved Flutter frontend wireframes`.

Stopped after Increment 6. No commit, push, or Increment 7 work was performed.

## Increment 7 — Full application integration

The production screens now use the controllers owned by AppDependencies. Library search/sort/refresh, playlist creation and occurrence-based editing/reordering/removal, exact manual lyrics saving/clearing, shared playback controls/queue/mini-player, and persisted listening statistics are connected. All 17 routes, four primary tabs, origin-aware navigation, MVC, SQLite schema, and Midnight Crimson styling are preserved.

See [the complete Increment 7 report](doc/Increment7-report.md) for the file inventory, screen integration matrix, actual verification outcomes, limitations, and manual steps.

### Working offline behavior

- A fresh database shows an empty library; production does not seed fixtures. Existing registered songs and playlists load from SQLite. Search and sort use LibraryController. Recents and Date added both mean the existing newest-first ordering.
- Playlists support creation, rename, description editing/clearing, addition of existing songs, duplicate occurrences, removal by entry ID, drag/up/down reorder, and deletion without removing songs. A partial two-field edit explicitly identifies a committed rename and a failed description save rather than claiming an atomic edit.
- Lyrics preserve exact multiline Unicode and whitespace. Empty text is saved as empty text; explicit Clear saves null. Forms retain failed drafts, prevent double submission, and close only after successful persistence. Cancel before submission discards edits.
- Confirmed song deletion uses the existing atomic database operation and preserves physical audio. An affected playback queue is subsequently stopped/cleared. **A later playback-cleanup failure is reported separately and never presented as a database rollback.**
- Song taps select the visible-library or ordered-playlist queue and open Now Playing without autoplay on queue replacement. Explicit playlist Play requests playback after selection succeeds. Queue sheets preserve duplicate indexes; all transport/timing UI uses PlaybackController. Missing audio and initialization failures stay distinct. No listening history is generated.
- Statistics uses actual saved history and the existing four calendar periods. Counts and exact listening duration remain controller results. The chart is explicitly limited to the latest up to 20 returned sessions; it is not a complete period series. Unsupported artist ranking, streaks, and export remain unavailable.

### Device and development boundaries

Device views distinguish saved trust, unavailable/disconnected/error states, and verified hardware. Test-only state cannot appear as authenticated hardware or supply verified telemetry. Supported local settings/forgetting and guarded connection/status actions forward to DeviceController; production discovery, pairing, identity verification, and authenticated communication remain unavailable. Local forgetting does not guarantee remote revocation or removal of OS Bluetooth bonding. Browser storage does not validate mobile secure trust.

Add Music URL drafts/paste and recording metadata drafts remain presentation-only. Imports, downloading/yt-dlp, recording, recording saves, synchronization, remote files, headset management, and unsupported hardware settings remain unavailable. Album/year/genre drafts do not alter the schema.

The isolated frontend gallery and original local-audio development harness remain separate. AppDependencies has an explicit test-only injection seam; production has no fixture/test-authentication activation flag. A browser-only integrated-app mode lives in the test target and uses a unique isolated database. It never seeds the normal application database.

### Reproduce integration verification

Use the complete formatting/analysis/test/four-build/browser sequence in the Increment 6 verification section above, adding:

```powershell
node --check test/browser/integrated_ui_verify.cjs
flutter test --no-pub --reporter expanded test/frontend_integration_test.dart
```

The full suite contains **248 tests**, retaining all 217 previous tests and adding 31 SQLite-backed integration cases. The browser runner now exercises actual playlist and lyrics forms and verifies persistence after reload at the same origin, along with persisted statistics, tabs, and device restrictions. The visual runner captures 17 production, 17 isolated gallery, and 17 SQLite-integrated test screens under ignored `build/increment7-visual/`; its third server uses port 52847. Actual results and qualitative inspection findings are recorded in the report.

Final Increment 7 verification on November 17, 2026:

| Check | Actual result |
| --- | --- |
| Formatting / analysis | Passed; 80 files, zero pending format changes; no analysis issues |
| Full Flutter suite | Passed; all 248 tests |
| All four established web builds | Passed |
| Real Chrome original persistence/security checks | Passed; seeded/restored at the same local origin |
| Real Chrome integrated UI | Passed; playlist create/rename/description clear/song addition, exact Unicode lyrics, persisted statistics, all four tabs, same-origin reload |
| Production fixture isolation / audio harness | Passed; fresh normal library empty, no fixture leakage; unchanged harness idle and Awaiting MP3 File |
| Rendered capture and qualitative review | 51 screen sets, 132 frames; all 17 integrated top views and selected lower/production/gallery sections inspected |
| Browser script syntax / `git diff --check` | Passed |
| Protected implementations and six WAV hashes | Unchanged |

One full test run timed out after large wall-clock gaps; its targeted rerun and final full 248-test run passed. Browser driver fixes for merged semantics and keyboard clearing are documented in the report. No failed or unexecuted check is counted as successful. Increment 7 is complete within its approved integration scope.

For a manual isolated fixture session, run the persistence-probe entry point on port 52842 and open `http://localhost:52842/?integrationApp=true&run=2026111707`. Preserve that exact origin for reloads. Only this test entry seeds two metadata-only songs/history rows. Add `&cleanup=true` afterwards to delete its isolated database. Existing production data and mobile device trust are separate.

Increment 4 remains **Partial — Awaiting MP3 File**. Real MP3 playback remains **Not Tested — Awaiting MP3 File**. Physical Radxa communication and native mobile/secure-storage acceptance remain unverified. No audio has been generated, downloaded, converted, renamed, or changed.

Suggested commit message: `feat: integrate Flutter frontend with application controllers`.

Stopped after Increment 7 implementation, verification, and reporting. No commit, push, or Increment 8 work was performed.
