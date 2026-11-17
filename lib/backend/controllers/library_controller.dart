import '../models/music_models.dart';
import '../services/database/local_music_repository.dart';
import 'controller_state.dart';

enum SongSort { title, artist, dateAdded }

class LibraryData {
  LibraryData({
    Iterable<Song> songs = const [],
    this.query = '',
    this.sort = SongSort.title,
    this.selectedSong,
  }) : songs = List.unmodifiable(songs);
  final List<Song> songs;
  final String query;
  final SongSort sort;
  final Song? selectedSong;

  List<Song> get visibleSongs {
    final needle = query.trim().toLowerCase();
    final result = songs
        .where(
          (s) =>
              s.title.toLowerCase().contains(needle) ||
              s.artistName.toLowerCase().contains(needle),
        )
        .toList();
    result.sort((a, b) {
      final order = switch (sort) {
        SongSort.title => a.title.toLowerCase().compareTo(
          b.title.toLowerCase(),
        ),
        SongSort.artist => a.artistName.toLowerCase().compareTo(
          b.artistName.toLowerCase(),
        ),
        SongSort.dateAdded => b.dateAdded.compareTo(a.dateAdded),
      };
      return order == 0 ? a.songId.compareTo(b.songId) : order;
    });
    return List.unmodifiable(result);
  }
}

class SongMetadataUpdate {
  const SongMetadataUpdate({
    this.title,
    this.artistName,
    this.durationMs,
    this.audioFormat,
    this.artworkPath,
    this.clearArtwork = false,
  });
  final String? title, artistName, audioFormat, artworkPath;
  final int? durationMs;
  final bool clearArtwork;
}

class LibraryController extends MusicController<LibraryData> {
  LibraryController(this.repository, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now,
      super(LibraryData());
  final LocalMusicRepository repository;
  final DateTime Function() _clock;
  @override
  bool isEmpty(LibraryData data) => data.visibleSongs.isEmpty;
  @override
  LibraryData prepareData(LibraryData data) => LibraryData(
    songs: data.songs,
    query: state.data.query,
    sort: state.data.sort,
    selectedSong: data.selectedSong,
  );

  Future<LibraryData> _read({Song? selected}) async {
    final songs = await repository.getSongs();
    final latest = state.data;
    final id = selected?.songId ?? latest.selectedSong?.songId;
    return LibraryData(
      songs: songs,
      query: latest.query,
      sort: latest.sort,
      selectedSong: songs.where((s) => s.songId == id).firstOrNull,
    );
  }

  Future<List<Song>> loadCachedSongs() => execute(() async {
    final data = await _read();
    return ControllerResult(data, data.songs);
  });
  Future<void> refreshLibrary() async {
    await loadCachedSongs();
  }

  List<Song> search(String query) {
    final old = state.data;
    changeData(
      LibraryData(
        songs: old.songs,
        query: query,
        sort: old.sort,
        selectedSong: old.selectedSong,
      ),
    );
    return state.data.visibleSongs;
  }

  void sortBy(SongSort sort) {
    final old = state.data;
    changeData(
      LibraryData(
        songs: old.songs,
        query: old.query,
        sort: sort,
        selectedSong: old.selectedSong,
      ),
    );
  }

  Future<Song> loadSong(String songId) => execute(() async {
    requireIdentifier(songId);
    final song = await repository.songs.find(songId);
    if (song == null) {
      throw const ControllerFailure(
        ControllerFailureKind.notFound,
        'Song not found',
      );
    }
    return ControllerResult(await _read(selected: song), song);
  });

  Future<Song> updateMetadata(String songId, SongMetadataUpdate update) =>
      execute(() async {
        requireIdentifier(songId);
        if ((update.durationMs != null && update.durationMs! < 0) ||
            (update.clearArtwork && update.artworkPath != null)) {
          throw const ControllerFailure(
            ControllerFailureKind.invalidInput,
            'Invalid metadata update',
          );
        }
        final changed = await repository.transaction((tx) async {
          final old = await tx.songs.find(songId);
          if (old == null) {
            throw const ControllerFailure(
              ControllerFailureKind.notFound,
              'Song not found',
            );
          }
          final song = Song(
            songId: old.songId,
            title: update.title == null
                ? old.title
                : requireName(update.title!),
            artistName: update.artistName ?? old.artistName,
            durationMs: update.durationMs ?? old.durationMs,
            audioFormat: update.audioFormat == null
                ? old.audioFormat
                : requireName(update.audioFormat!),
            filePath: old.filePath,
            dateAdded: old.dateAdded,
            lyricsText: old.lyricsText,
            artworkPath: update.clearArtwork
                ? null
                : update.artworkPath ?? old.artworkPath,
          );
          await tx.songs.update(song);
          return song;
        });
        return ControllerResult(await _read(selected: changed), changed);
      }, mutation: true);

  Future<void> removeSong(String songId) => execute(() async {
    requireIdentifier(songId);
    await repository.deleteSongAndNormalize(songId, _clock().toUtc());
    return ControllerResult(await _read(), null);
  }, mutation: true);
}
