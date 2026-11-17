import '../models/music_models.dart';
import '../services/database/local_music_repository.dart';
import 'controller_state.dart';

class PlaylistData {
  PlaylistData({
    Iterable<Playlist> playlists = const [],
    this.selectedPlaylist,
    Iterable<PlaylistEntry> entries = const [],
    Iterable<Song> songs = const [],
  }) : playlists = List.unmodifiable(playlists),
       entries = List.unmodifiable(entries),
       songs = List.unmodifiable(songs);
  final List<Playlist> playlists;
  final Playlist? selectedPlaylist;
  final List<PlaylistEntry> entries;
  final List<Song> songs;
}

class PlaylistController extends MusicController<PlaylistData> {
  PlaylistController(
    this.repository, {
    DateTime Function()? clock,
    String Function()? idFactory,
  }) : _clock = clock ?? DateTime.now,
       _idFactory = idFactory ?? newMusicIdentifier,
       super(PlaylistData());
  final LocalMusicRepository repository;
  final DateTime Function() _clock;
  final String Function() _idFactory;
  @override
  bool isEmpty(PlaylistData data) => data.playlists.isEmpty;

  Future<Playlist> _requirePlaylist(LocalMusicRepository tx, String id) async {
    requireIdentifier(id);
    final playlist = await tx.playlists.find(id);
    if (playlist == null) throw MusicRecordNotFound('playlist', id);
    return playlist;
  }

  Future<PlaylistData> _snapshot(
    LocalMusicRepository tx,
    String? selectedId,
  ) async {
    final all = await tx.getPlaylists();
    final selected = all.where((p) => p.playlistId == selectedId).firstOrNull;
    final entries = selected == null
        ? <PlaylistEntry>[]
        : await tx.getEntries(selected.playlistId);
    final songs = <Song>[];
    for (final entry in entries) {
      final song = await tx.songs.find(entry.songId);
      if (song == null) throw MusicRecordNotFound('song', entry.songId);
      songs.add(song);
    }
    return PlaylistData(
      playlists: all,
      selectedPlaylist: selected,
      entries: entries,
      songs: songs,
    );
  }

  Future<List<Playlist>> loadPlaylists() => execute(() async {
    final data = await repository.transaction(
      (tx) => _snapshot(tx, state.data.selectedPlaylist?.playlistId),
    );
    return ControllerResult(data, data.playlists);
  });

  Future<Playlist> showPlaylist(String id) => execute(() async {
    final data = await repository.transaction((tx) async {
      await _requirePlaylist(tx, id);
      return _snapshot(tx, id);
    });
    return ControllerResult(data, data.selectedPlaylist!);
  });

  Future<R> _mutate<R>(
    String? selectedId,
    Future<R> Function(LocalMusicRepository tx) action,
  ) => execute(() async {
    final result = await repository.transaction((tx) async {
      final value = await action(tx);
      return ControllerResult(await _snapshot(tx, selectedId), value);
    });
    return result;
  }, mutation: true);

  Future<Playlist> createPlaylist(String name, {String? description}) {
    // ID creation happens in the serialized operation, not during construction.
    return execute(() async {
      final clean = requireName(name);
      final id = _idFactory();
      requireIdentifier(id);
      final now = _clock().toUtc();
      final playlist = Playlist(
        playlistId: id,
        name: clean,
        description: description,
        createdAt: now,
        updatedAt: now,
      );
      final data = await repository.transaction((tx) async {
        await tx.playlists.insert(playlist);
        return _snapshot(tx, id);
      });
      return ControllerResult(data, playlist);
    }, mutation: true);
  }

  Future<Playlist> renamePlaylist(String id, String name) =>
      _mutate(id, (tx) async {
        final old = await _requirePlaylist(tx, id);
        final changed = Playlist(
          playlistId: old.playlistId,
          name: requireName(name),
          description: old.description,
          createdAt: old.createdAt,
          updatedAt: _clock().toUtc(),
        );
        await tx.playlists.update(changed);
        return changed;
      });

  Future<Playlist> updateDescription(String id, String? text) =>
      _mutate(id, (tx) async {
        final old = await _requirePlaylist(tx, id);
        final changed = Playlist(
          playlistId: id,
          name: old.name,
          description: text,
          createdAt: old.createdAt,
          updatedAt: _clock().toUtc(),
        );
        await tx.playlists.update(changed);
        return changed;
      });

  Future<void> deletePlaylist(String id) => _mutate<void>(null, (tx) async {
    await _requirePlaylist(tx, id);
    await tx.playlists.delete(id);
  });

  Future<PlaylistEntry> addSong(String playlistId, String songId) =>
      addSongs(playlistId, [songId]).then((entries) => entries.single);

  Future<List<PlaylistEntry>> addSongs(
    String playlistId,
    List<String> songIds,
  ) {
    final ids = List<String>.of(songIds);
    return _mutate(playlistId, (tx) async {
      await _requirePlaylist(tx, playlistId);
      if (ids.isEmpty) {
        throw const ControllerFailure(
          ControllerFailureKind.invalidInput,
          'Select at least one song',
        );
      }
      for (final songId in ids) {
        requireIdentifier(songId);
        if (await tx.songs.find(songId) == null) {
          throw MusicRecordNotFound('song', songId);
        }
      }
      final ordered = await tx.getEntries(playlistId);
      final added = <PlaylistEntry>[];
      for (final songId in ids) {
        final id = _idFactory();
        requireIdentifier(id);
        final entry = PlaylistEntry(
          entryId: id,
          playlistId: playlistId,
          songId: songId,
          position:
              (ordered.isEmpty ? 0 : ordered.last.position + 1) + added.length,
          addedAt: _clock().toUtc(),
        );
        await tx.entries.insert(entry);
        added.add(entry);
      }
      await tx.normalizePlaylistEntries(playlistId, _clock().toUtc());
      return Future.wait(
        added.map((entry) async => (await tx.entries.find(entry.entryId))!),
      );
    });
  }

  Future<void> removeEntry(String entryId) => execute(() async {
    requireIdentifier(entryId);
    final data = await repository.transaction((tx) async {
      final entry = await tx.entries.find(entryId);
      if (entry == null) throw MusicRecordNotFound('playlist entry', entryId);
      await tx.entries.delete(entryId);
      await tx.normalizePlaylistEntries(entry.playlistId, _clock().toUtc());
      return _snapshot(tx, entry.playlistId);
    });
    return ControllerResult(data, null);
  }, mutation: true);

  Future<void> reorder(String entryId, int finalPosition) => execute(() async {
    requireIdentifier(entryId);
    final data = await repository.transaction((tx) async {
      final entry = await tx.entries.find(entryId);
      if (entry == null) throw MusicRecordNotFound('playlist entry', entryId);
      final ordered = await tx.getEntries(entry.playlistId);
      if (finalPosition < 0 || finalPosition >= ordered.length) {
        throw const ControllerFailure(
          ControllerFailureKind.invalidInput,
          'Invalid playlist position',
        );
      }
      final ids = ordered.map((e) => e.entryId).toList()..remove(entryId);
      ids.insert(finalPosition, entryId);
      await tx.writeEntryOrder(entry.playlistId, ids, _clock().toUtc());
      return _snapshot(tx, entry.playlistId);
    });
    return ControllerResult(data, null);
  }, mutation: true);
}
