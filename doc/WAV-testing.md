# Existing WAV songs — development testing correction

The owner explicitly requested using the six supplied WAV recordings as actual
test songs. This supersedes the empty MP3-only development catalog. It does not
begin Increment 8 or implement importing, conversion, downloads, recording, or
Radxa operations.

## Run

```powershell
flutter run -d chrome --web-port=52848
```

Normal debug startup now enables registration automatically. The Library opens
on Songs when real songs exist and there are no playlists, so the tracks are
visible immediately. Explicit category choices are retained. VS Code's CTA2000
Chrome configuration uses that same normal entry point and stable port.
Stop the existing run completely before relaunching; hot reload does not rerun main.

If asset staging is needed, use `.\run_test_music.cmd`.

The launcher checks `Music/01 Track 1.wav` through `Music/06 Track 6.wav`, stages
byte-identical copies in `assets/audio/`, and opens the real app in Chrome with
development registration enabled. Open Library > Songs, select a track, then Play.
Port 52848 stays fixed for SQLite persistence at the same origin.

PowerShell scripts are restricted on this computer, so the CMD wrapper permits
this script only in its child process. It does not change any persisted execution
policy. Originals are read/hashed, never renamed or edited. Differing existing
destination assets are not overwritten.

Stage only with `run_test_music.cmd -StageOnly`; afterwards, the direct equivalent is:

```powershell
flutter run -d chrome --web-port=52848 --dart-define=ENABLE_DEVELOPMENT_AUDIO=true
```

## Actual metadata and boundaries

The files are RIFF/WAVE PCM, stereo, 44,100 Hz, 16-bit. Existing INFO tags identify
Track 1 through Track 6 and Unknown artist. Metadata durations use the actual data
length/byte rate, truncated to milliseconds. Runtime duration comes from the engine.

| Song | Stable ID | Duration |
| --- | --- | --- |
| Track 1 | dev-wav-track-01 | 238146 ms |
| Track 2 | dev-wav-track-02 | 241560 ms |
| Track 3 | dev-wav-track-03 | 278080 ms |
| Track 4 | dev-wav-track-04 | 211000 ms |
| Track 5 | dev-wav-track-05 | 324306 ms |
| Track 6 | dev-wav-track-06 | 240880 ms |

The existing registrar now accepts WAV and MP3 inside assets/audio/, stores the
correct format, checks existence, and preserves existing records/edited lyrics.
Main's debug startup enables registration by default, with explicit true/false
environment overrides. Release/profile defaults remain off. The composition root
and isolated harness still require explicit enabling, preserving test isolation.
Missing assets are reported rather than inserted; debug startup gives a visible
staging/restart instruction if fixtures are missing. A fresh release database
remains empty without the development define. Catalog
JSON is metadata; Git ignores originals and staged audio. Clean checkouts can
build without these recordings.

## Verification

Correction verification completed on November 17, 2026:

| Check | Actual outcome |
| --- | --- |
| Metadata/header inspection | Six actual PCM WAVs; existing titles/artist and durations recorded above |
| Staging and Git ignore checks | Six byte-identical staged copies; original and staged files ignored; original hashes unchanged |
| Formatting / analysis | Passed; no formatting changes remaining and no analysis issues |
| Full Flutter suite | Passed; 251 tests, retaining the previous 248 and adding three WAV/catalog/encoded-path cases |
| Normal, WAV-enabled app, WAV-enabled harness web builds | Passed |
| Real Chrome release app | Fresh database empty without explicit registration |
| Real Chrome integrated app | All six actual WAV songs loaded and restored after same-origin reload; actual song selection, Play, advancing progress and Pause passed through Now Playing |
| Real Chrome audio engine | All six decoded with durations matching the real WAV headers; play/pause/resume, advancing position, seek, next/previous, natural completion/wrap and stop passed |
| Script syntax and `git diff --check` | Passed |

