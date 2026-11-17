import 'package:sqflite_common/sqlite_api.dart';

import '../../models/music_models.dart';

/// Typed CRUD with bound parameters; no SQL escapes the data-service layer.
class EntityStore<T> {
  EntityStore(this._db, this._table, this._id, this._decode, this._encode);
  final DatabaseExecutor _db;
  final String _table, _id;
  final T Function(DataMap) _decode;
  final DataMap Function(T) _encode;

  Future<void> insert(T entity) async => _db.insert(_table, _encode(entity));

  Future<T?> find(String id) async {
    final rows = await _db.query(_table, where: '$_id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : _decode(rows.single);
  }

  Future<List<T>> list() async =>
      (await _db.query(_table, orderBy: _id)).map(_decode).toList();

  Future<int> update(T entity) {
    final map = _encode(entity);
    return _db.update(_table, map, where: '$_id = ?', whereArgs: [map[_id]]);
  }

  Future<int> delete(String id) =>
      _db.delete(_table, where: '$_id = ?', whereArgs: [id]);
}

class LocalMusicRepository {
  LocalMusicRepository(this._db);
  final DatabaseExecutor _db;

  late final songs = EntityStore<Song>(
    _db,
    'SONG',
    'song_id',
    Song.fromMap,
    (s) => s.toMap(),
  );
  late final playlists = EntityStore<Playlist>(
    _db,
    'PLAYLIST',
    'playlist_id',
    Playlist.fromMap,
    (p) => p.toMap(),
  );
  late final entries = EntityStore<PlaylistEntry>(
    _db,
    'PLAYLIST_ENTRY',
    'entry_id',
    PlaylistEntry.fromMap,
    (e) => e.toMap(),
  );
  late final history = EntityStore<ListeningHistory>(
    _db,
    'LISTENING_HISTORY',
    'history_id',
    ListeningHistory.fromMap,
    (h) => h.toMap(),
  );

  Future<List<Song>> getSongs() => songs.list();
  Future<List<Playlist>> getPlaylists() => playlists.list();

  Future<List<PlaylistEntry>> getEntries(String playlistId) async =>
      (await _db.query(
        'PLAYLIST_ENTRY',
        where: 'playlist_id = ?',
        whereArgs: [playlistId],
        orderBy: 'position, entry_id',
      )).map(PlaylistEntry.fromMap).toList();

  Future<String?> getLyrics(String songId) async =>
      (await songs.find(songId))?.lyricsText;

  Future<int> updateLyrics(String songId, String? text) => _db.update(
    'SONG',
    {'lyrics_text': text},
    where: 'song_id = ?',
    whereArgs: [songId],
  );

  Future<T> transaction<T>(
    Future<T> Function(LocalMusicRepository repository) action,
  ) {
    final db = _db;
    if (db is! Database) {
      throw StateError('Nested repository transactions are not supported');
    }
    return db.transaction(
      (transaction) => action(LocalMusicRepository(transaction)),
    );
  }
}
