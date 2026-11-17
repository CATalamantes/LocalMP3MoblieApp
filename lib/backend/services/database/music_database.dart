import 'package:sqflite_common/sqlite_api.dart';

/// Owns the connection. Factories and paths are injected for platform isolation.
class MusicDatabase {
  MusicDatabase({required this.factory, required this.path});

  final DatabaseFactory factory;
  final String path;
  Future<Database>? _opening;

  Future<Database> open() => _opening ??= _open();

  Future<Database> _open() async {
    try {
      return await factory.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 1,
          onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
          onCreate: (db, version) async {
            for (final statement in _schema) {
              await db.execute(statement);
            }
          },
          // Do not silently recreate data if a newer schema is encountered.
          onDowngrade: (db, oldVersion, newVersion) => throw StateError(
            'Database schema $oldVersion is newer than $newVersion',
          ),
        ),
      );
    } catch (_) {
      _opening = null;
      rethrow;
    }
  }

  Future<void> close() async {
    final pending = _opening;
    if (pending != null) {
      await (await pending).close();
      _opening = null;
    }
  }

  static const _schema = [
    '''CREATE TABLE SONG (
      song_id TEXT PRIMARY KEY NOT NULL,
      title TEXT NOT NULL, artist_name TEXT NOT NULL,
      duration_ms INTEGER NOT NULL CHECK(duration_ms >= 0),
      audio_format TEXT NOT NULL, file_path TEXT NOT NULL,
      artwork_path TEXT, date_added INTEGER NOT NULL, lyrics_text TEXT
    )''',
    '''CREATE TABLE PLAYLIST (
      playlist_id TEXT PRIMARY KEY NOT NULL, name TEXT NOT NULL,
      description TEXT, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL
    )''',
    '''CREATE TABLE PLAYLIST_ENTRY (
      entry_id TEXT PRIMARY KEY NOT NULL,
      playlist_id TEXT NOT NULL REFERENCES PLAYLIST(playlist_id) ON DELETE CASCADE,
      song_id TEXT NOT NULL REFERENCES SONG(song_id) ON DELETE CASCADE,
      position INTEGER NOT NULL CHECK(position >= 0), added_at INTEGER NOT NULL
    )''',
    '''CREATE TABLE LISTENING_HISTORY (
      history_id TEXT PRIMARY KEY NOT NULL,
      song_id TEXT NOT NULL REFERENCES SONG(song_id) ON DELETE CASCADE,
      started_at INTEGER NOT NULL, ended_at INTEGER,
      listened_ms INTEGER NOT NULL CHECK(listened_ms >= 0),
      counted_play INTEGER NOT NULL CHECK(counted_play IN (0, 1))
    )''',
    'CREATE INDEX entries_by_playlist ON PLAYLIST_ENTRY(playlist_id, position)',
    'CREATE INDEX entries_by_song ON PLAYLIST_ENTRY(song_id)',
    'CREATE INDEX history_by_song ON LISTENING_HISTORY(song_id, started_at)',
  ];
}
