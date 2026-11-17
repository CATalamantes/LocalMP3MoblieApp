import 'package:cta2000/frontend/development/frontend_fixtures.dart';
import 'package:cta2000/frontend/pages/frontend_page.dart';
import 'package:cta2000/frontend/pages/library_pages.dart';
import 'package:cta2000/frontend/pages/main_shell.dart';
import 'package:cta2000/frontend/routes/app_router.dart';
import 'package:cta2000/frontend/routes/app_screen.dart';
import 'package:cta2000/frontend/routes/frontend_navigation.dart';
import 'package:cta2000/frontend/theme/app_theme.dart';
import 'package:cta2000/frontend/widgets/draft_editors.dart';
import 'package:cta2000/frontend/widgets/design_widgets.dart';
import 'package:cta2000/frontend/widgets/presentation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> render(
  WidgetTester tester,
  AppScreen screen,
  ScreenPresentation data,
) async {
  await tester.pumpWidget(
    MaterialApp(
      key: UniqueKey(),
      theme: AppTheme.frontend,
      onGenerateRoute: AppRouter.onGenerateRoute,
      home: AppScreen.mainScreens.contains(screen)
          ? MainShell(initialScreen: screen, presentation: data)
          : FrontendPage(
              screen: screen,
              arguments: FrontendRouteArguments(presentation: data),
            ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'grid selection changes the playlist layout at narrow enlarged text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 844);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await render(
        tester,
        AppScreen.library,
        frontendFixture(PresentationMode.ready),
      );
      expect(find.byType(ArtworkFrame), findsNothing);
      await tapVisible(tester, find.byTooltip('Grid layout'));
      expect(find.byType(ArtworkFrame), findsNWidgets(4));
      expect(tester.takeException(), isNull);
      await tapVisible(tester, find.byTooltip('List layout'));
      expect(find.byType(ArtworkFrame), findsNothing);
    },
  );
  testWidgets(
    'recording draft stays usable with the keyboard at 320px and 200% text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 844);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      addTearDown(tester.view.resetViewInsets);
      await render(
        tester,
        AppScreen.saveRecording,
        frontendFixture(PresentationMode.ready),
      );
      final title = find.byKey(const ValueKey('recording-Title'));
      await tester.ensureVisible(title);
      await tester.enterText(title, 'Unsaved keyboard draft');
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('Save & Add to Library'));
      expect(
        find.text(
          'Saving unavailable. No recording or library entry was created.',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
  for (final mode in PresentationMode.values) {
    testWidgets('all 17 screens render the ${mode.name} presentation', (
      tester,
    ) async {
      for (final screen in AppScreen.values) {
        await render(tester, screen, frontendFixture(mode));
        expect(find.byKey(ValueKey('screen-${screen.name}')), findsOneWidget);
        expect(
          tester.takeException(),
          isNull,
          reason: '${screen.name}/${mode.name}',
        );
        if (mode == PresentationMode.loading) {
          expect(find.text('Loading'), findsOneWidget);
        }
        if (mode == PresentationMode.error) {
          expect(find.text('Unable to display data'), findsOneWidget);
        }
      }
    });
  }
  for (final width in [320.0, 390.0, 430.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'populated and unconnected layouts fit $width at ${scale}x text',
        (tester) async {
          tester.view.physicalSize = Size(width, 844);
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          for (final mode in [
            PresentationMode.ready,
            PresentationMode.unconnected,
          ]) {
            for (final screen in AppScreen.values) {
              await render(tester, screen, frontendFixture(mode));
              expect(
                tester.takeException(),
                isNull,
                reason: '${screen.name}/${mode.name}/$width/$scale',
              );
              await tester.drag(
                find.byKey(ValueKey('screen-${screen.name}')),
                const Offset(0, -650),
              );
              await tester.pumpAndSettle();
              expect(tester.takeException(), isNull);
            }
          }
        },
      );
    }
  }
  testWidgets(
    'search input and sort choices publish UI callbacks without sorting data',
    (tester) async {
      final data = frontendFixture(PresentationMode.ready);
      String? query, sort;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.frontend,
          home: Scaffold(
            body: LibraryPage(
              data: data,
              searchExpanded: true,
              onSearchChanged: (v) => query = v,
              onSortChanged: (v) => sort = v,
            ),
          ),
        ),
      );
      await tester.enterText(
        find.byKey(const ValueKey('library-search')),
        'my own music',
      );
      expect(query, 'my own music');
      await tapVisible(tester, find.text('Recents'));
      await tapVisible(tester, find.text('Title').last);
      expect(sort, 'Title');
      expect(data.songs.first.title, 'Night Window');
      await tapVisible(tester, find.text('Songs'));
      expect(find.text('Night Window'), findsOneWidget);
    },
  );
  testWidgets('header search opens the real local search field', (
    tester,
  ) async {
    await render(tester, AppScreen.library, ScreenPresentation());
    expect(find.byKey(const ValueKey('library-search')), findsNothing);
    await tester.tap(find.byTooltip('Search library'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('library-search')),
      'draft query',
    );
    expect(find.text('draft query'), findsOneWidget);
  });
  testWidgets(
    'playlist draft validates, refuses persistence and cancels without changing metadata',
    (tester) async {
      final data = frontendFixture(PresentationMode.ready);
      await render(tester, AppScreen.playlist, data);
      await tapVisible(tester, find.text('Edit'));
      final title = find.byKey(const ValueKey('draft-Title'));
      await tester.enterText(title, '');
      await tapVisible(tester, find.byKey(const ValueKey('draft-save')));
      expect(find.text('Title is required'), findsOneWidget);
      await tester.enterText(title, 'Unsaved replacement');
      await tapVisible(tester, find.byKey(const ValueKey('draft-save')));
      expect(
        find.text('Saving unavailable. Your draft has not been applied.'),
        findsOneWidget,
      );
      expect(find.byType(DraftEditor), findsOneWidget);
      await tapVisible(tester, find.byKey(const ValueKey('draft-cancel')));
      expect(data.playlist!.name, 'After Hours');
      expect(find.text('After Hours'), findsOneWidget);
    },
  );
  testWidgets(
    'manual lyrics editing preserves exact multiline draft and cancel restores display',
    (tester) async {
      final data = frontendFixture(PresentationMode.ready);
      await render(tester, AppScreen.songDetails, data);
      await tapVisible(tester, find.text('Edit lyrics'));
      const draft = '  First line\n\nSecond line  \n第三行';
      final lyrics = find.byKey(const ValueKey('draft-Lyrics'));
      await tester.enterText(lyrics, draft);
      await tapVisible(tester, find.byKey(const ValueKey('draft-save')));
      expect(tester.widget<TextFormField>(lyrics).controller!.text, draft);
      await tapVisible(tester, find.byKey(const ValueKey('draft-cancel')));
      expect(find.text(data.song!.lyricsText!), findsOneWidget);
      expect(data.song!.lyricsText, isNot(draft));
    },
  );
  testWidgets(
    'recording form validates only a draft and never invents a file',
    (tester) async {
      final data = frontendFixture(PresentationMode.ready);
      await render(tester, AppScreen.saveRecording, data);
      await tapVisible(tester, find.text('Save & Add to Library'));
      expect(find.text('Title is required'), findsOneWidget);
      final title = find.byKey(const ValueKey('recording-Title'));
      await tester.ensureVisible(title);
      await tester.enterText(title, 'Unsaved title');
      await tapVisible(tester, find.text('Save & Add to Library'));
      expect(
        find.text(
          'Saving unavailable. No recording or library entry was created.',
        ),
        findsOneWidget,
      );
      await tapVisible(tester, find.text('Cancel draft'));
      expect(tester.widget<TextFormField>(title).controller!.text, '');
      expect(data.recording!.recordingId, 'design-recording');
      await render(tester, AppScreen.saveRecording, ScreenPresentation());
      expect(
        tester
            .widget<TextButton>(
              find.widgetWithText(TextButton, 'Save & Add to Library'),
            )
            .onPressed,
        isNull,
      );
    },
  );
  testWidgets(
    'clipboard paste fills the URL only, and local syntax validation is visible',
    (tester) async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async => call.method == 'Clipboard.getData'
            ? {'text': 'https://example.invalid/my-file'}
            : null,
      );
      addTearDown(
        () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
      );
      await render(tester, AppScreen.addMusic, ScreenPresentation());
      await tapVisible(tester, find.byTooltip('Paste URL'));
      final field = find.byKey(const ValueKey('audio-url'));
      expect(
        tester.widget<TextFormField>(field).controller!.text,
        'https://example.invalid/my-file',
      );
      await tester.enterText(field, 'not a URL');
      await tester.pump();
      expect(find.text('Enter an HTTP or HTTPS URL'), findsOneWidget);
      expect(
        tester
            .widget<TextButton>(
              find.widgetWithText(TextButton, 'Download Song'),
            )
            .onPressed,
        isNull,
      );
    },
  );
  testWidgets(
    'statistics period selection changes presentation without recalculating statistics',
    (tester) async {
      final data = frontendFixture(PresentationMode.ready);
      await render(tester, AppScreen.statistics, data);
      for (final period in ['Week', 'Month', 'Year', 'All Time']) {
        await tapVisible(tester, find.widgetWithText(ChoiceChip, period));
        expect(
          tester
              .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, period))
              .selected,
          isTrue,
        );
      }
      expect(data.statistics!.totalCountedPlays, 24);
    },
  );
  testWidgets('forget confirmation is explicit and cannot remove trust', (
    tester,
  ) async {
    final data = frontendFixture(PresentationMode.ready);
    await render(tester, AppScreen.connections, data);
    await tapVisible(tester, find.text('Forget Device'));
    await tapVisible(tester, find.widgetWithText(TextButton, 'Forget'));
    expect(
      find.text('Forget unavailable. Nothing was changed.'),
      findsOneWidget,
    );
    expect(data.device!.deviceId, 'DESIGN-SAMPLE');
    await tapVisible(tester, find.text('Cancel'));
  });
  testWidgets(
    'all local transport buttons and progress sliders remain disabled',
    (tester) async {
      await render(
        tester,
        AppScreen.nowPlaying,
        frontendFixture(PresentationMode.ready),
      );
      for (final label in [
        'Previous unavailable',
        'Playback unavailable',
        'Next unavailable',
        'Shuffle unavailable',
        'Repeat unavailable',
      ]) {
        expect(
          tester
              .widget<IconButton>(
                find.byWidgetPredicate(
                  (widget) => widget is IconButton && widget.tooltip == label,
                ),
              )
              .onPressed,
          isNull,
        );
      }
      expect(tester.widget<Slider>(find.byType(Slider)).onChanged, isNull);
      expect(find.textContaining('Awaiting MP3 File'), findsOneWidget);
      expect(find.text('—:—'), findsNWidgets(2));
    },
  );
  testWidgets(
    'keyboard-open lyrics dialog remains scrollable at 320px and 200% text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 844);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      addTearDown(tester.view.resetViewInsets);
      await render(
        tester,
        AppScreen.songDetails,
        frontendFixture(PresentationMode.ready),
      );
      await tapVisible(tester, find.text('Edit lyrics'));
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      await tapVisible(tester, find.byKey(const ValueKey('draft-cancel')));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'navigation and icon controls meet labels and touch-target guidelines',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await render(tester, AppScreen.library, ScreenPresentation());
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
      } finally {
        semantics.dispose();
      }
    },
  );
  test('Midnight Crimson tokens are unchanged and preview files are references, not audio', () {
    expect(AppTheme.background, const Color(0xFF101722));
    expect(AppTheme.crimson, const Color(0xFFE11927));
    expect(AppTheme.blue, const Color(0xFF1D3956));
    expect(frontendFixture(PresentationMode.ready).device!.testOnly, isTrue);
    expect(ScreenPresentation().song, isNull);
  });
}
