import 'dart:io';

import 'package:cta2000/backend/controllers/controller_state.dart';
import 'package:cta2000/backend/services/artwork/artwork_service.dart';
import 'package:cta2000/frontend/routes/app_screen.dart';
import 'package:cta2000/frontend/routes/frontend_navigation.dart';
import 'package:cta2000/frontend/widgets/design_widgets.dart';
import 'package:cta2000/frontend/widgets/song_editors.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/integrated_fixture.dart';
import 'increment71_controllers_test.dart' show MemoryArtworkStore;

void main() {
  late IntegratedFixture f;
  late MemoryArtworkStore images;
  setUp(() async {
    images = MemoryArtworkStore();
    f = IntegratedFixture();
    await f.open(
      artwork: ArtworkService(
        store: images,
        picker: () async => XFile('web/icons/Icon-192.png'),
      ),
    );
  });
  tearDown(() async => f.close());
  void scenario(String name, Future<void> Function(WidgetTester) run) =>
      testWidgets(name, (tester) async {
        await tester.runAsync(() => run(tester));
      });
  Future<void> launch(
    WidgetTester tester, {
    double width = 430,
    double scale = 1,
  }) async {
    tester.view.physicalSize = Size(width, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(f.app());
    await drainUi(tester);
  }

  Future<void> details(WidgetTester tester) async {
    Navigator.of(
      tester.element(find.byKey(const ValueKey('mini-player-preview'))),
    ).pushNamed(
      AppScreen.songDetails.route,
      arguments: const FrontendRouteArguments(songId: 'alpha'),
    );
    await drainUi(tester);
  }

  Future<void> menu(WidgetTester tester) async {
    final row = find.byType(SongRow).first;
    await tester.ensureVisible(row);
    await tester.tap(
      find.descendant(of: row, matching: find.byTooltip('Song actions')),
    );
    await drainUi(tester);
  }

  scenario(
    'metadata form validates, cancels drafts, chooses image and propagates to playback without engine changes',
    (tester) async {
      await f.store.history('metadata-history', 'alpha', ms: 1234);
      await launch(tester);
      await clickText(tester, 'Alpha song');
      final playlist = await f.dependencies.playlists.createPlaylist(
        'Metadata playlist',
      );
      await f.dependencies.playlists.addSongs(playlist.playlistId, [
        'alpha',
        'alpha',
      ]);
      final engine = List.of(f.engine.commands);
      final occurrences = f.dependencies.playback.state.data.occurrences
          .map((o) => o.id)
          .toList();
      await details(tester);
      await clickText(tester, 'Edit Song Information');
      await tester.enterText(find.byKey(const ValueKey('song-title')), '');
      await clickText(tester, 'Save');
      expect(find.text('Title is required'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('song-title')),
        'Discarded title',
      );
      await clickText(tester, 'Choose artwork');
      expect(images.images, isEmpty);
      await clickText(tester, 'Cancel');
      expect(
        (await f.store.repository.songs.find('alpha'))!.title,
        'Alpha song',
      );
      await clickText(tester, 'Edit Song Information');
      await tester.enterText(
        find.byKey(const ValueKey('song-title')),
        'Edited title',
      );
      await tester.enterText(
        find.byKey(const ValueKey('song-artist')),
        'Edited artist',
      );
      await clickText(tester, 'Choose artwork');
      await tester.tap(find.byKey(const ValueKey('song-edit-save')));
      await tester.tap(find.byKey(const ValueKey('song-edit-save')));
      await drainUi(tester);
      expect(find.byType(SongInformationEditor), findsNothing);
      expect(find.text('Edited title'), findsWidgets);
      expect(find.text('Edited artist'), findsNWidgets(2));
      expect(
        f.dependencies.playback.state.data.queue.first.title,
        'Edited title',
      );
      expect(
        f.dependencies.playback.state.data.occurrences.map((o) => o.id),
        occurrences,
      );
      expect(f.engine.commands, engine);
      expect(images.images.length, 1);
      expect(
        f.dependencies.library.state.data.songs
            .firstWhere((s) => s.songId == 'alpha')
            .artistName,
        'Edited artist',
      );
      expect(f.dependencies.playlists.state.data.songs.map((s) => s.title), [
        'Edited title',
        'Edited title',
      ]);
      expect(
        f.dependencies.statistics.state.data.topTracks.single.song.title,
        'Edited title',
      );
      final saved = (await f.store.repository.songs.find('alpha'))!;
      expect(
        await f.dependencies.artwork.read(saved.artworkPath),
        await File('web/icons/Icon-192.png').readAsBytes(),
      );
      await clickText(tester, 'Edit Song Information');
      await clickText(tester, 'Clear artwork');
      await clickText(tester, 'Save');
      expect(
        (await f.store.repository.songs.find('alpha'))!.artworkPath,
        isNull,
      );
      expect(images.images, isEmpty);
    },
  );
  scenario(
    'failed image storage retains metadata and selected image draft for retry',
    (tester) async {
      await launch(tester);
      await details(tester);
      await clickText(tester, 'Edit Song Information');
      await tester.enterText(
        find.byKey(const ValueKey('song-title')),
        'Retained draft',
      );
      await clickText(tester, 'Choose artwork');
      images.failWrite = true;
      await clickText(tester, 'Save');
      expect(find.byType(SongInformationEditor), findsOneWidget);
      expect(
        find.textContaining('Artwork could not be stored'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('song-title')))
            .controller!
            .text,
        'Retained draft',
      );
      expect(
        (await f.store.repository.songs.find('alpha'))!.title,
        'Alpha song',
      );
      images.failWrite = false;
      await clickText(tester, 'Save');
      expect(
        (await f.store.repository.songs.find('alpha'))!.title,
        'Retained draft',
      );
      expect(images.images.length, 1);
    },
  );
  scenario(
    'batch picker, row actions and duplicate additions update playlist without changing playback',
    (tester) async {
      final playlist = await f.dependencies.playlists.createPlaylist(
        'Batch playlist',
      );
      await f.dependencies.playback.setQueue(['alpha']);
      await f.dependencies.playback.play();
      await launch(tester);
      await clickText(tester, 'Batch playlist');
      await clickText(tester, 'Add');
      for (final id in ['alpha', 'beta']) {
        await tester.tap(find.byKey(ValueKey('pick-song-$id')));
        await drainUi(tester);
      }
      await tester.tap(find.byKey(const ValueKey('add-selected-songs')));
      await tester.tap(find.byKey(const ValueKey('add-selected-songs')));
      await drainUi(tester);
      expect(f.dependencies.playlists.state.data.entries.map((e) => e.songId), [
        'alpha',
        'beta',
      ]);
      await tester.pageBack();
      await drainUi(tester);
      await clickText(tester, 'Songs');
      await menu(tester);
      await clickText(tester, 'Add to Playlist');
      await clickText(tester, 'Batch playlist');
      final entries = await f.store.repository.getEntries(playlist.playlistId);
      expect(entries.map((e) => e.songId), ['alpha', 'beta', 'alpha']);
      expect(entries.map((e) => e.entryId).toSet().length, 3);
      expect(f.dependencies.playback.state.data.queue.length, 1);
      expect(f.dependencies.playback.state.data.isPlaying, true);
    },
  );
  scenario(
    'failed batch preserves selections, reports SQL error and prevents partial inserts',
    (tester) async {
      await f.dependencies.playlists.createPlaylist('Failed batch');
      await f.store.db.execute(
        "CREATE TRIGGER reject_batch BEFORE INSERT ON PLAYLIST_ENTRY WHEN NEW.song_id = 'beta' BEGIN SELECT RAISE(ABORT, 'injected'); END",
      );
      await launch(tester);
      await clickText(tester, 'Failed batch');
      await clickText(tester, 'Add');
      for (final id in ['alpha', 'beta']) {
        await tester.tap(find.byKey(ValueKey('pick-song-$id')));
        await drainUi(tester);
      }
      await clickText(tester, 'Add Selected');
      expect(find.text('2 selected'), findsOneWidget);
      expect(find.text('The local data operation failed'), findsNWidgets(2));
      expect(
        tester
            .widget<CheckboxListTile>(
              find.byKey(const ValueKey('pick-song-alpha')),
            )
            .value,
        true,
      );
      expect(await f.store.repository.entries.list(), isEmpty);
      await f.store.db.execute('DROP TRIGGER reject_batch');
      await clickText(tester, 'Add Selected');
      expect(f.dependencies.playlists.state.data.entries.length, 2);
    },
  );
  scenario(
    'queue menu priority, accessible reorder/removal and duplicate selection use occurrence IDs',
    (tester) async {
      await launch(tester);
      await clickText(tester, 'Alpha song');
      final commands = List.of(f.engine.commands);
      await menu(tester);
      await clickText(tester, 'Add to Queue');
      await menu(tester);
      await clickText(tester, 'Play Next');
      expect(f.dependencies.playback.state.data.queue.map((s) => s.songId), [
        'alpha',
        'alpha',
        'alpha',
        'beta',
      ]);
      expect(f.engine.commands, commands);
      await tester.tap(find.byKey(const ValueKey('mini-player-preview')));
      await drainUi(tester);
      await clickText(tester, 'Queue');
      expect(find.byTooltip('Remove queue occurrence 1'), findsNothing);
      await clickTooltip(tester, 'Move queue occurrence 2 down');
      await clickTooltip(tester, 'Remove queue occurrence 3');
      expect(f.dependencies.playback.state.data.queue.length, 3);
      expect(f.engine.commands, commands);
      await clickTooltip(tester, 'Select queue occurrence 3');
      expect(f.dependencies.playback.state.data.selectedSong!.songId, 'beta');
      expect(f.dependencies.playback.state.data.isPlaying, true);
      await clickText(tester, 'Close');
    },
  );
  for (final width in [320.0, 390.0, 430.0]) {
    for (final scale in [1.0, 2.0]) {
      scenario(
        'metadata/picker/queue forms fit $width at ${scale}x and keyboard inset',
        (tester) async {
          await f.dependencies.playlists.createPlaylist('Responsive');
          await f.dependencies.playback.setQueue(['alpha', 'beta', 'alpha']);
          await launch(tester, width: width, scale: scale);
          await details(tester);
          await clickText(tester, 'Edit Song Information');
          tester.view.viewInsets = const FakeViewPadding(bottom: 250);
          addTearDown(tester.view.resetViewInsets);
          await tester.pump();
          await tester.enterText(
            find.byKey(const ValueKey('song-title')),
            'Responsive title',
          );
          await clickText(tester, 'Save');
          expect(tester.takeException(), isNull);
          tester.view.resetViewInsets();
          await tester.pageBack();
          await drainUi(tester);
          await clickText(tester, 'Responsive');
          await clickText(tester, 'Add');
          await tester.tap(find.byKey(const ValueKey('pick-song-alpha')));
          await drainUi(tester);
          await clickText(tester, 'Add Selected');
          expect(tester.takeException(), isNull);
          await tester.tap(find.byKey(const ValueKey('mini-player-preview')));
          await drainUi(tester);
          await clickText(tester, 'Queue');
          await clickTooltip(tester, 'Move queue occurrence 2 down');
          expect(tester.takeException(), isNull);
          await clickText(tester, 'Close');
          expect(
            f.dependencies.library.state.status,
            isNot(ControllerStatus.loading),
          );
        },
      );
    }
  }
}
