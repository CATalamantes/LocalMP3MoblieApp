import '../../backend/models/device_models.dart';
import '../../backend/models/listening_statistics.dart';
import '../../backend/models/music_models.dart';

/// Rendering inputs only. No fetching, persistence, playback, or device access.
enum PresentationMode { unconnected, ready, loading, empty, error, unavailable }

class ScreenPresentation {
  ScreenPresentation({
    this.mode = PresentationMode.unconnected,
    this.song,
    this.playlist,
    Iterable<Song> songs = const [],
    Iterable<Playlist> playlists = const [],
    this.statistics,
    this.device,
    Iterable<RemoteFile> files = const [],
    Iterable<String> folders = const [],
    this.recording,
    this.designPreview = false,
    Map<String, double> activityHours = const {},
  }) : songs = List.unmodifiable(songs),
       playlists = List.unmodifiable(playlists),
       files = List.unmodifiable(files),
       folders = List.unmodifiable(folders),
       activityHours = Map.unmodifiable(activityHours);
  final PresentationMode mode;
  final Song? song;
  final Playlist? playlist;
  final List<Song> songs;
  final List<Playlist> playlists;
  final ListeningStatistics? statistics;
  final DeviceStatus? device;
  final List<RemoteFile> files;
  final List<String> folders;
  final RecordingMetadata? recording;
  final Map<String, double> activityHours;
  // Diagnostic provenance only; cannot enable an operation or hardware trust.
  final bool designPreview;

  ScreenPresentation selecting({Song? song, Playlist? playlist}) =>
      ScreenPresentation(
        mode: mode,
        song: song ?? this.song,
        playlist: playlist ?? this.playlist,
        songs: songs,
        playlists: playlists,
        statistics: statistics,
        device: device,
        files: files,
        folders: folders,
        recording: recording,
        designPreview: designPreview,
        activityHours: activityHours,
      );
}
