// Diagnostic display fixtures only. No stores, controllers, services or audio bytes.
// Never imported by production pages, routing, main.dart or app.dart.
import '../../backend/models/device_models.dart';
import '../../backend/models/listening_statistics.dart';
import '../../backend/models/music_models.dart';
import '../widgets/presentation.dart';

ScreenPresentation frontendFixture(PresentationMode mode) {
  if (mode != PresentationMode.ready) {
    return ScreenPresentation(mode: mode, designPreview: true);
  }
  final date = DateTime.utc(2026, 11, 17);
  final songs = [
    for (var i = 0; i < 3; i++)
      Song(
        songId: 'design-song-$i',
        title: ['Night Window', 'Paper Satellites', 'Blue Hour'][i],
        artistName: [
          'Sample Artist A',
          'Sample Artist B',
          'Sample Artist C',
        ][i],
        durationMs: 180000,
        audioFormat: 'MP3',
        filePath: 'asset:///assets/audio/design-reference-only-$i.mp3',
        dateAdded: date,
        lyricsText: 'The city settles into light\nA quiet window in the night\n\nWe leave a little space to dream\nAnd follow every silver seam',
      ),
  ];
  final playlist = Playlist(
    playlistId: 'design-playlist',
    name: 'After Hours',
    description: 'Design sample · A personal collection for the evening',
    createdAt: date,
    updatedAt: date,
  );
  return ScreenPresentation(
    mode: mode,
    designPreview: true,
    song: songs.first,
    songs: songs,
    playlist: playlist,
    playlists: [
      playlist,
      for (var i = 0; i < 3; i++)
        Playlist(
          playlistId: 'design-playlist-$i',
          name: [
            'Quiet Commute',
            'Home Collection',
            'Instrumental Sketches',
          ][i],
          description: 'Design sample · Personal playlist',
          createdAt: date,
          updatedAt: date,
        ),
    ],
    statistics: ListeningStatistics(
      totalCountedPlays: 24,
      totalListeningDuration: const Duration(hours: 3, minutes: 42),
      topTracks: [
        for (var i = 0; i < songs.length; i++)
          SongStatistics(
            song: songs[i],
            countedPlays: 10 - i * 2,
            listeningDuration: const Duration(minutes: 30),
          ),
      ],
      recentHistory: [
        ListeningHistory(
          historyId: 'design-history',
          songId: songs.first.songId,
          startedAt: date,
          listenedMs: 90000,
          countedPlay: false,
        ),
      ],
    ),
    activityHours: const {
      'Mon': .4,
      'Tue': .6,
      'Wed': .2,
      'Thu': .5,
      'Fri': 1,
      'Sat': .7,
      'Sun': .3,
    },
    device: DeviceStatus(
      deviceId: 'DESIGN-SAMPLE',
      capabilities: DeviceCapabilities(const []),
      testOnly: true,
      firmwareVersion: 'Design preview',
      batteryPercent: 64,
      charging: false,
      storageBytes: 64000000000,
      freeBytes: 35600000000,
    ),
    folders: const ['Design sample folder'],
    files: const [
      RemoteFile(
        fileId: 'design-file',
        name: 'Sample track.mp3',
        testOnly: true,
        sizeBytes: 8400000,
      ),
    ],
    recording: const RecordingMetadata(
      recordingId: 'design-recording',
      testOnly: true,
      duration: Duration(minutes: 3),
    ),
  );
}
