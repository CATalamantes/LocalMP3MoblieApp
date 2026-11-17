// Test-only real SQLite composition. Audio events are explicit simulations.
import 'package:cta2000/app.dart';
import 'package:cta2000/backend/app_dependencies.dart';
import 'package:cta2000/backend/services/audio/audio_source_resolver.dart';
import 'package:cta2000/backend/services/audio/local_audio_service.dart';
import 'package:cta2000/frontend/widgets/application_binding.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'audio_fakes.dart';
import 'controller_fixture.dart';
import 'device_integration_fixture.dart';

class CleanupFailureEngine extends ScriptedAudioEngine {
  bool failStop = false;
  @override
  Future<void> stop() async {
    if (failStop) throw StateError('Test-only cleanup failure');
    await super.stop();
  }
}

class IntegratedFixture {
  IntegratedFixture({bool testDevice = false})
    : device = DeviceFixture(production: !testDevice);
  final store = ControllerFixture();
  final DeviceFixture device;
  final engine = CleanupFailureEngine();
  late AppDependencies dependencies;
  Future<void> open({
    bool songs = true,
    String? path,
    bool missingAudio = false,
  }) async {
    if (path == null) {
      await store.open();
    } else {
      await store.open(path: path);
    }
    if (songs && await store.repository.songs.find('alpha') == null) {
      await store.song(
        'alpha',
        title: 'Alpha song',
        artist: 'Zulu artist',
        filePath: 'asset:///assets/audio/test-alpha.mp3',
      );
      await store.song(
        'beta',
        title: 'Beta song',
        artist: 'Alpha artist',
        filePath: 'asset:///assets/audio/test-beta.mp3',
        added: store.now.add(const Duration(days: 1)),
      );
    }
    dependencies = AppDependencies.forTesting(
      database: store.database,
      music: store.repository,
      device: device.controller,
      audio: LocalAudioService(
        resolver: AudioSourceResolver(assetExists: (_) async => !missingAudio),
        engineFactory: () => engine,
      ),
    );
    await dependencies.device.loadSavedDevice().catchError((_) {});
  }

  Widget app() =>
      Mp3ControllerApp(dependencies: dependencies, ownsDependencies: false);
  FrontendActions actions(WidgetTester tester) =>
      tester.widget<ApplicationScope>(find.byType(ApplicationScope)).actions;
  Future<void> close() => dependencies.close();
}

Future<void> drainUi(WidgetTester tester) async {
  // Real SQLite FFI work is not advanced by the widget fake clock.
  for (var turn = 0; turn < 2; turn++) {
    await Future<void>.delayed(const Duration(milliseconds: 25));
    await tester.pumpAndSettle();
  }
}

Future<void> clickText(WidgetTester tester, String text) async {
  final target = find.text(text).last;
  await tester.ensureVisible(target);
  await tester.tap(target);
  await drainUi(tester);
}

Future<void> clickTooltip(WidgetTester tester, String tooltip) async {
  final target = find
      .byWidgetPredicate(
        (widget) => widget is IconButton && widget.tooltip == tooltip,
      )
      .last;
  await tester.ensureVisible(target);
  await tester.tap(target);
  await drainUi(tester);
}
