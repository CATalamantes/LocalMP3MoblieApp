import 'package:cta2000/backend/controllers/controller_state.dart';
import 'package:cta2000/backend/controllers/statistics_controller.dart';
import 'package:cta2000/backend/models/listening_statistics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/controller_fixture.dart';

void main() {
  late ControllerFixture f;
  late StatisticsController stats;
  setUp(() async {
    f = ControllerFixture();
    await f.open();
    stats = f.own(StatisticsController(f.repository, clock: f.clock));
  });
  tearDown(() => f.close());

  test(
    'empty history and existing songs with no plays return exact zero totals',
    () async {
      await f.song('a');
      final result = await stats.load(songId: 'a');
      expect(result.totalCountedPlays, 0);
      expect(result.totalListeningDuration, Duration.zero);
      expect(result.selectedSong!.countedPlays, 0);
      expect(result.selectedSong!.listeningDuration, Duration.zero);
      expect(result.topTracks, isEmpty);
      expect(stats.state.status, ControllerStatus.empty);
    },
  );

  test('countedPlay controls plays, actual listenedMs includes incomplete sessions; ties use ID', () async {
    for (final id in ['b', 'a', 'c']) {
      await f.song(id);
    }
    await f.history('h1', 'a', ms: 1234);
    await f.history('h2', 'a', ms: 3456, counted: false);
    await f.history('h3', 'b', ms: 5000);
    await f.history('h4', 'c', ms: 2500, counted: false);
    final result = await stats.load(songId: 'a');
    expect(result.totalCountedPlays, 2);
    expect(result.totalListeningDuration.inMilliseconds, 12190);
    expect(result.topTracks.map((s) => s.song.songId), ['a', 'b']);
    expect(result.selectedSong!.countedPlays, 1);
    expect(result.selectedSong!.listeningDuration.inMilliseconds, 4690);
    expect(result.recentHistory.map((h) => h.historyId), [
      'h1',
      'h2',
      'h3',
      'h4',
    ]);
    expect(() => result.topTracks.clear(), throwsUnsupportedError);
    expect(() => result.recentHistory.clear(), throwsUnsupportedError);
    expect((await stats.load(songId: 'c')).selectedSong!.countedPlays, 0);
  });

  test(
    'period uses session start and half-open bounds without duration prorating',
    () async {
      await f.song('a');
      final start = DateTime.utc(2026, 11, 1), end = DateTime.utc(2026, 12, 1);
      await f.history(
        'before',
        'a',
        ms: 500,
        started: start.subtract(const Duration(milliseconds: 1)),
      );
      await f.history('at-start', 'a', ms: 600, started: start);
      await f.history(
        'inside',
        'a',
        ms: 700,
        started: end.subtract(const Duration(milliseconds: 1)),
      );
      await f.history('at-end', 'a', ms: 800, started: end);
      final result = await stats.load(
        period: StatisticsPeriod.custom,
        start: start,
        end: end,
      );
      expect(result.totalCountedPlays, 2);
      expect(result.totalListeningDuration.inMilliseconds, 1300);
      expect(result.recentHistory.map((h) => h.historyId), [
        'inside',
        'at-start',
      ]);
    },
  );

  test(
    'calendar week is Monday-start and month/year boundaries use local dates',
    () async {
      f.now = DateTime(2026, 11, 17, 13, 30);
      final week = stats.rangeFor(StatisticsPeriod.week);
      expect(week.start, DateTime(2026, 11, 16).toUtc());
      expect(week.end, DateTime(2026, 11, 23).toUtc());
      final month = stats.rangeFor(StatisticsPeriod.month);
      expect(month.start, DateTime(2026, 11, 1).toUtc());
      expect(month.end, DateTime(2026, 12, 1).toUtc());
      final year = stats.rangeFor(StatisticsPeriod.year);
      expect(year.start, DateTime(2026, 1, 1).toUtc());
      expect(year.end, DateTime(2027, 1, 1).toUtc());
      f.now = DateTime(2028, 2, 29, 23);
      expect(
        stats.rangeFor(StatisticsPeriod.month).end,
        DateTime(2028, 3, 1).toUtc(),
      );
      f.now = DateTime(2027, 1, 3); // Sunday, crossing a year boundary.
      expect(
        stats.rangeFor(StatisticsPeriod.week).start,
        DateTime(2026, 12, 28).toUtc(),
      );
      expect(
        stats.rangeFor(StatisticsPeriod.week).end,
        DateTime(2027, 1, 4).toUtc(),
      );
      // Also exercise calendar selection through the repository, not only the resolver.
      await f.song('a');
      await f.history(
        'inside',
        'a',
        ms: 50,
        started: DateTime(2026, 12, 31, 12),
      );
      expect(
        (await stats.load(period: StatisticsPeriod.week)).totalCountedPlays,
        1,
      );
      expect(
        (await stats.load(period: StatisticsPeriod.year)).totalCountedPlays,
        0,
      );
    },
  );

  test('calendar boundaries survive DST weeks as calendar dates', () {
    for (final local in [DateTime(2026, 3, 8, 12), DateTime(2026, 11, 1, 12)]) {
      f.now = local;
      final week = stats.rangeFor(StatisticsPeriod.week);
      final monday = DateTime(
        local.year,
        local.month,
        local.day - (local.weekday - 1),
      );
      final nextMonday = DateTime(
        local.year,
        local.month,
        local.day - (local.weekday - 1) + 7,
      );
      expect(week.start, monday.toUtc());
      expect(week.end, nextMonday.toUtc());
    }
  });

  test('recent history defaults to 20, supports a smaller limit and orders timestamps', () async {
    await f.song('a');
    for (var i = 0; i < 25; i++) {
      await f.history(
        'h-$i',
        'a',
        ms: i,
        started: f.now.add(Duration(seconds: i)),
      );
    }
    final result = await stats.load();
    expect(result.recentHistory, hasLength(20));
    expect(result.recentHistory.first.historyId, 'h-24');
    expect(
      (await stats.load(recentLimit: 2)).recentHistory.map((h) => h.historyId),
      ['h-24', 'h-23'],
    );
  });

  test('invalid ranges, limits and missing songs fail without inventing references', () async {
    final invalid = isA<ControllerFailure>().having(
      (e) => e.kind,
      'kind',
      ControllerFailureKind.invalidInput,
    );
    for (final limit in [0, -1]) {
      await expectLater(stats.load(recentLimit: limit), throwsA(invalid));
    }
    await expectLater(
      stats.load(period: StatisticsPeriod.custom),
      throwsA(invalid),
    );
    await expectLater(
      stats.load(period: StatisticsPeriod.custom, start: f.now, end: f.now),
      throwsA(invalid),
    );
    await expectLater(stats.load(start: f.now), throwsA(invalid));
    await expectLater(stats.load(songId: ' '), throwsA(invalid));
    await expectLater(
      stats.load(songId: 'missing'),
      throwsA(
        isA<ControllerFailure>().having(
          (e) => e.kind,
          'kind',
          ControllerFailureKind.notFound,
        ),
      ),
    );
    await expectLater(
      f.history('orphan', 'missing', ms: 1),
      throwsA(isA<DatabaseException>()),
    );
    await f.song('a');
    await expectLater(
      f.history('negative', 'a', ms: -1),
      throwsA(isA<DatabaseException>()),
    );
    expect((await stats.load()).totalCountedPlays, 0);
  });
}
