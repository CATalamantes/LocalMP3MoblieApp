import 'package:cta2000/app.dart';
import 'package:cta2000/frontend/routes/app_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Finder screenFinder(AppScreen screen) =>
    find.byKey(ValueKey('screen-${screen.name}'));

Future<void> selectTab(WidgetTester tester, AppScreen screen) async {
  await tester.tap(find.byKey(ValueKey('tab-${screen.name}')));
  await tester.pumpAndSettle();
  expect(screenFinder(screen), findsOneWidget);
}

Future<void> openDetail(WidgetTester tester, AppScreen screen) async {
  final link = find.byKey(ValueKey('open-${screen.name}'));
  await tester.ensureVisible(link);
  await tester.tap(link);
  await tester.pumpAndSettle();
  expect(screenFinder(screen), findsOneWidget);
  expect(tester.takeException(), isNull);
}

void main() {
  // Every approved screen is exercised via a visible navigation control.
  // Each detail path is unwound one level at a time to verify its origin.
  final journeys = <AppScreen, List<List<AppScreen>>>{
    AppScreen.library: [
      [
        AppScreen.playlist,
        AppScreen.nowPlaying,
        AppScreen.songDetails,
        AppScreen.lyrics,
      ],
      [AppScreen.nowPlaying],
      [AppScreen.sync],
    ],
    AppScreen.addMusic: [
      [AppScreen.record, AppScreen.saveRecording],
    ],
    AppScreen.device: [
      [AppScreen.connections],
      [AppScreen.sync],
      [AppScreen.storage, AppScreen.files],
      [AppScreen.files],
      [AppScreen.bluetoothAudio],
      [AppScreen.batteryDisplay],
      [AppScreen.aboutDevice],
    ],
    AppScreen.statistics: [[]],
  };

  test('navigation journeys cover exactly the 17 approved screens', () {
    final covered = <AppScreen>{
      ...journeys.keys,
      for (final paths in journeys.values)
        for (final path in paths) ...path,
    };
    expect(covered, AppScreen.values.toSet());
    expect(covered, hasLength(17));
    expect(
      AppScreen.values.map((screen) => screen.route).toSet(),
      hasLength(17),
    );
  });

  for (final entry in journeys.entries) {
    for (final path in entry.value) {
      testWidgets(
        '${entry.key.name}: ${path.map((s) => s.name).join(' → ')} and back',
        (tester) async {
          await tester.pumpWidget(const Mp3ControllerApp());
          expect(screenFinder(AppScreen.library), findsOneWidget);
          await selectTab(tester, entry.key);
          for (final screen in path) {
            await openDetail(tester, screen);
          }
          for (var index = path.length - 1; index >= 0; index--) {
            await tester.pageBack();
            await tester.pumpAndSettle();
            expect(
              screenFinder(index == 0 ? entry.key : path[index - 1]),
              findsOneWidget,
            );
            expect(tester.takeException(), isNull);
          }
        },
      );
    }
  }

  testWidgets('mini-player preview returns to the selected tab', (
    tester,
  ) async {
    await tester.pumpWidget(const Mp3ControllerApp());
    await selectTab(tester, AppScreen.statistics);
    await tester.tap(find.byKey(const ValueKey('mini-player-preview')));
    await tester.pumpAndSettle();
    expect(screenFinder(AppScreen.nowPlaying), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(screenFinder(AppScreen.statistics), findsOneWidget);
    await selectTab(tester, AppScreen.library);
  });

  for (final width in [320.0, 390.0]) {
    testWidgets('all screens fit width $width with enlarged text', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(const Mp3ControllerApp());
      for (final mainScreen in AppScreen.mainScreens) {
        await selectTab(tester, mainScreen);
        expect(tester.takeException(), isNull, reason: mainScreen.name);
      }
      final context = tester.element(screenFinder(AppScreen.statistics));
      for (final screen in AppScreen.values.where(
        (s) => !AppScreen.mainScreens.contains(s),
      )) {
        Navigator.of(context).pushNamed(screen.route);
        await tester.pumpAndSettle();
        expect(screenFinder(screen), findsOneWidget);
        expect(tester.takeException(), isNull, reason: screen.name);
        await tester.pageBack();
        await tester.pumpAndSettle();
      }
    });
  }
}
