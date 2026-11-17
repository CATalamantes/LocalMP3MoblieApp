import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart' as just;

import 'audio_service.dart';
import 'audio_source_resolver.dart';

abstract interface class AudioEngine {
  AudioSnapshot get current;
  Stream<AudioSnapshot> get events;
  Future<void> initialize();
  Future<void> load(ResolvedAudioSource source, int session, String songId);
  Future<void> play();
  Future<void> pause();
  Future<void> stop();
  Future<void> seek(Duration position);
  Future<void> setVolume(double volume);
  Future<void> dispose();
}

class _SourceTag {
  const _SourceTag(this.session, this.songId);
  final int session;
  final String songId;
}

/// Adapter only: decoding is performed by just_audio and the platform.
class JustAudioEngine implements AudioEngine {
  JustAudioEngine({
    just.AudioPlayer? player,
    Future<void> Function()? configureSession,
  }) : _player = player ?? just.AudioPlayer(),
       _configureSession = configureSession ?? _configureMusic;
  final just.AudioPlayer _player;
  final Future<void> Function() _configureSession;
  final _events = StreamController<AudioSnapshot>.broadcast(sync: true);
  final _subscriptions = <StreamSubscription<Object?>>[];
  bool _disposed = false, _initialized = false;
  AudioFailure? _error;

  static Future<void> _configureMusic() async {
    if (!kIsWeb &&
        {
          TargetPlatform.android,
          TargetPlatform.iOS,
        }.contains(defaultTargetPlatform)) {
      await (await AudioSession.instance).configure(
        const AudioSessionConfiguration.music(),
      );
    }
  }

  @override
  AudioSnapshot get current {
    final tag = _player.sequenceState.currentSource?.tag;
    return AudioSnapshot(
      session: tag is _SourceTag ? tag.session : 0,
      songId: tag is _SourceTag ? tag.songId : null,
      phase: _error != null
          ? AudioPhase.error
          : switch (_player.processingState) {
              just.ProcessingState.idle => AudioPhase.idle,
              just.ProcessingState.loading => AudioPhase.loading,
              just.ProcessingState.buffering => AudioPhase.buffering,
              just.ProcessingState.ready => AudioPhase.ready,
              just.ProcessingState.completed => AudioPhase.completed,
            },
      playing: _error == null && _player.playing,
      position: _player.position,
      duration: _player.duration,
      error: _error,
    );
  }

  @override
  Stream<AudioSnapshot> get events => _events.stream;
  void _emit() {
    if (!_disposed) _events.add(current);
  }

  void _fail(Object error) {
    if (_disposed) return;
    _error = AudioFailure(
      AudioFailureKind.playback,
      'Audio engine playback failed',
      cause: error,
    );
    _emit();
  }

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    await _configureSession();
    if (_disposed) {
      throw const AudioFailure(
        AudioFailureKind.disposed,
        'Audio engine is disposed',
      );
    }
    _subscriptions.addAll([
      _player.playerStateStream.listen((_) => _emit()),
      _player.positionStream.listen((_) => _emit()),
      _player.durationStream.listen((_) => _emit()),
      _player.errorStream.listen(_fail),
    ]);
    _initialized = true;
  }

  @override
  Future<void> load(
    ResolvedAudioSource source,
    int session,
    String songId,
  ) async {
    _error = null;
    final tag = _SourceTag(session, songId);
    final audio = source.kind == LocalSourceKind.asset
        ? just.AudioSource.asset(source.location, tag: tag)
        : just.AudioSource.uri(Uri.parse(source.location), tag: tag);
    await _player.setAudioSource(audio);
    _emit();
  }

  @override
  Future<void> play() async {
    // just_audio's play future lasts until completion/pause. Never serialize
    // subsequent commands behind that future; failures still reach our stream.
    final source = _player.sequenceState.currentSource?.tag;
    unawaited(
      _player.play().catchError((Object error) {
        if (_disposed) return;
        if (identical(source, _player.sequenceState.currentSource?.tag)) {
          _fail(error);
        }
      }),
    );
  }

  @override
  Future<void> pause() => _player.pause();
  @override
  Future<void> stop() async {
    await _player.pause();
    await _player.seek(Duration.zero);
    await _player.stop();
    _emit();
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);
  @override
  Future<void> setVolume(double volume) => _player.setVolume(volume);
  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await _player.dispose();
    await _events.close();
  }
}
