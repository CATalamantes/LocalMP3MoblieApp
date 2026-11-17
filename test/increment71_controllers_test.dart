import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cta2000/backend/controllers/controller_state.dart';
import 'package:cta2000/backend/controllers/library_controller.dart';
import 'package:cta2000/backend/controllers/playback_controller.dart';
import 'package:cta2000/backend/controllers/playlist_controller.dart';
import 'package:cta2000/backend/services/artwork/artwork_service.dart';
import 'package:cta2000/backend/services/artwork/artwork_store.dart';
import 'package:cta2000/backend/services/artwork/native_artwork_store.dart';
import 'package:cta2000/backend/models/music_models.dart';
import 'package:cta2000/backend/services/database/local_music_repository.dart';
import 'package:cta2000/backend/services/audio/audio_service.dart';
import 'package:cta2000/backend/services/audio/audio_source_resolver.dart';
import 'package:cta2000/backend/services/audio/local_audio_service.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/audio_fakes.dart';
import 'support/controller_fixture.dart';

class MemoryArtworkStore implements ArtworkStore {
  final images = <String, Uint8List>{};
  bool failWrite = false, failDelete = false;
  @override
  Future<void> write(String id, Uint8List bytes) async {
    if (failWrite) throw StateError('Injected storage error');
    images[id] = Uint8List.fromList(bytes);
  }

  @override
  Future<Uint8List?> read(String id) async => images[id];
  @override
  Future<void> delete(String id) async {
    if (failDelete) throw StateError('Injected cleanup error');
    images.remove(id);
  }
}

class GatedArtworkStore extends MemoryArtworkStore {
  final started = Completer<void>();
  final release = Completer<void>();
  @override
  Future<void> write(String id, Uint8List bytes) async {
    started.complete();
    await release.future;
    await super.write(id, bytes);
  }
}

class RefreshFailureRepository extends LocalMusicRepository {
  RefreshFailureRepository(super.db);
  @override
  Future<List<Song>> getSongs() async =>
      throw StateError('Injected postcommit read failure');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ControllerFixture f;
  late ScriptedAudioEngine engine;
  late PlaybackController playback;
  late PlaylistController playlists;
  late MemoryArtworkStore images;
  late ArtworkService artwork;
  late LibraryController library;
  late ArtworkDraft image;
  setUp(() async {
    f = ControllerFixture();
    await f.open();
    for (final id in ['a', 'b', 'c', 'd', 'e', 'f']) {
      await f.song(
        id,
        filePath: 'asset:///assets/audio/$id.mp3',
        lyrics: 'Protected lyrics',
      );
    }
    await f.playlist('playlist');
    engine = ScriptedAudioEngine();
    playback = PlaybackController(
      f.repository,
      audio: LocalAudioService(
        resolver: AudioSourceResolver(assetExists: (_) async => true),
        engineFactory: () => engine,
      ),
    );
    playlists = f.own(
      PlaylistController(f.repository, clock: f.clock, idFactory: f.id),
    );
    images = MemoryArtworkStore();
    artwork = ArtworkService(store: images);
    library = f.own(LibraryController(f.repository, artwork: artwork));
    image = ArtworkDraft(await File('web/icons/Icon-192.png').readAsBytes());
  });
  tearDown(() async {
    await playback.close();
    await f.close();
  });
  List<String> ids() => playback.state.data.queue.map((s) => s.songId).toList();

  test(
    'artwork dimension limits reject wide and tall images before persistence',
    () async {
      for (final size in [const ui.Size(4097, 1), const ui.Size(1, 4097)]) {
        final recorder = ui.PictureRecorder();
        ui.Canvas(recorder).drawRect(ui.Offset.zero & size, ui.Paint());
        final picture = recorder.endRecording();
        final oversized = await picture.toImage(
          size.width.toInt(),
          size.height.toInt(),
        );
        final png = (await oversized.toByteData(
          format: ui.ImageByteFormat.png,
        ))!.buffer.asUint8List();
        oversized.dispose();
        picture.dispose();
        await expectLater(
          artwork.validate(ArtworkDraft(png)),
          throwsA(isA<ArtworkFailure>()),
        );
      }
      expect(images.images, isEmpty);
    },
  );

