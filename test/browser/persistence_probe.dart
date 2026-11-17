// Browser-only verification entry point, never imported by the application.
import 'dart:convert';

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
            lyricsText: 'Persistent manual lyrics',
          ),
        );
        await tx.playlists.insert(
          Playlist(
            playlistId: 'browser-playlist',
            name: 'Browser playlist',
            createdAt: date,
            updatedAt: date,
          ),
        );
        await tx.entries.insert(
          PlaylistEntry(
            entryId: 'browser-entry',
            playlistId: 'browser-playlist',
            songId: 'browser-song',
            position: 0,
            addedAt: date,
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
    }
    await database.close();
    repository = LocalMusicRepository(await database.open());
    if (await repository.getLyrics('browser-song') !=
            'Persistent manual lyrics' ||
        (await repository.getPlaylists()).single.name != 'Browser playlist' ||
        (await repository.getEntries('browser-playlist')).single.songId !=
            'browser-song' ||
        !(await repository.history.list()).single.countedPlay) {
      throw StateError('Browser persistence mismatch');
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
