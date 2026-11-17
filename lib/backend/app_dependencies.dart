import 'controllers/device_controller.dart';

import 'package:flutter/foundation.dart';

import 'controllers/library_controller.dart';
import 'controllers/playlist_controller.dart';
import 'controllers/lyrics_controller.dart';
import 'controllers/statistics_controller.dart';
import 'controllers/playback_controller.dart';

import 'services/database/local_music_repository.dart';
import 'services/audio/audio_service.dart';
import 'services/audio/local_audio_service.dart';
import 'services/audio/development_audio_registration.dart';
import 'services/database/music_database.dart';
import 'services/database/platform_database.dart';
import 'services/device/connection_manager.dart';
import 'services/device/json_http_client.dart';
import 'services/device/mobile_trust_storage.dart';
import 'services/device/pairing_service.dart';
import 'services/device/radxa_client.dart';
import 'services/artwork/artwork_service.dart';

/// Composition root. Network absence never prevents opening the local library.
class AppDependencies {
  AppDependencies._(
    this.database,
    this.music,
    this.connections,
    this.pairing,
    this.http,
    this.audio,
    this.developmentAudio, [
    this._providedDevice,
    ArtworkService? artworkService,
  ]) : artwork = artworkService ?? ArtworkService();

  final MusicDatabase database;
  final LocalMusicRepository music;
  final ConnectionManager connections;
  final PairingService pairing;
  final JsonHttpClient? http;
  final AudioService? audio;
  final DevelopmentAudioRegistration developmentAudio;
  final ArtworkService artwork;
  late final library = LibraryController(music, artwork: artwork);
  late final playlists = PlaylistController(music);
  late final lyrics = LyricsController(music);
  late final statistics = StatisticsController(music);
  late final playback = PlaybackController(music, audio: audio);
  late final radxa =
      _providedDevice?.client ?? RadxaClient.production(connections);
  final DeviceController? _providedDevice;
  late final device =
      _providedDevice ??
      DeviceController(
        connections: connections,
        pairing: pairing,
        client: radxa,
      );

  /// Explicit composition seam; adapters are supplied by tests, never discovered
  /// or activated by a production flag. All controllers share the same database.
  @visibleForTesting
  static AppDependencies forTesting({
    required MusicDatabase database,
    required LocalMusicRepository music,
    required DeviceController device,
    AudioService? audio,
    ArtworkService? artwork,
  }) {
    return AppDependencies._(
      database,
      music,
      device.connections,
      device.pairing,
      null,
      audio,
      DevelopmentAudioRegistration(),
      device,
      artwork,
    );
  }

  static Future<AppDependencies> create({
    MusicDatabase? database,
    HttpConfiguration? httpConfiguration,
    AudioService? audioService,
    ArtworkService? artworkService,
    bool enableLocalPlayback = true,
    bool developmentAudioEnabled = const bool.fromEnvironment(
      'ENABLE_DEVELOPMENT_AUDIO',
    ),
  }) async {
    final local = database ?? await createPlatformDatabase();
    final repository = LocalMusicRepository(await local.open());
    final registration = await DevelopmentAudioRegistrar(repository)
        .register(enabled: developmentAudioEnabled);
    final settings = MobileDeviceSettingsStore();
    final credentials = MobileCredentialStore();
    final connections = ConnectionManager.production(
      settings: settings,
      credentials: credentials,
    );
    // The production manager remains unavailable even if a dev HTTP probe works.
    final dependencies = AppDependencies._(
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
      enableLocalPlayback ? audioService ?? LocalAudioService() : null,
      registration,
      null,
      artworkService,
    );
    // Device/storage availability never prevents the offline application opening.
    try {
      await dependencies.device.loadSavedDevice();
    } catch (_) {
      /* State retains the typed failure. */
    }
    return dependencies;
  }

  Future<void>? _closing;
  Future<void> close() => _closing ??= _close();
  Future<void> _close() async {
    library.dispose();
    playlists.dispose();
    lyrics.dispose();
    statistics.dispose();
    await device.close();
    await playback.close();
    await artwork.pendingOperations;
    http?.close();
    await database.close();
  }
}
