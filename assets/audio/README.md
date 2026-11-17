# Local development audio — awaiting an MP3 file

No audio files are included. Do not generate, download, or convert audio for this increment.
The original WAV files in `Music/` remain untouched and are not registered assets.

Later, place your own playable MP3 here (for example `owner-test.mp3`) and add an entry
to `development_songs.json`:

```json
[
  {
    "song_id": "dev-owner-test",
    "title": "My test track",
    "artist_name": "My artist",
    "asset_path": "assets/audio/owner-test.mp3",
    "duration_ms": 0
  }
]
```

Keep IDs stable. Duration zero means unknown metadata; the playback display uses the
engine's actual duration. Do not change the JSON to refer to nonexistent files.
MP3 files are ignored by Git. This documentation and the empty catalog keep the
directory represented in Git and let builds succeed without audio fixtures.

Registration is opt-in with `--dart-define=ENABLE_DEVELOPMENT_AUDIO=true`. Existing
metadata and lyrics are never overwritten. See the root README for the isolated
playback harness and verification instructions. Real playback is
**Not Tested — Awaiting MP3 File**.
