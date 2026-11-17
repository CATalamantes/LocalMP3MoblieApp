import 'dart:async';

import 'package:cta2000/backend/controllers/controller_state.dart';
import 'package:cta2000/backend/controllers/library_controller.dart';
import 'package:cta2000/backend/controllers/lyrics_controller.dart';
import 'package:cta2000/backend/controllers/playback_controller.dart';
import 'package:cta2000/backend/controllers/playlist_controller.dart';
import 'package:cta2000/backend/controllers/statistics_controller.dart';
import 'package:cta2000/backend/models/listening_statistics.dart';
import 'package:cta2000/backend/models/music_models.dart';
import 'package:cta2000/backend/services/database/local_music_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common/sqlite_api.dart';

import 'support/controller_fixture.dart';

/// Delays a completed real repository read, allowing later requests to finish
/// first without replacing SQLite integration with canned result fixtures.
class ReadGate {
  ReadGate(this.method, {this.fail = false});
  final String method;
  final bool fail;
  final started = Completer<void>();
  final release = Completer<void>();
  bool used = false;

  Future<T> hold<T>(String operation, T value) async {
    if (method == operation && !used) {
      used = true;
      started.complete();
      await release.future;
      if (fail) throw StateError('Injected deferred repository failure');
    }
    return value;
  }
}

class GatedSongs extends EntityStore<Song> {
  GatedSongs(Database db, this.gate)
    : super(db, 'SONG', 'song_id', Song.fromMap, (s) => s.toMap());
  final ReadGate gate;
  @override
  Future<Song?> find(String id) async =>
      gate.hold('song', await super.find(id));
}

class GatedRepository extends LocalMusicRepository {
  GatedRepository(Database super.db, this.gate) : _songs = GatedSongs(db, gate);
  final ReadGate gate;
  final GatedSongs _songs;
  @override
  EntityStore<Song> get songs => _songs;
  @override
  Future<List<Song>> getSongs() async =>
      gate.hold('library', await super.getSongs());
  @override
  Future<T> transaction<T>(
    Future<T> Function(LocalMusicRepository repository) action,
  ) async => gate.hold('playlist', await super.transaction(action));
  @override
  Future<ListeningStatistics> readStatistics({
    ListeningRange range = const ListeningRange(),
    int recentLimit = 20,
    String? songId,
  }) async => gate.hold(
    'statistics',
    await super.readStatistics(
      range: range,
      recentLimit: recentLimit,
      songId: songId,
    ),
  );
}

class Driver {
  const Driver(this.controller, this.first, this.newer, this.missing);
  final MusicController<Object?> controller;
  final Future<void> Function() first, newer, missing;
}

