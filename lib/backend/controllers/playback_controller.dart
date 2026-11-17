import 'dart:async';

import '../models/music_models.dart';
import '../services/audio/audio_service.dart';
import '../services/database/local_music_repository.dart';
import 'controller_state.dart';

enum PlaybackCapability { unavailable, local }

class PlaybackFailure extends ControllerFailure {
  PlaybackFailure(this.audioFailure)
    : super(switch (audioFailure.audioKind) {
        AudioFailureKind.missingSource => ControllerFailureKind.notFound,
        AudioFailureKind.unsupportedSource ||
        AudioFailureKind.invalidPosition ||
        AudioFailureKind.invalidCatalog => ControllerFailureKind.invalidInput,
        AudioFailureKind.disposed => ControllerFailureKind.disposed,
        _ => ControllerFailureKind.unavailable,
      }, audioFailure.message);
  final AudioFailure audioFailure;
}

class PlaybackData {
  PlaybackData({
    Iterable<Song> queue = const [],
    this.queueIndex,
    this.audio = const AudioSnapshot(),
    this.playIntent = false,
    this.capability = PlaybackCapability.unavailable,
  }) : queue = List.unmodifiable(queue);
  final List<Song> queue;
  final int? queueIndex;
  Song? get selectedSong => queueIndex == null ? null : queue[queueIndex!];
  final AudioSnapshot audio;
  final bool playIntent;
  final PlaybackCapability capability;
  bool get isPlaying => audio.isPlaying;
  bool get isPaused => audio.isPaused;
  Duration get position => audio.position;
  Duration? get duration => audio.duration;
  AudioFailure? get audioError => audio.error;
}

class PlaybackController extends MusicController<PlaybackData> {
  PlaybackController(
    this.repository, {
    AudioService? audio,
    this.continuousPlayback = true,
  }) : _audio = audio,
       super(
         PlaybackData(
           capability: audio == null
               ? PlaybackCapability.unavailable
               : PlaybackCapability.local,
         ),
       ) {
    _subscription = audio?.events.listen(_onAudio);
  }
  final LocalMusicRepository repository;
  final AudioService? _audio;
  final bool continuousPlayback;
  StreamSubscription<AudioSnapshot>? _subscription;
  bool _audioDisposed = false, _intent = false;
  int _sourceEpoch = 0;
  int? _completedEpoch;
  List<String> _desiredIds = [];
  int? _desiredIndex;
  PlaybackData _prepared = PlaybackData();
  Future<void>? _shutdown;

  @override
  ControllerFailure mapFailure(Object error) =>
      error is AudioFailure ? PlaybackFailure(error) : super.mapFailure(error);
  @override
  PlaybackData prepareData(PlaybackData data) =>
      _audio == null ? data : _withAudio(data);
  @override
  ControllerFailure? failureForData(PlaybackData data) =>
      data.audioError == null ? null : PlaybackFailure(data.audioError!);
  @override
  PlaybackData prepareErrorData(PlaybackData data, ControllerFailure failure) {
    if (_audio == null) return data;
    if (failure.kind != ControllerFailureKind.invalidInput) _intent = false;
    return _withAudio(data);
  }

  PlaybackData _withAudio(PlaybackData data) {
    final actual = _audio!.current;
    return PlaybackData(
      queue: data.queue,
      queueIndex: data.queueIndex,
      playIntent: _intent,
      capability: PlaybackCapability.local,
      audio:
          actual.session == _sourceEpoch &&
              actual.songId == data.selectedSong?.songId
          ? actual
          : AudioSnapshot(
              session: _sourceEpoch,
              songId: data.selectedSong?.songId,
            ),
    );
  }

  void _onAudio(AudioSnapshot event) {
    if (_audioDisposed || event.session != _sourceEpoch) return;
    final selected = _prepared.selectedSong;
    if (event.songId != selected?.songId) return;
    if (event.error != null) _intent = false;
    publishEventData(
      _withAudio(_prepared),
      failure: event.error == null ? null : PlaybackFailure(event.error!),
    );
    if (event.phase != AudioPhase.completed ||
        !_intent ||
        selected == null ||
        _completedEpoch == event.session) {
      return;
    }
    _completedEpoch = event.session;
    final epoch = event.session;
    scheduleMicrotask(() async {
      if (_audioDisposed || epoch != _sourceEpoch || !_intent) return;
      try {
        if (!continuousPlayback && _desiredIndex == _desiredIds.length - 1) {
          await pause();
        } else {
          await next();
        }
      } catch (_) {
        // execute() already publishes the typed failure. Never skip repeatedly.
        if (epoch == _sourceEpoch) _intent = false;
      }
    });
  }

