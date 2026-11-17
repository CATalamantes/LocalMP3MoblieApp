// Mocked package boundary only. No native audio engine, codec, or MP3 fixture.
import 'dart:async';

import 'package:cta2000/backend/services/audio/audio_service.dart';
import 'package:cta2000/backend/services/audio/audio_source_resolver.dart';
import 'package:cta2000/backend/services/audio/just_audio_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart' as just;

class MockPackagePlayer implements just.AudioPlayer {
  final states = StreamController<just.PlayerState>.broadcast(sync: true);
  final positions = StreamController<Duration>.broadcast(sync: true);
  final durations = StreamController<Duration?>.broadcast(sync: true);
  final errors = StreamController<just.PlayerException>.broadcast(sync: true);
  final commands = <String>[];
  Completer<void>? playCompletion;
  just.AudioSource? source;
  @override
  bool playing = false;
  @override
  just.ProcessingState processingState = just.ProcessingState.idle;
  @override
  Duration position = Duration.zero;
  @override
  Duration? duration;
  @override
  just.SequenceState get sequenceState => just.SequenceState(
    sequence: source == null ? [] : [source as just.IndexedAudioSource],
    currentIndex: 0,
    shuffleIndices: [0],
    shuffleModeEnabled: false,
    loopMode: just.LoopMode.off,
  );
  @override
  Stream<just.PlayerState> get playerStateStream => states.stream;
  @override
  Stream<Duration> get positionStream => positions.stream;
  @override
  Stream<Duration?> get durationStream => durations.stream;
  @override
  Stream<just.PlayerException> get errorStream => errors.stream;
  void emit() => states.add(just.PlayerState(playing, processingState));
  @override
  Future<Duration?> setAudioSource(
    just.AudioSource audioSource, {
    bool preload = true,
    int? initialIndex,
    Duration? initialPosition,
  }) async {
    source = audioSource;
    duration = const Duration(seconds: 5);
    processingState = just.ProcessingState.ready;
    commands.add('load');
    emit();
    return duration;
  }

  @override
  Future<void> play() {
    commands.add('play');
    playing = true;
    emit();
    return (playCompletion = Completer<void>()).future;
  }

  @override
  Future<void> pause() async {
    commands.add('pause');
    playing = false;
    emit();
    if (playCompletion != null && !playCompletion!.isCompleted) {
      playCompletion!.complete();
    }
  }

  @override
  Future<void> seek(Duration? value, {int? index}) async {
    commands.add('seek');
    position = value ?? Duration.zero;
    positions.add(position);
  }

  @override
  Future<void> stop() async {
    commands.add('stop');
    processingState = just.ProcessingState.idle;
    emit();
  }

  @override
  Future<void> setVolume(double value) async {
    commands.add('volume:$value');
  }

  @override
  Future<void> dispose() async {
    commands.add('dispose');
    await states.close();
    await positions.close();
    await durations.close();
    await errors.close();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('real adapter maps just_audio operations and events through a mocked player', () async {
    final player = MockPackagePlayer();
    var configured = 0;
    final engine = JustAudioEngine(
      player: player,
      configureSession: () async {
        configured++;
      },
    );
    final events = <AudioSnapshot>[];
    final subscription = engine.events.listen(events.add);
    await engine.initialize();
    await engine.initialize();
    expect(configured, 1);
    await engine.load(
      const ResolvedAudioSource(
        LocalSourceKind.asset,
        'assets/audio/not-a-real-fixture.mp3',
      ),
      7,
      'song',
    );
    expect(engine.current.session, 7);
    expect(engine.current.songId, 'song');
    expect(engine.current.phase, AudioPhase.ready);
    expect(engine.current.duration, const Duration(seconds: 5));
    await engine
        .play(); // Must not wait for just_audio's entire playback future.
    expect(player.playCompletion!.isCompleted, isFalse);
    expect(engine.current.isPlaying, isTrue);
    player.processingState = just.ProcessingState.buffering;
    player.emit();
    expect(engine.current.playing, isTrue);
    expect(engine.current.isPlaying, isFalse);
    player.processingState = just.ProcessingState.ready;
    player.emit();
    await engine.seek(const Duration(seconds: 2));
    expect(engine.current.position, const Duration(seconds: 2));
    await engine.setVolume(0.3);
    await engine.pause();
    expect(engine.current.isPaused, isTrue);
    player.processingState = just.ProcessingState.completed;
    player.emit();
    expect(engine.current.phase, AudioPhase.completed);
    await engine.stop();
    expect(engine.current.position, Duration.zero);
    expect(
      player.commands,
      containsAll(['load', 'play', 'pause', 'seek', 'stop', 'volume:0.3']),
    );
    expect(events, isNotEmpty);
    await subscription.cancel();
    await engine.dispose();
    expect(player.commands.last, 'dispose');
  });

  test(
    'late rejected play promise from an old source cannot fail the new source',
    () async {
      final player = MockPackagePlayer();
      final engine = JustAudioEngine(
        player: player,
        configureSession: () async {},
      );
      await engine.initialize();
      await engine.load(
        const ResolvedAudioSource(
          LocalSourceKind.asset,
          'assets/audio/first.mp3',
        ),
        1,
        'first',
      );
      await engine.play();
      final old = player.playCompletion!;
      await engine.load(
        const ResolvedAudioSource(
          LocalSourceKind.asset,
          'assets/audio/second.mp3',
        ),
        2,
        'second',
      );
      old.completeError(StateError('Old mocked rejection'));
      await Future<void>.delayed(Duration.zero);
      expect(engine.current.songId, 'second');
      expect(engine.current.error, isNull);
      await engine.dispose();
    },
  );

  test('package error events become typed playback failure, never successful playing', () async {
    final player = MockPackagePlayer();
    final engine = JustAudioEngine(
      player: player,
      configureSession: () async {},
    );
    await engine.initialize();
    await engine.load(
      const ResolvedAudioSource(LocalSourceKind.file, 'file:///not-real.mp3'),
      2,
      'file',
    );
    player.errors.add(just.PlayerException(1, 'Mocked decoder error', 0));
    expect(engine.current.error!.audioKind, AudioFailureKind.playback);
    expect(engine.current.isPlaying, isFalse);
    await engine.dispose();
  });
}
