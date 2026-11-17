import '../models/music_models.dart';
import '../services/database/local_music_repository.dart';
import '../services/artwork/artwork_service.dart';
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
    this.replacementArtwork,
  });
  final String? title, artistName, audioFormat, artworkPath;
  final int? durationMs;
  final bool clearArtwork;
  final ArtworkDraft? replacementArtwork;
}

class SongSaveResult {
  SongSaveResult(this.song, Iterable<String> warnings)
    : warnings = List.unmodifiable(warnings);
  final Song song;
  final List<String> warnings;
}

class SongDeleteResult {
  SongDeleteResult(Iterable<String> warnings)
    : warnings = List.unmodifiable(warnings);
  final List<String> warnings;
}

class LibraryController extends MusicController<LibraryData> {
  LibraryController(
    this.repository, {
    DateTime Function()? clock,
    ArtworkService? artwork,
  }) : _clock = clock ?? DateTime.now,
       artwork = artwork ?? ArtworkService(),
       super(LibraryData());
  final LocalMusicRepository repository;
  final DateTime Function() _clock;
  final ArtworkService artwork;
  final Set<String> _pendingCleanup = {};
  Future<ArtworkDraft?> pickArtwork() {
    ensureActive();
    return artwork.pick();
  }

  Future<void> _cleanup(String? reference, List<String> warnings) async {
    if (ArtworkService.managedId(reference) != null) {
      _pendingCleanup.add(reference!);
    }
    for (final ref in _pendingCleanup.toList()) {
      try {
        if (!(await repository.getSongs()).any((s) => s.artworkPath == ref)) {
          await artwork.delete(ref);
        }
        _pendingCleanup.remove(ref);
      } catch (_) {
        warnings.add(
          'Saved data is committed; unused artwork cleanup will be retried on the next edit.',
        );
      }
    }
  }

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
      saveSongInformation(songId, update).then((result) => result.song);

  Future<SongSaveResult> saveSongInformation(
    String songId,
    SongMetadataUpdate update,
  ) => execute(() async {
    return artwork.exclusive(() async {
      ensureActive();
      requireIdentifier(songId);
      if ((update.durationMs != null && update.durationMs! < 0) ||
          ([
                update.clearArtwork,
                update.artworkPath != null,
                update.replacementArtwork != null,
              ].where((v) => v).length >
              1)) {
        throw const ControllerFailure(
          ControllerFailureKind.invalidInput,
          'Invalid metadata update',
        );
      }
      if (update.title != null) requireName(update.title!);
      String? newReference, oldReference;
      Song changed;
      final warnings = <String>[];
      try {
        if (update.replacementArtwork != null) {
          newReference = await artwork.save(update.replacementArtwork!);
        }
        ensureActive();
        changed = await repository.transaction((tx) async {
          final old = await tx.songs.find(songId);
          if (old == null) {
            throw const ControllerFailure(
              ControllerFailureKind.notFound,
              'Song not found',
            );
          }
          oldReference = old.artworkPath;
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
                : newReference ?? update.artworkPath ?? old.artworkPath,
          );
          await tx.songs.update(song);
          return song;
        });
      } catch (_) {
        await _cleanup(newReference, warnings);
        rethrow;
      }
      await _cleanup(oldReference, warnings);
      LibraryData data;
      try {
        data = await _read(selected: changed);
      } catch (_) {
        warnings.add(
          'Song saved. Refresh the library to reload committed data.',
        );
        data = LibraryData(
          songs: state.data.songs.map((s) => s.songId == songId ? changed : s),
          selectedSong: changed,
        );
      }
      return ControllerResult(data, SongSaveResult(changed, warnings));
    });
  }, mutation: true);

  Future<void> removeSong(String songId) =>
      deleteSongInformation(songId).then<void>((_) {});
  Future<SongDeleteResult> deleteSongInformation(String songId) =>
      execute(() async {
        return artwork.exclusive(() async {
          ensureActive();
          requireIdentifier(songId);
          final old = await repository.songs.find(songId);
          await repository.deleteSongAndNormalize(songId, _clock().toUtc());
          final warnings = <String>[];
          await _cleanup(old?.artworkPath, warnings);
          LibraryData data;
          try {
            data = await _read();
          } catch (_) {
            warnings.add('Song removed. Refresh to reload saved data.');
            data = LibraryData(
              songs: state.data.songs.where((s) => s.songId != songId),
            );
          }
          return ControllerResult(data, SongDeleteResult(warnings));
        });
      }, mutation: true);
}
