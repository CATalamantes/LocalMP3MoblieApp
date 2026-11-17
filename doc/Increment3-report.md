# Increment 3 report — November 17, 2026

**Increment:** 3 — Controllers and Business Logic

**Status:** Complete within the approved scope.

**Implemented:**

- Library loading, search/sort, lookup, metadata updates, and atomic metadata deletion.
- Playlist creation, naming/descriptions, ordered membership, repeated occurrences, occurrence removal, and transactional reordering.
- Exact optional manual lyrics saving, editing, clearing, and reopen persistence.
- Counted plays, actual listening duration, top tracks, recent history, song-level statistics, and local calendar/custom periods.
- Queue selection and wraparound without active playback or fabricated history.
- Immutable ChangeNotifier state, typed failures, mutation serialization, generation guards, disposal protection, and application lifecycle composition.

**Files Created:**

```text
lib/backend/controllers/controller_state.dart
lib/backend/controllers/library_controller.dart
lib/backend/controllers/playlist_controller.dart
lib/backend/controllers/lyrics_controller.dart
lib/backend/controllers/statistics_controller.dart
lib/backend/controllers/playback_controller.dart
lib/backend/models/listening_statistics.dart
test/music_controllers_test.dart
test/statistics_controller_test.dart
test/controller_lifecycle_test.dart
test/support/controller_fixture.dart
doc/Increment3-report.md
```

**Files Modified:**

```text
lib/backend/app_dependencies.dart
lib/backend/services/database/local_music_repository.dart
test/browser/persistence_probe.dart
test/browser/verify.cjs
README.md
```

**Architecture Notes:**

The five new controllers extend a shared ChangeNotifier foundation and access the existing repository. SQL stays in database services; the existing four models, relational columns, schema version, frontend screens/routes/theme, and networking/security implementation remain unchanged. Listening-statistics result types are read-only data-transfer objects, not new database entities. No dependencies were added.

Deleting a song identifies its affected playlists, deletes the row with existing cascade behavior, normalizes remaining entry positions, and updates affected playlist timestamps in one SQLite transaction. No file operations occur in application song deletion. Playlist occurrence changes also use transactions. Failures are typed and returned both through state and thrown futures.

Every async publication checks disposal and request generation, including failures. Writes are serialized per controller. Queued work is rejected after disposal; active SQLite transactions may finish, but their results cannot overwrite newer state or notify disposed listeners. Other controllers refresh explicitly after cross-controller changes. Application dependency disposal includes all five controllers.

**Verification Results:**

| Command/check | Actual outcome |
| --- | --- |
| `flutter analyze` | Passed; no issues |
| `flutter test --reporter expanded` | Passed; all 98 tests |
| `dart format --output=none --set-exit-if-changed lib test` | Passed; 39 Dart files, no changes needed |
| `git diff --check` | Passed |
| Controller SQL audit | Passed; no SQL in controllers |
| `node --check test/browser/verify.cjs` | Passed |
| `flutter build web` | Passed; production build |
| `flutter build web --no-pub --target test/browser/persistence_probe.dart --output build/browser-verification` | Passed |
| `node test/browser/verify.cjs` | Passed in real headless Chrome |
| Protected frontend, original entities/schema, and networking comparison | Unchanged |

The suite includes the previous 48 tests, 15 controller/database workflow tests, 7 statistics tests, and 28 lifecycle/race tests. Each controller has explicit deferred success and failure coverage after disposal and superseding requests. A late success cannot clear a newer error. Cached search/queue clearing supersession and disposal of queued mutations are also verified.

Real SQLite fault-injection tests force normalization failure in the second affected playlist and confirm rollback of the song, cascaded playlist entries, listening history, earlier normalization, and timestamps. A physical file-preservation sentinel remains intact after successful deletion. Separate reorder rollback, exact Unicode/multiline lyrics after database reopening, and application controller composition/lifecycle tests pass.

Statistics tests cover counted versus uncounted sessions, exact millisecond totals, ID-based tie-breaking, empty/no-play results, half-open date ranges, recent-history limits, Monday weeks, month/year/leap-year boundaries, calendar construction around DST transition dates, invalid inputs, and foreign-key enforcement. These tests use the runtime's local timezone; they do not claim an exhaustive timezone matrix.

Chrome records `seeded` and then `restored` at the same origin (`http://127.0.0.1:52842`). It exercises controller-written metadata, playlist creation/rename/descriptions, duplicate occurrences/reorder/removal, song deletion/normalization, lyrics, statistics, queue wraparound, database reopening, and page reload persistence. Existing real browser HTTP and mobile-trust-isolation checks still pass. Production Library renders without an initialization error at port 52843. Verification uses isolated test databases/profile and cleans its temporary resources.

Initial formatting-related lint findings were fixed before the successful final analysis. No test failures were observed. Local logs are in ignored build artifacts `build/increment3-tests.log` and `build/increment3-browser.log`.

**Manual Verification:**

1. Run `flutter test test/music_controllers_test.dart test/statistics_controller_test.dart test/controller_lifecycle_test.dart` for the new controller integration and lifecycle cases.
2. Run formatting checks, `flutter analyze`, `flutter test`, and `flutter build web`.
3. Build the browser probe with the command above and run `node test/browser/verify.cjs`. Require both `controllers:true` and `queueWrap:true` on the seeded and restored results.
4. Run `flutter run -d chrome`; verify existing navigation. Screens intentionally remain placeholders until their frontend/integration increments.
5. Controller API details and defaults are documented in the README's Increment 3 section. All tests use isolated metadata, not production data.

**Known Limitations:**

- Actual playback, audio decoding/seeking, imports, hardware synchronization, and listening-history generation remain unavailable. Queue actions select songs only; `isPlaying` stays false.
- Final frontend binding is deferred to Increment 7. Controllers can be exercised independently through the tests now.
- Native Android/iOS builds, mobile persistence/security, Bluetooth bonding, and Radxa authentication were not executed or validated in this increment. Existing security restrictions remain in force.
- Calendar filters use the phone/runtime local timezone. Whole sessions are assigned by start time without duration prorating. Top tracks exclude zero counted plays, while all included listened milliseconds contribute to durations.
- A committed mutation may complete after it is superseded or disposed, but cannot publish stale state. Explicit refresh is required for caches held by another controller.

**Suggested Git Commit Message:** `feat: implement music management controllers and business logic`

**Next Increment:** 4 — Local MP3 Playback. Not started; requires owner review, manual commit/push, and explicit authorization.

Stopped after Increment 3. No commit or push was performed.
