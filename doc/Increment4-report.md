# Increment 4 report

**Increment:** 4 — Local MP3 Playback

**Status:** Partial

Implementation, simulated audio tests, SQLite integration, browser regression checks, and web builds passed. Real MP3 playback acceptance is **Not Tested — Awaiting MP3 File**. No MP3 exists in the supplied project, and the owner prohibited generating, downloading, converting, or modifying audio. Passing tests with doubles and successful compilation do not establish real decoding or audible playback.

Verification date: November 17, 2026. Host: Windows; Flutter 3.47.2 / Dart 3.13.2.

## Implemented

- Injectable `AudioService`, immutable snapshots, typed failures, and a lazy single-engine `LocalAudioService` under the existing backend organization.
- `JustAudioEngine` wraps just_audio for load, play, pause, stop, seek, volume, actual engine position/duration, processing, completion, error propagation, and disposal. Music audio-session configuration is applied on Android/iOS without adding background-playback features.
- Existing `PlaybackController` now combines its persisted-song-backed queue with local playback; the metadata-only constructor path and original queue test coverage are retained.
- Explicit asset/native-file source resolution without changing Song fields or SQLite. Browser file URIs, ambiguous paths, remote URLs, and traversal are rejected. Missing/unsupported sources are distinct from initialization/plugin failures.
- Opt-in, idempotent catalog registration through the existing repository. Missing assets are reported rather than registered; existing metadata/lyrics and unrelated records are preserved.
- Tracked `assets/audio/README.md` and empty `development_songs.json`, with Flutter asset registration. Actual audio stays ignored by the existing Git rules.
- An isolated development harness outside production routing, with user-initiated controls and actual state display. It stays idle with disabled controls when no fixture is registered.
- Unit/adapter/integration/widget coverage without any generated MP3, WAV, or other audio bytes; the real Chrome regression runner additionally checks the harness's honest missing-fixture state.

## Files created

```text
assets/audio/README.md
assets/audio/development_songs.json
lib/backend/services/audio/audio_service.dart
lib/backend/services/audio/audio_source_resolver.dart
lib/backend/services/audio/development_audio_registration.dart
lib/backend/services/audio/file_source_io.dart
lib/backend/services/audio/file_source_web.dart
lib/backend/services/audio/just_audio_engine.dart
lib/backend/services/audio/local_audio_service.dart
lib/frontend/development/local_playback_harness.dart
test/development_audio_registration_test.dart
test/just_audio_adapter_test.dart
test/local_audio_service_test.dart
test/local_playback_harness_test.dart
test/playback_audio_controller_test.dart
test/support/audio_fakes.dart
doc/Increment4-report.md
```

## Files modified

```text
README.md
lib/backend/app_dependencies.dart
lib/backend/controllers/controller_state.dart
lib/backend/controllers/playback_controller.dart
pubspec.yaml
pubspec.lock
test/browser/verify.cjs
test/music_controllers_test.dart
```

The existing composition test explicitly selects metadata-only playback. Its file-preservation sentinel now uses `.bin` rather than an MP3 filename, retaining the same preservation assertion without creating a placeholder MP3. No previous test coverage was removed. The common controller base adds overridable failure/state preparation and guarded event publication; other controllers retain their existing behavior.

## Architecture notes

### Packages and platform configuration

