import '../models/listening_statistics.dart';
import '../services/database/local_music_repository.dart';
import 'controller_state.dart';

class StatisticsController extends MusicController<ListeningStatistics> {
  StatisticsController(this.repository, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now,
      super(ListeningStatistics());
  final LocalMusicRepository repository;
  final DateTime Function() _clock;
  @override
  bool isEmpty(ListeningStatistics data) => data.recentHistory.isEmpty;

  ListeningRange rangeFor(
    StatisticsPeriod period, {
    DateTime? start,
    DateTime? end,
  }) {
    if (period == StatisticsPeriod.custom) {
      if (start == null || end == null || !start.isBefore(end)) {
        throw const ControllerFailure(
          ControllerFailureKind.invalidInput,
          'A valid start/end range is required',
        );
      }
      return ListeningRange(start: start.toUtc(), end: end.toUtc());
    }
    if (start != null || end != null) {
      throw const ControllerFailure(
        ControllerFailureKind.invalidInput,
        'Explicit dates require a custom period',
      );
    }
    if (period == StatisticsPeriod.allTime) return const ListeningRange();
    final now = _clock().toLocal();
    // Build local calendar dates rather than adding fixed 24-hour durations:
    // DST days need not be exactly 24 hours long.
    final (first, last) = switch (period) {
      StatisticsPeriod.week => (
        DateTime(now.year, now.month, now.day - (now.weekday - 1)),
        DateTime(now.year, now.month, now.day - (now.weekday - 1) + 7),
      ),
      StatisticsPeriod.month => (
        DateTime(now.year, now.month),
        DateTime(now.year, now.month + 1),
      ),
      StatisticsPeriod.year => (DateTime(now.year), DateTime(now.year + 1)),
      _ => throw StateError('Unexpected period'),
    };
    return ListeningRange(start: first.toUtc(), end: last.toUtc());
  }

  Future<ListeningStatistics> load({
    StatisticsPeriod period = StatisticsPeriod.allTime,
    DateTime? start,
    DateTime? end,
    int recentLimit = 20,
    String? songId,
  }) => execute(() async {
    if (recentLimit <= 0) {
      throw const ControllerFailure(
        ControllerFailureKind.invalidInput,
        'History limit must be positive',
      );
    }
    if (songId != null) requireIdentifier(songId);
    final range = rangeFor(period, start: start, end: end);
    final data = await repository.readStatistics(
      range: range,
      recentLimit: recentLimit,
      songId: songId,
    );
    return ControllerResult(data, data);
  });
}
