import 'dart:async';
import 'dart:io';

import 'package:cta2000/backend/services/device/device_contracts.dart';

import 'package:cta2000/backend/controllers/controller_state.dart';
import 'package:cta2000/backend/services/audio/audio_service.dart';
import 'package:cta2000/frontend/pages/frontend_page.dart';
import 'package:cta2000/frontend/routes/app_screen.dart';
import 'package:cta2000/frontend/routes/frontend_navigation.dart';
import 'package:cta2000/frontend/widgets/application_binding.dart';
import 'package:cta2000/frontend/widgets/design_widgets.dart';
import 'package:cta2000/frontend/widgets/draft_editors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/integrated_fixture.dart';

void integrationWidgets(String name, Future<void> Function(WidgetTester) body) {
  testWidgets(name, (tester) async {
    await tester.runAsync(() => body(tester));
  });
}

void main() {
  late IntegratedFixture f;
  setUp(() async {
    f = IntegratedFixture();
    await f.open();
  });
  tearDown(() async {
    await f.close();
  });

  Future<void> launch(WidgetTester tester) async {
    tester.view.physicalSize = const Size(430, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(f.app());
    await drainUi(tester);
  }

  Future<void> route(
    WidgetTester tester,
    AppScreen screen, {
    String? songId,
    String? playlistId,
  }) async {
    Navigator.of(
      tester.element(find.byKey(const ValueKey('mini-player-preview'))),
    ).pushNamed(
      screen.route,
      arguments: FrontendRouteArguments(songId: songId, playlistId: playlistId),
    );
    await drainUi(tester);
  }

  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('draft-save')));
    await drainUi(tester);
  }

  integrationWidgets(
    'songs are visible immediately when the library has songs and no playlists, while explicit category choices persist',
    (tester) async {
      await launch(tester);
      expect(find.text('Select a song to play'), findsOneWidget);
      expect(find.text('Alpha song'), findsOneWidget);
      expect(find.text('Beta song'), findsOneWidget);
      final songsChip = find.byWidgetPredicate(
        (widget) =>
            widget is ChoiceChip &&
            widget.label is Text &&
            (widget.label as Text).data == 'Songs',
      );
      expect(tester.widget<ChoiceChip>(songsChip).selected, isTrue);
      await clickText(tester, 'Playlists');
      expect(find.text('Alpha song'), findsNothing);
      await clickText(tester, 'Refresh library');
      expect(find.text('Alpha song'), findsNothing);
      await clickText(tester, 'Songs');
      expect(find.text('Alpha song'), findsOneWidget);
    },
  );

  integrationWidgets(
    'SQLite songs, controller search/sort and refresh drive the Library',
    (tester) async {
      await launch(tester);
      await clickText(tester, 'Songs');
      expect(find.text('Alpha song'), findsOneWidget);
      expect(find.text('Beta song'), findsOneWidget);
      await clickTooltip(tester, 'Search library');
      await tester.enterText(
        find.byKey(const ValueKey('library-search')),
        'Zulu',
      );
      await drainUi(tester);
      expect(find.text('Alpha song'), findsOneWidget);
      expect(find.text('Beta song'), findsNothing);
      await clickTooltip(tester, 'Clear search');
      final sort = tester.widget<DropdownButton<String>>(
        find.byType(DropdownButton<String>),
      );
      sort.onChanged!('Artist');
      await drainUi(tester);
      expect(
        f.dependencies.library.state.data.visibleSongs.first.songId,
        'beta',
      );
      final rows = tester.widgetList<SongRow>(find.byType(SongRow)).toList();
      expect(rows.first.song.songId, 'beta');
      await Future.sync(() => f.store.song('gamma', title: 'Gamma song'));
      await clickText(tester, 'Refresh library');
      expect(find.text('Gamma song'), findsOneWidget);
    },
  );

  integrationWidgets(
    'create, rename and clear description persist through actual forms',
    (tester) async {
      await launch(tester);
      await clickText(tester, 'Create playlist');
      await tester.enterText(
        find.byKey(const ValueKey('draft-Title')),
        'My playlist',
      );
      await tester.enterText(
        find.byKey(const ValueKey('draft-Description')),
        'Description',
      );
      await save(tester);
      expect(find.byType(DraftEditor), findsNothing);
      expect(find.text('My playlist'), findsOneWidget);
      await clickText(tester, 'My playlist');
      await clickText(tester, 'Edit');
      await tester.enterText(
        find.byKey(const ValueKey('draft-Title')),
        'Renamed playlist',
      );
      await tester.enterText(
        find.byKey(const ValueKey('draft-Description')),
        '',
      );
      await save(tester);
      expect(find.text('Renamed playlist'), findsOneWidget);
      final records = await Future.sync(
        () => f.store.repository.getPlaylists(),
      );
      expect(records.single.name, 'Renamed playlist');
      expect(records.single.description, isNull);
    },
  );

  integrationWidgets(
    'duplicate entry removal and accessible reorder use occurrence IDs',
    (tester) async {
      final playlist = await f.dependencies.playlists.createPlaylist(
        'Duplicates',
      );
      final first = await f.dependencies.playlists.addSong(
        playlist.playlistId,
        'alpha',
      );
      final second = await f.dependencies.playlists.addSong(
        playlist.playlistId,
        'alpha',
      );
      await f.dependencies.playlists.addSong(playlist.playlistId, 'beta');
      await launch(tester);
      await clickText(tester, 'Duplicates');
      final row = find.byKey(ValueKey(first.entryId));
      await tester.ensureVisible(row);
      await tester.tap(
        find.descendant(of: row, matching: find.byType(IconButton)),
      );
      await drainUi(tester);
      await clickText(tester, 'Remove this occurrence');
      await clickText(tester, 'Remove');
      await clickText(tester, 'Close');
      var entries = await Future.sync(
        () => f.store.repository.getEntries(playlist.playlistId),
      );
      expect(entries.map((e) => e.entryId), contains(second.entryId));
      expect(entries.map((e) => e.entryId), isNot(contains(first.entryId)));
      await clickText(tester, 'Reorder');
      await clickTooltip(tester, 'Move occurrence 2 up');
      entries = await Future.sync(
        () => f.store.repository.getEntries(playlist.playlistId),
      );
      expect(entries.first.songId, 'beta');
      expect(entries.map((e) => e.position), [0, 1]);
    },
  );

  integrationWidgets(
    'add existing songs and delete playlist preserve song records',
    (tester) async {
      final playlist = await f.dependencies.playlists.createPlaylist(
        'Add and delete',
      );
      await launch(tester);
      await clickText(tester, 'Add and delete');
      await clickText(tester, 'Add');
      await clickTooltip(tester, 'Add Alpha song');
      await clickText(tester, 'Add');
      await clickText(tester, 'Close');
      expect(
        f.dependencies.playlists.state.data.entries.single.songId,
        'alpha',
      );
      await clickText(tester, 'Remove playlist');
      await clickText(tester, 'Remove');
      expect(find.text('Playlist removed. Songs preserved.'), findsOneWidget);
      expect(
        await Future.sync(
          () => f.store.repository.playlists.find(playlist.playlistId),
        ),
        isNull,
      );
      expect(
        await Future.sync(() => f.store.repository.songs.find('alpha')),
        isNotNull,
      );
    },
  );

  integrationWidgets(
    'lyrics save preserves Unicode and whitespace; cancel and clear work',
    (tester) async {
      const text = '  Hello 世界 🎵\n\nline two!  \n';
      await launch(tester);
      await route(tester, AppScreen.songDetails, songId: 'alpha');
      await clickText(tester, 'Edit lyrics');
      await tester.enterText(find.byKey(const ValueKey('draft-Lyrics')), text);
      await save(tester);
      expect(find.text(text), findsOneWidget);
      expect(
        (await Future.sync(() => f.store.repository.songs.find('alpha')))!
            .lyricsText,
        text,
      );
      await clickText(tester, 'Edit lyrics');
      await tester.enterText(
        find.byKey(const ValueKey('draft-Lyrics')),
        'discard',
      );
      await clickText(tester, 'Cancel');
      expect(find.text(text), findsOneWidget);
      await clickText(tester, 'Fullscreen Lyrics');
      expect(find.text(text), findsOneWidget);
      await tester.pageBack();
      await drainUi(tester);
      await clickText(tester, 'Clear lyrics');
      await clickText(tester, 'Clear');
      await clickText(tester, 'Close');
      expect(
        (await Future.sync(() => f.store.repository.songs.find('alpha')))!
            .lyricsText,
        isNull,
      );
    },
  );

  integrationWidgets(
    'failed save keeps draft, displays typed failure, and permits cancel',
    (tester) async {
      await launch(tester);
      await route(tester, AppScreen.songDetails, songId: 'alpha');
      await clickText(tester, 'Edit lyrics');
      await tester.enterText(
        find.byKey(const ValueKey('draft-Lyrics')),
        'retained draft',
      );
      await Future.sync(() => f.dependencies.library.removeSong('alpha'));
      await save(tester);
      expect(find.byType(DraftEditor), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(DraftEditor),
          matching: find.text('Song not found'),
        ),
        findsOneWidget,
      );
      expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('draft-Lyrics')))
            .controller!
            .text,
        'retained draft',
      );
      await clickText(tester, 'Cancel');
    },
  );

  integrationWidgets(
    'simulated audio: UI commands and shared mini-player reflect actual controller events',
    (tester) async {
      await launch(tester);
      await clickText(tester, 'Songs');
      await clickText(tester, 'Alpha song');
      expect(
        f.dependencies.playback.state.data.queue.map((song) => song.songId),
        ['alpha', 'beta'],
      );
      expect(f.dependencies.playback.state.data.isPlaying, isFalse);
      await tester.ensureVisible(find.byKey(const ValueKey('playback-toggle')));
      await tester.tap(find.byKey(const ValueKey('playback-toggle')));
      await drainUi(tester);
      expect(f.dependencies.playback.state.data.isPlaying, isTrue);
      expect(find.text('Playing locally'), findsOneWidget);
      f.engine.event(position: const Duration(seconds: 3));
      await drainUi(tester);
      expect(find.text('0:03'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('playback-next')));
      await drainUi(tester);
      expect(f.dependencies.playback.state.data.selectedSong!.songId, 'beta');
      expect(f.dependencies.playback.state.data.isPlaying, isTrue);
      await tester.tap(find.byKey(const ValueKey('playback-previous')));
      await drainUi(tester);
      expect(f.dependencies.playback.state.data.selectedSong!.songId, 'alpha');
      await tester.tap(find.byKey(const ValueKey('playback-toggle')));
      await drainUi(tester);
      expect(f.dependencies.playback.state.data.isPlaying, isFalse);
      final slider = tester.widget<Slider>(
        find.byKey(const ValueKey('playback-seek')),
      );
      slider.onChangeEnd!(.5);
      await drainUi(tester);
      expect(f.dependencies.playback.state.data.position.inSeconds, 5);
      await clickText(tester, 'Stop');
      expect(f.dependencies.playback.state.data.audio.phase, AudioPhase.idle);
      await tester.pageBack();
      await drainUi(tester);
      expect(find.text('Alpha song'), findsNWidgets(2));
      expect(find.byKey(const ValueKey('mini-player-toggle')), findsOneWidget);
    },
  );

  integrationWidgets(
    'simulated duplicate queue selection addresses index and preserves play intent',
    (tester) async {
      await f.dependencies.playback.setQueue(['alpha', 'beta', 'alpha']);
      await f.dependencies.playback.play();
      await launch(tester);
      await clickText(tester, 'Now Playing');
      await clickText(tester, 'Queue');
      await clickTooltip(tester, 'Select queue occurrence 3');
      expect(f.dependencies.playback.state.data.queueIndex, 2);
      expect(f.dependencies.playback.state.data.isPlaying, isTrue);
      await clickText(tester, 'Close');
      expect(f.dependencies.playback.state.data.queue.length, 3);
    },
  );

  integrationWidgets(
    'statistics use persisted counted and uncounted sessions and calendar periods',
    (tester) async {
      final now = DateTime.now();
      await f.store.history('counted', 'alpha', ms: 12345, started: now);
      await f.store.history(
        'uncounted',
        'beta',
        ms: 2001,
        counted: false,
        started: now,
      );
      await f.store.history(
        'prior-year',
        'alpha',
        ms: 1000,
        started: DateTime(now.year - 1, 6, 15),
      );
      await launch(tester);
      await clickText(tester, 'Statistics');
      expect(find.text('0h 0m 15s 346ms'), findsOneWidget);
      expect(find.text('2 plays'), findsOneWidget);
      expect(find.textContaining('Latest up to 20 sessions'), findsOneWidget);
      for (final label in ['Week', 'Month', 'Year', 'All Time']) {
        await clickText(tester, label);
        expect(
          f.dependencies.statistics.state.status,
          isNot(ControllerStatus.loading),
        );
        expect(
          find.text(
            label == 'All Time' ? '0h 0m 15s 346ms' : '0h 0m 14s 346ms',
          ),
          findsOneWidget,
        );
      }
      expect(find.textContaining('Design sample'), findsNothing);
    },
  );

  integrationWidgets(
    'production unavailable device remains honest across all hardware pages',
    (tester) async {
      await launch(tester);
      await clickText(tester, 'Device');
      for (final screen in [
        AppScreen.connections,
        AppScreen.sync,
        AppScreen.storage,
        AppScreen.files,
        AppScreen.bluetoothAudio,
        AppScreen.batteryDisplay,
        AppScreen.aboutDevice,
      ]) {
        await route(tester, screen);
        expect(find.text('Authenticated hardware'), findsNothing);
        expect(f.dependencies.device.state.data.hardwareAuthenticated, isFalse);
        await tester.pageBack();
        await drainUi(tester);
      }
    },
  );

  integrationWidgets(
    'saved trust, guarded connection failure, and local forgetting through supported adapters',
    (tester) async {
      f.device.saveTrust();
      await f.dependencies.device.loadSavedDevice();
      await launch(tester);
      await route(tester, AppScreen.connections);
      expect(find.text('Saved trust · Not connected'), findsOneWidget);
      await clickText(tester, 'Force Reconnect');
      expect(f.dependencies.device.state.data.hardwareAuthenticated, isFalse);
      expect(
        find.textContaining('Production authentication and pairing'),
        findsOneWidget,
      );
      await clickText(tester, 'Forget Device');
      expect(
        find.textContaining('operating-system Bluetooth bonding'),
        findsOneWidget,
      );
      await clickText(tester, 'Forget');
      expect(f.device.settings.value, isNull);
      expect(f.device.credentials.value, isNull);
      expect(
        find.textContaining('Local device trust removed.'),
        findsOneWidget,
      );
    },
  );

  integrationWidgets(
    'not-found routes show no stale details after deletion or selection changes',
    (tester) async {
      await launch(tester);
      await route(tester, AppScreen.songDetails, songId: 'alpha');
      expect(find.text('Alpha song'), findsOneWidget);
      await Future.sync(() => f.dependencies.library.removeSong('alpha'));
      await route(tester, AppScreen.lyrics, songId: 'alpha');
      expect(find.text('Song not found'), findsOneWidget);
      expect(find.text('Alpha song'), findsNothing);
    },
  );

  integrationWidgets(
    'pending editor blocks double submission and discards late UI completion after disposal',
    (tester) async {
      await launch(tester);
      var calls = 0;
      final completer = Completer<void>();
      showDraftEditor(
        tester.element(find.byKey(const ValueKey('mini-player-preview'))),
        title: 'Pending test',
        fields: const {'Title': 'draft'},
        onSave: (_) async {
          calls++;
          await completer.future;
        },
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('draft-save')));
      await tester.pump();
      expect(
        tester
            .widget<TextButton>(find.byKey(const ValueKey('draft-save')))
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<TextButton>(find.byKey(const ValueKey('draft-cancel')))
            .onPressed,
        isNull,
      );
      expect(calls, 1);
      await tester.pumpWidget(const SizedBox.shrink());
      completer.complete();
      await drainUi(tester);
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'deletion commit and failed audio cleanup are independent outcomes',
    () async {
      await f.dependencies.playback.setQueue(['alpha', 'beta', 'alpha']);
      f.engine.failStop = true;
      final actions = FrontendActions(f.dependencies);
      final outcome = await actions.removeSong('alpha');
      expect(outcome.deleted, isTrue);
      expect(outcome.cleanupError, isNotNull);
      expect(outcome.message, contains('Song removed from the library.'));
      expect(outcome.message, contains('Playback queue cleanup failed'));
      expect(await f.store.repository.songs.find('alpha'), isNull);
      expect(f.dependencies.playback.state.data.queue, isEmpty);
      f.engine.failStop = false;
    },
  );

  test(
    'failed deletion leaves queue intact and does not attempt cleanup',
    () async {
      await f.dependencies.playback.setQueue(['alpha']);
      final before = f.engine.commands.length;
      final result = await FrontendActions(f.dependencies)
          .removeSong('missing');
      expect(result.deleted, isFalse);
      expect(result.cleanupError, isNull);
      expect(f.engine.commands.length, before);
      expect(f.dependencies.playback.state.data.queue.single.songId, 'alpha');
    },
  );

  integrationWidgets(
    'empty SQLite and empty history use real zero and unavailable states',
    (tester) async {
      await f.dependencies.library.removeSong('alpha');
      await f.dependencies.library.removeSong('beta');
      await launch(tester);
      expect(find.text('No saved songs or playlists'), findsOneWidget);
      await clickText(tester, 'Statistics');
      expect(find.text('0h 0m 0s 0ms'), findsOneWidget);
      expect(find.text('No chart data'), findsNothing);
      expect(find.text('No listening history'), findsOneWidget);
    },
  );

  integrationWidgets(
    'real SQLite refresh errors are visible and loading terminates',
    (tester) async {
      await launch(tester);
      await f.store.database.close();
      await clickText(tester, 'Refresh library');
      expect(find.text('The local data operation failed'), findsOneWidget);
      expect(f.dependencies.library.state.status, ControllerStatus.error);
    },
  );

  integrationWidgets(
    'missing audio and engine initialization errors remain distinct without fake progress',
    (tester) async {
      await f.close();
      f = IntegratedFixture();
      await f.open(missingAudio: true);
      await launch(tester);
      await clickText(tester, 'Songs');
      await clickText(tester, 'Alpha song');
      expect(find.textContaining('Audio source missing.'), findsWidgets);
      expect(find.text('—:—'), findsNWidgets(2));
      expect(f.dependencies.playback.state.data.isPlaying, isFalse);
      expect(f.engine.commands, isEmpty);
    },
  );

  integrationWidgets(
    'audio initialization failure is not reported as missing MP3',
    (tester) async {
      f.engine.initializationFails = true;
      await launch(tester);
      await clickText(tester, 'Songs');
      await clickText(tester, 'Alpha song');
      expect(find.text('The audio engine could not initialize.'), findsWidgets);
      expect(f.dependencies.playback.state.data.isPlaying, isFalse);
    },
  );

  integrationWidgets(
    'authentication failure remains distinct and test sessions never render verified telemetry',
    (tester) async {
      await f.close();
      f = IntegratedFixture(testDevice: true);
      await f.open();
      await f.device.connect();
      await launch(tester);
      await route(tester, AppScreen.connections);
      expect(
        find.text('Test-only state · Not authenticated hardware'),
        findsOneWidget,
      );
      expect(find.text('Authenticated hardware'), findsNothing);
      expect(
        livePresentation(f.actions(tester), AppScreen.storage).device,
        isNull,
      );
      await expectLater(
        f.dependencies.device.execute<void>(
          () async =>
              throw const DeviceFailure(DeviceFailureKind.authentication),
        ),
        throwsA(isA<ControllerFailure>()),
      );
      await drainUi(tester);
      expect(find.text('Device authentication failed.'), findsOneWidget);
    },
  );

  integrationWidgets(
    'playlist and exact lyrics UI writes survive closing and reopening SQLite',
    (tester) async {
      final directory = await Directory.systemTemp.createTemp(
        'cta2000-integration-',
      );
      final root = Directory.systemTemp.absolute.path;
      addTearDown(() async {
        await f.close();
        if (!directory.absolute.path.startsWith(root) ||
            !directory.uri.pathSegments
                .where((p) => p.isNotEmpty)
                .last
                .startsWith('cta2000-integration-')) {
          throw StateError('Unsafe test cleanup');
        }
        await directory.delete(recursive: true);
      });
      await f.close();
      f = IntegratedFixture();
      await f.open(path: '${directory.path}/integration.db');
      await launch(tester);
      await clickText(tester, 'Create playlist');
      await tester.enterText(
        find.byKey(const ValueKey('draft-Title')),
        'Reopened playlist',
      );
      await save(tester);
      await route(tester, AppScreen.songDetails, songId: 'alpha');
      await clickText(tester, 'Edit lyrics');
      await tester.enterText(
        find.byKey(const ValueKey('draft-Lyrics')),
        '  exact 世界\n\nlyrics!  ',
      );
      await save(tester);
      await tester.pumpWidget(const SizedBox.shrink());
      await f.close();
      f = IntegratedFixture();
      await f.open(path: '${directory.path}/integration.db');
      await launch(tester);
      expect(find.text('Reopened playlist'), findsOneWidget);
      await route(tester, AppScreen.songDetails, songId: 'alpha');
      expect(find.text('  exact 世界\n\nlyrics!  '), findsOneWidget);
    },
  );

  integrationWidgets(
    'partial playlist edit reports committed rename and retains failed description',
    (tester) async {
      final playlist = await f.dependencies.playlists.createPlaylist(
        'Before',
        description: 'Original',
      );
      await f.store.db.execute(
        "CREATE TRIGGER reject_test_description BEFORE UPDATE ON PLAYLIST WHEN NEW.description = 'reject-test' BEGIN SELECT RAISE(ABORT, 'Test-only rejection'); END",
      );
      await launch(tester);
      await clickText(tester, 'Before');
      await clickText(tester, 'Edit');
      await tester.enterText(
        find.byKey(const ValueKey('draft-Title')),
        'Saved name',
      );
      await tester.enterText(
        find.byKey(const ValueKey('draft-Description')),
        'reject-test',
      );
      await save(tester);
      expect(
        find.textContaining('Playlist name saved. Description was not saved:'),
        findsOneWidget,
      );
      final stored = await f.store.repository.playlists.find(
        playlist.playlistId,
      );
      expect(stored!.name, 'Saved name');
      expect(stored.description, 'Original');
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const ValueKey('draft-Description')),
            )
            .controller!
            .text,
        'reject-test',
      );
      await tester.enterText(
        find.byKey(const ValueKey('draft-Description')),
        'Retry description',
      );
      await save(tester);
      expect(find.byType(DraftEditor), findsNothing);
      expect(
        (await f.store.repository.playlists.find(playlist.playlistId))!
            .description,
        'Retry description',
      );
    },
  );

  integrationWidgets(
    'song removal UI confirms database success despite later playback cleanup failure',
    (tester) async {
      await f.dependencies.playback.setQueue(['alpha', 'beta', 'alpha']);
      f.engine.failStop = true;
      await launch(tester);
      await clickText(tester, 'Songs');
      final row = find.byWidgetPredicate(
        (widget) => widget is SongRow && widget.song.songId == 'alpha',
      );
      await tester.ensureVisible(row);
      await tester.tap(
        find.descendant(of: row, matching: find.byType(IconButton)),
      );
      await drainUi(tester);
      await clickText(tester, 'Remove song');
      await clickText(tester, 'Remove');
      expect(
        find.textContaining('Song removed from the library.'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Playback queue cleanup failed:'),
        findsOneWidget,
      );
      expect(await f.store.repository.songs.find('alpha'), isNull);
      f.engine.failStop = false;
    },
  );

  integrationWidgets(
    'integrated lyrics form stays usable with keyboard at 320px and 200% text',
    (tester) async {
      await launch(tester);
      tester.view.physicalSize = const Size(320, 844);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      addTearDown(tester.view.resetViewInsets);
      await route(tester, AppScreen.songDetails, songId: 'alpha');
      await clickText(tester, 'Edit lyrics');
      await tester.enterText(
        find.byKey(const ValueKey('draft-Lyrics')),
        'Keyboard-safe 世界\nline two',
      );
      await tester.ensureVisible(find.byKey(const ValueKey('draft-save')));
      await save(tester);
      expect(
        (await f.store.repository.songs.find('alpha'))!.lyricsText,
        'Keyboard-safe 世界\nline two',
      );
      expect(tester.takeException(), isNull);
    },
  );

  test('recent activity chart never substitutes its 20-session subset for full-period totals', () async {
    final now = DateTime.now();
    for (var i = 0; i < 21; i++) {
      await f.store.history(
        'limit-$i',
        'alpha',
        ms: 1000,
        started: now.subtract(Duration(seconds: i)),
      );
    }
    await f.dependencies.statistics.load();
    final data = livePresentation(
      FrontendActions(f.dependencies),
      AppScreen.statistics,
    );
    expect(data.statistics!.totalCountedPlays, 21);
    expect(
      data.statistics!.totalListeningDuration,
      const Duration(seconds: 21),
    );
    expect(data.statistics!.recentHistory.length, 20);
    expect(
      data.activityHours.values.fold(0.0, (a, b) => a + b),
      closeTo(20 / 3600, 0.000000001),
    );
  });

  for (final width in [320.0, 390.0, 430.0]) {
    for (final scale in [1.0, 2.0]) {
      integrationWidgets(
        'integrated 17-screen regression at $width and ${scale}x text',
        (tester) async {
          tester.view.physicalSize = Size(width, 844);
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final playlist = await f.dependencies.playlists.createPlaylist(
            'Long playlist title for responsive layouts',
          );
          await f.dependencies.playlists.addSong(playlist.playlistId, 'alpha');
          await f.dependencies.playlists.addSong(playlist.playlistId, 'alpha');
          await f.dependencies.playback.setQueue(['alpha', 'alpha', 'beta']);
          await f.dependencies.lyrics.saveManualLyrics(
            'alpha',
            'Long manual lyrics\nSecond line 🎵',
          );
          final actions = FrontendActions(f.dependencies);
          await actions.start();
          await f.dependencies.playlists.showPlaylist(playlist.playlistId);
          await f.dependencies.lyrics.loadManualLyrics('alpha');
          for (final screen in AppScreen.values) {
            await tester.pumpWidget(
              MaterialApp(
                navigatorObservers: [frontendRouteObserver],
                home: ApplicationScope(
                  actions: actions,
                  child: FrontendPage(
                    screen: screen,
                    arguments: FrontendRouteArguments(
                      songId: 'alpha',
                      playlistId: playlist.playlistId,
                    ),
                  ),
                ),
              ),
            );
            await drainUi(tester);
            final scroll = find.byKey(ValueKey('screen-${screen.name}'));
            await tester.drag(scroll, const Offset(0, -500));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull, reason: screen.name);
          }
          actions.active = false;
        },
      );
    }
  }
}
