# Increment 5 report

**Increment:** 5 — Device Communication & Integration Preparation

**Status:** Complete within the approved hardware-free scope.

This result covers Flutter architecture, test-only orchestration, proposal codec validation, real loopback HTTP, browser regression verification, and builds. Production discovery, pairing, authenticated connections, and protected device commands remain unavailable. No physical Radxa or native security acceptance is claimed. Increment 4 remains **Partial — Awaiting MP3 File**.

Verification date: November 17, 2026. Host: Windows, using the existing Flutter/Dart SDK and Chrome.

## Implemented

- `DeviceController` exposes sanitized saved trust, discovery, pairing, explicit/automatic connection, disconnect, device status/capabilities, configuration changes, local forgetting, loading/error/unavailable states, and safe shutdown.
- The UML's `RadxaClient` façade exposes typed remote playback, recording, file-list/removal, and download-job contracts over existing services. No phone-audio integration or physical command execution was added.
- Service-only device DTOs preserve nullable telemetry and test provenance without adding SQLite tables or changing existing models.
- Production and test constructors remain separate. A production client rejects test sessions; test orchestration never sets `hardwareAuthenticated` true. Controller test connections use `testConnected`, separate from authenticated hardware.
- Pairing gains discovery/window contracts, cancellation, expiry checks, generation guards, and serialized credential/settings writes and cleanup. Forgetting may cancel pairing, drains active writes, and cannot return success while an older credential write could restore trust.
- Connections revalidate trust/configuration before retries, accepting sessions, and dispatching commands. Reconnection retains the approved initial-plus-three 1/2/4-second retry policy and terminal security failures.
- Request-scoped command cancellation/timeouts, session rejection after security errors, capability-generation guards, no automatic replay, and explicit uncertain outcomes for changing commands with lost/malformed responses.
- Proposal v1 JSON envelopes and strict typed result validation, with real loopback validation/echo tests that execute no protected commands and transmit no credentials.
- Transfer progress/cancellation contracts and Wi-Fi requirements are prepared; actual upload/download remains unavailable and touches no files.
- Composition/lifecycle registration, enhanced real-browser assertions, README updates, and the protocol document.

## Files created

```text
lib/backend/controllers/device_controller.dart
lib/backend/models/device_models.dart
lib/backend/services/device/device_protocol.dart
lib/backend/services/device/radxa_client.dart
test/device_controller_test.dart
test/device_commands_test.dart
test/device_connection_safety_test.dart
test/device_protocol_http_test.dart
test/pairing_lifecycle_test.dart
test/support/device_integration_fixture.dart
doc/device-protocol.md
doc/Increment5-report.md
```

## Files modified

```text
README.md
lib/backend/app_dependencies.dart
lib/backend/services/device/connection_manager.dart
lib/backend/services/device/device_contracts.dart
lib/backend/services/device/pairing_service.dart
test/browser/persistence_probe.dart
test/browser/verify.cjs
test/playback_audio_controller_test.dart
test/support/device_fakes.dart
```

No dependency or platform-scaffolding change was needed. Existing fake adapter signatures were extended to accept cancellation and expose a test-only pairing window. No earlier test assertions or coverage were removed. The playback-test-only change replaces fixed event-loop settling with waiting for its expected fake-engine state; LocalAudioService and PlaybackController are unchanged.

## Architecture notes

The existing MVC organization is preserved: device DTOs model service data, DeviceController coordinates operations and publishes immutable state, RadxaClient provides a typed command façade, and existing services own transport/security/storage behavior. Views make no new networking calls and remain unbound to these components. Application code stays under frontend/backend except the established root entry points.

`AppDependencies` owns `device` and `radxa`. It loads saved metadata through the new controller and contains device-store/platform failures so SQLite and local music management remain available. It does not attempt a hardware connection during this initialization. Controller shutdown invalidates requests, detaches its listener, disposes the command client and connection manager, cancels pairing, and awaits pending trust-write cleanup before the application closes its remaining services/database.

Controller phases include no trust, discovered/untrusted, pairing, saved trust, connecting, authenticated, test-connected, disconnected, reconnecting, forgetting, error, and unavailable. Generic controller loading/error status remains available independently. Security errors stay sticky across reachability/events and metadata reload; an explicit successful verified connection or successful forgetting clears them. Credentials, passkeys, and pinned material never enter controller state.

New requests supersede pending controller connection/enrollment work. Generation/session guards cover success and failure publication, service events, status/capability caches, disconnect, forgetting, configuration changes, and disposal. A stale capability/status response cannot widen capabilities learned from a newer response. No late completion may notify a disposed controller or repopulate a forgotten device's telemetry.

The existing settings and credential stores retain their namespaces and responsibility split. Pairing requires an observed open/nonexpired window, secured provisioning, and an explicit independent identity/authorization verifier. Credentials are committed before the settings marker. An already-started storage write is not abandoned on cancellation: cleanup drains it and attempts both removals. Failed cleanup is reported; missing/mismatched/incomplete trust cannot authenticate. Forgetting is local only and does not claim native bond removal or remote revocation.