Selected [just_audio 0.10.6](https://pub.dev/packages/just_audio) and [audio_session 0.2.4](https://pub.dev/packages/audio_session). Their installed package manifests require Dart ^3.6.0 and Flutter >=3.27.0, compatible with this project's SDK. Dependency resolution, static analysis, and all three web builds succeeded. The lockfile records the resolved transitive dependencies; no state-management or unrelated framework was added.

The adapter configures `AudioSessionConfiguration.music()` on Android/iOS and retains just_audio's default interruption handling. Web relies on its browser audio backend. The package's play future lasts until pause/completion; the adapter observes failures without serializing all later commands behind that future. Old play-future failures cannot fail a new source, and callbacks after disposal are ignored.

No streaming/proxy, recording/microphone, background-audio, lock-screen, or network-security changes were introduced. Bundled local audio does not require remote streaming permissions. Existing iOS scaffolding remains; Android scaffolding is absent. Native compilation, interruptions, focus, codecs, and output routing remain unverified. Native Windows/Linux audio support was not added; Windows development uses Chrome.

### MVC and SQLite

Views invoke the existing controller; they never call the audio package. The controller owns selection, queue policy, playback intent, and published application state. Audio services own platform interaction; the package/native browser backend owns decoding. `AppDependencies` injects the audio service and awaits shutdown before closing the shared database. Tests can inject a service or an engine/source resolver. `enableLocalPlayback: false` preserves an explicit metadata-only capability.

Only the existing `Song.filePath` stores source references:

```text
asset:///assets/audio/owner-test.mp3   # Bundled Flutter asset
file:///absolute/native/path.mp3      # Future native local source
```

No audio blobs, extra entities, columns, migrations, or schema-version changes are introduced. The four approved tables and model fields remain unchanged. URI resolution is separate from future file importing; file picking, copying, and persistence permissions are not implemented.

The registrar reads the development catalog only when `ENABLE_DEVELOPMENT_AUDIO=true`. It validates entries, checks the asset manifest, and inserts absent stable song IDs inside a repository transaction. Reopening/re-registering does not overwrite user edits or lyrics, delete other songs, or duplicate rows. The checked-in catalog is empty and launches require no fixture. Invalid catalog content fails explicitly. Existing IDs remain untouched even if a later catalog changes their metadata.

### Queue and playback policy

- Queue replacement (`setQueue` or `selectSong`) stops prior audio, resets intent, and prepares the selected source paused. Clearing a queue clears selection/intent and stops its engine. A later play after stop reloads the selected source.
- Direct occurrence selection (`selectAt`), next, and previous preserve play intent. A playing queue continues with the selected occurrence; a paused queue prepares it without starting. Duplicate occurrences retain their queue indices. Manual next/previous wrap; a one-song queue stays on its sole occurrence.
- Records are reloaded from SQLite when selecting/playing. Missing database records or sources fail meaningfully; entries are not silently removed or skipped. Failed switches stop old audio rather than leaving the previous track running.
- Natural completion advances once per session. `continuousPlayback` defaults to true: end-of-queue wraps and a single track restarts. If false, natural completion at the last occurrence stops there, while manual navigation still wraps. Explicit stop and failed loads never trigger an automatic skip/retry loop.
- Playback state separates application play intent from the engine's `playing` flag and processing phase. `isPlaying` requires ready + engine playing + no error; buffering can retain intent without reporting ready playback. Position and actual/unknown duration come from engine events, not fabricated progress timers.
- Negative seek values, unknown duration, and non-ready seek states are rejected. Values beyond duration clamp to its end. The engine must accept a seek before its position is published. Volume must be finite and within [0, 1].
- Initialization and source-load timeouts are 10 and 20 seconds. These are operational limits, not playback timers. Commands serialize while generation/session checks prevent stale results, errors, progress, and completion from taking over newer state. Pause during loading clears intent immediately. Disposal prevents notifications, cancels subscriptions, and releases the single player.

`AudioFailureKind` includes `missingSource`, `unsupportedSource`, `engineInitialization`, `playback`, `invalidPosition`, `invalidCatalog`, `cancelled`, and `disposed`. `PlaybackFailure` retains the typed audio failure while following the shared controller contract: errors are published and returned through failed futures. Missing platform plugins during loading are initialization failures; decoder/play errors remain playback failures.

### Listening history and hardware boundary

No approved play-counting threshold is defined, so no listening-history writes or counted-play claims are added. Real position/completion events remain available for a future explicit policy. Tests and development playback never fabricate counted plays.

Local playback targets the current Flutter platform only. It does not send Radxa commands or establish device identity. Production pairing/authenticated connections remain unavailable pending real verification, authorization, and BLE/provisioning adapters. Existing HTTP cancellation, retries, mobile trust isolation, and networking security are unchanged; test-only adapters cannot establish production hardware authentication.

## Verification results

Final checks ran against the implementation in this report:

| Command/check | Actual outcome |
| --- | --- |
| `flutter pub get` | Passed; audio dependencies resolved |
| `dart format --output=none --set-exit-if-changed lib test` | Passed; 53 files, 0 changes in the final check |
| `flutter analyze --no-pub` | Passed; no issues |
| `flutter test --no-pub --reporter expanded` | Passed; all 127 tests |
| `flutter build web --no-pub` | Passed; production target in `build/web` |
| `flutter build web --no-pub --target lib/frontend/development/local_playback_harness.dart --output build/audio-development` | Passed |
| `flutter build web --no-pub --target test/browser/persistence_probe.dart --output build/browser-verification` | Passed |
| `node --check test/browser/verify.cjs` | Passed |
| `node test/browser/verify.cjs` | Passed in real headless Chrome; details below |
| `git diff --check` | Passed |
| Protected source comparison | Original frontend pages/widgets/routes/theme, database services/schema, model files, and device services unchanged |
| Existing audio preservation | All six WAV SHA-256 hashes match their pre-implementation hashes; no audio generated/downloaded/converted |
| Audio asset inventory/ignore checks | Only README and empty catalog in `assets/audio/`; representative MP3 and original WAV paths match existing ignore rules |

Flutter builds reported successful Wasm dry runs and font tree shaking. The executed builds/browser runs used the default web target; no separate Wasm runtime acceptance is claimed. SDK/cache access outside the workspace required the environment's elevated tool permission and succeeded.

The suite retains 98 prior tests and adds 29:

| Test boundary | New tests | What the passing result establishes |
| --- | --- | --- |
| Audio service with scripted engine | 8 | Command delegation, engine-event state, missing/unsupported sources before initialization, initialization versus decoder/play/plugin failures, seek acceptance/clamping, buffering, stale sessions, disposal |
| Real just_audio adapter with mocked package player | 3 | Package API/event mapping, nonblocking play future handling, stale rejected play future protection, typed package errors; no native engine or audio decoding |
| Development catalog with actual isolated SQLite | 4 | Explicit opt-in, stable/idempotent registration, reference consistency, missing files, invalid catalog, user metadata/lyrics and unrelated record preservation |
| PlaybackController with actual SQLite and fake engine | 12 | Existing queue semantics, duplicates, selection, replacement, pause/resume/stop, progress propagation, seek validation, rapid navigation, late events, natural/single-track completion, failures, empty queues, disposal |
| Empty-catalog harness widget tests | 2 | Awaiting-fixture message, disabled controls, zero player initialization, narrow 320/390 px layouts with enlarged text |

These are simulated audio tests even when SQLite and the adapter's implementation are real. They do not prove that a playable MP3 was loaded, rendered by the platform, or heard.

Chrome produced:

```text
FIRST LOAD: seeded, closeReopen=true, tables=4, lyrics=true,
            controllers=true, queueWrap=true, http=true,
            hardwareAuthenticated=false, mobileTrustUnavailable=true
SAME-ORIGIN RELOAD: restored, same passing values,
                    origin=http://127.0.0.1:52842
PRODUCTION APP: Library rendered without initialization error (port 52843)
DEVELOPMENT HARNESS: Awaiting MP3 File; idle, no active playback (port 52844)
REAL MP3 ACCEPTANCE: Not Tested — Awaiting MP3 File
```

The browser check uses real SQLite WASM/IndexedDB through the existing repository and controllers, then reloads the page at the same local origin. It preserves the prior HTTP/trust checks and cleans its isolated resources. It does not substitute host-side SQLite for browser persistence, and it makes no audio claim from page startup.

During development, test URI canonicalization, an asynchronous completion assertion, a package mock constructor, formatting/lint findings, and fake-async widget-test cleanup were corrected. A stalled test process was terminated and cleanup fixed before the successful full suite. No unresolved test failure remains. Local logs are ignored build artifacts `build/increment4-tests.log` and `build/increment4-browser.log`.

### Real playback acceptance matrix

| Required acceptance check | Actual outcome |
| --- | --- |
| MP3 asset loaded | **Not Tested — Awaiting MP3 File** |
| Real audio engine reached ready state | **Not Tested — Awaiting MP3 File** |
| Real play/pause commands succeeded | **Not Tested — Awaiting MP3 File** |
| Playback position advanced | **Not Tested — Awaiting MP3 File** |
| Seeking succeeded | **Not Tested — Awaiting MP3 File** |
| Natural completion observed | **Not Tested — Awaiting MP3 File** |
| Audio audibly verified | **Not Tested — Awaiting MP3 File** |
| Android playback verified | **Not Tested — Awaiting MP3 File**; Android target/platform checks also unavailable |
| iOS playback verified | **Not Tested — Awaiting MP3 File**; native build/signing unavailable on Windows |

## Manual verification

This is a future acceptance procedure; no audio has been supplied or exercised as part of this report.

1. Place an owner-supplied, legitimately usable MP3 at `assets/audio/owner-test.mp3`. Actual MP3s are ignored by Git. Leave the original WAVs unchanged.
2. Set `assets/audio/development_songs.json` to:

   ```json
   [{
     "song_id": "dev-owner-test",
     "title": "My test track",
     "artist_name": "My artist",
     "asset_path": "assets/audio/owner-test.mp3",
     "duration_ms": 0
   }]
   ```

   Keep IDs stable. Add another ID/path for multi-track acceptance. Duration zero is unknown catalog metadata; the display uses actual engine duration. Existing registered IDs are never overwritten; use a new stable ID for a different fixture.
3. Fully restart/rebuild to include the new asset, then run:

   ```powershell
   flutter run -d chrome -t lib/frontend/development/local_playback_harness.dart --web-port=52841 --dart-define=ENABLE_DEVELOPMENT_AUDIO=true
   ```

4. Choose the initial occurrence and click **Load queue**. Confirm ready, actual duration, and paused state. Click **Play** with a user gesture; hear audio and confirm ready/playing plus increasing position. Browser autoplay restrictions are preserved. If rejected, inspect the error and retry through a fresh user interaction; do not record success from intent alone.
5. Pause; confirm stopped progress. Resume from the same point. Enter a seek in seconds, click Seek, and confirm accepted position. Check negative rejection and end clamping. Stop; confirm idle/zero progress and silence. Play again, navigate next/previous, and select another starting occurrence by loading the queue again.
6. Let tracks complete naturally and confirm one advance, queue wrap, and single-track replay. Errors should be explicit without skipping indefinitely. Independently record audible acceptance, Chrome version/OS, fixture provenance, and native Android/iOS results when those platforms are available.
7. Without fixtures/registration the harness must remain Awaiting MP3 File with disabled controls. The production app's approved screen navigation remains separate.

For automated regression checks, use the reproduction sequence in README, rebuilding all three web targets before `node test/browser/verify.cjs`. Run the new suites independently with:

```powershell
flutter test --no-pub test/local_audio_service_test.dart test/just_audio_adapter_test.dart test/development_audio_registration_test.dart test/playback_audio_controller_test.dart test/local_playback_harness_test.dart
```

## Known limitations and preserved inputs

- Increment 4 remains Partial until real MP3 playback is verified. Browser harness startup, simulated completion, and successful compilation are not audible acceptance.
- The supplied WAVs remain at `Music/01 Track 1.wav` through `Music/06 Track 6.wav`, outside registered assets. Inspection identified stereo 16-bit PCM at 44.1 kHz, a candidate for native/browser decoding. Actual decoding was not attempted. Backend/browser/OS support must be tested independently; WAV support is not inferred to guarantee MP3 or cross-platform behavior.
- No audio was generated, downloaded, converted, renamed, overwritten, or deleted. Final SHA-256 hashes match the originals:

  | File | SHA-256 |
  | --- | --- |
  | `01 Track 1.wav` | `82ba513d9030b7a35129ab6d6c9e43bdc5706eb6d7041d15504a95ead39c7c04` |
  | `02 Track 2.wav` | `1f755f332339eedc8f8614428bc2f7bd0d5daae3de45d1823826cc439a7d62c2` |
  | `03 Track 3.wav` | `befd8b843dda6bec938393c7ff01b3d811c84843aa61e322596a720bbdecc993` |
  | `04 Track 4.wav` | `0b0539042f22d4ad5a623023891a9cc224d8ad5764c576a65e5a0bf33bc03845` |
  | `05 Track 5.wav` | `bf71597f4b393e647b41756c8fd70d9a3ad068ada4f53df9de940c654671b7ec` |
  | `06 Track 6.wav` | `79095be250fa6cce9251d121277b6c764ef5401eaab4f859b708d6212364b6c1` |

- Listening-history write policy awaits an owner-approved definition. Final Now Playing/library binding, imports, recording, downloads, physical playback, and BLE/provisioning are not implemented here.
- Existing browser development SQLite remains separate from mobile secure-device trust. Native storage, hardware authentication, and pairing are not newly validated or enabled.
- Later work, only after separate authorization: Increment 5 — Device Communication Architecture Review; Increment 6 — approved frontend layouts; Increment 7 — full frontend/controller/database integration; Increment 8 — testing, stabilization, and demonstration. None was started.

**Suggested Git Commit Message:** `feat: implement local MP3 playback and queue integration`

**Next Increment:** 5 — Device Communication Architecture Review. Requires owner review, manual commit/push, and explicit authorization.

Stopped after Increment 4. No commit or push was performed.
