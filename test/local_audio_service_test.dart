import 'dart:async';

import 'package:cta2000/backend/models/music_models.dart';
import 'package:cta2000/backend/services/audio/audio_service.dart';
import 'package:cta2000/backend/services/audio/audio_source_resolver.dart';
import 'package:cta2000/backend/services/audio/local_audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';

import 'support/audio_fakes.dart';

Song fixture({String path = 'asset:///assets/audio/fake.mp3'}) => Song(
  songId: 'fake',
  title: 'Test double only',
  artistName: 'Test',
  durationMs: 0,
  audioFormat: 'MP3',
  filePath: path,
  dateAdded: DateTime.utc(2026),
);
Matcher audioFailure(AudioFailureKind kind) =>
    isA<AudioFailure>().having((e) => e.audioKind, 'audioKind', kind);

void main() {
  late ScriptedAudioEngine engine;
  late LocalAudioService service;
  setUp(() {
    engine = ScriptedAudioEngine();
    service = LocalAudioService(
      resolver: AudioSourceResolver(assetExists: (_) async => true),
      engineFactory: () => engine,
    );
    service.activate(1, songId: 'fake');
  });
  tearDown(() => service.dispose());

  test('service forwards load/play/pause/stop/seek and real-engine event fields (simulated)', () async {
    final phases = <AudioPhase>[];
    final subscription = service.events.listen((e) => phases.add(e.phase));
    await service.load(fixture(), 1);
    expect(service.current.phase, AudioPhase.ready);
    expect(service.current.duration, const Duration(seconds: 10));
    await service.play(1);
    expect(service.current.isPlaying, isTrue);
    engine.event(position: const Duration(seconds: 2));
    expect(service.current.position, const Duration(seconds: 2));
    engine.event(phase: AudioPhase.buffering);
    expect(service.current.playing, isTrue);
    expect(service.current.isPlaying, isFalse);
    engine.event(phase: AudioPhase.ready);
    await service.pause(1);
    expect(service.current.isPaused, isTrue);
    await service.resume(1);
    expect(service.current.isPlaying, isTrue);
    await service.seek(const Duration(seconds: 99), 1);
    expect(service.current.position, const Duration(seconds: 10));
    expect(service.current.phase, AudioPhase.completed);
    await service.setVolume(0.4, 1);
    await service.stop(1);
    expect(service.current.position, Duration.zero);
    expect(service.current.phase, AudioPhase.idle);
    expect(engine.commands, contains('volume:0.4'));
    expect(
      phases,
      containsAll([AudioPhase.loading, AudioPhase.ready, AudioPhase.completed]),
    );
    await subscription.cancel();
  });

  test(
    'missing and unsupported sources fail before constructing an engine',
    () async {
      var constructed = 0;
      final missing = LocalAudioService(
        resolver: AudioSourceResolver(assetExists: (_) async => false),
        engineFactory: () {
          constructed++;
          return engine;
        },
      );
      missing.activate(1, songId: 'fake');
      await expectLater(
        missing.load(fixture(), 1),
        throwsA(audioFailure(AudioFailureKind.missingSource)),
      );
      await expectLater(
        missing.load(fixture(path: 'https://example.invalid/audio.mp3'), 1),
        throwsA(audioFailure(AudioFailureKind.unsupportedSource)),
      );
      await expectLater(
        missing.load(fixture(path: 'audio/ambiguous.mp3'), 1),
        throwsA(audioFailure(AudioFailureKind.unsupportedSource)),
      );
      expect(constructed, 0);
      await missing.dispose();
    },
  );

  test('initialization, decoding and play failures remain distinct and never report playing', () async {
    engine.initializationFails = true;
    await expectLater(
      service.load(fixture(), 1),
      throwsA(audioFailure(AudioFailureKind.engineInitialization)),
    );
    expect(service.current.isPlaying, isFalse);
    await service.dispose();
    engine = ScriptedAudioEngine()..loadFails = true;
    service = LocalAudioService(
      resolver: AudioSourceResolver(assetExists: (_) async => true),
      engineFactory: () => engine,
    );
    service.activate(1, songId: 'fake');
    await expectLater(
      service.load(fixture(), 1),
      throwsA(audioFailure(AudioFailureKind.playback)),
    );
    expect(service.current.isPlaying, isFalse);
    engine.loadFails = false;
    await service.load(fixture(), 1);
    engine.playFails = true;
    await expectLater(
      service.play(1),
      throwsA(audioFailure(AudioFailureKind.playback)),
    );
    expect(service.current.phase, AudioPhase.error);
    expect(service.current.isPlaying, isFalse);
  });

  test('a missing platform plugin during load is an initialization failure, not a missing source', () async {
    engine.loadError = MissingPluginException('Mock plugin unavailable');
    await expectLater(
      service.load(fixture(), 1),
      throwsA(audioFailure(AudioFailureKind.engineInitialization)),
    );
    expect(service.current.isPlaying, isFalse);
  });

  test('play requests alone do not synthesize playing events', () async {
    engine.holdPlayEvents = true;
    await service.load(fixture(), 1);
    await service.play(1);
    expect(service.current.isPlaying, isFalse);
    engine.event(playing: true);
    expect(service.current.isPlaying, isTrue);
  });

  test('unknown/negative seeks are rejected and seek position waits for acceptance', () async {
    await expectLater(
      service.seek(Duration.zero, 1),
      throwsA(audioFailure(AudioFailureKind.invalidPosition)),
    );
    await service.load(fixture(), 1);
    await expectLater(
      service.seek(const Duration(seconds: -1), 1),
      throwsA(audioFailure(AudioFailureKind.invalidPosition)),
    );
    engine.seekGate = Completer<void>();
    final seeking = service.seek(const Duration(seconds: 3), 1);
    await Future<void>.delayed(Duration.zero);
    expect(service.current.position, Duration.zero);
    engine.seekGate!.complete();
    await seeking;
    expect(service.current.position, const Duration(seconds: 3));
    await expectLater(
      service.setVolume(double.nan, 1),
      throwsA(audioFailure(AudioFailureKind.invalidPosition)),
    );
    engine.reportedDuration = null;
    engine.event();
    await expectLater(
      service.seek(Duration.zero, 1),
      throwsA(audioFailure(AudioFailureKind.invalidPosition)),
    );
  });

  test('source generations drop late progress and completion events', () async {
    await service.load(fixture(), 1);
    service.activate(2, songId: 'new');
    engine.emit(
      const AudioSnapshot(
        session: 1,
        songId: 'fake',
        phase: AudioPhase.completed,
        playing: true,
      ),
    );
    expect(service.current.session, 2);
    expect(service.current.songId, 'new');
    expect(service.current.phase, AudioPhase.idle);
    await expectLater(
      service.play(1),
      throwsA(audioFailure(AudioFailureKind.cancelled)),
    );
  });

  test(
    'disposal during loading releases resources and drops late results',
    () async {
      engine.loadGate = Completer<void>();
      final loading = expectLater(
        service.load(fixture(), 1),
        throwsA(audioFailure(AudioFailureKind.disposed)),
      );
      await engine.loadStarted.future;
      final closing = service.dispose();
      engine.loadGate!.complete();
      await loading;
      await closing;
      expect(engine.disposed, isTrue);
      await expectLater(
        service.play(1),
        throwsA(audioFailure(AudioFailureKind.disposed)),
      );
    },
  );
}