  test('metadata-only queue supports serialized rapid duplicate additions and navigation', () async {
    final controller = f.own(PlaybackController(f.repository));
    await controller.setQueue(['e', 'f']);
    await Future.wait([
      controller.addToQueue('a'),
      controller.addToQueue('b'),
      controller.addToQueue('a'),
    ]);
    expect(controller.state.data.queue.map((s) => s.songId), [
      'e',
      'a',
      'b',
      'a',
      'f',
    ]);
    await controller.selectAt(2);
    await controller.playNext('c');
    expect(controller.state.data.queue.map((s) => s.songId), [
      'e',
      'a',
      'b',
      'c',
      'a',
      'f',
    ]);
    expect(controller.state.data.selectedSong!.songId, 'b');
    await expectLater(
      controller.setQueue(['a'], initialIndex: 9),
      throwsA(isA<ControllerFailure>()),
    );
    await controller.addToQueue('d');
    expect(controller.state.data.selectedSong!.songId, 'b');
  });

  test('metadata save receipt reports committed SQLite success despite final refresh failure', () async {
    final controller = f.own(
      LibraryController(RefreshFailureRepository(f.db), artwork: artwork),
    );
    final result = await controller.saveSongInformation(
      'a',
      const SongMetadataUpdate(title: 'Committed'),
    );
    expect(result.song.title, 'Committed');
    expect(result.warnings, isNotEmpty);
    expect((await f.repository.songs.find('a'))!.title, 'Committed');
    final deletion = await controller.deleteSongInformation('a');
    expect(deletion.warnings, isNotEmpty);
    expect(await f.repository.songs.find('a'), isNull);
  });

  test('disposal during image storage prevents metadata commit, removes new unreferenced art, and never notifies late', () async {
    final store = GatedArtworkStore();
    final controller = LibraryController(
      f.repository,
      artwork: ArtworkService(store: store),
    );
    var notifications = 0;
    controller.addListener(() => notifications++);
    final saving = controller.saveSongInformation(
      'a',
      SongMetadataUpdate(title: 'Stale', replacementArtwork: image),
    );
    final rejected = expectLater(saving, throwsA(isA<ControllerFailure>()));
    await store.started.future;
    controller.dispose();
    final count = notifications;
    store.release.complete();
    await rejected;
    expect(notifications, count);
    expect((await f.repository.songs.find('a'))!.title, 'a');
    expect(store.images, isEmpty);
  });

