# Increment 7.1 — Song Metadata Editing, Playlist Fixes & Queue Management

**Status: Complete for Increment 7.1.** Real MP3 acceptance remains **Not Tested — Awaiting MP3 File**; Increment 4 retains its Partial acceptance. Native picker UI and native application builds remain unverified. No commit, push, or Increment 8 work was performed.

## Implementation

### Song information and artwork

Song Details and song three-dot menus now open an editor populated with the current title, artist and artwork. Title is required; artist remains optional under the existing policy. Duration and format are read-only. Cancel discards the draft. Pending operations disable submissions and dismissal; validation/storage/SQLite errors retain the draft for retry. Only changed fields are submitted, with separate keep, replace and clear artwork semantics.

`LibraryController.saveSongInformation` extends the existing metadata operation. `updateMetadata` remains a compatible delegate. Song ID, audio file reference, date added, lyrics, playlist occurrences and listening history are preserved. No audio file is edited. A committed save returns `SongSaveResult`, including separate cleanup/refresh warnings. A postcommit refresh failure cannot turn a saved row into a reported rollback. Song deletion similarly returns a committed receipt while keeping later playback queue cleanup independent.

`ArtworkService` owns selection, byte validation and managed image storage. The picker uses `file_selector`; native paths use `path_provider`. PNG/JPEG images are limited to 5 MiB and 4096 pixels on either dimension, with actual decoding required. The codec works on web as well as native targets; Flutter web's unsupported encoded-descriptor dimension getters are avoided. Selected image bytes stay in memory until Save. The source image and all audio remain untouched.

Native storage uses application-support `cta2000-artwork/` files. Web storage uses the `cta2000-artwork` IndexedDB database and `images` object store. Only opaque `artwork:///` references enter the existing SONG artwork field. No image bytes, browser blob URLs, new SQLite columns, or new SQLite tables are persisted. Rendering uses the shared `ArtworkFrame`, with a neutral fallback for missing/unreadable/unmanaged references.

Image lifecycle operations are serialized using the injected service shared by the application. A replacement is durably written before its SQLite reference commits. Failed SQLite saves remove the unreferenced new image. After a successful replacement, clear or song deletion, old managed images are removed only after checking all remaining Song references. Shared and unmanaged references are preserved. Failed cleanup remains pending for a safe retry on a later metadata/deletion operation in that application session, with postcommit warnings. Shutdown waits for in-flight managed image operations before closing SQLite.

Metadata refreshes Library, playlist details, Now Playing, mini-player, lyrics/details, queue labels/artwork and song statistics. Playback labels update by stable Song ID; refresh does not reload audio, replace queue occurrences or reset progress.

### Playlist investigation and correction

**Root cause: awkward and incomplete selection UX, not a reproduced database insertion defect.** Before implementation, the existing integrated test for adding a library song through the plus button passed. The owner also clarified that playlist persistence worked. The old picker required tapping a small trailing plus and then a second confirmation; tapping the song itself did not select it, and song context menus lacked Add to Playlist.

Playlist Add now opens a row/checkbox picker with selection count and a single **Add Selected** action. It captures playlist/song identities, retains selections on error and guards double submission. Empty libraries show an honest empty state. Song menus now include **Add to Playlist**, with persisted playlists loaded through the existing controller and a useful empty state when none exist.

`PlaylistController.addSongs(playlistId, songIds)` validates every reference, inserts all occurrences, normalizes positions once and builds the refreshed snapshot inside one SQLite transaction. Any validation, insert, normalization or snapshot failure rolls back the entire batch. Existing `addSong` delegates to the batch API. Picker additions follow displayed order; repeated additions, including the same song, create distinct entry IDs. Adding songs to playlists never changes playback.

### Playback queue and selection

Temporary queue state remains in `PlaybackController`, with immutable published `QueueOccurrence` IDs, manual/source provenance and a queue revision. Existing Song-list and queue-index accessors remain available. Duplicate songs keep separate occurrence identities.

| API | Behavior |
| --- | --- |
| `playNext(songId)` | Inserts immediately after the selected occurrence. |
| `addToQueue(songId)` | Appends to the contiguous manual-priority block after the selected occurrence, before ordinary source tracks. |
| `removeUpcoming(occurrenceId)` | Removes exactly one upcoming occurrence. |
| `reorderUpcoming(occurrenceId, finalIndex, revision: …)` | Moves an upcoming occurrence to its final zero-based index; rejects stale revisions and protected destinations. |
| `refreshMetadata(songs)` | Updates labels/artwork by Song ID without changing occurrence IDs or calling audio. |