  int _activate() {
    final epoch = ++_sourceEpoch;
    _completedEpoch = null;
    _audio!.activate(
      epoch,
      songId: _desiredIndex == null ? null : _desiredIds[_desiredIndex!],
    );
    return epoch;
  }

  void _checkEpoch(int epoch) {
    ensureActive();
    if (epoch != _sourceEpoch) {
      throw const AudioFailure(
        AudioFailureKind.cancelled,
        'Track selection was superseded',
      );
    }
  }

  Future<PlaybackData> _readDesired(List<String> ids, int? index) async =>
      PlaybackData(
        queue: await Future.wait(ids.map(_song)),
        queueIndex: index,
        capability: PlaybackCapability.local,
      );

  Future<Song?> _selectAudio(
    List<String> ids,
    int? index, {
    required bool resetIntent,
  }) {
    ensureActive();
    if (index != null && (index < 0 || index >= ids.length)) {
      return execute(
        () async => throw const ControllerFailure(
          ControllerFailureKind.invalidInput,
          'Invalid queue position',
        ),
      );
    }
    _desiredIds = List.of(ids);
    _desiredIndex = index;
    if (resetIntent) _intent = false;
    final epoch = _activate();
    return execute(() async {
      _checkEpoch(epoch);
      await _audio!.stop(epoch);
      _checkEpoch(epoch);
      final data = await _readDesired(ids, index);
      _checkEpoch(epoch);
      _prepared = data;
      final song = data.selectedSong;
      if (song != null) {
        await _audio.load(song, epoch);
        _checkEpoch(epoch);
        if (_intent) await _audio.play(epoch);
      }
      return ControllerResult(_withAudio(data), song);
    }, mutation: true);
  }

  @override
  bool isEmpty(PlaybackData data) => data.queue.isEmpty;

  Future<Song> _song(String id) async {
    requireIdentifier(id);
    final song = await repository.songs.find(id);
    if (song == null) throw MusicRecordNotFound('song', id);
    return song;
  }

  Future<void> setQueue(List<String> songIds, {int initialIndex = 0}) {
    if (_audio != null) {
      if (initialIndex < 0 ||
          (songIds.isEmpty
              ? initialIndex != 0
              : initialIndex >= songIds.length)) {
        return execute<void>(
          () async => throw const ControllerFailure(
            ControllerFailureKind.invalidInput,
            'Invalid queue position',
          ),
        );
      }
      return _selectAudio(
        List.of(songIds),
        songIds.isEmpty ? null : initialIndex,
        resetIntent: true,
      ).then<void>((_) {});
    }
    final ids = List<String>.of(songIds);
    return execute(() async {
      if (initialIndex < 0 ||
          (ids.isEmpty ? initialIndex != 0 : initialIndex >= ids.length)) {
        throw const ControllerFailure(
          ControllerFailureKind.invalidInput,
          'Invalid queue position',
        );
      }
      final songs = await Future.wait(ids.map(_song));
      return ControllerResult(
        PlaybackData(
          queue: songs,
          queueIndex: songs.isEmpty ? null : initialIndex,
        ),
        null,
      );
    });
  }

  Future<void> selectSong(String songId) => setQueue([songId]);
  Future<void> clearQueue() {
    ensureActive();
    if (_audio == null) {
      changeData(PlaybackData());
      return Future.value();
    }
    _intent = false;
    _desiredIds = [];
    _desiredIndex = null;
    final epoch = _activate();
    _prepared = PlaybackData(capability: PlaybackCapability.local);
    changeData(_withAudio(_prepared));
    return _audio.stop(epoch).catchError((Object error) {
      if (!_audioDisposed && epoch == _sourceEpoch) {
        publishEventData(_withAudio(_prepared), failure: mapFailure(error));
      }
      throw mapFailure(error);
    });
  }

