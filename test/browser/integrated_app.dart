// Browser test entry only. No production route/flag imports or seeds this file.
import 'dart:convert';

import 'package:cta2000/app.dart';
import 'package:cta2000/backend/app_dependencies.dart';
import 'package:cta2000/backend/models/music_models.dart';
import 'package:cta2000/backend/services/database/local_music_repository.dart';
import 'package:cta2000/backend/services/database/music_database.dart';
import 'package:cta2000/backend/services/artwork/artwork_service.dart';
import 'package:cta2000/backend/services/artwork/platform_artwork_store.dart';
import 'package:flutter/widgets.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:web/web.dart' as web;
import 'package:cta2000/frontend/routes/app_screen.dart';
import 'package:cta2000/frontend/routes/frontend_navigation.dart';

Future<void> runIntegratedBrowserApp() async {
  try {
    final run = Uri.base.queryParameters['run'];
    if (run == null || !RegExp(r'^\d+$').hasMatch(run)) {
      throw StateError('Missing test run ID');
    }
    final path = 'integrated-browser-$run.db';
    if (Uri.base.queryParameters['cleanup'] == 'true') {
      await databaseFactoryFfiWeb.deleteDatabase(path);
      web.window.indexedDB.deleteDatabase('integrated-artwork-$run');
      reportIntegration({'status': 'cleaned'});
      return;
    }
    final database = MusicDatabase(factory: databaseFactoryFfiWeb, path: path);
    final repository = LocalMusicRepository(await database.open());
    final seeded = await repository.songs.find('ui-alpha') == null;
    final visual = Uri.base.queryParameters['visual'] == 'true';
    if (seeded) {
      final now = DateTime.now().toUtc();
      await repository.transaction((tx) async {
        await tx.songs.insert(
          Song(
            songId: 'ui-alpha',
            title: 'Browser integration Alpha',
            artistName: 'Browser test artist',
            durationMs: 90000,
            audioFormat: 'MP3',
            filePath: 'test-only-no-audio.mp3',
            dateAdded: now,
          ),
        );
        await tx.songs.insert(
          Song(
            songId: 'ui-beta',
            title: 'Browser integration Beta',
            artistName: 'Another test artist',
            durationMs: 80000,
            audioFormat: 'MP3',
            filePath: 'test-only-no-audio-either.mp3',
            dateAdded: now,
          ),
        );
        await tx.history.insert(
          ListeningHistory(
            historyId: 'ui-counted',
            songId: 'ui-alpha',
            startedAt: now,
            listenedMs: 12345,
            countedPlay: true,
          ),
        );
        await tx.history.insert(
          ListeningHistory(
            historyId: 'ui-uncounted',
            songId: 'ui-beta',
            startedAt: now,
            listenedMs: 2001,
            countedPlay: false,
          ),
        );
      });
    }
    final playlists = await repository.getPlaylists();
    final dependencies = await AppDependencies.create(
      database: database,
      enableLocalPlayback: false,
      developmentAudioEnabled: false,
      artworkService: ArtworkService(
        store: createArtworkStore(namespace: 'integrated-artwork-$run'),
      ),
    );
    String? playlistId;
    if (visual) {
      final p =
          playlists
              .where((p) => p.name == 'SQLite integration playlist')
              .firstOrNull ??
          await dependencies.playlists.createPlaylist(
            'SQLite integration playlist',
            description: 'Persisted test metadata · No audio or hardware',
          );
      playlistId = p.playlistId;
      if ((await repository.getEntries(p.playlistId)).isEmpty) {
        await dependencies.playlists.addSong(p.playlistId, 'ui-alpha');
        await dependencies.playlists.addSong(p.playlistId, 'ui-beta');
        await dependencies.playlists.addSong(p.playlistId, 'ui-alpha');
      }
      await dependencies.lyrics.saveManualLyrics(
        'ui-alpha',
        'Actual SQLite test lyrics\n\nUnicode 世界 🎵\nManual text; no synchronization.',
      );
      await dependencies.playback.setQueue(['ui-alpha', 'ui-beta', 'ui-alpha']);
    }
    // Snapshot is diagnostic evidence, not an alternate UI mutation interface.
    reportIntegration({
      'status': seeded ? 'seeded' : 'restored',
      'origin': Uri.base.origin,
      'songCount': (await repository.getSongs()).length,
      'playlists': [
        for (final p in playlists)
          {
            'name': p.name,
            'description': p.description,
            'entries': (await repository.getEntries(p.playlistId)).length,
          },
      ],
      'lyrics': (await repository.songs.find('ui-alpha'))?.lyricsText,
      'title': (await repository.songs.find('ui-alpha'))?.title,
      'artist': (await repository.songs.find('ui-alpha'))?.artistName,
      'artworkReference': (await repository.songs.find('ui-alpha'))
          ?.artworkPath,
      'artworkBytes': (await dependencies.artwork.read(
        (await repository.songs.find('ui-alpha'))?.artworkPath,
      ))?.length,
      'hardwareAuthenticated':
          dependencies.device.state.data.hardwareAuthenticated,
    });
    final navigator = GlobalKey<NavigatorState>();
    runApp(
      Mp3ControllerApp(
        dependencies: dependencies,
        navigatorKey: navigator,
        serviceWarning: visual
            ? 'BROWSER INTEGRATION TEST · ISOLATED SQLITE · NO AUDIO/HARDWARE'
            : null,
      ),
    );
    if (visual) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final screen = AppScreen.values
            .where(
              (screen) => screen.name == Uri.base.queryParameters['screen'],
            )
            .firstOrNull;
        if (screen != null) {
          navigator.currentState!.pushNamed(
            screen.route,
            arguments: FrontendRouteArguments(
              songId: 'ui-alpha',
              playlistId: playlistId,
            ),
          );
        }
      });
    }
  } catch (error) {
    reportIntegration({'status': 'failed', 'error': error.toString()});
  }
}

void reportIntegration(Map<String, Object?> value) => web
    .document
    .documentElement!
    .setAttribute('data-integration', jsonEncode(value));
