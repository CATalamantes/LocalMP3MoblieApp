import '../models/music_models.dart';
import '../services/database/local_music_repository.dart';
import 'controller_state.dart';

enum PlaybackCapability { unavailable }

class PlaybackData {
  PlaybackData({Iterable<Song> queue = const [], this.queueIndex})
    : queue = List.unmodifiable(queue);
  final List<Song> queue;
  final int? queueIndex;
  Song? get selectedSong => queueIndex == null ? null : queue[queueIndex!];
  bool get isPlaying => false;
  PlaybackCapability get capability => PlaybackCapability.unavailable;
}

class PlaybackController extends MusicController<PlaybackData> {
  PlaybackController(this.repository) : super(PlaybackData());
  final LocalMusicRepository repository;
  @override
  bool isEmpty(PlaybackData data) => data.queue.isEmpty;

  Future<Song> _song(String id) async {
    requireIdentifier(id);
    final song = await repository.songs.find(id);
    if (song == null) throw MusicRecordNotFound('song', id);
    return song;
  }

  Future<void> setQueue(List<String> songIds, {int initialIndex = 0}) {
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
  void clearQueue() => changeData(PlaybackData());

  Future<Song> selectAt(int index) {
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
    final before = state.data;
    if (before.queue.isEmpty) {
      return execute(() async => ControllerResult(PlaybackData(), null));
    }
    return selectAt((before.queueIndex! + direction) % before.queue.length);
  }

  Future<void> play() => _unavailable();
  Future<void> pause() => _unavailable();
  Future<void> setVolume(double level) => _unavailable();
  Future<void> _unavailable() => execute<void>(() async {
    throw const ControllerFailure(
      ControllerFailureKind.unavailable,
      'No audio engine is available until Increment 4',
    );
  });
}
