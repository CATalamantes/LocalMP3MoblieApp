import 'package:cta2000/backend/app_dependencies.dart';
import 'package:cta2000/backend/services/audio/audio_source_resolver.dart';
import 'package:cta2000/backend/services/audio/local_audio_service.dart';
import 'package:cta2000/frontend/development/local_playback_harness.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/audio_fakes.dart';
import 'support/controller_fixture.dart';

void main() {
  for (final width in [320.0, 390.0]) {
    testWidgets(
      'empty development harness at $width disables playback without initializing an engine',
      (tester) async {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        tester.platformDispatcher.textScaleFactorTestValue = 1.5;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        late ControllerFixture fixture;
        late AppDependencies app;
        var engines = 0;
        await tester.runAsync(() async {
          fixture = ControllerFixture();
          await fixture.open();
          app = await AppDependencies.create(
            database: fixture.database,
            audioService: LocalAudioService(
              resolver: AudioSourceResolver(assetExists: (_) async => false),
              engineFactory: () {
                engines++;
                return ScriptedAudioEngine();
              },
            ),
          );
        });
        await tester.pumpWidget(LocalPlaybackHarness(dependencies: app));
        await tester.pumpAndSettle();
        expect(find.text('Awaiting MP3 File'), findsOneWidget);
        expect(
          find.textContaining('Not Tested — Awaiting MP3 File'),
          findsOneWidget,
        );
        for (final key in [
          'dev-load',
          'dev-play',
          'dev-pause',
          'dev-resume',
          'dev-stop',
          'dev-next',
          'dev-previous',
          'dev-seek',
        ]) {
          final button = tester.widget<OutlinedButton>(
            find.byKey(ValueKey(key)),
          );
          expect(button.onPressed, isNull);
        }
        expect(engines, 0);
        expect(tester.takeException(), isNull);
        await tester.runAsync(() async {
          await app.close();
          await fixture.close();
        });
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
