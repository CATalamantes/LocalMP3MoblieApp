import 'dart:io';

import 'package:cta2000/backend/app_dependencies.dart';

import 'package:cta2000/backend/controllers/controller_state.dart';
import 'package:cta2000/backend/controllers/library_controller.dart';
import 'package:cta2000/backend/controllers/lyrics_controller.dart';
import 'package:cta2000/backend/controllers/playback_controller.dart';
import 'package:cta2000/backend/controllers/playlist_controller.dart';
import 'package:cta2000/backend/models/music_models.dart';
import 'package:cta2000/backend/services/database/local_music_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/controller_fixture.dart';

Matcher failure(ControllerFailureKind kind) =>
    isA<ControllerFailure>().having((e) => e.kind, 'kind', kind);

void main() {
  late ControllerFixture f;
  late LibraryController library;
  late PlaylistController playlists;
  late LyricsController lyrics;
  late PlaybackController playback;

  setUp(() async {
    f = ControllerFixture();
    await f.open();
    library = f.own(LibraryController(f.repository, clock: f.clock));
    playlists = f.own(
      PlaylistController(f.repository, clock: f.clock, idFactory: f.id),
    );
    lyrics = f.own(LyricsController(f.repository));
    playback = f.own(PlaybackController(f.repository));
  });
  tearDown(() => f.close());

  test('application composition provides working controllers and disposes their lifecycle', () async {
    final app = await AppDependencies.create(
      database: f.database,
      enableLocalPlayback: false,
    );
    await f.song('a');
    final p = await app.playlists.createPlaylist('Composed');
    await app.playlists.addSong(p.playlistId, 'a');
    await app.lyrics.saveManualLyrics('a', 'Shared repository');
    expect((await app.library.loadSong('a')).lyricsText, 'Shared repository');
    await app.playback.setQueue(['a']);
    expect((await app.statistics.load()).totalCountedPlays, 0);
    expect(app.connections.snapshot.hardwareAuthenticated, isFalse);
    await app.close();
    await expectLater(
      app.library.loadCachedSongs(),
      throwsA(failure(ControllerFailureKind.disposed)),
    );
    await expectLater(
      app.playlists.loadPlaylists(),
      throwsA(failure(ControllerFailureKind.disposed)),
    );
    await expectLater(
      app.lyrics.loadManualLyrics('a'),
      throwsA(failure(ControllerFailureKind.disposed)),
    );
    await expectLater(
      app.statistics.load(),
      throwsA(failure(ControllerFailureKind.disposed)),
    );
    await expectLater(
      app.playback.setQueue(['a']),
      throwsA(failure(ControllerFailureKind.disposed)),
    );
  });

  test('library empty, loading, success, title/artist search and deterministic sorting', () async {
    final statuses = <ControllerStatus>[];
    library.addListener(() => statuses.add(library.state.status));
    expect(await library.loadCachedSongs(), isEmpty);
    expect(statuses, [ControllerStatus.loading, ControllerStatus.empty]);
    await f.song('b', title: 'Beta', artist: 'Second');
    await f.song(
      'c',
      title: 'Alpha',
      artist: 'First',
      added: f.now.add(const Duration(days: 1)),
    );
    await f.song('a', title: 'alpha', artist: 'First');
    await library.refreshLibrary();
    expect(library.state.status, ControllerStatus.success);
    expect(library.state.data.visibleSongs.map((s) => s.songId), [
      'a',
      'c',
      'b',
    ]);
    expect(library.search(' ALPHA ').map((s) => s.songId), ['a', 'c']);
    expect(library.search('second').single.songId, 'b');
    expect(library.search('absent'), isEmpty);
    expect(library.state.status, ControllerStatus.empty);
    library.search('');
    library.sortBy(SongSort.artist);
    expect(library.state.data.visibleSongs.map((s) => s.songId), [
      'a',
      'c',
      'b',
    ]);
    library.sortBy(SongSort.dateAdded);
    expect(library.state.data.visibleSongs.first.songId, 'c');
    expect((await library.loadSong('b')).songId, 'b');
    expect(library.state.data.selectedSong!.songId, 'b');
    expect(() => library.state.data.songs.clear(), throwsUnsupportedError);
    expect(
      () => library.state.data.visibleSongs.clear(),
      throwsUnsupportedError,
    );
  });

  test(
    'metadata editing preserves identity, file, added date and exact lyrics',
    () async {
      await f.song('a', lyrics: 'Original\n歌詞', artwork: 'old.png');
      final old = (await f.repository.songs.find('a'))!;
      final updated = await library.updateMetadata(
        'a',
        const SongMetadataUpdate(
          title: ' New title ',
          artistName: 'New artist',
          durationMs: 3000,
          audioFormat: 'FLAC',
        ),
      );
      expect(updated.title, 'New title');
      expect(updated.artistName, 'New artist');
      expect(updated.durationMs, 3000);
      expect(updated.audioFormat, 'FLAC');
      expect(updated.filePath, old.filePath);
      expect(updated.dateAdded, old.dateAdded);
      expect(updated.lyricsText, old.lyricsText);
      expect(updated.artworkPath, 'old.png');
      expect(
        (await library.updateMetadata(
          'a',
          const SongMetadataUpdate(artworkPath: 'new.png'),
        )).artworkPath,
        'new.png',
      );
      expect(
        (await library.updateMetadata(
          'a',
          const SongMetadataUpdate(clearArtwork: true),
        )).artworkPath,
        isNull,
      );
    },
  );

  test('invalid library operations expose meaningful errors and preserve persisted data', () async {
    await f.song('a');
    for (final update in [
      const SongMetadataUpdate(title: ' '),
      const SongMetadataUpdate(durationMs: -1),
      const SongMetadataUpdate(audioFormat: ''),
      const SongMetadataUpdate(artworkPath: 'x', clearArtwork: true),
    ]) {
      await expectLater(
        library.updateMetadata('a', update),
        throwsA(failure(ControllerFailureKind.invalidInput)),
      );
    }
    await expectLater(
      library.loadSong(' '),
      throwsA(failure(ControllerFailureKind.invalidInput)),
    );
    await expectLater(
      library.loadSong('missing'),
      throwsA(failure(ControllerFailureKind.notFound)),
    );
    await expectLater(
      library.updateMetadata('missing', const SongMetadataUpdate(title: 'x')),
      throwsA(failure(ControllerFailureKind.notFound)),
    );
    await expectLater(
      library.removeSong('missing'),
      throwsA(failure(ControllerFailureKind.notFound)),
    );
    expect(library.state.error!.kind, ControllerFailureKind.notFound);
    expect((await f.repository.songs.find('a'))!.title, 'a');
  });

  Future<void> seedDeletion() async {
    for (final id in ['a', 'b', 'c']) {
      await f.song(id);
    }
    for (final p in ['p', 'q']) {
      await f.playlist(p);
      await f.entry('$p-0', p, 'a', 0);
      await f.entry('$p-1', p, 'b', 4);
      await f.entry('$p-2', p, 'a', 9);
      await f.entry('$p-3', p, 'c', 12);
    }
    await f.history('history', 'a', ms: 9000);
  }

  test('song deletion atomically cascades and normalizes every affected playlist, preserving files', () async {
    final directory = await Directory.systemTemp.createTemp(
      'cta2000-preserve-',
    );
    final file = File('${directory.path}/file-preservation-sentinel.bin');
    try {
      await file.writeAsBytes([
        1,
        2,
        3,
      ]); // File-preservation sentinel, not playable test audio.
      await seedDeletion();
      await library.updateMetadata(
        'a',
        const SongMetadataUpdate(title: 'Delete metadata only'),
      );
      final original = (await f.repository.songs.find('a'))!;
      await f.repository.songs.update(
        Song(
          songId: original.songId,
          title: original.title,
          artistName: original.artistName,
          durationMs: original.durationMs,
          audioFormat: original.audioFormat,
          filePath: file.path,
          dateAdded: original.dateAdded,
          artworkPath: original.artworkPath,
          lyricsText: original.lyricsText,
        ),
      );
      final updated = f.now.add(const Duration(days: 1));
      f.now = updated;
      await library.removeSong('a');
      expect(await f.repository.songs.find('a'), isNull);
      expect(await f.repository.history.list(), isEmpty);
      for (final p in ['p', 'q']) {
        final entries = await f.repository.getEntries(p);
        expect(entries.map((e) => e.songId), ['b', 'c']);
        expect(entries.map((e) => e.position), [0, 1]);
        expect((await f.repository.playlists.find(p))!.updatedAt, updated);
      }
      expect(await file.readAsBytes(), [1, 2, 3]);
    } finally {
      if (await file.exists()) await file.delete();
      await directory.delete();
    }
  });

  test('failure during second playlist normalization rolls back deletion, cascades and all updates', () async {
    await seedDeletion();
    final before = (await f.repository.entries.list())
        .map((e) => e.toMap())
        .toList();
    await f.db.execute(
      """CREATE TEMP TRIGGER fail_second_playlist BEFORE UPDATE OF position ON PLAYLIST_ENTRY
      WHEN OLD.playlist_id = 'q' BEGIN SELECT RAISE(ABORT, 'injected normalization failure'); END""",
    );
    f.now = f.now.add(const Duration(days: 2));
    await expectLater(
      library.removeSong('a'),
      throwsA(failure(ControllerFailureKind.storage)),
    );
    expect(await f.repository.songs.find('a'), isNotNull);
    expect(await f.repository.history.list(), hasLength(1));
    expect(
      (await f.repository.entries.list()).map((e) => e.toMap()).toList(),
      before,
    );
    expect(
      (await f.repository.playlists.find('p'))!.updatedAt,
      DateTime.utc(2026, 11, 17),
    );
  });

  test('playlists create, retrieve, rename, describe, clear and delete without removing songs', () async {
    expect(await playlists.loadPlaylists(), isEmpty);
    final p = await playlists.createPlaylist(
      ' Collection ',
      description: 'Description',
    );
    expect(p.name, 'Collection');
    expect(p.createdAt, f.now);
    f.now = f.now.add(const Duration(hours: 1));
    expect(
      (await playlists.renamePlaylist(p.playlistId, 'Changed')).name,
      'Changed',
    );
    expect(
      (await playlists.updateDescription(p.playlistId, 'Updated')).description,
      'Updated',
    );
    expect(
      (await playlists.updateDescription(p.playlistId, null)).description,
      isNull,
    );
    expect((await playlists.showPlaylist(p.playlistId)).updatedAt, f.now);
    await f.song('a');
    await playlists.addSong(p.playlistId, 'a');
    expect(playlists.state.data.songs.single.songId, 'a');
    expect(() => playlists.state.data.entries.clear(), throwsUnsupportedError);
    await playlists.deletePlaylist(p.playlistId);
    expect(await f.repository.entries.list(), isEmpty);
    expect(await f.repository.songs.find('a'), isNotNull);
    expect(playlists.state.data.selectedPlaylist, isNull);
  });

  test('playlist occurrences are independent, reorder preserves identity, removal closes gaps', () async {
    await f.song('a');
    await f.song('b');
    final p = await playlists.createPlaylist('Queue');
    final first = await playlists.addSong(p.playlistId, 'a');
    final second = await playlists.addSong(p.playlistId, 'a');
    final third = await playlists.addSong(p.playlistId, 'b');
    expect(first.entryId, isNot(second.entryId));
    expect(playlists.state.data.songs.map((s) => s.songId), ['a', 'a', 'b']);
    await playlists.reorder(third.entryId, 0);
    expect(playlists.state.data.entries.map((e) => e.entryId), [
      third.entryId,
      first.entryId,
      second.entryId,
    ]);
    await playlists.removeEntry(first.entryId);
    expect(playlists.state.data.entries.map((e) => e.entryId), [
      third.entryId,
      second.entryId,
    ]);
    expect(playlists.state.data.entries.map((e) => e.position), [0, 1]);
    expect(await f.repository.entries.find(second.entryId), isNotNull);
  });

  test('playlist validation rejects missing references and invalid reorder positions', () async {
    await expectLater(
      playlists.createPlaylist(' '),
      throwsA(failure(ControllerFailureKind.invalidInput)),
    );
    await expectLater(
      playlists.showPlaylist('missing'),
      throwsA(failure(ControllerFailureKind.notFound)),
    );
    await expectLater(
      playlists.showPlaylist(''),
      throwsA(failure(ControllerFailureKind.invalidInput)),
    );
    await expectLater(
      playlists.renamePlaylist('missing', 'name'),
      throwsA(failure(ControllerFailureKind.notFound)),
    );
    final p = await playlists.createPlaylist('P');
    await f.song('a');
    await expectLater(
      playlists.addSong(p.playlistId, 'missing'),
      throwsA(failure(ControllerFailureKind.notFound)),
    );
    await expectLater(
      playlists.addSong('missing', 'a'),
      throwsA(failure(ControllerFailureKind.notFound)),
    );
    final e = await playlists.addSong(p.playlistId, 'a');
    for (final index in [-1, 1]) {
      await expectLater(
        playlists.reorder(e.entryId, index),
        throwsA(failure(ControllerFailureKind.invalidInput)),
      );
    }
    await expectLater(
      playlists.removeEntry('missing'),
      throwsA(failure(ControllerFailureKind.notFound)),
    );
    expect((await f.repository.getEntries(p.playlistId)).single.position, 0);
  });

  test(
    'reordering rollback preserves positions and playlist timestamp',
    () async {
      await f.song('a');
      final p = await playlists.createPlaylist('P');
      final a = await playlists.addSong(p.playlistId, 'a');
      final b = await playlists.addSong(p.playlistId, 'a');
      await f.db.execute(
        """CREATE TEMP TRIGGER fail_reorder BEFORE UPDATE OF position ON PLAYLIST_ENTRY
      WHEN NEW.position = 1 BEGIN SELECT RAISE(ABORT, 'injected reorder failure'); END""",
      );
      final before = (await f.repository.getEntries(p.playlistId))
          .map((e) => e.toMap())
          .toList();
      f.now = f.now.add(const Duration(days: 1));
      await expectLater(
        playlists.reorder(b.entryId, 0),
        throwsA(failure(ControllerFailureKind.storage)),
      );
      expect(
        (await f.repository.getEntries(p.playlistId))
            .map((e) => e.toMap())
            .toList(),
        before,
      );
      expect((await f.repository.entries.find(a.entryId))!.position, 0);
      expect(
        (await f.repository.playlists.find(p.playlistId))!.updatedAt,
        p.updatedAt,
      );
    },
  );

  test(
    'concurrent playlist mutations serialize, preserving every occurrence',
    () async {
      await f.song('a');
      final p = await playlists.createPlaylist('P');
      final results = await Future.wait(
        List.generate(5, (_) => playlists.addSong(p.playlistId, 'a')),
      );
      expect(results.map((e) => e.entryId).toSet(), hasLength(5));
      expect(playlists.state.data.entries.map((e) => e.position), [
        0,
        1,
        2,
        3,
        4,
      ]);
    },
  );

  test('lyrics null differs from missing song; exact text, empty text and clearing are supported', () async {
    await f.song('a');
    expect(await lyrics.loadManualLyrics('a'), isNull);
    expect(lyrics.state.data.song!.songId, 'a');
    const text = '  First line\n歌詞 🎵\nPunctuation: “Hello!”\n\n';
    await lyrics.saveManualLyrics('a', text);
    expect(await lyrics.loadManualLyrics('a'), text);
    await lyrics.saveManualLyrics('a', '');
    expect(await lyrics.loadManualLyrics('a'), '');
    await lyrics.clearManualLyrics('a');
    expect(await lyrics.loadManualLyrics('a'), isNull);
    await expectLater(
      lyrics.loadManualLyrics('missing'),
      throwsA(failure(ControllerFailureKind.notFound)),
    );
    await expectLater(
      lyrics.saveManualLyrics('missing', text),
      throwsA(failure(ControllerFailureKind.notFound)),
    );
    await expectLater(
      lyrics.clearManualLyrics(' '),
      throwsA(failure(ControllerFailureKind.invalidInput)),
    );
  });

  test(
    'lyrics controller data persists across actual database reopen',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'cta2000-controller-',
      );
      final path = '${directory.path}/library.db';
      final persistent = ControllerFixture();
      await persistent.open(path: path);
      try {
        await persistent.song('a');
        final writer = persistent.own(LyricsController(persistent.repository));
        await writer.saveManualLyrics('a', 'Saved\n持続');
        writer.dispose();
        await persistent.database.close();
        final reopened = LocalMusicRepository(await persistent.database.open());
        final reader = persistent.own(LyricsController(reopened));
        expect(await reader.loadManualLyrics('a'), 'Saved\n持続');
      } finally {
        await persistent.close();
        await databaseFactoryFfi.deleteDatabase(path);
        await directory.delete();
      }
    },
  );

  test(
    'queue wraps in both directions and preserves duplicate occurrences',
    () async {
      for (final id in ['a', 'b']) {
        await f.song(id);
      }
      await playback.setQueue(['a', 'b', 'a']);
      expect(playback.state.data.queueIndex, 0);
      expect((await playback.previous())!.songId, 'a');
      expect(playback.state.data.queueIndex, 2);
      await playback.next();
      expect(playback.state.data.queueIndex, 0);
      await playback.next();
      expect(playback.state.data.selectedSong!.songId, 'b');
      await playback.selectAt(2);
      expect(playback.state.data.queueIndex, 2);
      expect(() => playback.state.data.queue.clear(), throwsUnsupportedError);
      await playback.selectSong('b');
      await playback.next();
      expect(playback.state.data.queueIndex, 0);
      await playback.previous();
      expect(playback.state.data.queueIndex, 0);
      expect(playback.state.data.isPlaying, isFalse);
    },
  );

  test('queue validation and unavailable audio never create active playback or history', () async {
    expect(await playback.next(), isNull);
    expect(await playback.previous(), isNull);
    await playback.setQueue([]);
    expect(playback.state.data.selectedSong, isNull);
    await f.song('a');
    await f.song('b');
    await playback.setQueue(['a', 'b']);
    for (final index in [-1, 2]) {
      await expectLater(
        playback.selectAt(index),
        throwsA(failure(ControllerFailureKind.invalidInput)),
      );
    }
    await expectLater(
      playback.setQueue([], initialIndex: 1),
      throwsA(failure(ControllerFailureKind.invalidInput)),
    );
    await expectLater(
      playback.setQueue(['missing']),
      throwsA(failure(ControllerFailureKind.notFound)),
    );
    await f.repository.songs.delete('b');
    await expectLater(
      playback.next(),
      throwsA(failure(ControllerFailureKind.notFound)),
    );
    expect(playback.state.data.queueIndex, 0);
    for (final operation in [
      playback.play,
      playback.pause,
      () => playback.setVolume(0.5),
    ]) {
      await expectLater(
        operation(),
        throwsA(failure(ControllerFailureKind.unavailable)),
      );
      expect(playback.state.data.isPlaying, isFalse);
    }
    expect(await f.repository.history.list(), isEmpty);
    playback.clearQueue();
    expect(playback.state.data.selectedSong, isNull);
  });
}
