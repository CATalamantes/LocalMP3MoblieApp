# Flutter–Radxa communication contract — proposal v1

This document guides a future Linux-side implementation. No Radxa server, production BLE adapter, certificate verifier, or credential-provisioning implementation is present or validated in this repository. The executable Flutter codec is a **proposal**, not evidence that hardware implements these messages.

## Requirements, implementation, proposals, and open decisions

| Classification | Contract |
| --- | --- |
| Confirmed project requirement | One trusted device; independent device identity verification and phone authorization; protected OS credential storage; authenticated HTTPS control preferred; authenticated BLE fallback for supported small commands; Wi-Fi-only bulk transfer |
| Approved UML v1 design | Hold physical button for 3 seconds, advertise pairing for 2 minutes, OLED displays temporary 6-digit passkey, authenticated LE Secure Connections; actual behavior requires hardware tests |
| Implemented Flutter foundation | Configurable JSON HTTP, cancellation/timeouts, mobile trust stores, test-only pairing/reconnect orchestration, typed remote commands/status, DeviceController, proposal codec |
| Implemented restriction | Production discovery/pairing/authenticated connections/commands are unavailable; no test outcome or successful HTTP response grants hardware trust |
| Proposal, implemented as a codec | The version-1 envelopes, operation names, payload/result shapes, and error codes below |
| Proposal, documentation only | Candidate HTTP routes, server deduplication, compatibility negotiation, and device-side lifecycle behavior |
| Undecided | BLE advertisements/UUIDs/characteristics, discovery protocol, trusted identity root, certificate/pinning mechanism, credential scheme/lifetime/rotation, enrollment proof, authorization scopes, revocation protocol, transfer protocol, provider policies for downloads |

No production security decision may rely on a device name, advertisement, response `device_id`, OS bond, or self-reported capability. A real verifier must establish the expected identity and this phone's authorization independently.

## Ownership and integration boundaries

`DeviceController` coordinates saved trust, discovery, pairing, connections, status/capabilities, configuration, disconnect, and forgetting. It exposes immutable ChangeNotifier state and sanitized device settings; views must not make HTTP requests or perform cryptography. Production screen binding remains deferred.

`RadxaClient` is the UML's typed remote façade over the existing `ConnectionManager`/`DeviceTransport`. It is independent of local phone playback. The manager selects and authenticates a transport; only a future concrete adapter may read secure credentials and map operations to network requests. Existing constructors accept transport/verifier doubles only through explicit `forTesting` paths. Production constructors cannot be enabled by a feature flag or test session.

The shared `JsonHttpClient` still performs real HTTP. A reachability probe establishes only that an endpoint responded. An HTTPS URL also does not prove the pinned Radxa identity. No concrete production `WiFiTransport` or `BluetoothTransport` is added merely to satisfy a UML class name.

The four approved SQLite tables and their model fields are unchanged. Device status types are service DTOs, not persisted entities. `MobileDeviceSettingsStore` stores only non-secret settings; `MobileCredentialStore` stores credentials and pinned material through native secure storage. Browser SQLite/preferences are never substitutes for mobile trust.

## Discovery, pairing, and forgetting

1. The physical button/window/passkey behavior follows the UML design above, pending hardware verification. The app does not simulate button presses, generate a production passkey, or invent a pairing window.
2. A future discovery adapter returns opaque discovery handles and optional untrusted display names. `inspectPairingWindow` supplies an observed window with expiry. Unknown, closed, or expired observations cannot start the test orchestration. This is an eligibility check, never an identity proof. The existing provision contract requires the returned device ID to match the selected logical ID; the real adapter's binding from discovery handles to independently verified logical identity remains an open integration specification.
3. A future secured provisioning adapter must enforce authenticated LE Secure Connections and the real device's enrollment window. Link encryption or OS bonding alone is insufficient.
4. `IdentityAuthorizationVerifier` must independently verify device identity and phone authorization. The exact proof/root/key exchange remains undecided. No implementation may replace verification with matching an expected device name or response ID.
5. Only after successful verification may credentials/pinned material be written to secure storage, followed by the non-secret settings commit marker. Both records must match the same device. A different device requires explicit forgetting first.
6. Cancellation, forgetting, supersession, and disposal invalidate pending enrollment. A storage write already in progress is drained; incomplete enrollment is rolled back before cleanup reports success. Cleanup failures are surfaced and incomplete records do not grant a connection. No timeout abandons a secure write that could later resurrect trust.
7. Forgetting disconnects and attempts both local record removals, even if another cleanup step fails. It affects no music, playlist, lyrics, or history data. It currently performs **no remote credential revocation or native bond removal**. Future reachable-device revocation must have an agreed authenticated protocol; offline local deletion cannot prove revocation on the Radxa.

