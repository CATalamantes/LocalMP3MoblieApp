import 'dart:async';

import 'package:flutter/material.dart';

import '../../backend/app_dependencies.dart';
import '../../backend/controllers/controller_state.dart';
import '../../backend/controllers/device_controller.dart';
import '../../backend/controllers/playback_controller.dart';
import '../../backend/models/listening_statistics.dart';
import '../../backend/models/music_models.dart';
import '../../backend/services/audio/audio_service.dart';
import '../routes/app_screen.dart';
import '../routes/frontend_navigation.dart';
import 'presentation.dart';

final frontendRouteObserver = RouteObserver<ModalRoute<void>>();

String actionError(Object error) {
  if (error is DeviceControllerFailure) {
    return switch (error.deviceFailure.name) {
      'authentication' => 'Device authentication failed.',
      'authorization' => 'This phone is not authorized for that operation.',
      'identity' => 'Device identity could not be verified.',
      'transient' => 'The device request timed out or was interrupted.',
      'cancelled' => 'The device request was cancelled.',
      'storage' => 'Local device trust could not be updated on this platform.',
      _ => 'This device operation is unavailable. Production authentication and pairing are not implemented.',
    };
  }
  if (error is PlaybackFailure) {
    return switch (error.audioFailure.audioKind) {
      AudioFailureKind.missingSource =>
        'Audio source missing. Awaiting MP3 File.',
      AudioFailureKind.unsupportedSource => 'This audio source is unsupported.',
      AudioFailureKind.engineInitialization =>
        'The audio engine could not initialize.',
      AudioFailureKind.cancelled => 'Playback selection was superseded.',
      _ => 'Local audio playback failed. No playback success is claimed.',
    };
  }
  return error is ControllerFailure
      ? error.message
      : 'The operation could not be completed.';
}

/// Reports independent commits: audio cleanup cannot roll back a deleted row.
class SongRemovalOutcome {
  const SongRemovalOutcome({
    this.deletionError,
    this.cleanupError,
    this.refreshError,
    this.warnings = const [],
  });
  final Object? deletionError, cleanupError, refreshError;
  final List<String> warnings;
  bool get deleted => deletionError == null;
  String get message => !deleted
      ? 'Song was not removed: ${actionError(deletionError!)}'
      : 'Song removed from the library. Physical audio file preserved.'
            '${warnings.isEmpty ? '' : ' ${warnings.join(' ')}'}'
            '${cleanupError == null ? '' : ' Playback queue cleanup failed: ${actionError(cleanupError!)}'}'
            '${refreshError == null ? '' : ' A view refresh failed; refresh to reload saved data.'}';
}

/// Explicit orchestration only: all validation, queries and mutations stay in
/// existing controllers. This does not own another domain state store.
class FrontendActions {
  FrontendActions(this.dependencies);
  final AppDependencies dependencies;
  StatisticsPeriod period = StatisticsPeriod.allTime;
  String? detailSongId;
  bool active = true;
  int selectionGeneration = 0;

  Future<void> start() async {
    await Future.wait([
      quietly(dependencies.library.loadCachedSongs),
      quietly(dependencies.playlists.loadPlaylists),
      quietly(() => dependencies.statistics.load(period: period)),
    ]);
  }

  Future<void> quietly(Future<void> Function() operation) async {
    try {
      if (active) await operation();
    } catch (_) {
      /* Controller publishes typed failure. */
    }
  }

  Future<void> refreshLibrary() async {
    await dependencies.library.refreshLibrary();
    if (active) await dependencies.playlists.loadPlaylists();
    if (active) {
      dependencies.playback.refreshMetadata(
        dependencies.library.state.data.songs,
      );
    }
    if (active) await loadStatistics();
  }

  Future<void> loadStatistics({
    StatisticsPeriod? selected,
    String? songId,
  }) async {
    if (selected != null) period = selected;
    await dependencies.statistics.load(
      period: period,
      songId: songId ?? detailSongId,
    );
  }

  Future<void> refreshSong(String songId) async {
    if (!active) return;
    await dependencies.lyrics.loadManualLyrics(songId);
    if (!active) return;
    await dependencies.library.refreshLibrary();
    if (active) await dependencies.playlists.loadPlaylists();
    if (active) {
      dependencies.playback.refreshMetadata(
        dependencies.library.state.data.songs,
      );
    }
    if (active) await loadStatistics();
  }

  Future<SongRemovalOutcome> removeSong(String id) async {
    final affectsQueue = dependencies.playback.state.data.queue.any(
      (song) => song.songId == id,
    );
    var warnings = <String>[];
    try {
      warnings = (await dependencies.library.deleteSongInformation(id))
          .warnings;
    } catch (error) {
      return SongRemovalOutcome(deletionError: error);
    }
    Object? cleanupError, refreshError;
    if (active &&
        (affectsQueue ||
            dependencies.playback.state.data.queue.any(
              (song) => song.songId == id,
            ))) {
      try {
        await dependencies.playback.clearQueue();
      } catch (error) {
        cleanupError = error;
      }
    }
    final removedDetail = detailSongId == id;
    if (removedDetail) detailSongId = null;
    if (active) {
      try {
        await dependencies.playlists.loadPlaylists();
        if (active) {
          await loadStatistics(
            songId: detailSongId == id ? null : detailSongId,
          );
        }
      } catch (error) {
        refreshError = error;
      }
      if (removedDetail) {
        await quietly(() => dependencies.lyrics.loadManualLyrics(id));
      }
    }
    return SongRemovalOutcome(
      cleanupError: cleanupError,
      refreshError: refreshError,
      warnings: warnings,
    );
  }

