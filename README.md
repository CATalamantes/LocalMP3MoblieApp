# MP3 Controller

Flutter/Dart companion application for a standalone Radxa MP3 player. Development follows MVC and one reviewed increment at a time.

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
    development/                    # Isolated local-playback verification entry point
  backend/
    app_dependencies.dart           # Service composition and lifecycle
    controllers/                    # Navigation, library, playlists, lyrics, statistics, queue
    models/                         # Approved entities and read-only statistics results
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
- `services/device/`: Real HTTP infrastructure, mobile trust-storage adapters, and testable pairing/reconnect orchestration (added to Increment 2 by owner direction). Real BLE/provisioning and hardware integration remain unavailable.

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
