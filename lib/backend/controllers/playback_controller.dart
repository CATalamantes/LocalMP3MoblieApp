import 'dart:async';

import '../models/music_models.dart';
import '../services/audio/audio_service.dart';
import '../services/database/local_music_repository.dart';
import 'controller_state.dart';

enum PlaybackCapability { unavailable, local }

class QueueOccurrence {
  const QueueOccurrence(this.id, {this.manual = false});
  final String id;
  final bool manual;
}

class QueueEditFailure extends ControllerFailure {
  const QueueEditFailure(String message)
    : super(ControllerFailureKind.invalidInput, message);
}

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
    Iterable<QueueOccurrence> occurrences = const [],
    this.revision = 0,
  }) : queue = List.unmodifiable(queue),
       occurrences = List.unmodifiable(occurrences);
  final List<Song> queue;
  final List<QueueOccurrence> occurrences;
  final int revision;
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
  List<QueueOccurrence> _occurrences = [];
  int _revision = 0;
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
      occurrences: data.occurrences,
      revision: data.revision,
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
        occurrences: List.of(_occurrences),
        revision: _revision,
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
    if (initialIndex < 0 ||
        (songIds.isEmpty
            ? initialIndex != 0
            : initialIndex >= songIds.length)) {
      return execute<void>(
        () async => throw const QueueEditFailure('Invalid queue position'),
      );
    }
    if (initialIndex >= 0 &&
        (songIds.isEmpty ? initialIndex == 0 : initialIndex < songIds.length)) {
      _occurrences = [
        for (final _ in songIds) QueueOccurrence(newMusicIdentifier()),
      ];
      ++_revision;
    }
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
    _desiredIds = ids;
    _desiredIndex = ids.isEmpty ? null : initialIndex;
    ++_sourceEpoch;
    final epoch = _sourceEpoch;
    final revision = _revision;
    final occurrences = List.of(_occurrences);
    return execute(() async {
      if (initialIndex < 0 ||
          (ids.isEmpty ? initialIndex != 0 : initialIndex >= ids.length)) {
        throw const ControllerFailure(
          ControllerFailureKind.invalidInput,
          'Invalid queue position',
        );
      }
      final songs = await Future.wait(ids.map(_song));
      final data = PlaybackData(
        queue: songs,
        queueIndex: songs.isEmpty ? null : initialIndex,
        occurrences: occurrences,
        revision: revision,
      );
      if (!_audioDisposed && epoch == _sourceEpoch) _prepared = data;
      return ControllerResult(data, null);
    });
  }

  Future<void> selectSong(String songId) => setQueue([songId]);
  Future<void> clearQueue() {
    ensureActive();
    _occurrences = [];
    ++_revision;
    _desiredIds = [];
    _desiredIndex = null;
    if (_audio == null) {
      ++_sourceEpoch;
      _prepared = PlaybackData();
      changeData(_prepared);
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
    final epoch = ++_sourceEpoch;
    return execute(() async {
      if (index < 0 || index >= before.queue.length) {
        throw const ControllerFailure(
          ControllerFailureKind.invalidInput,
          'Invalid queue position',
        );
      }
      final selected = await _song(before.queue[index].songId);
      if (!_audioDisposed && epoch == _sourceEpoch) _desiredIndex = index;
      final songs = before.queue.toList()..[index] = selected;
      final data = PlaybackData(
        queue: songs,
        queueIndex: index,
        occurrences: before.occurrences,
        revision: before.revision,
      );
      if (!_audioDisposed && epoch == _sourceEpoch) _prepared = data;
      return ControllerResult(data, selected);
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

  /// Manual additions form a FIFO block before ordinary source tracks.
  Future<void> playNext(String songId) => _insert(songId, next: true);
  Future<void> addToQueue(String songId) => _insert(songId, next: false);
  Future<void> _insert(String songId, {required bool next}) {
    ensureActive();
    if (_desiredIds.isEmpty) return setQueue([songId]);
    final epoch = _sourceEpoch;
    return execute(() async {
      Song song;
      try {
        song = await _song(songId);
      } catch (_) {
        throw const QueueEditFailure('Song is no longer available');
      }
      ensureActive();
      if (epoch != _sourceEpoch) {
        throw const QueueEditFailure('Queue selection was superseded');
      }
      var index = _desiredIndex! + 1;
      if (!next) {
        while (index < _occurrences.length && _occurrences[index].manual) {
          ++index;
        }
      }
      final data = _prepared;
      if (data.queue.length != _desiredIds.length ||
          data.queueIndex != _desiredIndex) {
        throw const QueueEditFailure(
          'Select an available source queue before editing',
        );
      }
      final songs = data.queue.toList()..insert(index, song);
      _desiredIds.insert(index, songId);
      _occurrences.insert(
        index,
        QueueOccurrence(newMusicIdentifier(), manual: true),
      );
      _commitQueue(songs);
      return ControllerResult(_queueData(), null);
    }, mutation: true);
  }

  Future<void> removeUpcoming(String occurrenceId) =>
      _editUpcoming(occurrenceId, null, null);
  Future<void> reorderUpcoming(
    String occurrenceId,
    int finalIndex, {
    required int revision,
  }) => _editUpcoming(occurrenceId, finalIndex, revision);

  Future<void> _editUpcoming(String id, int? target, int? revision) {
    ensureActive();
    final epoch = _sourceEpoch;
    return execute(() async {
      if (epoch != _sourceEpoch ||
          (revision != null && revision != _revision)) {
        throw const QueueEditFailure('Queue changed; try again');
      }
      final index = _occurrences.indexWhere((entry) => entry.id == id);
      if (_desiredIndex == null ||
          index <= _desiredIndex! ||
          (target != null &&
              (target <= _desiredIndex! || target >= _occurrences.length))) {
        throw const QueueEditFailure('Only upcoming occurrences can be edited');
      }
      if (_prepared.queue.length != _desiredIds.length ||
          _prepared.queueIndex != _desiredIndex) {
        throw const QueueEditFailure(
          'Select an available source queue before editing',
        );
      }
      final songs = _prepared.queue.toList();
      final song = songs.removeAt(index);
      final songId = _desiredIds.removeAt(index);
      final occurrence = _occurrences.removeAt(index);
      if (target != null) {
        songs.insert(target, song);
        _desiredIds.insert(target, songId);
        _occurrences.insert(target, occurrence);
      }
      _commitQueue(songs);
      return ControllerResult(_queueData(), null);
    }, mutation: true);
  }

  void _commitQueue(List<Song> songs) {
    ++_revision;
    _prepared = PlaybackData(
      queue: songs,
      queueIndex: _desiredIndex,
      occurrences: List.of(_occurrences),
      revision: _revision,
      capability: _audio == null
          ? PlaybackCapability.unavailable
          : PlaybackCapability.local,
    );
  }

  PlaybackData _queueData() =>
      _audio == null ? _prepared : _withAudio(_prepared);

  /// Refresh labels without loading, stopping, or replacing an audio source.
  void refreshMetadata(List<Song> songs) {
    ensureActive();
    final latest = {for (final song in songs) song.songId: song};
    final data = _prepared;
    _prepared = PlaybackData(
      queue: data.queue.map((s) => latest[s.songId] ?? s),
      queueIndex: data.queueIndex,
      occurrences: data.occurrences,
      revision: data.revision,
      capability: data.capability,
      audio: data.audio,
      playIntent: data.playIntent,
    );
    publishEventData(_audio == null ? _prepared : _withAudio(_prepared));
  }

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
