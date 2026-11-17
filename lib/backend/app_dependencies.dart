import 'controllers/device_controller.dart';
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

/// Composition root. Network absence never prevents opening the local library.
class AppDependencies {
  AppDependencies._(
    this.database,
    this.music,
    this.connections,
    this.pairing,
    this.http,
    this.audio,
    this.developmentAudio,
  );

  final MusicDatabase database;
  final LocalMusicRepository music;
  final ConnectionManager connections;
  final PairingService pairing;
  final JsonHttpClient? http;
  final AudioService? audio;
  final DevelopmentAudioRegistration developmentAudio;
  late final library = LibraryController(music);
  late final playlists = PlaylistController(music);
  late final lyrics = LyricsController(music);
  late final statistics = StatisticsController(music);
  late final playback = PlaybackController(music, audio: audio);
  late final radxa = RadxaClient.production(connections);
  late final device = DeviceController(
    connections: connections,
    pairing: pairing,
    client: radxa,
  );

  static Future<AppDependencies> create({
    MusicDatabase? database,
    HttpConfiguration? httpConfiguration,
    AudioService? audioService,
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
    http?.close();
    await database.close();
  }
}
