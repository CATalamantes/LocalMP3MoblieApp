// SQLite maps use the approved relational column names. Dates are UTC epoch ms.
typedef DataMap = Map<String, Object?>;

DateTime _date(Object? value) =>
    DateTime.fromMillisecondsSinceEpoch(value as int, isUtc: true);

class Song {
  const Song({
    required this.songId,
    required this.title,
    required this.artistName,
    required this.durationMs,
    required this.audioFormat,
    required this.filePath,
    required this.dateAdded,
    this.artworkPath,
    this.lyricsText,
  });

  final String songId, title, artistName, audioFormat, filePath;
  final int durationMs;
  final DateTime dateAdded;
  final String? artworkPath, lyricsText;

  factory Song.fromMap(DataMap map) => Song(
    songId: map['song_id'] as String,
    title: map['title'] as String,
    artistName: map['artist_name'] as String,
    durationMs: map['duration_ms'] as int,
    audioFormat: map['audio_format'] as String,
    filePath: map['file_path'] as String,
    artworkPath: map['artwork_path'] as String?,
    dateAdded: _date(map['date_added']),
    lyricsText: map['lyrics_text'] as String?,
  );

  DataMap toMap() => {
    'song_id': songId,
    'title': title,
    'artist_name': artistName,
    'duration_ms': durationMs,
    'audio_format': audioFormat,
    'file_path': filePath,
    'artwork_path': artworkPath,
    'date_added': dateAdded.millisecondsSinceEpoch,
    'lyrics_text': lyricsText,
  };
}

class Playlist {
  const Playlist({
    required this.playlistId,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    this.description,
  });

  final String playlistId, name;
  final String? description;
  final DateTime createdAt, updatedAt;

  factory Playlist.fromMap(DataMap map) => Playlist(
    playlistId: map['playlist_id'] as String,
    name: map['name'] as String,
    description: map['description'] as String?,
    createdAt: _date(map['created_at']),
    updatedAt: _date(map['updated_at']),
  );

  DataMap toMap() => {
    'playlist_id': playlistId,
    'name': name,
    'description': description,
    'created_at': createdAt.millisecondsSinceEpoch,
    'updated_at': updatedAt.millisecondsSinceEpoch,
  };
}

class PlaylistEntry {
  const PlaylistEntry({
    required this.entryId,
    required this.playlistId,
    required this.songId,
    required this.position,
    required this.addedAt,
  });

  final String entryId, playlistId, songId;
  final int position;
  final DateTime addedAt;

  factory PlaylistEntry.fromMap(DataMap map) => PlaylistEntry(
    entryId: map['entry_id'] as String,
    playlistId: map['playlist_id'] as String,
    songId: map['song_id'] as String,
    position: map['position'] as int,
    addedAt: _date(map['added_at']),
  );

  DataMap toMap() => {
    'entry_id': entryId,
    'playlist_id': playlistId,
    'song_id': songId,
    'position': position,
    'added_at': addedAt.millisecondsSinceEpoch,
  };
}

class ListeningHistory {
  const ListeningHistory({
    required this.historyId,
    required this.songId,
    required this.startedAt,
    required this.listenedMs,
    required this.countedPlay,
    this.endedAt,
  });

  final String historyId, songId;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int listenedMs;
  final bool countedPlay;

  factory ListeningHistory.fromMap(DataMap map) => ListeningHistory(
    historyId: map['history_id'] as String,
    songId: map['song_id'] as String,
    startedAt: _date(map['started_at']),
    endedAt: map['ended_at'] == null ? null : _date(map['ended_at']),
    listenedMs: map['listened_ms'] as int,
    countedPlay: map['counted_play'] == 1,
  );

  DataMap toMap() => {
    'history_id': historyId,
    'song_id': songId,
    'started_at': startedAt.millisecondsSinceEpoch,
    'ended_at': endedAt?.millisecondsSinceEpoch,
    'listened_ms': listenedMs,
    'counted_play': countedPlay ? 1 : 0,
  };
}