The owner's queue-priority clarification supersedes the original tail-append example: Track 5 playing, then Add to Queue Track 1 and Track 2, produces **5 → 1 → 2 → 6**. Play Next can insert ahead of that FIFO block. Explicit reorder is respected. Entries remain part of the temporary session and existing wraparound order; no consume-once mode or persistent queue was added.

Nonempty queue edits serialize with playback commands and call no audio engine operations. They preserve source session, position, actual playing/paused state, intent and current occurrence. Missing records, stale edits, invalid indices and attempts to edit current/past occurrences produce queue errors without clearing play intent. Edits from an older selection cannot modify its replacement queue. Empty additions prepare the first source without autoplay. Completion and Next/Previous follow the updated order and retain existing continuous/wraparound behavior. Queue edits write neither playlists nor listening history.

Library/playlist song taps now explicitly autoplay the selected song **without leaving the list**, as approved. The mini-player opens Now Playing. Its inner play/pause control remains independent. Queue-sheet selection and Next/Previous preserve current play intent, including remaining paused. The queue sheet distinguishes occurrences by position, marks the selected occurrence, and offers upcoming drag handles, move-up/down buttons and occurrence-specific removal. Current/past occurrences have no removal/reorder controls.

## Architecture and preserved boundaries

Views collect input and render state; controllers validate and orchestrate; services own file, SQLite, audio and device operations. There is no second repository, playback service, controller stack, backend server or state-management framework.

The approved Song, Playlist, PlaylistEntry and ListeningHistory entities and four-table relational schema are unchanged. Song deletion still cascades playlist entries and normalizes affected positions atomically in SQLite while preserving audio files. No routes or theme definitions changed. All application code remains under frontend/backend except the existing entry points.

All 17 destinations remain: Library, Playlist Details, Now Playing, Lyrics & Song Details, Fullscreen Lyrics, Add Music, Record Audio, Save to Library, Device, Connections, Music Sync, Storage, File Manager, Bluetooth Audio, Battery & Display, About Device and Listening Statistics. Existing detail return paths and all-screen responsive tests remain covered.

Networking, Radxa protocol, retries, cancellation and trust boundaries are unchanged. Production pairing/authenticated connections remain unavailable; no test adapter is promoted to successful hardware authentication. Browser artwork storage is ordinary local development/application storage, separate from mobile secure device trust.

## Actual verification

| Check | Final outcome |
| --- | --- |
| `dart format --output=none --set-exit-if-changed lib test` | Passed; 91 Dart files, no remaining changes. |
| `flutter analyze --no-pub` | Passed; no issues. |
| `flutter test --no-pub --reporter expanded` | Passed; **283 tests**: all 252 existing scenarios retained, plus 20 controller/storage and 11 integrated frontend scenarios. |
| `flutter build web --no-pub` | Passed; production output `build/web`. |
| Audio development harness build | Passed; `build/audio-development`. |
| Frontend preview build | Passed; `build/frontend-preview`. |
| Browser persistence probe build | Passed; `build/browser-verification`. |
| `node --check` on `verify.cjs`, `visual_verify.cjs`, `integrated_ui_verify.cjs` | Passed. |
| `node --check test/browser/wav_playback_verify.cjs` | Passed. |
| `node test/browser/verify.cjs` | Passed in actual headless Chrome, including real UI file selection and same-origin reload. |
| `node test/browser/visual_verify.cjs` | Passed; all 17 screens captured in production, preview and isolated SQLite-integrated modes. |
| Development-enabled production and WAV harness builds | Passed; `build/test-music`, `build/wav-playback`. |
| `node test/browser/wav_playback_verify.cjs` | Passed with the six existing WAV files and real Chrome audio engine. |
| Original and asset WAV SHA256 comparison | Passed; all six originals and all six asset copies match the established values. |
| `git diff --check` | Passed. |

Builds emitted existing dependency Wasm dry-run warnings; successful JavaScript web builds do not establish Wasm support. Git emitted line-ending conversion notices without whitespace errors. Early development runs exposed the web descriptor issue and browser automation timing/navigation issues; those were corrected before the passing final checks. No failed attempt is counted as a passing check.