  for (final playing in [true, false]) {
    test(
      'FIFO priority, Play Next, remove and reorder preserve ${playing ? 'playing' : 'paused'} source and position',
      () async {
        await playback.setQueue([
          'a',
          'b',
          'c',
          'd',
          'e',
          'f',
        ], initialIndex: 4);
        if (playing) await playback.play();
        engine.event(position: const Duration(seconds: 3));
        final session = playback.state.data.audio.session;
        final occurrence = playback.state.data.occurrences[4].id;
        final commands = List.of(engine.commands);
        await playback.addToQueue('a');
        await playback.addToQueue('b');
        expect(ids(), ['a', 'b', 'c', 'd', 'e', 'a', 'b', 'f']);
        await playback.playNext('c');
        expect(ids().skip(4), ['e', 'c', 'a', 'b', 'f']);
        var data = playback.state.data;
        await playback.reorderUpcoming(
          data.occurrences[7].id,
          5,
          revision: data.revision,
        );
        expect(ids().skip(4), ['e', 'b', 'c', 'a', 'f']);
        data = playback.state.data;
        await playback.removeUpcoming(data.occurrences[6].id);
        expect(ids().skip(4), ['e', 'b', 'a', 'f']);
        expect(engine.commands, commands);
        expect(playback.state.data.audio.session, session);
        expect(playback.state.data.position, const Duration(seconds: 3));
        expect(playback.state.data.isPlaying, playing);
        expect(playback.state.data.playIntent, playing);
        expect(playback.state.data.occurrences[4].id, occurrence);
        expect((await f.repository.getEntries('playlist')), isEmpty);
        expect(await f.repository.history.list(), isEmpty);
      },
    );
  }
  test('empty additions prepare without autoplay; duplicate occurrences survive wrap', () async {
    await playback.playNext('a');
    expect(playback.state.data.audio.phase, AudioPhase.ready);
    expect(playback.state.data.isPlaying, false);
    await playback.addToQueue('a');
    expect(playback.state.data.occurrences.map((o) => o.id).toSet().length, 2);
    await playback.next();
    expect(playback.state.data.queueIndex, 1);
    await playback.next();
    expect(playback.state.data.queueIndex, 0);
    expect(playback.state.data.isPlaying, false);
  });
  test(
    'completion follows priority order then normal source and wraps',
    () async {
      await playback.setQueue(['e', 'f']);
      await playback.play();
      await playback.addToQueue('a');
      await playback.addToQueue('b');
      for (final expected in ['a', 'b', 'f', 'e']) {
        engine.event(phase: AudioPhase.completed, playing: false);
        for (
          var i = 0;
          i < 100 && playback.state.data.selectedSong?.songId != expected;
          i++
        ) {
          await Future<void>.delayed(const Duration(milliseconds: 2));
        }
        expect(playback.state.data.selectedSong!.songId, expected);
        // Wait for load/play command to finish before the next completion.
        for (var i = 0; i < 100 && !playback.state.data.isPlaying; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 2));
        }
        expect(playback.state.data.isPlaying, true);
      }
    },
  );
  test(
    'invalid, past, current and stale edits retain playing intent',
    () async {
      await playback.setQueue(['a', 'b', 'c'], initialIndex: 1);
      await playback.play();
      final data = playback.state.data;
      for (final occurrence in data.occurrences.take(2)) {
        await expectLater(
          playback.removeUpcoming(occurrence.id),
          throwsA(isA<QueueEditFailure>()),
        );
      }
      await expectLater(
        playback.removeUpcoming('missing'),
        throwsA(isA<QueueEditFailure>()),
      );
      await expectLater(
        playback.addToQueue('missing'),
        throwsA(isA<QueueEditFailure>()),
      );
      await expectLater(
        playback.reorderUpcoming(
          data.occurrences[2].id,
          0,
          revision: data.revision,
        ),
        throwsA(isA<QueueEditFailure>()),
      );
      await playback.addToQueue('d');
      await expectLater(
        playback.reorderUpcoming(
          data.occurrences[2].id,
          2,
          revision: data.revision,
        ),
        throwsA(isA<QueueEditFailure>()),
      );
      expect(playback.state.data.isPlaying, true);
      expect(playback.state.data.playIntent, true);
    },
  );
  test('rapid additions serialize FIFO and an old edit cannot change a new source queue', () async {
    await playback.setQueue(['e', 'f']);
    await Future.wait([
      playback.addToQueue('a'),
      playback.addToQueue('b'),
      playback.addToQueue('c'),
    ]);
    expect(ids(), ['e', 'a', 'b', 'c', 'f']);
    final obsolete = playback.addToQueue('d');
    final rejected = expectLater(obsolete, throwsA(isA<QueueEditFailure>()));
    await playback.setQueue(['b']);
    await rejected;
    expect(ids(), ['b']);
  });
  test('disposed queue edit cannot publish or notify', () async {
    await playback.setQueue(['a']);
    var notifications = 0;
    playback.addListener(() => notifications++);
    final edit = playback.addToQueue('b');
    final result = expectLater(edit, throwsA(isA<ControllerFailure>()));
    final count = notifications;
    await playback.close();
    await result;
    expect(notifications, count);
  });
  test(
    'metadata refresh changes all duplicate labels with no engine commands',
    () async {
      await playback.setQueue(['a', 'a']);
      await playback.play();
      final before = List.of(engine.commands);
      await library.updateMetadata(
        'a',
        const SongMetadataUpdate(title: 'Edited', artistName: 'New artist'),
      );
      playback.refreshMetadata(await f.repository.getSongs());
      expect(playback.state.data.queue.map((s) => s.title), [
        'Edited',
        'Edited',
      ]);
      expect(engine.commands, before);
    },
  );

  test('batch validates every reference, appends duplicates and persists normalized distinct occurrences', () async {
    await f.playlist('gaps');
    await f.entry('gap-first', 'gaps', 'a', 3);
    await f.entry('gap-last', 'gaps', 'b', 20);
    await playlists.addSongs('gaps', ['c', 'a']);
    expect((await f.repository.getEntries('gaps')).map((e) => e.songId), [
      'a',
      'b',
      'c',
      'a',
    ]);
    expect((await f.repository.getEntries('gaps')).map((e) => e.position), [
      0,
      1,
      2,
      3,
    ]);
    final added = await playlists.addSongs('playlist', ['a', 'b', 'a']);
    expect(added.map((e) => e.entryId).toSet().length, 3);
    expect(added.map((e) => e.position), [0, 1, 2]);
    await playlists.addSong('playlist', 'a');
    await playlists.showPlaylist('playlist');
    expect(playlists.state.data.songs.map((s) => s.songId), [
      'a',
      'b',
      'a',
      'a',
    ]);
    await expectLater(
      playlists.addSongs('playlist', ['b', 'missing']),
      throwsA(isA<ControllerFailure>()),
    );
    expect((await f.repository.getEntries('playlist')).length, 4);
    await expectLater(
      playlists.addSongs('missing', ['a']),
      throwsA(isA<ControllerFailure>()),
    );
    await expectLater(
      playlists.addSongs('playlist', []),
      throwsA(isA<ControllerFailure>()),
    );
  });
  test(
    'batch SQLite failure rolls back every insert and normalization',
    () async {
      await playlists.addSong('playlist', 'a');
      await f.db.execute(
        "CREATE TRIGGER reject_batch BEFORE INSERT ON PLAYLIST_ENTRY WHEN NEW.song_id = 'c' BEGIN SELECT RAISE(ABORT, 'injected'); END",
      );
      await expectLater(
        playlists.addSongs('playlist', ['b', 'c']),
        throwsA(isA<ControllerFailure>()),
      );
      expect((await f.repository.getEntries('playlist')).map((e) => e.songId), [
        'a',
      ]);
      expect((await f.repository.getEntries('playlist')).single.position, 0);
    },
  );

  test('title artist artwork edits preserve identity, lyrics, membership and history', () async {
    await playlists.addSongs('playlist', ['a', 'a']);
    await f.history('history', 'a', ms: 123);
    final old = (await f.repository.songs.find('a'))!;
    final result = await library.saveSongInformation(
      'a',
      SongMetadataUpdate(
        title: 'Changed',
        artistName: 'Changed artist',
        replacementArtwork: image,
      ),
    );
    final saved = result.song;
    expect(result.warnings, isEmpty);
    expect(saved.title, 'Changed');
    expect(saved.artistName, 'Changed artist');
    expect(saved.songId, old.songId);
    expect(saved.filePath, old.filePath);
    expect(saved.dateAdded, old.dateAdded);
    expect(saved.lyricsText, old.lyricsText);
    expect(saved.durationMs, old.durationMs);
    expect(saved.audioFormat, old.audioFormat);
    expect((await f.repository.getEntries('playlist')).length, 2);
    expect((await f.repository.history.list()).single.listenedMs, 123);
    expect(await artwork.read(saved.artworkPath), image.bytes);
    await library.updateMetadata('a', const SongMetadataUpdate(artistName: ''));
    expect(
      (await f.repository.songs.find('a'))!.artworkPath,
      saved.artworkPath,
    );
    await library.updateMetadata(
      'a',
      const SongMetadataUpdate(clearArtwork: true),
    );
    expect((await f.repository.songs.find('a'))!.artworkPath, isNull);
    expect(images.images, isEmpty);
  });
  test('shared managed artwork retained until final reference cleared; external paths never deleted', () async {
    final ref = (await library.saveSongInformation(
      'a',
      SongMetadataUpdate(replacementArtwork: image),
    )).song.artworkPath!;
    await library.updateMetadata('b', SongMetadataUpdate(artworkPath: ref));
    await library.updateMetadata(
      'a',
      const SongMetadataUpdate(clearArtwork: true),
    );
    expect(await artwork.read(ref), isNotNull);
    await library.removeSong('b');
    expect(await artwork.read(ref), isNull);
    await library.updateMetadata(
      'c',
      const SongMetadataUpdate(artworkPath: 'original/private.jpg'),
    );
    await library.updateMetadata(
      'c',
      const SongMetadataUpdate(clearArtwork: true),
    );
    expect(images.images, isEmpty);
  });
  test('image storage failure, invalid input and SQL failure leave old metadata intact and no orphan', () async {
    images.failWrite = true;
    await expectLater(
      library.saveSongInformation(
        'a',
        SongMetadataUpdate(title: 'Unsaved', replacementArtwork: image),
      ),
      throwsA(isA<ArtworkFailure>()),
    );
    images.failWrite = false;
    await expectLater(
      library.updateMetadata('a', const SongMetadataUpdate(title: ' ')),
      throwsA(isA<ControllerFailure>()),
    );
    await f.db.execute(
      "CREATE TRIGGER reject_metadata BEFORE UPDATE ON SONG BEGIN SELECT RAISE(ABORT, 'injected'); END",
    );
    await expectLater(
      library.saveSongInformation(
        'a',
        SongMetadataUpdate(replacementArtwork: image),
      ),
      throwsA(isA<ControllerFailure>()),
    );
    expect(images.images, isEmpty);
    expect((await f.repository.songs.find('a'))!.title, 'a');
  });
  test(
    'cleanup failure is a committed warning and safe cleanup retries later',
    () async {
      final ref = (await library.saveSongInformation(
        'a',
        SongMetadataUpdate(replacementArtwork: image),
      )).song.artworkPath!;
      images.failDelete = true;
      final result = await library.saveSongInformation(
        'a',
        const SongMetadataUpdate(title: 'Saved', clearArtwork: true),
      );
      expect(result.song.title, 'Saved');
      expect(result.warnings, isNotEmpty);
      expect((await f.repository.songs.find('a'))!.artworkPath, isNull);
      images.failDelete = false;
      await library.updateMetadata(
        'a',
        const SongMetadataUpdate(artistName: 'Saved artist'),
      );
      expect(await artwork.read(ref), isNull);
    },
  );
  test('image validation rejects unsupported, corrupt and oversized bytes; picker cancellation never writes', () async {
    for (final bytes in [
      Uint8List.fromList([1, 2, 3]),
      Uint8List.fromList([137, 80, 78, 71, 0, 0, 0, 0]),
      Uint8List(5 * 1024 * 1024 + 1),
    ]) {
      await expectLater(
        artwork.validate(ArtworkDraft(bytes)),
        throwsA(isA<ArtworkFailure>()),
      );
    }
    expect(
      await ArtworkService(store: images, picker: () async => null).pick(),
      isNull,
    );
    final selected = await ArtworkService(
      store: images,
      picker: () async => XFile('web/icons/Icon-192.png'),
    ).pick();
    expect(selected!.bytes, image.bytes);
    expect(images.images, isEmpty);
  });
  test('native managed image and SQLite references persist across reopening without changing source image', () async {
    final directory = await Directory.systemTemp.createTemp(
      'cta2000-artwork-test-',
    );
    addTearDown(() async {
      final target = directory.absolute;
      final root = Directory.systemTemp.absolute;
      if (!target.path.startsWith('${root.path}${Platform.pathSeparator}') ||
          !target.uri.pathSegments
              .where((p) => p.isNotEmpty)
              .last
              .startsWith('cta2000-artwork-test-')) {
        throw StateError('Unsafe artwork test cleanup');
      }
      await target.delete(recursive: true);
    });
    final original = await File('web/icons/Icon-192.png').readAsBytes();
    final native = ArtworkService(
      store: NativeArtworkStore(
        () async => Directory('${directory.path}/artwork'),
      ),
    );
    final first = ControllerFixture();
    await first.open(path: '${directory.path}/music.db');
    await first.song('persisted');
    final controller = LibraryController(first.repository, artwork: native);
    final saved = await controller.saveSongInformation(
      'persisted',
      SongMetadataUpdate(title: 'Persisted title', replacementArtwork: image),
    );
    controller.dispose();
    await first.close();
    final reopened = ControllerFixture();
    await reopened.open(path: '${directory.path}/music.db');
    final song = (await reopened.repository.songs.find('persisted'))!;
    expect(song.title, 'Persisted title');
    expect(song.artworkPath, saved.song.artworkPath);
    expect(
      await ArtworkService(
        store: NativeArtworkStore(
          () async => Directory('${directory.path}/artwork'),
        ),
      ).read(song.artworkPath),
      original,
    );
    expect(await File('web/icons/Icon-192.png').readAsBytes(), original);
    await reopened.close();
  });
}
