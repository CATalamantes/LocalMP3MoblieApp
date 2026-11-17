import 'dart:async';

import 'package:flutter/services.dart';

import '../../models/music_models.dart';
import 'audio_service.dart';
import 'audio_source_resolver.dart';
import 'just_audio_engine.dart';

class LocalAudioService implements AudioService {
  LocalAudioService({
    AudioSourceResolver? resolver,
    AudioEngine Function()? engineFactory,
  }) : _resolver = resolver ?? AudioSourceResolver(),
       _engineFactory = engineFactory ?? JustAudioEngine.new;
  final AudioSourceResolver _resolver;
  final AudioEngine Function() _engineFactory;
  AudioEngine? _engine;
  StreamSubscription<AudioSnapshot>? _subscription;
  final _events = StreamController<AudioSnapshot>.broadcast(sync: true);
  Future<void> _tail = Future.value();
  int _session = 0;
  bool _disposed = false;
  AudioSnapshot _current = const AudioSnapshot();
  @override
  AudioSnapshot get current => _current;
  @override
  Stream<AudioSnapshot> get events => _events.stream;

  void _check(int session) {
    if (_disposed) {
      throw AudioFailure(
        AudioFailureKind.disposed,
        'Audio service is disposed',
      );
    }
    if (session != _session) {
      throw AudioFailure(
        AudioFailureKind.cancelled,
        'Audio request was superseded',
      );
    }
  }

  void _publish(AudioSnapshot snapshot) {
    if (_disposed || snapshot.session != _session) return;
    _current = snapshot;
    _events.add(snapshot);
  }

  @override
  void activate(int session, {String? songId}) {
    if (_disposed) {
      throw AudioFailure(
        AudioFailureKind.disposed,
        'Audio service is disposed',
      );
    }
    _session = session;
    _publish(AudioSnapshot(session: session, songId: songId));
  }

  Future<AudioEngine> _readyEngine() async {
    if (_engine != null) return _engine!;
    AudioEngine? engine;
    try {
      engine = _engineFactory();
      await engine.initialize().timeout(const Duration(seconds: 10));
      if (_disposed) {
        await engine.dispose();
        throw AudioFailure(
          AudioFailureKind.disposed,
          'Audio service is disposed',
        );
      }
      _engine = engine;
      _subscription = engine.events.listen(_publish);
      return engine;
    } catch (error) {
      if (engine != null && !_disposed) {
        await engine.dispose();
      }
      if (error is AudioFailure) rethrow;
      throw AudioFailure(
        AudioFailureKind.engineInitialization,
        'Audio engine could not initialize',
        cause: error,
      );
    }
  }

  Future<void> _run(int session, Future<void> Function() action) {
    final result = _tail.then((_) async {
      _check(session);
      try {
        await action();
        _check(session);
        if (_current.error != null) throw _current.error!;
      } catch (error) {
        final failure = error is AudioFailure
            ? error
            : AudioFailure(
                error is MissingPluginException
                    ? AudioFailureKind.engineInitialization
                    : AudioFailureKind.playback,
                error is MissingPluginException
                    ? 'The platform audio plugin is unavailable'
                    : 'Local audio operation failed',
                cause: error,
              );
        if (session == _session &&
            !_disposed &&
            !{
              AudioFailureKind.cancelled,
              AudioFailureKind.disposed,
              AudioFailureKind.invalidPosition,
            }.contains(failure.audioKind)) {
          try {
            await _engine?.stop();
          } catch (_) {
            /* Preserve the original failure. */
          }
          _publish(
            AudioSnapshot(
              session: session,
              songId: _current.songId,
              phase: AudioPhase.error,
              position: _current.position,
              duration: _current.duration,
              error: failure,
            ),
          );
        }
        throw failure;
      }
    });
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  @override
  Future<void> load(Song song, int session) => _run(session, () async {
    _publish(
      AudioSnapshot(
        session: session,
        songId: song.songId,
        phase: AudioPhase.loading,
      ),
    );
    final source = await _resolver.resolve(song);
    _check(session);
    final engine = await _readyEngine();
    _check(session);
    await engine.stop();
    _check(session);
    try {
      await engine
          .load(source, session, song.songId)
          .timeout(const Duration(seconds: 20));
    } on TimeoutException {
      await engine.stop();
      throw AudioFailure(AudioFailureKind.playback, 'Audio load timed out');
    }
    _check(session);
    _publish(engine.current);
  });

  @override
  Future<void> play(int session) => _run(session, () async {
    if (_engine == null ||
        _current.songId == null ||
        !{
          AudioPhase.ready,
          AudioPhase.buffering,
          AudioPhase.completed,
        }.contains(_current.phase)) {
      throw AudioFailure(
        AudioFailureKind.playback,
        'No ready source is loaded',
      );
    }
    await _engine!.play();
    _publish(_engine!.current);
  });
  @override
  Future<void> pause(int session) => _run(session, () async {
    await _engine?.pause();
    if (_engine != null) _publish(_engine!.current);
  });
  @override
  Future<void> resume(int session) => play(session);
  @override
  Future<void> stop(int session) => _run(session, () async {
    await _engine?.stop();
    _publish(AudioSnapshot(session: session, songId: _current.songId));
  });
  @override
  Future<void> seek(Duration position, int session) => _run(session, () async {
    final duration = _current.duration;
    if (position < Duration.zero ||
        duration == null ||
        _engine == null ||
        !{AudioPhase.ready, AudioPhase.completed}.contains(_current.phase)) {
      throw AudioFailure(
        AudioFailureKind.invalidPosition,
        'Seek requires a nonnegative position and known ready duration',
      );
    }
    await _engine!.seek(position > duration ? duration : position);
    _publish(_engine!.current);
  });
  @override
  Future<void> setVolume(double volume, int session) => _run(session, () async {
    if (!volume.isFinite || volume < 0 || volume > 1) {
      throw AudioFailure(
        AudioFailureKind.invalidPosition,
        'Volume must be between zero and one',
      );
    }
    await (await _readyEngine()).setVolume(volume);
  });
  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _subscription?.cancel();
    await _engine?.dispose();
    await _tail;
    await _events.close();
  }
}
