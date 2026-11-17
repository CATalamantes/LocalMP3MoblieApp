# Increment 2 report — November 17, 2026

**Increment:** 2 — SQLite, HTTP Networking, and Device Trust Foundations

**Status:** Complete within the approved hardware-free scope.

**Implemented:**

- Approved four models and four-table SQLite schema, typed CRUD, relationships, transactions, nullable manual lyrics, version-1 initialization, and persistence.
- Shared repository code with separate mobile and browser database initialization. Browser persistence uses SQLite WASM/IndexedDB; native host tests use SQLite FFI.
- Real configurable JSON HTTP requests and probe, request cancellation, timeouts, typed errors, and local-server verification.
- Single-device pairing/reconnect orchestration and mobile preferences/secure-storage adapters. Production authentication remains unavailable; mock results are test-only.
- One initial reconnect attempt plus three retries delayed 1, 2, and 4 seconds. Security failures do not downgrade to BLE; large transfers cannot use BLE.
- App dependency composition, storage initialization independent of networking, honest startup error/warning banners, and documentation.

**Files Created:**

```text
lib/backend/app_dependencies.dart
lib/backend/models/music_models.dart
lib/backend/services/database/local_music_repository.dart
lib/backend/services/database/music_database.dart
lib/backend/services/database/platform_database.dart
lib/backend/services/database/platform_database_mobile.dart
lib/backend/services/database/platform_database_web.dart
lib/backend/services/device/connection_manager.dart
lib/backend/services/device/device_contracts.dart
lib/backend/services/device/json_http_client.dart
lib/backend/services/device/mobile_trust_storage.dart
lib/backend/services/device/pairing_service.dart
test/database_test.dart
test/device_workflow_test.dart
test/http_networking_test.dart
test/mobile_storage_adapter_test.dart
test/browser/persistence_probe.dart
test/browser/verify.cjs
test/support/device_fakes.dart
test/support/http_server.cjs
web/sqflite_sw.js
web/sqlite3.wasm
ios/Runner/Runner.entitlements
doc/Increment2-report.md
```

**Files Modified:**

```text
lib/main.dart
lib/app.dart
pubspec.yaml
pubspec.lock
test/navigation_test.dart
ios/Runner/Info.plist
ios/Runner.xcodeproj/project.pbxproj
README.md
```

**Architecture Notes:**

All application additions remain under `backend/` except entry-point composition in `main.dart` and `app.dart`. Existing frontend pages, routing, Midnight Crimson theme, and navigation controller are unchanged. SQL lives in database services and HTTP implementation lives in device services. Views do not execute SQL or implement networking. Models use the approved fields; no device/configuration table or audio-byte storage was introduced.

The composition root creates the real HTTP client when configured, but hardware authentication has no production adapter. Test constructors label their results `testOnly`; production constructors cannot consume test transport results. Mobile settings contain no credentials; credentials and identity material use native secure-storage APIs. Browser access to those stores is explicitly rejected. Local forgetting does not claim OS bond removal or remote authorization revocation.

**Verification Results:**

| Command/check | Actual outcome |
| --- | --- |
| `flutter pub get` | Passed |
| `dart run sqflite_common_ffi_web:setup` | Passed; generated SQLite browser assets |
| `dart format --output=none --set-exit-if-changed lib test` | Passed; 28 Dart files, no pending formatting changes |
| `flutter analyze --no-pub` | Passed; no issues |
| `flutter test --no-pub --reporter expanded` | Passed; all 48 tests |
| `flutter build web --no-pub` | Passed; `build/web` |
| `flutter build web --no-pub --target test/browser/persistence_probe.dart --output build/browser-verification` | Passed |
| `node test/browser/verify.cjs` | Passed in real Chrome |
| Standalone local HTTP fixture smoke test | Passed: health JSON, POST echo, unknown endpoint 404 |
| `node --check` on both JavaScript verification/server scripts | Passed |
| iOS plist/entitlements XML parsing | Passed; syntax only |
| Existing frontend/controller source comparison | Unchanged |
| `git diff --check` | Passed |

The 48 tests cover SQLite/models (8), device workflows (13), real loopback HTTP (7), mocked mobile adapter contracts (3), and navigation/layout/startup states (17). All 17 approved screens and detail return paths remain covered.

Chrome produced `seeded` on first load and `restored` after page reload at the same origin, `http://127.0.0.1:52842`. Both loads verified all four entities, lyrics, database close/reopen, real browser HTTP, unavailable browser access to mobile trust, and false hardware authentication. The production build then rendered Library at port 52843 without an initialization error. Test databases and browser/server processes were cleaned up.

Initial lint findings and a browser-harness URL configuration error were corrected before the successful final checks. The browser result above is independent of host-side FFI tests. Local logs are in ignored build artifacts, `build/increment2-tests.log` and `build/increment2-browser.log`.

**Manual Verification:**

1. Run the commands in the README's Increment 2 verification section.
2. Run `node test/browser/verify.cjs` after preparing both web builds. Confirm `seeded`, `restored`, and successful production app startup.
3. Run `flutter test --no-pub test/http_networking_test.dart` to reproduce real local HTTP requests and errors. Use `node test/support/http_server.cjs` for the documented interactive test fixture.
4. Run `flutter run -d chrome`; visit the approved screens and their detail/back paths. Music-management and device screens remain placeholders until their assigned integration increments.

**Known Limitations:**

- Android/iOS native builds, signing, on-device SQLite persistence, and actual secure-storage encryption/persistence were not tested on this Windows host. The storage adapter tests mock preferences or the native method channel.
- Production BLE/provisioning, pinned device identity verification, phone authorization, OS bonding, authenticated reconnection, and Radxa commands remain unavailable. Real HTTPS device/certificate behavior is not validated by loopback HTTP tests.
- Browser SQLite is development storage isolated by origin; clearing browser storage removes it. It is not mobile secure-device trust.
- Future schema migrations must be explicitly implemented. No prior application database existed to migrate in this increment.
- Song importing, playback, full music-management controllers, and UI data binding remain in later increments. No audio files were added, seeded, committed, or pushed.

**Suggested Git Commit Message:** `feat: add SQLite persistence and device networking foundations`

**Next Increment:** 3 — Controllers and Business Logic, only after owner review, manual push, and explicit authorization. No Increment 3 implementation was started.

Stopped after Increment 2. No commit or push was performed.