  Future<Song> selectAt(int index) {
    if (_audio != null) {
      return _selectAudio(
        List.of(_desiredIds),
        index,
        resetIntent: false,
      ).then((song) => song!);
    }
    final before = state.data;
    return execute(() async {
      if (index < 0 || index >= before.queue.length) {
        throw const ControllerFailure(
          ControllerFailureKind.invalidInput,
          'Invalid queue position',
        );
      }
      final selected = await _song(before.queue[index].songId);
      final songs = before.queue.toList()..[index] = selected;
      return ControllerResult(
        PlaybackData(queue: songs, queueIndex: index),
        selected,
      );
    });
  }

  Future<Song?> next() => _move(1);
  Future<Song?> previous() => _move(-1);
  Future<Song?> _move(int direction) {
    ensureActive();
    if (_audio != null) {
      if (_desiredIds.isEmpty) return _selectAudio([], null, resetIntent: true);
      return _selectAudio(
        List.of(_desiredIds),
        (_desiredIndex! + direction) % _desiredIds.length,
        resetIntent: false,
      );
    }
    final before = state.data;
    if (before.queue.isEmpty) {
      return execute(() async => ControllerResult(PlaybackData(), null));
    }
    return selectAt((before.queueIndex! + direction) % before.queue.length);
  }

  Future<void> play() {
    if (_audio == null) return _unavailable();
    ensureActive();
    _intent = true;
    return execute(() async {
      if (_desiredIndex == null) {
        _intent = false;
        throw const ControllerFailure(
          ControllerFailureKind.invalidInput,
          'Select a song before playing',
        );
      }
      if (!_intent) return ControllerResult(_withAudio(_prepared), null);
      var epoch = _sourceEpoch;
      final actual = _audio.current;
      if (actual.phase == AudioPhase.completed ||
          actual.phase == AudioPhase.error) {
        epoch = _activate();
      }
      final data = await _readDesired(List.of(_desiredIds), _desiredIndex);
      _checkEpoch(epoch);
      _prepared = data;
      if (_audio.current.phase == AudioPhase.idle ||
          _audio.current.phase == AudioPhase.error ||
          _audio.current.songId != data.selectedSong!.songId) {
        await _audio.load(data.selectedSong!, epoch);
      }
      _checkEpoch(epoch);
      if (_intent && !_audio.current.playing) await _audio.play(epoch);
      return ControllerResult(_withAudio(data), null);
    }, mutation: true);
  }

  Future<void> resume() => play();
  Future<void> pause() {
    if (_audio == null) return _unavailable();
    ensureActive();
    _intent = false;
    return execute(() async {
      await _audio.pause(_sourceEpoch);
      return ControllerResult(_withAudio(_prepared), null);
    }, mutation: true);
  }

  Future<void> stop() {
    if (_audio == null) return _unavailable();
    ensureActive();
    _intent = false;
    final epoch = _activate();
    return execute(() async {
      await _audio.stop(epoch);
      _checkEpoch(epoch);
      final data = await _readDesired(List.of(_desiredIds), _desiredIndex);
      _checkEpoch(epoch);
      _prepared = data;
      return ControllerResult(_withAudio(data), null);
    }, mutation: true);
  }

  Future<void> seek(Duration position) {
    if (_audio == null) return _unavailable();
    return execute(() async {
      await _audio.seek(position, _sourceEpoch);
      return ControllerResult(_withAudio(_prepared), null);
    }, mutation: true);
  }

  Future<void> setVolume(double level) {
    if (_audio == null) return _unavailable();
    return execute(() async {
      await _audio.setVolume(level, _sourceEpoch);
      return ControllerResult(_withAudio(_prepared), null);
    }, mutation: true);
  }

  Future<void> _unavailable() => execute<void>(() async {
    throw const ControllerFailure(
      ControllerFailureKind.unavailable,
      'No audio service was injected',
    );
  });

  @override
  void dispose() {
    if (_audioDisposed) return;
    _audioDisposed = true;
    ++_sourceEpoch;
    _intent = false;
    _shutdown = () async {
      await _subscription?.cancel();
      await _audio?.dispose();
    }();
    unawaited(_shutdown!.catchError((Object _) {}));
    super.dispose();
  }

  Future<void> close() async {
    dispose();
    await _shutdown;
  }
}
