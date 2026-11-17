import '../models/music_models.dart';
import '../services/database/local_music_repository.dart';
import 'controller_state.dart';

class LyricsData {
  const LyricsData({this.song});
  final Song? song;
  String? get lyricsText => song?.lyricsText;
}

class LyricsController extends MusicController<LyricsData> {
  LyricsController(this.repository) : super(const LyricsData());
  final LocalMusicRepository repository;
  @override
  bool isEmpty(LyricsData data) => data.song == null || data.lyricsText == null;

  Future<Song> _song(LocalMusicRepository repo, String id) async {
    requireIdentifier(id);
    final song = await repo.songs.find(id);
    if (song == null) {
      throw const ControllerFailure(
        ControllerFailureKind.notFound,
        'Song not found',
      );
    }
    return song;
  }

  Future<String?> loadManualLyrics(String songId) => execute(() async {
    final song = await _song(repository, songId);
    return ControllerResult(LyricsData(song: song), song.lyricsText);
  });

  Future<void> saveManualLyrics(String songId, String text) =>
      _save(songId, text);
  Future<void> clearManualLyrics(String songId) => _save(songId, null);

  Future<void> _save(String songId, String? text) => execute(() async {
    final song = await repository.transaction((tx) async {
      await _song(tx, songId);
      await tx.updateLyrics(songId, text);
      return _song(tx, songId);
    });
    return ControllerResult(LyricsData(song: song), null);
  }, mutation: true);
}