void main() {
  late ControllerFixture f;
  setUp(() async {
    f = ControllerFixture();
    await f.open();
    await f.song('a');
    await f.song('b');
    await f.playlist('p');
    await f.playlist('q');
  });
  tearDown(() => f.close());

  Driver driver(String type, ReadGate gate) {
    final repo = GatedRepository(f.db, gate);
    switch (type) {
      case 'library':
        final c = f.own(LibraryController(repo));
        return Driver(
          c,
          () async {
            await c.loadCachedSongs();
          },
          () async {
            await c.loadSong('b');
          },
          () async {
            await c.loadSong('missing');
          },
        );
      case 'playlist':
        final c = f.own(PlaylistController(repo));
        return Driver(
          c,
          () async {
            await c.showPlaylist('p');
          },
          () async {
            await c.showPlaylist('q');
          },
          () async {
            await c.showPlaylist('missing');
          },
        );
      case 'lyrics':
        final c = f.own(LyricsController(repo));
        return Driver(
          c,
          () async {
            await c.loadManualLyrics('a');
          },
          () async {
            await c.loadManualLyrics('b');
          },
          () async {
            await c.loadManualLyrics('missing');
          },
        );
      case 'statistics':
        final c = f.own(StatisticsController(repo));
        return Driver(
          c,
          () async {
            await c.load(songId: 'a');
          },
          () async {
            await c.load(songId: 'b');
          },
          () async {
            await c.load(songId: 'missing');
          },
        );
      case 'playback':
        final c = f.own(PlaybackController(repo));
        return Driver(
          c,
          () => c.setQueue(['a']),
          () => c.setQueue(['b']),
          () => c.setQueue(['missing']),
        );
      default:
        throw StateError('Unknown controller');
    }
  }

  for (final type in [
    'library',
    'playlist',
    'lyrics',
    'statistics',
    'playback',
  ]) {
    final method = switch (type) {
      'lyrics' || 'playback' => 'song',
      _ => type,
    };
    for (final oldFails in [false, true]) {
      test(
        '$type ignores deferred ${oldFails ? 'failure' : 'success'} after a newer request',
        () async {
          final gate = ReadGate(method, fail: oldFails);
          final d = driver(type, gate);
          var notifications = 0;
          d.controller.addListener(() => notifications++);
          final older = d.first();
          final checked = oldFails
              ? expectLater(older, throwsA(isA<ControllerFailure>()))
              : older;
          await gate.started.future;
          await d.newer();
          final newest = d.controller.state;
          final count = notifications;
          gate.release.complete();
          await checked;
          expect(identical(d.controller.state, newest), isTrue);
          expect(notifications, count);
        },
      );

      test(
        '$type ignores deferred ${oldFails ? 'failure' : 'success'} after disposal and rejects new work',
        () async {
          final gate = ReadGate(method, fail: oldFails);
          final d = driver(type, gate);
          var notifications = 0;
          d.controller.addListener(() => notifications++);
          final older = d.first();
          final checked = oldFails
              ? expectLater(older, throwsA(isA<ControllerFailure>()))
              : older;
          await gate.started.future;
          final before = d.controller.state;
          d.controller.dispose();
          final count = notifications;
          gate.release.complete();
          await checked;
          expect(identical(d.controller.state, before), isTrue);
          expect(notifications, count);
          await expectLater(
            d.newer(),
            throwsA(
              isA<ControllerFailure>().having(
                (e) => e.kind,
                'kind',
                ControllerFailureKind.disposed,
              ),
            ),
          );
          expect(notifications, count);
        },
      );
    }

    test('$type late success cannot clear a newer error', () async {
      final gate = ReadGate(method);
      final d = driver(type, gate);
      final older = d.first();
      await gate.started.future;
      await expectLater(d.missing(), throwsA(isA<ControllerFailure>()));
      final newest = d.controller.state;
      gate.release.complete();
      await older;
      expect(identical(d.controller.state, newest), isTrue);
      expect(d.controller.state.status, ControllerStatus.error);
    });
  }

  test(
    'synchronous library search supersedes pending loads and their errors',
    () async {
      final gate = ReadGate('library', fail: true);
      final c = f.own(LibraryController(GatedRepository(f.db, gate)));
      final old = expectLater(
        c.loadCachedSongs(),
        throwsA(isA<ControllerFailure>()),
      );
      await gate.started.future;
      c.search('new query');
      final newer = c.state;
      gate.release.complete();
      await old;
      expect(identical(c.state, newer), isTrue);
      expect(c.state.data.query, 'new query');
    },
  );

  test('clearing queue invalidates pending queue selection', () async {
    final gate = ReadGate('song');
    final c = f.own(PlaybackController(GatedRepository(f.db, gate)));
    final old = c.setQueue(['a']);
    await gate.started.future;
    c.clearQueue();
    final newer = c.state;
    gate.release.complete();
    await old;
    expect(identical(c.state, newer), isTrue);
    expect(c.state.data.queue, isEmpty);
  });

  test('queued mutations cannot start after disposal; an active transaction may finish safely', () async {
    final gate = ReadGate('playlist');
    var id = 0;
    final c = f.own(
      PlaylistController(
        GatedRepository(f.db, gate),
        idFactory: () => 'queued-${++id}',
      ),
    );
    final first = c.createPlaylist('First');
    await gate.started.future;
    final second = expectLater(
      c.createPlaylist('Never starts'),
      throwsA(
        isA<ControllerFailure>().having(
          (e) => e.kind,
          'kind',
          ControllerFailureKind.disposed,
        ),
      ),
    );
    var notifications = 0;
    c.addListener(() => notifications++);
    c.dispose();
    gate.release.complete();
    await first;
    await second;
    expect(notifications, 0);
    expect(
      (await f.repository.getPlaylists())
          .where((p) => p.playlistId.startsWith('queued-'))
          .map((p) => p.name),
      ['First'],
    );
  });
}
