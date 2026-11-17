// All engine events here are simulated. No MP3 loading or audible playback.
import 'dart:async';

import 'package:cta2000/backend/controllers/controller_state.dart';
import 'package:cta2000/backend/controllers/playback_controller.dart';
import 'package:cta2000/backend/services/audio/audio_service.dart';
import 'package:cta2000/backend/services/audio/audio_source_resolver.dart';
import 'package:cta2000/backend/services/audio/local_audio_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/audio_fakes.dart';
import 'support/controller_fixture.dart';

Future<void> settle() async {
  // Drain asynchronous command/event dispatch; never advance a fake play clock.
  for (var i = 0; i < 12; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

Future<void> waitFor(bool Function() condition) async {
  for (var i = 0; i < 1000; i++) {
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
  fail('Simulated engine/controller did not settle');
}

void main() {
  late ControllerFixture f;
  late ScriptedAudioEngine engine;
  late PlaybackController c;
  late LocalAudioService service;
  setUp(() async {
    f = ControllerFixture();
    await f.open();
    for (final id in ['a', 'b', 'c', 'missing']) {
      await f.song(id, filePath: 'asset:///assets/audio/$id.mp3');
    }
    engine = ScriptedAudioEngine();
    service = LocalAudioService(
      resolver: AudioSourceResolver(
        assetExists: (key) async => !key.contains('missing'),
      ),
      engineFactory: () => engine,
    );
    c = PlaybackController(f.repository, audio: service);
  });
  tearDown(() async {
    await c.close();
    await f.close();
  });

  test('selection prepares paused, navigation preserves intent and duplicates wrap', () async {
    await c.setQueue(['a', 'b', 'a']);
    expect(c.state.data.capability, PlaybackCapability.local);
    expect(c.state.data.audio.phase, AudioPhase.ready);
    expect(c.state.data.isPlaying, isFalse);
    await c.play();
    expect(c.state.data.isPlaying, isTrue);
    await c.next();
    expect(c.state.data.selectedSong!.songId, 'b');
    expect(c.state.data.isPlaying, isTrue);
    await c.previous();
    expect(c.state.data.queueIndex, 0);
    await c.previous();
    expect(c.state.data.queueIndex, 2);
    await c.next();
    expect(c.state.data.queueIndex, 0);
    await c.pause();
    expect(c.state.data.isPaused, isTrue);
    await c.next();
    expect(c.state.data.queueIndex, 1);
    expect(c.state.data.isPlaying, isFalse);
    await c.resume();
    expect(c.state.data.isPlaying, isTrue);
    await c.setVolume(0.2);
    expect(engine.commands, contains('volume:0.2'));
    expect(await f.repository.history.list(), isEmpty);
  });

  test('queue replacement/clear stop old audio; stop retains selection and resets engine progress', () async {
    await c.setQueue(['a']);
    await c.play();
    engine.event(position: const Duration(seconds: 3));
    expect(c.state.data.position, const Duration(seconds: 3));
    await c.stop();
    expect(c.state.data.selectedSong!.songId, 'a');
    expect(c.state.data.position, Duration.zero);
    expect(c.state.data.isPlaying, isFalse);
    await c.resume();
    expect(c.state.data.isPlaying, isTrue);
    await c.setQueue(['b', 'a']);
    expect(c.state.data.selectedSong!.songId, 'b');
    expect(c.state.data.isPlaying, isFalse);
    expect(c.state.data.playIntent, isFalse);
    await c.play();
    await c.clearQueue();
    expect(c.state.data.selectedSong, isNull);
    expect(c.state.data.isPlaying, isFalse);
    expect(engine.current.playing, isFalse);
  });

  test('playing, buffering, duration and position derive from events, not requested play', () async {
    engine.holdPlayEvents = true;
    await c.setQueue(['a']);
    await c.play();
    expect(c.state.data.playIntent, isTrue);
    expect(c.state.data.isPlaying, isFalse);
    engine.event(playing: true, phase: AudioPhase.buffering);
    expect(c.state.data.audio.phase, AudioPhase.buffering);
    expect(c.state.data.isPlaying, isFalse);
    engine.event(
      phase: AudioPhase.ready,
      position: const Duration(milliseconds: 700),
    );
    expect(c.state.data.isPlaying, isTrue);
    expect(c.state.data.position.inMilliseconds, 700);
    expect(c.state.data.duration, const Duration(seconds: 10));
  });

  test(
    'seek clamps, rejects negatives and waits for engine acceptance',
    () async {
      await c.setQueue(['a']);
      await expectLater(
        c.seek(const Duration(seconds: -1)),
        throwsA(
          isA<PlaybackFailure>().having(
            (e) => e.audioFailure.audioKind,
            'audio kind',
            AudioFailureKind.invalidPosition,
          ),
        ),
      );
      engine.seekGate = Completer<void>();
      final pending = c.seek(const Duration(seconds: 90));
      await settle();
      expect(c.state.data.position, Duration.zero);
      engine.seekGate!.complete();
      await pending;
      expect(c.state.data.position, const Duration(seconds: 10));
      expect(engine.commands, contains('seek:10000'));
    },
  );

  test('pause during loading cancels pending play intent without accidental autoplay', () async {
    engine.loadGate = Completer<void>();
    final loading = c.setQueue(['a']);
    await engine.loadStarted.future;
    final playing = c.play();
    final pausing = c.pause();
    engine.loadGate!.complete();
    await loading;
    await playing;
    await pausing;
    expect(engine.commands.where((command) => command == 'play'), isEmpty);
    expect(c.state.data.isPlaying, isFalse);
    expect(c.state.data.playIntent, isFalse);
    expect(c.state.data.audio.phase, AudioPhase.ready);
  });

  test('rapid navigation uses desired occurrence index and suppresses superseded operations', () async {
    await c.setQueue(['a', 'b', 'c']);
    await c.play();
    final first = expectLater(c.next(), throwsA(isA<PlaybackFailure>()));
    final second = expectLater(c.next(), throwsA(isA<PlaybackFailure>()));
    final third = c.next();
    await first;
    await second;
    await third;
    expect(c.state.data.queueIndex, 0);
    expect(c.state.data.selectedSong!.songId, 'a');
    expect(c.state.data.isPlaying, isTrue);
    expect(engine.commands.where((cmd) => cmd.startsWith('load:')), [
      'load:a',
      'load:a',
    ]);
  });

  test('replacing a queue during loading and old completion/position events cannot revive it', () async {
    engine.loadGate = Completer<void>();
    final old = expectLater(c.setQueue(['a']), throwsA(isA<PlaybackFailure>()));
    await engine.loadStarted.future;
    final oldSession = engine.current.session;
    final replacement = c.setQueue(['b']);
    engine.loadGate!.complete();
    await old;
    await replacement;
    final index = c.state.data.queueIndex;
    engine.emit(
      AudioSnapshot(
        session: oldSession,
        songId: 'a',
        playing: true,
        phase: AudioPhase.completed,
        position: const Duration(seconds: 9),
      ),
    );
    await settle();
    expect(c.state.data.selectedSong!.songId, 'b');
    expect(c.state.data.queueIndex, index);
    expect(c.state.data.position, Duration.zero);
    expect(c.state.data.isPlaying, isFalse);
  });

  test('completion advances once, wraps queue and stop blocks completion advancement', () async {
    await c.setQueue(['a', 'b']);
    await c.play();
    final completed = AudioSnapshot(
      session: engine.current.session,
      songId: 'a',
      phase: AudioPhase.completed,
      playing: true,
      duration: const Duration(seconds: 10),
    );
    engine.emit(completed);
    engine.emit(completed);
    await waitFor(() => c.state.data.queueIndex == 1 && c.state.data.isPlaying);
    expect(c.state.data.queueIndex, 1);
    expect(engine.commands.where((cmd) => cmd == 'load:b'), hasLength(1));
    engine.event(phase: AudioPhase.completed);
    await waitFor(() => c.state.data.queueIndex == 0 && c.state.data.isPlaying);
    expect(c.state.data.queueIndex, 0);
    final beforeStop = engine.current.session;
    final stopping = c.stop();
    engine.emit(
      AudioSnapshot(
        session: beforeStop,
        songId: 'a',
        phase: AudioPhase.completed,
        playing: true,
      ),
    );
    await stopping;
    await settle();
    expect(c.state.data.queueIndex, 0);
    expect(c.state.data.isPlaying, isFalse);
  });

  test('single-track continuous completion restarts once; disabled looping stops at end', () async {
    await c.setQueue(['a']);
    await c.play();
    engine.event(phase: AudioPhase.completed);
    await settle();
    expect(c.state.data.queueIndex, 0);
    expect(engine.commands.where((cmd) => cmd == 'load:a'), hasLength(2));
    await c.close();
    engine = ScriptedAudioEngine();
    service = LocalAudioService(
      resolver: AudioSourceResolver(assetExists: (_) async => true),
      engineFactory: () => engine,
    );
    c = PlaybackController(
      f.repository,
      audio: service,
      continuousPlayback: false,
    );
    await c.setQueue(['a', 'b']);
    await c.play();
    engine.event(phase: AudioPhase.completed);
    await settle();
    expect(c.state.data.queueIndex, 1);
    engine.event(phase: AudioPhase.completed);
    await settle();
    expect(c.state.data.queueIndex, 1);
    expect(c.state.data.isPlaying, isFalse);
    expect(c.state.data.playIntent, isFalse);
    await c.next();
    expect(c.state.data.queueIndex, 0); // manual wrap is unchanged.
  });

  test('missing source/deleted song failures stop prior audio without skipping loops', () async {
    await c.setQueue(['a', 'missing']);
    await c.play();
    await expectLater(
      c.next(),
      throwsA(
        isA<PlaybackFailure>().having(
          (e) => e.audioFailure.audioKind,
          'audio kind',
          AudioFailureKind.missingSource,
        ),
      ),
    );
    expect(c.state.status, ControllerStatus.error);
    expect(c.state.data.isPlaying, isFalse);
    await settle();
    expect(engine.commands.where((cmd) => cmd.startsWith('load:')), ['load:a']);
    await c.setQueue(['a', 'b']);
    await c.play();
    await f.repository.songs.delete('b');
    await expectLater(
      c.next(),
      throwsA(
        isA<ControllerFailure>().having(
          (e) => e.kind,
          'kind',
          ControllerFailureKind.notFound,
        ),
      ),
    );
    expect(c.state.data.isPlaying, isFalse);
  });

  test(
    'empty queue cannot play; repeated play does not create competing loads',
    () async {
      await expectLater(
        c.play(),
        throwsA(
          isA<ControllerFailure>().having(
            (e) => e.kind,
            'kind',
            ControllerFailureKind.invalidInput,
          ),
        ),
      );
      expect(await c.next(), isNull);
      await c.setQueue(['a']);
      await Future.wait([c.play(), c.play(), c.play()]);
      expect(engine.commands.where((cmd) => cmd == 'initialize'), hasLength(1));
      expect(engine.commands.where((cmd) => cmd == 'load:a'), hasLength(1));
      expect(engine.commands.where((cmd) => cmd == 'play'), hasLength(1));
    },
  );

  test('disposal during source load drops notifications and releases the single engine', () async {
    engine.loadGate = Completer<void>();
    var notifications = 0;
    c.addListener(() => notifications++);
    final loading = expectLater(
      c.setQueue(['a']),
      throwsA(isA<ControllerFailure>()),
    );
    await engine.loadStarted.future;
    c.dispose();
    final before = notifications;
    engine.loadGate!.complete();
    await loading;
    await c.close();
    expect(notifications, before);
    expect(engine.disposed, isTrue);
    expect(
      () => c.play(),
      throwsA(
        isA<ControllerFailure>().having(
          (e) => e.kind,
          'kind',
          ControllerFailureKind.disposed,
        ),
      ),
    );
  });
}
