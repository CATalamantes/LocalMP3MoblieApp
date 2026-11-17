import '../../models/music_models.dart';

enum AudioFailureKind {
  missingSource,
  unsupportedSource,
  engineInitialization,
  playback,
  invalidPosition,
  invalidCatalog,
  cancelled,
  disposed,
}

class AudioFailure implements Exception {
  const AudioFailure(this.audioKind, this.message, {this.cause});
  final AudioFailureKind audioKind;
  final String message;
  final Object? cause;
  @override
  String toString() => 'AudioFailure(${audioKind.name}: $message)';
}

enum AudioPhase { idle, loading, ready, buffering, completed, error }

class AudioSnapshot {
  const AudioSnapshot({
    this.session = 0,
    this.songId,
    this.phase = AudioPhase.idle,
    this.playing = false,
    this.position = Duration.zero,
    this.duration,
    this.error,
  });
  final int session;
  final String? songId;
  final AudioPhase phase;

  /// The engine's play flag, independent of processing/buffering.
  final bool playing;
  final Duration position;
  final Duration? duration;
  final AudioFailure? error;
  bool get isPlaying => playing && phase == AudioPhase.ready && error == null;
  bool get isPaused => !playing && phase == AudioPhase.ready && error == null;
}

/// Shared boundary for local playback. No device commands or history writes.
abstract interface class AudioService {
  AudioSnapshot get current;
  Stream<AudioSnapshot> get events;
  void activate(int session, {String? songId});
  Future<void> load(Song song, int session);
  Future<void> play(int session);
  Future<void> resume(int session);
  Future<void> pause(int session);
  Future<void> stop(int session);
  Future<void> seek(Duration position, int session);
  Future<void> setVolume(double volume, int session);
  Future<void> dispose();
}
