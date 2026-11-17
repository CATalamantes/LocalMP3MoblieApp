import 'package:cta2000/backend/controllers/controller_state.dart';
import 'package:cta2000/backend/models/music_models.dart';
import 'package:cta2000/backend/services/database/local_music_repository.dart';
import 'package:cta2000/backend/services/database/music_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class ControllerFixture {
  late MusicDatabase database;
  late Database db;
  late LocalMusicRepository repository;
  final controllers = <MusicController<Object?>>[];
  DateTime now = DateTime.utc(2026, 11, 17);
  int sequence = 0;
  String id() => 'id-${++sequence}';
  DateTime clock() => now;

  Future<void> open({String path = inMemoryDatabasePath}) async {
    sqfliteFfiInit();
    database = MusicDatabase(factory: databaseFactoryFfi, path: path);
    db = await database.open();
    repository = LocalMusicRepository(db);
  }

  T own<T extends MusicController<Object?>>(T controller) {
    controllers.add(controller);
    return controller;
  }

  Future<void> song(
    String id, {
    String? title,
    String artist = 'Artist',
    String? lyrics,
    String? artwork,
    String? filePath,
    DateTime? added,
  }) => repository.songs.insert(
    Song(
      songId: id,
      title: title ?? id,
      artistName: artist,
      durationMs: 90000,
      audioFormat: 'MP3',
      filePath: filePath ?? 'audio/$id.mp3',
      dateAdded: added ?? now,
      lyricsText: lyrics,
      artworkPath: artwork,
    ),
  );

  Future<void> playlist(String id) => repository.playlists.insert(
    Playlist(playlistId: id, name: id, createdAt: now, updatedAt: now),
  );

  Future<void> entry(
    String id,
    String playlistId,
    String songId,
    int position,
  ) => repository.entries.insert(
    PlaylistEntry(
      entryId: id,
      playlistId: playlistId,
      songId: songId,
      position: position,
      addedAt: now,
    ),
  );

  Future<void> history(
    String id,
    String songId, {
    required int ms,
    bool counted = true,
    DateTime? started,
  }) => repository.history.insert(
    ListeningHistory(
      historyId: id,
      songId: songId,
      startedAt: started ?? now,
      listenedMs: ms,
      countedPlay: counted,
    ),
  );

  Future<void> close() async {
    for (final controller in controllers) {
      controller.dispose();
    }
    await database.close();
  }
}