ConnectionManager still allows real transport doubles only through its test constructor. It makes one initial attempt and up to three transient-failure retries after 1/2/4 seconds; the existing deterministic timing test is preserved. Identity/authentication/authorization failures never retry or downgrade. A request timeout cancels that command rather than unrelated requests. The default authentication/command limit is 10 seconds. Neither a failed response nor reconnect automatically replays a command.

RadxaClient's operation allowlist prevents a general remote shell. Capabilities and transport support are checked before non-bootstrap commands. Received status corroborates an ID only inside an existing authorized session; JSON IDs/names do not create trust. Device-layer errors distinguish authentication/authorization/identity, protocol/unsupported/unavailable, transient/storage/invalid-input, and cancellation. Remote error body text is not exposed. HTTP 401/403 remain distinct, while the original generic HTTP client implementation is unchanged.

LocalAudioService remains separate from remote Radxa playback. No audio, recording, music import, Linux execution, download, full synchronization, or file transfer happens in this increment. Device file identifiers and download-job DTOs are tested contracts, not operational hardware workflows.

## Protocol decisions

The full contract is in [device-protocol.md](device-protocol.md).

| Classification | Decision |
| --- | --- |
| Confirmed | Single trusted device; independent identity and phone authorization; secure credential storage; HTTPS; authenticated small-command BLE fallback; Wi-Fi-only bulk transfer |
| Approved UML design, hardware unverified | Three-second physical button hold, two-minute window, temporary six-digit OLED passkey, authenticated LE Secure Connections |
| Implemented proposal codec | Integer `protocol_version: 1`, request ID, operation allowlist, object payload, matching response ID/version, exactly one result/error, typed result parsing |
| Documentation-only proposal | Candidate `/v1/commands` and `/v1/status` routes, server-side deduplication and future compatibility negotiation |
| Undecided/unimplemented | BLE UUIDs/advertisements/characteristics; discovery identity binding; trusted root and pin verification; credential scheme, rotation, authorization/revocation; transfer framing/integrity; actual Linux service |

Executable loopback fixtures accept candidate messages as nested synthetic data and validate/echo them. They do not interpret the operation or execute protected commands, even when a proposed playback/recording operation appears in the nested data. Separate test transports exercise authorized command orchestration, always marked test-only.

UML differences are documented explicitly. The owner-authorized Increment 4 local playback capability supersedes the diagram's Radxa-only playback note. Concrete WiFiTransport/BluetoothTransport, SyncService workflows, headphone audio management, and remote trust revocation remain future integrations. Existing transport/security interfaces are reused instead of creating nominal fake production classes. No server is claimed to exist on the Radxa.

## Verification results

| Command/check | Actual outcome |
| --- | --- |
| `dart format --output=none --set-exit-if-changed lib test` | Passed; 63 Dart files, 0 changes |
| `flutter analyze --no-pub` | Passed; no issues |
| `flutter test --no-pub --reporter expanded` | Passed; all **188 tests**, no skips |
| `flutter build web --no-pub` | Passed; production app |
| `flutter build web --no-pub --target lib/frontend/development/local_playback_harness.dart --output build/audio-development` | Passed |
| `flutter build web --no-pub --target test/browser/persistence_probe.dart --output build/browser-verification` | Passed |
| `node --check test/browser/verify.cjs` | Passed |
| `node test/browser/verify.cjs` | Passed in real headless Chrome |
| `git diff --check` | Passed |
| Protected source comparison | Existing frontend, local audio services/controller, shared controller base, database/schema/models, dependency manifests, and mobile secure-store/HTTP implementation unchanged |
| Original audio preservation | All six WAV hashes match Increment 4's recorded originals; no audio fixture added or altered |

The suite retains all 127 earlier tests and adds 61:

| Suite | Tests | Coverage |
| --- | --- | --- |
| DeviceController | 16 | Initial/saved/discovered trust, test-only enrollment/connect, unavailable production, nullable telemetry, disconnect/forget, terminal security errors, configuration, request supersession, late responses, disposal |
| Pairing lifecycle | 14 | Discovery/window rejection/expiry, verified enrollment, mismatched identity, cancellation, credential/settings commit races, disposal, cleanup failures, safe settings updates |
| Device commands | 15 | Authentication/provenance gates, capability/transport checks, typed routing/results, arguments, remote contracts, uncertain outcomes/no replay, stale capability responses, security rejection, transfer restrictions, disposal |
| Connection safety | 5 | Transient recovery/delays, trust removal while retrying, endpoint changes during authentication, changed credentials before sending, hung-command timeout/cancellation |
| Real loopback HTTP/proposal | 11 | Actual GET/POST and JSON, 401/403/404/501/503, malformed/missing data, telemetry/type validation, allowlist/errors, interrupted connection, timeout/cancellation, insecure credential rejection |

