import 'package:sqflite_common/sqlite_api.dart';

import '../../models/music_models.dart';
import '../../models/listening_statistics.dart';

class MusicRecordNotFound implements Exception {
  const MusicRecordNotFound(this.entity, this.id);
  final String entity, id;
}

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

  /// Deletion, cascades and every affected playlist update share one commit.
  /// Physical audio files are never accessed by this service.
  Future<void> deleteSongAndNormalize(String songId, DateTime updatedAt) =>
      transaction((tx) async {
        if (await tx.songs.find(songId) == null) {
          throw MusicRecordNotFound('song', songId);
        }
        final affected = await tx._db.query(
          'PLAYLIST_ENTRY',
          columns: ['playlist_id'],
          where: 'song_id = ?',
          whereArgs: [songId],
          distinct: true,
          orderBy: 'playlist_id',
        );
        await tx.songs.delete(songId);
        for (final row in affected) {
          await tx.normalizePlaylistEntries(
            row['playlist_id'] as String,
            updatedAt,
          );
        }
      });

  Future<void> normalizePlaylistEntries(
    String playlistId,
    DateTime updatedAt,
  ) async {
    await writeEntryOrder(
      playlistId,
      (await getEntries(playlistId)).map((e) => e.entryId).toList(),
      updatedAt,
    );
  }

  /// Called inside the existing repository transaction; rejects partial orders.
  Future<void> writeEntryOrder(
    String playlistId,
    List<String> ids,
    DateTime updatedAt,
  ) async {
    if (_db is! Transaction) {
      throw StateError('Entry ordering requires a transaction');
    }
    final playlist = await playlists.find(playlistId);
    if (playlist == null) throw MusicRecordNotFound('playlist', playlistId);
    final current = await getEntries(playlistId);
    final byId = {for (final e in current) e.entryId: e};
    if (ids.length != current.length ||
        ids.toSet().length != ids.length ||
        !ids.every(byId.containsKey)) {
      throw ArgumentError(
        'Entry order must contain every occurrence exactly once',
      );
    }
    for (var index = 0; index < ids.length; index++) {
      final old = byId[ids[index]]!;
      await entries.update(
        PlaylistEntry(
          entryId: old.entryId,
          playlistId: old.playlistId,
          songId: old.songId,
          position: index,
          addedAt: old.addedAt,
        ),
      );
    }
    await playlists.update(
      Playlist(
        playlistId: playlist.playlistId,
        name: playlist.name,
        description: playlist.description,
        createdAt: playlist.createdAt,
        updatedAt: updatedAt,
      ),
    );
  }

  Future<ListeningStatistics> readStatistics({
    ListeningRange range = const ListeningRange(),
    int recentLimit = 20,
    String? songId,
  }) => transaction((tx) async {
    final clauses = <String>[];
    final arguments = <Object?>[];
    if (range.start != null) {
      clauses.add('started_at >= ?');
      arguments.add(range.start!.millisecondsSinceEpoch);
    }
    if (range.end != null) {
      clauses.add('started_at < ?');
      arguments.add(range.end!.millisecondsSinceEpoch);
    }
    final where = clauses.isEmpty ? '' : 'WHERE ${clauses.join(' AND ')}';
    const totals =
        'COALESCE(SUM(counted_play), 0) AS plays, COALESCE(SUM(listened_ms), 0) AS duration';
    final summary = (await tx._db.rawQuery(
      'SELECT $totals FROM LISTENING_HISTORY $where',
      arguments,
    )).single;
    final rankings = await tx._db.rawQuery(
      '''SELECT song_id, $totals
      FROM LISTENING_HISTORY $where GROUP BY song_id
      HAVING SUM(counted_play) > 0 ORDER BY plays DESC, song_id ASC''',
      arguments,
    );
    final top = <SongStatistics>[];
    for (final row in rankings) {
      final id = row['song_id'] as String;
      final song = await tx.songs.find(id);
      if (song == null) throw MusicRecordNotFound('song', id);
      top.add(
        SongStatistics(
          song: song,
          countedPlays: row['plays'] as int,
          listeningDuration: Duration(milliseconds: row['duration'] as int),
        ),
      );
    }
    final recent = (await tx._db.query(
      'LISTENING_HISTORY',
      where: clauses.isEmpty ? null : clauses.join(' AND '),
      whereArgs: arguments,
      orderBy: 'started_at DESC, history_id ASC',
      limit: recentLimit,
    )).map(ListeningHistory.fromMap).toList();
    SongStatistics? selected;
    if (songId != null) {
      final song = await tx.songs.find(songId);
      if (song == null) throw MusicRecordNotFound('song', songId);
      final filter = [...clauses, 'song_id = ?'].join(' AND ');
      final values = (await tx._db.rawQuery(
        'SELECT $totals FROM LISTENING_HISTORY WHERE $filter',
        [...arguments, songId],
      )).single;
      selected = SongStatistics(
        song: song,
        countedPlays: values['plays'] as int,
        listeningDuration: Duration(milliseconds: values['duration'] as int),
      );
    }
    return ListeningStatistics(
      totalCountedPlays: summary['plays'] as int,
      totalListeningDuration: Duration(
        milliseconds: summary['duration'] as int,
      ),
      topTracks: top,
      recentHistory: recent,
      selectedSong: selected,
      range: range,
    );
  });

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
