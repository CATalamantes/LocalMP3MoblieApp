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
  backend/
    controllers/                    # MVC behavior and application state
test/                               # Navigation and layout verification
```

Frontend pages render state and receive user interactions; backend controllers coordinate behavior and notify views. Models and infrastructure services will be added under `lib/backend/` only when their increments require implementations:

- `models/`: Song, Playlist, PlaylistEntry, and ListeningHistory (Increment 2).
- `services/database/`: SQLite initialization, queries, and persistence (Increment 2).
- `services/audio/`: Local test-audio playback (Increment 4).
- `services/device/`: Future Radxa communication boundaries (Increment 5 and later hardware integration).

These future directories and the future `assets/` structure are intentionally not created empty. All application code belongs under `lib/frontend/` or `lib/backend/`, except the entry points `main.dart` and `app.dart` directly under `lib/`. Routing lives in `lib/frontend/routes/`, preserving `app_router.dart` and `app_screen.dart`. Device HTTP/BLE services are separate from Flutter Navigator routing.

### Increment boundaries

- The entry point starts MaterialApp; centralized routes and theme configure the application. A ChangeNotifier controller owns main-tab selection. Views display state and request navigation.
- Midnight Crimson uses navy backgrounds, blue surfaces, crimson accents, and white/gray text, with no green UI accents.
- Future increments introduce Song, Playlist, PlaylistEntry, ListeningHistory, SQLite services, business controllers, audio, and device interfaces. Song retains optional `lyrics_text`. No empty layer scaffolding or premature infrastructure is created.
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