Only test adapters currently implement discovery/window/provisioning/verification. Their records and sessions remain test-only. Native platform encryption, persistence, permissions, enrollment, and physical-window enforcement need on-device tests.

## Connections, cancellation, and command outcomes

- Use HTTPS for device endpoints. Existing explicit local-development HTTP is restricted to loopback and rejects authorization/cookie headers. Never send credentials or protected device commands over it.
- The manager requires matching saved settings, credentials, nonempty pinned identity, an HTTPS endpoint, and a configured authenticated transport. Recheck saved trust/configuration before retries, before accepting authentication, and before commands.
- Automatic reconnection honors `autoReconnect`; explicit connect may proceed when that preference is disabled. One initial attempt plus at most three retries uses delays **1, 2, and 4 seconds**. Only transient failures retry. Identity/authentication/authorization failures are terminal.
- Prefer authenticated Wi-Fi. BLE fallback is permitted only after transient Wi-Fi failure, for a specifically supported small operation, with its own identity/authorization verification. Never downgrade security or use BLE for bulk audio transfer.
- Each authentication attempt and command has a 10-second default limit. HTTP also retains its configurable timeout. Cancellation aborts supported clients/adapters; generation checks reject late results even when an adapter ignores cancellation.
- Disconnect, forget, configuration changes, and disposal stop retries. DeviceController supersession also cancels its pending connection/enrollment; older work cannot restore controller state. Credentials/configuration must be changed through the coordinated settings path so cancellation occurs immediately. Revalidation additionally detects direct store changes before another attempt or command.
- Submitted commands are sent once. No reconnect, BLE fallback, or retry automatically replays a command after dispatch. A changing command with a lost/cancelled/malformed response can have an unknown outcome; `DeviceCommandFailure.outcomeUnknown` warns callers not to assume it was undone or blindly resend it.
- Authentication/identity errors invalidate the command session and cached capabilities. HTTP reachability and saved-metadata refresh cannot clear a controller's security failure; a new explicitly successful verified session or successful forgetting is required.

## Candidate HTTP mapping — not implemented on hardware

Suggested future routes are `POST /v1/commands` for the request envelope and `GET /v1/status?protocol_version=1&request_id=<id>` for a status read. Both require the eventual approved authentication mechanism and pinned identity verification. These routes are not configured in production Flutter transports and are not fixture endpoints.

Authorization scheme, pin validation, certificate rotation, and enrollment credentials must be specified and reviewed before implementing either route. Secrets belong in the agreed secured transport mechanism, never URLs, JSON payload examples, logs, SQLite, or shared preferences. Redirects remain disabled. No permissive certificate callback may stand in for identity verification.

Real loopback tests use isolated `/fixture/` validation/health endpoints, or the existing browser `/api/echo` fixture. Candidate messages are nested under `candidate` as synthetic data. Fixtures never interpret the nested operation, execute device actions, issue credentials, or establish hardware authentication. Negative HTTP 401/403 responses exercise classification, not real authentication.

## Proposal v1 envelopes

All object keys below are proposals implemented by `DeviceProtocol`. The integer `protocol_version` is exactly 1. `request_id` is a nonempty correlation string; the production ID generator uses 128 random bits, and tests inject deterministic IDs. Operations are an explicit allowlist. Payloads are JSON objects.

```json
{
  "protocol_version": 1,
  "request_id": "example-correlation-id",
  "operation": "seek",
  "payload": {"position_ms": 15000}
}
```

Responses must match the requested version and ID and contain exactly one of `result` and `error`:

```json
{
  "protocol_version": 1,
  "request_id": "example-correlation-id",
  "result": {"accepted": true}
}
```

```json
{
  "protocol_version": 1,
  "request_id": "example-correlation-id",
  "error": {"code": "forbidden"}
}
```

IDs correlate replies; they are not authentication proofs, counters of counted music plays, or an implemented deduplication guarantee. Device-status IDs must agree with the already authenticated session, but that check cannot establish the session itself.

Future server proposal: deduplicate changing operations by authenticated client identity plus request ID and payload, returning the recorded outcome and rejecting conflicting ID reuse. Retention window, persistence across restarts, and status lookup are undecided. Flutter therefore does not rely on server deduplication or automatically retry commands.

## Typed operations and results — proposal