The engine reported 238146, 241560, 278080, 211000, 324306, and 240880 ms for
Tracks 1–6. Evidence is in ignored `build/wav-browser.log` and
`build/wav-playback-verification.json`. These were real just_audio/Chrome engine
checks with the supplied files, not audio doubles. Audible output was not assessed
by a person; native/mobile and MP3 acceptance remain unverified.

The first browser run exposed encoded spaces in asset URIs: Uri.path retained
percent escapes while the asset manifest used decoded keys. The resolver now
uses decoded, validated path segments and continues rejecting traversal/embedded
separators. A regression test covers that case. The browser driver also waits
for an actual positive engine duration rather than assuming the first ready
event already includes it. Final verification passed after those corrections.

```powershell
.\run_test_music.cmd -StageOnly
dart format --output=none --set-exit-if-changed lib test
flutter analyze --no-pub
flutter test --no-pub --reporter expanded
flutter build web --no-pub
flutter build web --no-pub --dart-define=ENABLE_DEVELOPMENT_AUDIO=true --output build/test-music
flutter build web --no-pub --target lib/frontend/development/local_playback_harness.dart --dart-define=ENABLE_DEVELOPMENT_AUDIO=true --output build/wav-playback
node --check test/browser/wav_playback_verify.cjs
node test/browser/wav_playback_verify.cjs
git diff --check
```

The real Chrome runner uses isolated servers on 52900/52901/52902 and a temporary
profile. WAV responses support proper MIME types and byte ranges. It exercises
actual UI/controller/just_audio paths, never an audio double. Browser evidence
cannot establish that a person heard output, native platform acceptance, or MP3 playback.

## Correction inventory

Created: `run_test_music.cmd`, `tool/run_test_music.ps1`,
`test/wav_development_registration_test.dart`,
`test/browser/wav_playback_verify.cjs`, and this report.

Modified: asset source resolver, development registrar, `assets/audio/development_songs.json`,
`assets/audio/README.md`, root README, and the Increment 7 report's correction note.
Six local byte-identical asset copies remain ignored, with no audio added to Git.

## Follow-up: normal debug launch and initial category

The owner's empty-library screenshot exposed a launch mismatch: the earlier
implementation only enabled registration through a special define, and the
Library defaulted to Playlists. Main now defaults the existing test catalog on
only in debug, retaining explicit overrides and the release/profile default off.
The Library shows Songs first when songs exist without playlists. No query,
schema, audio-engine, playback-controller, or hardware-security logic changed.
When songs are available but none is selected, the mini-player says "Select a
song to play" rather than incorrectly saying an MP3 file is required.

Additional files: modified `lib/main.dart`, `lib/frontend/pages/library_pages.dart`,
`lib/frontend/widgets/design_widgets.dart`, `test/frontend_integration_test.dart`, the browser verification runner, and these
instructions; added `.vscode/launch.json`. Analysis and the full 252-test suite
passed. The ordinary unflagged debug-server check confirmed immediate song
visibility, same-origin reload, selection, actual Play/advancing progress/Pause,
and all six real WAV engine tests. The final repeat passed with the corrected
mini-player instruction; `build/debug-music-library.png` was captured and visually
inspected. The temporary debug server was stopped after verification.

To reproduce the normal debug path, start this in one terminal:

```powershell
flutter run -d web-server --web-hostname=127.0.0.1 --web-port=52903 --no-pub
```

With the three builds above available, use another terminal:

```powershell
$env:WAV_DEBUG_URL='http://127.0.0.1:52903/'
node test/browser/wav_playback_verify.cjs
$env:WAV_DEBUG_URL=$null
```

No audio define or special bootstrap is used by that debug server. The release
app is separately checked to remain empty by default. Logs are in ignored
`build/debug-music-tests.log` and `build/debug-music-browser.log`. Native output,
personal audibility, MP3 acceptance and physical Radxa communication are not claimed.

Real MP3 playback remains **Not Tested — Awaiting MP3 File**; Increment 4's MP3
acceptance remains Partial. Schema, playback-controller rules, 17 screens, theme,
and device security are unchanged. No commit, push, or Increment 8 work.
