// Test-only simulated engine: no audio files, decoding, or audible output.
import 'dart:async';

import 'package:cta2000/backend/services/audio/audio_service.dart';
import 'package:cta2000/backend/services/audio/audio_source_resolver.dart';
import 'package:cta2000/backend/services/audio/just_audio_engine.dart';

class ScriptedAudioEngine implements AudioEngine {
  final changes = StreamController<AudioSnapshot>.broadcast(sync: true);
  final commands = <String>[];
  AudioSnapshot snapshot = const AudioSnapshot();
  Completer<void>? loadGate, initializationGate;
  Completer<void> loadStarted = Completer<void>();
  Completer<void>? seekGate;
  bool initializationFails = false, loadFails = false, playFails = false;
  Object? loadError;
  bool holdPlayEvents = false, disposed = false;
  Duration? reportedDuration = const Duration(seconds: 10);
  @override
  AudioSnapshot get current => snapshot;
  @override
  Stream<AudioSnapshot> get events => changes.stream;
  void emit(AudioSnapshot value) {
    snapshot = value;
    if (!disposed) changes.add(value);
  }

  void event({AudioPhase? phase, bool? playing, Duration? position}) => emit(
    AudioSnapshot(
      session: snapshot.session,
      songId: snapshot.songId,
      phase: phase ?? snapshot.phase,
      playing: playing ?? snapshot.playing,
      position: position ?? snapshot.position,
      duration: reportedDuration,
    ),
  );
  @override
  Future<void> initialize() async {
    commands.add('initialize');
    await initializationGate?.future;
    if (initializationFails) throw StateError('Mock initialization failure');
  }

  @override
  Future<void> load(
    ResolvedAudioSource source,
    int session,
    String songId,
  ) async {
    commands.add('load:$songId');
    emit(
      AudioSnapshot(
        session: session,
        songId: songId,
        phase: AudioPhase.loading,
      ),
    );
    if (!loadStarted.isCompleted) loadStarted.complete();
    await loadGate?.future;
    if (loadError != null) throw loadError!;
    if (loadFails) throw StateError('Mock decoding failure');
    emit(
      AudioSnapshot(
        session: session,
        songId: songId,
        phase: AudioPhase.ready,
        duration: reportedDuration,
      ),
    );
  }

  @override
  Future<void> play() async {
    commands.add('play');
    if (playFails) throw StateError('Mock autoplay or engine failure');
    if (!holdPlayEvents) event(playing: true);
  }

  @override
  Future<void> pause() async {
    commands.add('pause');
    event(playing: false);
  }

  @override
  Future<void> stop() async {
    commands.add('stop');
    emit(AudioSnapshot(session: snapshot.session, songId: snapshot.songId));
  }

  @override
  Future<void> seek(Duration position) async {
    commands.add('seek:${position.inMilliseconds}');
    await seekGate?.future;
    event(
      position: position,
      phase: position == reportedDuration
          ? AudioPhase.completed
          : AudioPhase.ready,
    );
  }

  @override
  Future<void> setVolume(double volume) async {
    commands.add('volume:$volume');
  }

  @override
  Future<void> dispose() async {
    if (disposed) return;
    disposed = true;
    commands.add('dispose');
    await changes.close();
  }
}
