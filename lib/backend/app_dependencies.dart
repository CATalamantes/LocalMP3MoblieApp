import 'package:flutter/foundation.dart';

import 'services/database/local_music_repository.dart';
import 'services/database/music_database.dart';
import 'services/database/platform_database.dart';
import 'services/device/connection_manager.dart';
import 'services/device/json_http_client.dart';
import 'services/device/mobile_trust_storage.dart';
import 'services/device/pairing_service.dart';

/// Composition root. Network absence never prevents opening the local library.
class AppDependencies {
  AppDependencies._(
    this.database,
    this.music,
    this.connections,
    this.pairing,
    this.http,
  );

  final MusicDatabase database;
  final LocalMusicRepository music;
  final ConnectionManager connections;
  final PairingService pairing;
  final JsonHttpClient? http;

  static Future<AppDependencies> create({
    MusicDatabase? database,
    HttpConfiguration? httpConfiguration,
  }) async {
    final local = database ?? await createPlatformDatabase();
    final repository = LocalMusicRepository(await local.open());
    final settings = MobileDeviceSettingsStore();
    final credentials = MobileCredentialStore();
    final connections = ConnectionManager.production(
      settings: settings,
      credentials: credentials,
    );
    // The production manager remains unavailable even if a dev HTTP probe works.
    if (!kIsWeb) await connections.reconnect();
    return AppDependencies._(
      local,
      repository,
      connections,
      PairingService.production(
        settings: settings,
        credentials: credentials,
        disconnect: connections.disconnect,
      ),
      httpConfiguration == null
          ? null
          : JsonHttpClient(configuration: httpConfiguration),
    );
  }

  Future<void> close() async {
    connections.dispose();
    http?.close();
    await database.close();
  }
}