  Future<void> chooseSong(
    BuildContext context,
    List<Song> queue,
    int index, {
    bool play = true,
    bool existingQueue = false,
  }) async {
    final request = ++selectionGeneration;
    await quietly(() async {
      if (existingQueue) {
        await dependencies.playback.selectAt(index);
      } else {
        await dependencies.playback.setQueue(
          queue.map((song) => song.songId).toList(),
          initialIndex: index,
        );
      }
      if (active && request == selectionGeneration && play) {
        await dependencies.playback.play();
      }
    });
  }
}

class ApplicationBinding extends StatefulWidget {
  const ApplicationBinding({
    super.key,
    required this.dependencies,
    required this.child,
  });
  final AppDependencies dependencies;
  final Widget child;
  @override
  State<ApplicationBinding> createState() => _ApplicationBindingState();
}

class _ApplicationBindingState extends State<ApplicationBinding> {
  late final actions = FrontendActions(widget.dependencies);
  @override
  void initState() {
    super.initState();
    unawaited(actions.start());
  }

  @override
  void dispose() {
    actions.active = false;
    ++actions.selectionGeneration;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      ApplicationScope(actions: actions, child: widget.child);
}

class ApplicationScope extends InheritedWidget {
  const ApplicationScope({
    super.key,
    required this.actions,
    required super.child,
  });
  final FrontendActions actions;
  static FrontendActions? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ApplicationScope>()?.actions;
  @override
  bool updateShouldNotify(ApplicationScope oldWidget) =>
      actions != oldWidget.actions;
}

PresentationMode controllerMode(ControllerState<Object?> state) =>
    switch (state.status) {
      ControllerStatus.idle ||
      ControllerStatus.loading => PresentationMode.loading,
      ControllerStatus.error => PresentationMode.error,
      ControllerStatus.empty => PresentationMode.empty,
      ControllerStatus.success => PresentationMode.ready,
    };

ScreenPresentation livePresentation(
  FrontendActions actions,
  AppScreen screen, {
  String? songId,
  String? playlistId,
}) {
  final d = actions.dependencies;
  final library = d.library.state, playlists = d.playlists.state;
  final playback = d.playback.state, lyrics = d.lyrics.state;
  final statistics = d.statistics.state, device = d.device.state;
  final selectedLyrics =
      lyrics.data.song?.songId == songId &&
          !(lyrics.status == ControllerStatus.error &&
              lyrics.error?.kind == ControllerFailureKind.notFound)
      ? lyrics.data.song
      : null;
  final verified =
      device.data.hardwareAuthenticated &&
      device.data.status?.testOnly == false &&
      device.data.status?.deviceId == device.data.trustedDevice?.deviceId;
  final chart = <String, double>{};
  final statisticsReady = {
    ControllerStatus.success,
    ControllerStatus.empty,
  }.contains(statistics.status);
  final history =
      (statisticsReady ? statistics.data.recentHistory : <ListeningHistory>[])
          .toList()
        ..sort((a, b) => a.startedAt.compareTo(b.startedAt));
  for (final record in history) {
    final day = record.startedAt.toLocal().toIso8601String().split('T').first;
    chart.update(
      day,
      (value) => value + record.listenedMs / 3600000,
      ifAbsent: () => record.listenedMs / 3600000,
    );
  }
  var state = switch (screen) {
    AppScreen.library => library,
    AppScreen.playlist => playlists,
    AppScreen.songDetails || AppScreen.lyrics => lyrics,
    AppScreen.nowPlaying => playback,
    AppScreen.statistics => statistics,
    _ => device,
  };
  var mode = controllerMode(state);
  if (screen == AppScreen.library &&
      library.status != ControllerStatus.error &&
      playlists.status == ControllerStatus.error) {
    state = playlists;
    mode = PresentationMode.error;
  }
  if (screen == AppScreen.library &&
      mode == PresentationMode.empty &&
      playlists.data.playlists.isNotEmpty) {
    mode = PresentationMode.ready;
  }
  if (screen == AppScreen.playlist && playlistId == null) {
    mode = PresentationMode.empty;
  }
  Song freshSong(Song song) =>
      library.data.songs
          .where((record) => record.songId == song.songId)
          .firstOrNull ??
      song;
  final current = playback.data.selectedSong;
  final song = screen == AppScreen.songDetails || screen == AppScreen.lyrics
      ? selectedLyrics
      : current == null
      ? null
      : freshSong(current);
  final playlist = playlists.data.selectedPlaylist?.playlistId == playlistId
      ? playlists.data.selectedPlaylist
      : null;
  if ({AppScreen.songDetails, AppScreen.lyrics}.contains(screen) &&
      songId == null) {
    mode = PresentationMode.empty;
  }
  if (screen == AppScreen.playlist &&
      playlist == null &&
      mode != PresentationMode.loading &&
      mode != PresentationMode.error) {
    mode = PresentationMode.empty;
  }
  final deviceScreen = {
    AppScreen.device,
    AppScreen.connections,
    AppScreen.sync,
    AppScreen.storage,
    AppScreen.files,
    AppScreen.bluetoothAudio,
    AppScreen.batteryDisplay,
    AppScreen.aboutDevice,
  }.contains(screen);
  if (deviceScreen &&
      device.status != ControllerStatus.loading &&
      !device.data.hardwareAuthenticated) {
    mode = device.status == ControllerStatus.error
        ? PresentationMode.error
        : PresentationMode.unavailable;
  }
  if ({
    AppScreen.addMusic,
    AppScreen.record,
    AppScreen.saveRecording,
  }.contains(screen)) {
    mode = PresentationMode.unavailable;
  }
  return ScreenPresentation(
    mode: mode,
    integrated: true,
    errorMessage: state.error == null ? null : actionError(state.error!),
    song: song,
    playlist: playlist,
    songs: screen == AppScreen.library
        ? library.data.visibleSongs
        : screen == AppScreen.playlist
        ? (playlist == null ? [] : playlists.data.songs)
        : playback.data.queue.map(freshSong),
    playlists: playlists.data.playlists,
    entries: playlist == null ? [] : playlists.data.entries,
    availableSongs: library.data.songs,
    statistics: statisticsReady ? statistics.data : null,
    playback: playback.data,
    playbackBusy: playback.status == ControllerStatus.loading,
    playbackError: playback.error == null ? null : actionError(playback.error!),
    device: verified ? device.data.status : null,
    deviceData: device.data,
    activityHours: chart,
    period: actions.period,
  );
}

class BoundContent extends StatefulWidget {
  const BoundContent({
    super.key,
    required this.screen,
    required this.fallback,
    required this.builder,
    this.songId,
    this.playlistId,
  });
  final AppScreen screen;
  final ScreenPresentation fallback;
  final String? songId, playlistId;
  final Widget Function(BuildContext, ScreenPresentation) builder;
  @override
  State<BoundContent> createState() => _BoundContentState();
}

class _BoundContentState extends State<BoundContent> with RouteAware {
  FrontendActions? actions;
  ModalRoute<void>? route;
  @override
  void didUpdateWidget(BoundContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.songId != oldWidget.songId ||
        widget.playlistId != oldWidget.playlistId ||
        widget.screen != oldWidget.screen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _load();
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final current = ApplicationScope.of(context);
    if (current != actions) {
      actions = current;
      if (current != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _load();
        });
      }
    }
    final next = ModalRoute.of(context);
    if (next is ModalRoute<void> && next != route) {
      frontendRouteObserver.unsubscribe(this);
      route = next;
      frontendRouteObserver.subscribe(this, next);
    }
  }

  void _load() {
    final a = actions;
    if (a == null || !(route?.isCurrent ?? true)) return;
    if (widget.screen == AppScreen.playlist && widget.playlistId != null) {
      unawaited(
        a.quietly(
          () => a.dependencies.playlists.showPlaylist(widget.playlistId!),
        ),
      );
    }
    if ({AppScreen.songDetails, AppScreen.lyrics}.contains(widget.screen) &&
        widget.songId != null) {
      a.detailSongId = widget.songId;
      unawaited(
        a.quietly(() => a.dependencies.lyrics.loadManualLyrics(widget.songId!)),
      );
      unawaited(a.quietly(() => a.loadStatistics(songId: widget.songId)));
    }
  }

  @override
  void didPopNext() {
    _load();
  }

  @override
  void dispose() {
    frontendRouteObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = actions;
    if (a == null) return widget.builder(context, widget.fallback);
    final d = a.dependencies;
    final listeners = switch (widget.screen) {
      AppScreen.library ||
      AppScreen.playlist => <Listenable>[d.library, d.playlists],
      AppScreen.nowPlaying => <Listenable>[d.playback, d.lyrics, d.library],
      AppScreen.songDetails || AppScreen.lyrics => <Listenable>[
        d.lyrics,
        d.playback,
        d.statistics,
        d.library,
      ],
      AppScreen.statistics => <Listenable>[d.statistics, d.library],
      _ => <Listenable>[d.device],
    };
    return AnimatedBuilder(
      animation: Listenable.merge(listeners),
      builder: (context, _) {
        final data = livePresentation(
          a,
          widget.screen,
          songId: widget.songId,
          playlistId: widget.playlistId,
        );
        final origin = PageNavigationScope.of(context)?.origin;
        return PageNavigationScope(
          origin: origin,
          presentation: data,
          child: Builder(builder: (context) => widget.builder(context, data)),
        );
      },
    );
  }
}
