import 'dart:io';

import 'package:cta2000/backend/models/music_models.dart';
import 'package:cta2000/backend/services/database/local_music_repository.dart';
import 'package:cta2000/backend/services/database/music_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

final date = DateTime.utc(2026, 11, 17);
Song song(String id, {String? lyrics}) => Song(
  songId: id,
  title: 'Test $id',
  artistName: 'Test artist',
  durationMs: 1000,
  audioFormat: 'MP3',
  filePath: 'assets/audio/$id.mp3',
  dateAdded: date,
  lyricsText: lyrics,
);
Playlist playlist(String id) => Playlist(
  playlistId: id,
  name: 'Collection',
  createdAt: date,
  updatedAt: date,
);
PlaylistEntry entry(String id, String songId, int position) => PlaylistEntry(
  entryId: id,
  playlistId: 'p',
  songId: songId,
  position: position,
  addedAt: date,
);
ListeningHistory history(String id, {bool counted = true}) => ListeningHistory(
  historyId: id,
  songId: 's',
  startedAt: date,
  listenedMs: 1000,
  countedPlay: counted,
);

void main() {
  sqfliteFfiInit();
  late MusicDatabase database;
  late LocalMusicRepository repository;

  setUp(() async {
    database = MusicDatabase(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    repository = LocalMusicRepository(await database.open());
  });
  tearDown(() => database.close());

  test('models round-trip all approved columns, UTC dates and nulls', () {
    final s = song('s', lyrics: 'Manual lyrics');
    expect(Song.fromMap(s.toMap()).toMap(), s.toMap());
    expect(Song.fromMap(s.toMap()).dateAdded.isUtc, isTrue);
    final p = playlist('p');
    expect(Playlist.fromMap(p.toMap()).toMap(), p.toMap());
    final e = entry('e', 's', 0);
    expect(PlaylistEntry.fromMap(e.toMap()).toMap(), e.toMap());
    for (final counted in [true, false]) {
      final h = history('h', counted: counted);
      expect(ListeningHistory.fromMap(h.toMap()).toMap(), h.toMap());
    }
    final completed = ListeningHistory(
      historyId: 'h',
      songId: 's',
      startedAt: date,
      endedAt: date.add(const Duration(seconds: 2)),
      listenedMs: 1000,
      countedPlay: true,
    );
    expect(
      ListeningHistory.fromMap(completed.toMap()).toMap(),
      completed.toMap(),
    );
  });

  test(
    'exactly four approved tables, version and foreign keys enabled',
    () async {
      final db = await database.open();
      expect(await db.getVersion(), 1);
      expect(
        (await db.rawQuery('PRAGMA foreign_keys')).single.values.single,
        1,
      );
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' AND name != 'android_metadata'",
      );
      expect(tables.map((r) => r['name']).toSet(), {
        'SONG',
        'PLAYLIST',
        'PLAYLIST_ENTRY',
        'LISTENING_HISTORY',
      });
      expect(identical(await database.open(), db), isTrue);
    },
  );

  test('song CRUD and lyrics save, replace and clear', () async {
    await repository.songs.insert(song('s'));
    expect(await repository.getLyrics('s'), isNull);
    expect(await repository.updateLyrics('s', 'First\nSecond'), 1);
    expect(await repository.getLyrics('s'), 'First\nSecond');
    await repository.updateLyrics('s', 'Edited');
    expect(await repository.getLyrics('s'), 'Edited');
    await repository.updateLyrics('s', null);
    expect(await repository.getLyrics('s'), isNull);
    await repository.songs.update(song('s', lyrics: 'Restored'));
    expect((await repository.getSongs()).single.lyricsText, 'Restored');
    expect(await repository.songs.delete('s'), 1);
    expect(await repository.songs.find('s'), isNull);
    expect(await repository.updateLyrics('missing', 'x'), 0);
  });

  test(
    'playlist, entry and history CRUD with duplicate song occurrences',
    () async {
      await repository.songs.insert(song('s'));
      await repository.playlists.insert(playlist('p'));
      await repository.playlists.update(
        Playlist(
          playlistId: 'p',
          name: 'Updated',
          description: 'Description',
          createdAt: date,
          updatedAt: date,
        ),
      );
      expect((await repository.playlists.find('p'))!.name, 'Updated');
      expect(await repository.getPlaylists(), hasLength(1));
      await repository.entries.insert(entry('e1', 's', 2));
      await repository.entries.insert(entry('e2', 's', 0));
      expect((await repository.getEntries('p')).map((e) => e.entryId), [
        'e2',
        'e1',
      ]);
      await repository.entries.update(entry('e1', 's', 1));
      expect((await repository.entries.find('e1'))!.position, 1);
      expect(await repository.entries.list(), hasLength(2));
      await repository.history.insert(history('h'));
      await repository.history.update(history('h', counted: false));
      expect((await repository.history.find('h'))!.countedPlay, isFalse);
      expect(await repository.history.list(), hasLength(1));
      await repository.history.delete('h');
      await repository.entries.delete('e2');
      expect(await repository.history.find('h'), isNull);
      expect(await repository.entries.find('e2'), isNull);
      await repository.playlists.delete('p');
      expect(await repository.playlists.find('p'), isNull);
      expect(await repository.entries.list(), isEmpty);
      expect(await repository.songs.find('s'), isNotNull);
    },
  );

  test('song deletion cascades without deleting the playlist', () async {
    await repository.songs.insert(song('s'));
    await repository.playlists.insert(playlist('p'));
    await repository.entries.insert(entry('e', 's', 0));
    await repository.history.insert(history('h'));
    await repository.songs.delete('s');
    expect(await repository.entries.list(), isEmpty);
    expect(await repository.history.list(), isEmpty);
    expect(await repository.playlists.find('p'), isNotNull);
  });

  test(
    'foreign keys, duplicate IDs and invalid numeric values are rejected',
    () async {
      await expectLater(
        repository.entries.insert(entry('e', 'missing', 0)),
        throwsA(isA<DatabaseException>()),
      );
      await expectLater(
        repository.history.insert(history('h')),
        throwsA(isA<DatabaseException>()),
      );
      await repository.songs.insert(song('s'));
      await expectLater(
        repository.songs.insert(song('s')),
        throwsA(isA<DatabaseException>()),
      );
      await repository.playlists.insert(playlist('p'));
      await expectLater(
        repository.entries.insert(entry('e', 's', -1)),
        throwsA(isA<DatabaseException>()),
      );
      await expectLater(
        (await database.open()).insert('LISTENING_HISTORY', {
          ...history('bad').toMap(),
          'counted_play': 2,
        }),
        throwsA(isA<DatabaseException>()),
      );
    },
  );

  test('transactions commit or roll back all related writes', () async {
    await expectLater(
      repository.transaction((tx) async {
        await tx.songs.insert(song('rollback'));
        await tx.entries.insert(entry('invalid', 'rollback', 0));
      }),
      throwsA(isA<DatabaseException>()),
    );
    expect(await repository.songs.find('rollback'), isNull);
    await repository.transaction((tx) async {
      await tx.songs.insert(song('s'));
      await tx.playlists.insert(playlist('p'));
      await tx.entries.insert(entry('e', 's', 0));
    });
    expect(await repository.entries.list(), hasLength(1));
  });

  test('file-backed data and lyrics survive closing and reopening', () async {
    final directory = await Directory.systemTemp.createTemp('cta2000-db-');
    final path = '${directory.path}/library.db';
    final fileDb = MusicDatabase(factory: databaseFactoryFfi, path: path);
    try {
      final repo = LocalMusicRepository(await fileDb.open());
      await repo.songs.insert(song('persistent', lyrics: 'Saved offline'));
      await repo.playlists.insert(playlist('p'));
      await fileDb.close();
      final restored = LocalMusicRepository(await fileDb.open());
      expect(await restored.getLyrics('persistent'), 'Saved offline');
      expect(await restored.getPlaylists(), hasLength(1));
    } finally {
      await fileDb.close();
      await databaseFactoryFfi.deleteDatabase(path);
      await directory.delete();
    }
  });
}
