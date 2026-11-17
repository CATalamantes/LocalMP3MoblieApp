# Local development audio

The six owner-supplied WAV recordings can now be used as real test songs.
Their existing INFO tags say Track 1 through Track 6, Unknown artist.
Catalog durations come from their actual RIFF/WAVE headers.

Run from the project folder on Windows:

```powershell
.\run_test_music.cmd
```

The launcher stages byte-identical copies from Music/ into this directory and
opens the real app in Chrome on port 52848. Normal debug startup also registers
the existing test audio automatically, without requiring a special flag:

```powershell
flutter run -d chrome --web-port=52848
```

With songs and no playlists, Library opens on Songs. Choose a track, then Play.
Fully stop/restart after a startup-code change; hot reload does not rerun main.
Originals are not edited,
converted, downloaded, or renamed. Staged copies and originals are ignored by Git.
The CMD wrapper permits its local PowerShell child without changing system policy.

Use `run_test_music.cmd -StageOnly` to stage without launching. Afterwards:

```powershell
flutter run -d chrome --web-port=52848 --dart-define=ENABLE_DEVELOPMENT_AUDIO=true
```

Registration is automatic in the normal debug app, off by default in release/profile,
and can be explicitly overridden with ENABLE_DEVELOPMENT_AUDIO=true/false.
It remains stable and preserves existing edited metadata/lyrics.
WAV and MP3 catalog entries are supported and stored with their actual format.
Missing assets are reported rather than inserted; builds work without fixtures.
Only documentation/catalog metadata and tooling are tracked, never audio.

See doc/WAV-testing.md for actual verification results. Real MP3 acceptance remains
Not Tested - Awaiting MP3 File. Browser WAV checks do not establish audible output,
native mobile playback, or physical Radxa acceptance.
