import 'music_models.dart';

enum StatisticsPeriod { allTime, week, month, year, custom }

class ListeningRange {
  const ListeningRange({this.start, this.end});
  final DateTime? start, end;
}

class SongStatistics {
  const SongStatistics({
    required this.song,
    required this.countedPlays,
    required this.listeningDuration,
  });
  final Song song;
  final int countedPlays;
  final Duration listeningDuration;
}

class ListeningStatistics {
  ListeningStatistics({
    this.totalCountedPlays = 0,
    this.totalListeningDuration = Duration.zero,
    Iterable<SongStatistics> topTracks = const [],
    Iterable<ListeningHistory> recentHistory = const [],
    this.selectedSong,
    this.range = const ListeningRange(),
  }) : topTracks = List.unmodifiable(topTracks),
       recentHistory = List.unmodifiable(recentHistory);
  final int totalCountedPlays;
  final Duration totalListeningDuration;
  final List<SongStatistics> topTracks;
  final List<ListeningHistory> recentHistory;
  final SongStatistics? selectedSong;
  final ListeningRange range;
}
