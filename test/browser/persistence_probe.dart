// Browser-only verification entry point, never imported by the application.
import 'dart:convert';

import 'package:cta2000/backend/controllers/controller_state.dart';
import 'package:cta2000/backend/controllers/library_controller.dart';
import 'package:cta2000/backend/controllers/lyrics_controller.dart';
import 'package:cta2000/backend/controllers/playlist_controller.dart';
import 'package:cta2000/backend/controllers/statistics_controller.dart';
import 'package:cta2000/backend/controllers/playback_controller.dart';

import 'package:cta2000/backend/models/music_models.dart';
import 'package:cta2000/backend/services/database/local_music_repository.dart';
import 'package:cta2000/backend/services/database/music_database.dart';
import 'package:cta2000/backend/services/device/json_http_client.dart';
import 'package:cta2000/backend/services/device/connection_manager.dart';
import 'package:cta2000/backend/services/device/device_contracts.dart';
import 'package:cta2000/backend/services/device/mobile_trust_storage.dart';
import 'package:flutter/widgets.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:web/web.dart' as web;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MusicDatabase? database;
  JsonHttpClient? http;
  final controllers = <MusicController<Object?>>[];
  try {
    final run = Uri.base.queryParameters['run'];
    if (run == null || !RegExp(r'^\d+$').hasMatch(run)) {
      throw StateError('Missing run ID');
    }
    final path = 'browser-verification-$run.db';
    if (Uri.base.queryParameters['cleanup'] == 'true') {
      await databaseFactoryFfiWeb.deleteDatabase(path);
      _report({'status': 'cleaned'});
      return;
    }
    database = MusicDatabase(factory: databaseFactoryFfiWeb, path: path);
    var repository = LocalMusicRepository(await database.open());
    final existing = await repository.songs.find('browser-song');
    final phase = existing == null ? 'seeded' : 'restored';
    final date = DateTime.utc(2026, 11, 17);
    if (existing == null) {
      await repository.transaction((tx) async {
        await tx.songs.insert(
          Song(
            songId: 'browser-song',
            title: 'Browser test',
            artistName: 'Test only',
            durationMs: 1000,
            audioFormat: 'MP3',
            filePath: 'test-only.mp3',
            dateAdded: date,
          ),
        );
        await tx.history.insert(
          ListeningHistory(
            historyId: 'browser-history',
            songId: 'browser-song',
            startedAt: date,
            listenedMs: 500,
            countedPlay: true,
          ),
        );
      });
      final library = LibraryController(repository);
      final lyrics = LyricsController(repository);
      var identifier = 0;
      final playlists = PlaylistController(
        repository,
        idFactory: () => identifier++ == 0
            ? 'browser-playlist'
            : 'browser-entry-$identifier',
      );
      controllers.addAll([library, lyrics, playlists]);
      await lyrics.saveManualLyrics('browser-song', 'Persistent manual lyrics');
      await library.updateMetadata(
        'browser-song',
        const SongMetadataUpdate(title: 'Browser controller song'),
      );
      final playlist = await playlists.createPlaylist('Initial playlist');
      await playlists.renamePlaylist(playlist.playlistId, 'Browser playlist');
      await playlists.updateDescription(playlist.playlistId, '説明 🎵');
      final first = await playlists.addSong(
        playlist.playlistId,
        'browser-song',
      );
      final second = await playlists.addSong(
        playlist.playlistId,
        'browser-song',
      );
      await playlists.reorder(second.entryId, 0);
      await playlists.removeEntry(first.entryId);
      await repository.songs.insert(
        Song(
          songId: 'browser-delete',
          title: 'Temporary metadata',
          artistName: 'Test',
          durationMs: 1,
          audioFormat: 'MP3',
          filePath: 'no-real-file.mp3',
          dateAdded: date,
        ),
      );
      await playlists.addSong(playlist.playlistId, 'browser-delete');
      await library.removeSong('browser-delete');
      if (await repository.songs.find('browser-delete') != null) {
        throw StateError('Controller deletion failed');
      }
    }
    for (final controller in controllers) {
      controller.dispose();
    }
    await database.close();
    repository = LocalMusicRepository(await database.open());
    final restoredLibrary = LibraryController(repository);
    final restoredLyrics = LyricsController(repository);
    final restoredPlaylists = PlaylistController(repository);
    final restoredStats = StatisticsController(repository);
    final queue = PlaybackController(repository);
    controllers.addAll([
      restoredLibrary,
      restoredLyrics,
      restoredPlaylists,
      restoredStats,
      queue,
    ]);
    final restoredSong = await restoredLibrary.loadSong('browser-song');
    final savedPlaylist = await restoredPlaylists.showPlaylist(
      'browser-playlist',
    );
    final statistics = await restoredStats.load(songId: 'browser-song');
    if (await restoredLyrics.loadManualLyrics('browser-song') !=
            'Persistent manual lyrics' ||
        restoredSong.title != 'Browser controller song' ||
        savedPlaylist.name != 'Browser playlist' ||
        savedPlaylist.description != '説明 🎵' ||
        restoredPlaylists.state.data.entries.single.position != 0 ||
        restoredPlaylists.state.data.songs.single.songId != 'browser-song' ||
        statistics.totalCountedPlays != 1 ||
        statistics.totalListeningDuration.inMilliseconds != 500) {
      throw StateError('Browser persistence mismatch');
    }
    await queue.setQueue(['browser-song', 'browser-song']);
    await queue.previous();
    if (queue.state.data.queueIndex != 1) {
      throw StateError('Queue previous wrap failed');
    }
    await queue.next();
    if (queue.state.data.queueIndex != 0 || queue.state.data.isPlaying) {
      throw StateError('Queue next wrap or unavailable playback failed');
    }
    http = JsonHttpClient(
      configuration: HttpConfiguration(
        baseUri: Uri.parse(Uri.base.origin),
        probePath: 'api/probe',
        localDevelopment: true,
      ),
    );
    final response =
        await http.request('POST', 'api/echo', body: {'browser': true}) as Map;
    if (response['testOnly'] != true ||
        (response['body'] as Map)['browser'] != true) {
      throw StateError('Browser HTTP mismatch');
    }
    await http.probe();
    final settings = MobileDeviceSettingsStore();
    final credentials = MobileCredentialStore();
    for (final read in <Future<Object?> Function()>[
      settings.read,
      credentials.read,
    ]) {
      try {
        await read();
        throw StateError('Browser accessed mobile trust storage');
      } on DeviceFailure catch (error) {
        if (error.kind != DeviceFailureKind.unavailable) rethrow;
      }
    }
    final production = ConnectionManager.production(
      settings: settings,
      credentials: credentials,
    );
    await production.reconnect();
    final hardwareAuthenticated = production.snapshot.hardwareAuthenticated;
    if (hardwareAuthenticated ||
        production.snapshot.phase != ConnectionPhase.unavailable) {
      throw StateError('Production hardware authentication became available');
    }
    production.dispose();
    _report({
      'status': phase,
      'closeReopen': true,
      'tables': 4,
      'lyrics': true,
      'controllers': true,
      'queueWrap': true,
      'http': true,
      'hardwareAuthenticated': hardwareAuthenticated,
      'mobileTrustUnavailable': true,
      'origin': Uri.base.origin,
    });
  } catch (error, stack) {
    _report({
      'status': 'failed',
      'error': error.toString(),
      'stack': stack.toString(),
    });
  } finally {
    for (final controller in controllers) {
      controller.dispose();
    }
    http?.close();
    await database?.close();
  }
}

void _report(Map<String, Object?> result) {
  web.document.documentElement!.setAttribute(
    'data-verification',
    jsonEncode(result),
  );
}