New deterministic tests cover metadata/protected fields, cancel and clear, shared image references, image validation, native file and SQLite reopening, write/SQLite/cleanup/postcommit-read failures, disposal during image storage, FIFO priority, playing/paused/empty/single/duplicate queues, protected/current/past removal, stale revisions, rapid edits, completion/wraparound, source/position preservation and no unintended database/audio writes. UI tests exercise retry with retained drafts/selections, double-submit protection, metadata refresh into playlists/statistics, queue actions and accessible reorder/removal. All 17 existing screens and new forms are tested at 320/390/430 pixels with 1×/2× text; form tests include keyboard insets.

### Browser evidence

The real Chrome persistence flow runs at **http://127.0.0.1:52842**, using unique `integrated-browser-<run>.db` SQLite databases and `integrated-artwork-<run>` IndexedDB storage. It uses production widgets/controllers, not a mutation backdoor. It creates/renames a playlist, clears its description, batch-adds two songs, adds a duplicate through the song menu, edits title/artist, selects the existing local Flutter PNG through the real picker, saves Unicode lyrics, edits/selects queue occurrences, checks actual statistics and verifies device authentication remains false.

After a same-origin page reload, diagnostics and UI verify the edited title/artist, stable managed artwork reference, readable image byte length and rendered artwork, three persisted playlist entries, two unchanged Song records, exact lyrics and no hardware authentication. The existing browser probe also verifies SQLite reopening, four tables, controller operations, queue wrap, actual local HTTP and unavailable protected commands. Fresh production storage contains no integration/design fixtures.

The separate real WAV run verifies all six engine-reported durations, autoplay from source lists, mini-player navigation, advancing progress, pause/resume, seek, Next/Previous, natural completion/wrap and Stop. It verifies **Track 5 → 1 → 2 → 6** through the main app and verifies that queue additions preserve Track 5 and its advancing position. This is WAV/Chrome evidence, not MP3 or human audibility acceptance.

Browser artifacts are ignored under `build/`: `increment71-browser.log`, `increment71-tests.log`, `increment71-wav.log`, `wav-playback-verification.json`, `increment71-audio-hashes.json`, and `increment71-visual/index.html`/`manifest.json`. New editor/queue captures at 320/390/430 and `increment71-artwork-restored.png` support review. Representative editor, queue, restored artwork, Song Details and statistics images were visually inspected. Screenshot capture alone is not a full pixel-diff oracle or a replacement for owner hands-on review.

## Complete file inventory

Created:

- `lib/backend/services/artwork/artwork_service.dart` — selection, validation, stable references and serialized lifecycle.
- `lib/backend/services/artwork/artwork_store.dart` — injectable durable byte-store contract.
- `lib/backend/services/artwork/platform_artwork_store.dart` — native/web selection.
- `lib/backend/services/artwork/native_artwork_store.dart` — application-managed native image files.
- `lib/backend/services/artwork/web_artwork_store.dart` — durable IndexedDB image transactions.
- `lib/frontend/widgets/song_editors.dart` — song information draft/editor.
- `lib/frontend/widgets/playlist_pickers.dart` — batch picker and playlist chooser.
- `lib/frontend/widgets/queue_sheet.dart` — occurrence-aware queue sheet and accessible editing.
- `test/increment71_controllers_test.dart` — 20 queue, batch, artwork and failure/lifecycle scenarios.
- `test/increment71_frontend_test.dart` — 11 integrated workflows and responsive form scenarios.
- `doc/Increment7.1-report.md` — this report.

Modified:

- `lib/backend/app_dependencies.dart` — inject/share artwork service and wait for managed operations on shutdown.
- `lib/backend/controllers/library_controller.dart` — reuse metadata logic with artwork lifecycle and committed-result receipts.
- `lib/backend/controllers/playlist_controller.dart` — atomic batch addition; compatible single-add delegate.
- `lib/backend/controllers/playback_controller.dart` — occurrence identities, priority edits, revision guards and metadata refresh.
- `lib/frontend/pages/library_pages.dart` — connect playlist Add to the batch picker.
- `lib/frontend/pages/playback_pages.dart` — song editor/artwork and live queue sheet.
- `lib/frontend/widgets/application_binding.dart` — autoplay in place, metadata refresh orchestration and independent deletion/cleanup warnings.
- `lib/frontend/widgets/design_widgets.dart` — shared image rendering, song menu actions and mini-player artwork.
- `pubspec.yaml`, `pubspec.lock` — file_selector/path_provider runtime dependencies; existing web dependency promoted to runtime.
- `test/frontend_integration_test.dart` — preserve scenarios while updating intentional source-tap and batch-picker assertions.
- `test/support/integrated_fixture.dart` — artwork injection seam.
- `test/browser/integrated_app.dart` — isolated artwork namespace and read-only reload diagnostics.
- `test/browser/integrated_ui_verify.cjs` — real metadata/image selection, duplicate/batch playlist and queue UI verification.
- `test/browser/visual_verify.cjs` — Increment 7.1 visual artifact location.
- `test/browser/wav_playback_verify.cjs` — main-app autoplay/priority/progress checks while retaining existing real-audio coverage.
- `README.md`, `doc/WAV-testing.md` — current behavior and artwork/project structure documentation.

No audio files, domain entity definitions, SQLite schema, routing definitions, theme files or device/networking implementations were changed.

## Manual verification

1. Fully restart `flutter run -d chrome --web-port=52848` with existing staged WAV assets. If staging is needed, use `run_test_music.cmd`; the supplied originals must remain unchanged. Keep the same host/port for persistence checks.
2. Open Library → Songs. Tap Track 5: the list should remain open and the mini-player should show actual playback. Tap the mini-player to open Now Playing, pause/resume and confirm real progress.
3. Open a song's three-dot menu → Edit Song Information, or use Song Details → Edit Song Information. Edit title/artist, choose a PNG/JPEG, and Save. Check the new information in Library, playlist details, mini-player, Now Playing, queue and statistics where that song has saved history. Cancel a second edit and confirm it was discarded. Clear artwork and Save. Try a blank title or unsupported image and confirm validation.
4. Create/open a playlist → Add, select multiple songs and press Add Selected once. Reopen the picker and add a song again. Confirm separate duplicate occurrences, then remove one and reorder another. Also use a song menu → Add to Playlist. Restart/reload and check persistence.
5. Start Track 5 from the source list. Add Track 1 and Track 2 with Add to Queue; Track 5 must continue uninterrupted. Next should play 1, then 2, then 6. Try Play Next, and inspect duplicate occurrence numbers in Now Playing → Queue. Move or remove upcoming occurrences; current/past items must remain protected. Pause and select another queue occurrence: it must stay paused.
6. Reload at the same origin: song metadata, artwork, lyrics and playlists persist; the temporary playback queue does not. Confirm Device continues to report unavailable authentication and importing/downloading/recording/sync controls remain honest.

## Known limitations

- Real MP3 playback: **Not Tested — Awaiting MP3 File**. Original Increment 4 status remains Partial. Headless WAV playback does not verify human audibility.
- Native file lifecycle and injected picker behavior are tested on the Windows host; real iOS/mobile picker UI, secure device storage and native application builds are not validated. Adding absent native scaffolding is outside this increment.
- Some headless captures show missing Unicode fallback glyphs. Exact Unicode text persistence is verified; full font/glyph availability across platforms is not established.
- Browser data is tied to the exact origin/profile, subject to quota/eviction/private mode/site-data clearing, and is not a backup or secure device-trust store. Legacy/unmanaged artwork references may render a neutral placeholder; they are never deleted as managed files.
- SQLite and image storage are separate durable stores. Normal failures clean up safely, but an abrupt process/browser crash between image persistence and SQLite commit can leave an unreferenced managed image. Cleanup retry bookkeeping is in-memory for this application session; no crash-proof cross-store transaction or broad orphan sweep is claimed.
- Temporary queue order/occurrence IDs are not persisted. Existing wraparound includes manual occurrences; shuffle, consume-once queues and new repeat modes are not implemented.
- Physical Radxa communication, identity verification, authorization, BLE/provisioning, importing, downloading, recording and synchronization remain unavailable/unverified as previously documented. No production hardware success is simulated.

**Suggested Git commit message:** `feat: add song editing and queue management, fix playlist song addition`

**Next increment:** 8 — Testing, Stabilization & Final Demonstration. Not started. Stop for owner review and manual commit/push.