Earlier suites still cover one-device restriction, verification/storage failure rollback, exact fake-clock retry timing/exhaustion, forbidden fallback, mobile storage adapter contracts, real SQLite/browser persistence, lyrics/playlists/statistics, local playback with doubles, and all 17 screens/detail return paths.

Chrome produced these results on both initial load and same-origin reload at `http://127.0.0.1:52842`:

```text
initial status=seeded; reload status=restored
closeReopen=true; tables=4; lyrics=true; controllers=true; queueWrap=true
http=true; hardwareAuthenticated=false; mobileTrustUnavailable=true
deviceControllerUnavailable=true; protectedCommandsUnavailable=true
proposalCodecHttp=true
PRODUCTION APP: Library rendered without initialization error (port 52843)
DEVELOPMENT HARNESS: Awaiting MP3 File; idle, no active playback (port 52844)
REAL MP3 ACCEPTANCE: Not Tested — Awaiting MP3 File
```

Browser persistence used real SQLite WASM/IndexedDB through the shared repository, not host-side SQLite as a substitute. Its HTTP/candidate codec checks never establish mobile trust. The isolated profile/database/server resources are cleaned up by the runner.

During implementation, static-analysis/style findings and a new test helper's declaration ordering were corrected. The first expanded full suite exposed an existing single-track-completion test that asserted after a fixed number of event-loop turns; its synchronization was fixed without changing assertions or production playback. The final full suite passes with no unresolved failure. SDK/cache access outside the workspace required elevated tool permission and succeeded. Builds performed successful Wasm dry runs; no separate Wasm runtime or native build is claimed.

Ignored local logs: `build/increment5-tests.log`, `build/increment5-device-tests.log`, `build/increment5-browser.log`. No generated build artifact is included in the change inventory.

## Manual verification

Reproduce the complete checks:

```powershell
dart format --output=none --set-exit-if-changed lib test
flutter analyze --no-pub
flutter test --no-pub --reporter expanded
flutter build web --no-pub
flutter build web --no-pub --target lib/frontend/development/local_playback_harness.dart --output build/audio-development
flutter build web --no-pub --target test/browser/persistence_probe.dart --output build/browser-verification
node --check test/browser/verify.cjs
node test/browser/verify.cjs
git diff --check
```

The browser runner requires Node 22+ and Chrome; use `CHROME_PATH` when necessary. Require both seeded/restored results and all three new device/proposal flags, with hardware authentication false. Production startup must succeed without hardware or device credentials. The audio-development harness must continue to show Awaiting MP3 File.

Run just the added suites:

```powershell
flutter test --no-pub test/device_controller_test.dart test/pairing_lifecycle_test.dart test/device_commands_test.dart test/device_connection_safety_test.dart test/device_protocol_http_test.dart
```

The HTTP suite starts an ephemeral real loopback server automatically, validates candidate JSON without executing commands, and cleans it up. The existing `node test/support/http_server.cjs` remains an optional interactive reachability/echo fixture; it is not a Radxa service or hardware simulator. Production screens remain previews, so these tests—not new UI controls—exercise the prepared APIs.

## Known limitations

- Actual BLE discovery/bonding/enrollment/window behavior, independent identity verification, phone authorization, pinned HTTPS, Radxa commands/telemetry, native credential persistence/encryption, and remote revocation are **Not Tested — Hardware/Platform Integration Required**.
- No production protocol/security decision is inferred from passing mocks or loopback HTTP. Real native Android/iOS tests are still required; Android scaffolding is absent and this Windows host cannot perform iOS signing/build acceptance.
- BLE UUIDs, advertisements, identity roots/proofs, credential scheme/rotation, authorization, transfer framing, and the Linux-side service need agreement before production adapters can be implemented. Proposal version/paths do not claim interoperability with hardware.
- Actual recording, synchronization, importing, yt-dlp downloading, file transfer, and headset configuration remain unavailable. Transfer progress types are contracts, not running workflows.
- Forgetting removes local trust only. Offline operation cannot prove remote authorization revocation or OS bond removal. Cleanup failure remains an explicit error requiring recovery; no unrelated local music data is deleted.
- There is no listening-history threshold or new history writer. Local audio is unchanged and remains **Partial — Awaiting MP3 File**; MP3 loading, engine readiness, real play/pause, progress, seeking, completion, audibility, Android playback, and iOS playback are **Not Tested — Awaiting MP3 File**.
- No audio was generated, downloaded, converted, renamed, or modified. All six original WAV files remain ignored and match the hashes in the Increment 4 report; the catalog remains empty.

**Suggested Git Commit Message:** `feat: prepare secure Radxa device communication integration`

**Next Increment:** 6 — Flutter Frontend Implementation. Requires owner review, manual commit/push, and explicit authorization.

Stopped after Increment 5. No commit or push was performed, and no Increment 6 work was started.