| Operation | Payload | Result |
| --- | --- | --- |
| `status` | `{}` | Device status below |
| `capabilities` | `{}` | `{"operations":["status","play"]}` |
| `playbackState` | `{}` | `phase`, optional `song_id`, `position_ms`, `duration_ms` |
| `play` | Optional nonempty `song_id` | `{"accepted":true}` |
| `pause`, `resume`, `stop`, `next`, `previous` | `{}` | `{"accepted":true}` |
| `seek` | Nonnegative integer `position_ms` | `{"accepted":true}` |
| `startRecording`, `stopRecording` | `{}` | `{"accepted":true}` |
| `recordingState` | `{}` | `phase`, optional `recording_id` |
| `recordingMetadata` | Nonempty `recording_id` | Matching `recording_id`, optional `file_id`, `duration_ms` |
| `listFiles` | `{}` | `files` array of nonempty `file_id`, `name`, optional `size_bytes` |
| `removeFile` | Nonempty `file_id` | `{"accepted":true}` |
| `submitDownload` | HTTP(S) `url`, with no URI user credentials | `job_id` and `phase` |
| `downloadStatus` | Nonempty `job_id` | Matching `job_id` and `phase` |

Capability names match operation names exactly. Status/capability reads bootstrap the capability set within an authorized session; other operations require both an advertised capability and transport support. Unknown capability strings grant no known operation. Capabilities are cleared when a session changes and older concurrent capability/status responses cannot overwrite newer results.

These status fields are proposed:

```json
{
  "device_id": "identity-already-verified-by-the-transport",
  "capabilities": {"operations": ["status", "capabilities", "playbackState"]},
  "firmware_version": null,
  "battery_percent": null,
  "charging": null,
  "storage_bytes": null,
  "free_bytes": null
}
```

`device_id` and the capability list are required. Optional telemetry stays null/absent until actually received; no zero/percentage/storage defaults are fabricated. Battery is an integer from 0–100, charging is boolean, byte counts are nonnegative integers, and free space cannot exceed known capacity. Connection/authentication state comes from the connection manager, not a device's self-reported boolean. Test provenance is attached locally to DTOs and never accepted as proof from JSON.

Remote playback phases: `idle`, `loading`, `ready`, `playing`, `paused`, `buffering`, `completed`, `error`. Position/duration are nullable nonnegative milliseconds; a reported position must not exceed known duration. The currently selected song is carried by `song_id`. This contract neither switches local playback to hardware nor writes listening history.

Recording phases: `idle`, `recording`, `stopped`, `failed`. Download phases: `queued`, `running`, `completed`, `failed`, `cancelled`. Successful submission or an acknowledgement does not prove recording, downloading, or playback completed. No actual recording/download occurs in Increment 5.

Transfer contracts expose a handle with progress snapshots (`pending`, `running`, `completed`, `cancelled`, `failed`; transferred bytes and optional total bytes) and cancellation. Upload/download methods remain unavailable even on an authenticated test Wi-Fi session; BLE rejects them as unsupported. No chunks, files, remote deletion workflow, or resume protocol are implemented. Transfer endpoint/chunking/integrity/authorization/cancellation details require a later agreed contract.

## Errors and compatibility

Proposed error codes: `unauthenticated`, `forbidden`, `identity_mismatch`, `unsupported`, `unavailable`, `transient`; unknown codes map to a protocol failure. Remote error body text is not exposed or logged. HTTP mapping distinguishes 401 authentication, 403 authorization, 404 unavailable, 405/501 unsupported, and other 5xx transient failures. Invalid JSON, missing fields, malformed telemetry, mismatched reply IDs, and unsupported versions fail closed. HTTP transport/timeouts retain their original low-level classification as well.

The codec currently accepts proposal version 1 only. A future adapter/server must negotiate an agreed compatible version before protected commands; unsupported major versions must not trigger a downgrade. Unknown advertised capabilities are harmless, while missing required fields or unknown status enums are rejected. HTTP route stability, minor-version extensions, maximum message sizes, polling/event delivery, and transfer compatibility are unresolved.

## UML alignment and remaining acceptance

- Reuse the existing ConnectionManager, PairingService, transport interface, HTTP client, and secure-store abstractions. Add the UML's DeviceController/RadxaClient responsibilities without duplicating networking infrastructure.
- The UML's Radxa-only playback note is superseded by the owner's authorized Increment 4 local development capability. Preserve that separation; Increment 4 remains **Partial — Awaiting MP3 File**.
- UML concrete Wi-Fi/Bluetooth adapters, SyncService workflows, device-side recording/downloading, and headphone audio management are future work. Headphones use a separate audio protocol; BLE control pairing does not configure A2DP.
- UML remote trust revocation is not implemented; local forgetting cannot claim remote revocation, especially while offline.
- Hardware acceptance must verify physical button/window/OLED behavior, OS-secured BLE, independent identity/auth proofs, Keychain/Keystore persistence, pinned HTTPS and rotation, authorization rejection, revocation, secure reconnection/fallback, actual telemetry/commands, and Wi-Fi transfers. Browser/host doubles and loopback HTTP cannot satisfy these checks.

Run the test/build/browser sequence in README and see `Increment5-report.md` for actual outcomes. Passing the hardware-free scope does not mark any hardware capability verified or enable production adapters.
