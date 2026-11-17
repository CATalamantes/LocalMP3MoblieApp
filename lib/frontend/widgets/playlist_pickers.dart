import 'package:flutter/material.dart';

import '../../backend/models/music_models.dart';
import 'application_binding.dart';
import 'design_widgets.dart';

Future<void> showAddSongs(
  BuildContext context,
  FrontendActions actions,
  String playlistId,
  List<Song> songs,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (_) => _SongPicker(
    actions: actions,
    playlistId: playlistId,
    songs: List.of(songs),
  ),
);

class _SongPicker extends StatefulWidget {
  const _SongPicker({
    required this.actions,
    required this.playlistId,
    required this.songs,
  });
  final FrontendActions actions;
  final String playlistId;
  final List<Song> songs;
  @override
  State<_SongPicker> createState() => _SongPickerState();
}

class _SongPickerState extends State<_SongPicker> {
  final _selected = <String>{};
  bool _pending = false;
  String? _error;
  Future<void> _save() async {
    if (_pending || _selected.isEmpty) return;
    setState(() {
      _pending = true;
      _error = null;
    });
    try {
      await widget.actions.dependencies.playlists.addSongs(
        widget.playlistId,
        widget.songs
            .where((s) => _selected.contains(s.songId))
            .map((s) => s.songId)
            .toList(),
      );
      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        Navigator.pop(context);
        messenger.showSnackBar(
          SnackBar(content: Text('${_selected.length} songs added.')),
        );
      }
    } catch (error) {
      if (mounted) setState(() => _error = actionError(error));
    } finally {
      if (mounted) setState(() => _pending = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_pending,
    child: SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .85,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Add songs', style: headingStyle),
              const Text(
                'Select songs. Repeated additions create separate occurrences.',
                style: mutedStyle,
              ),
              if (widget.songs.isEmpty) const Text('No songs available'),
              for (final song in widget.songs)
                CheckboxListTile(
                  key: ValueKey('pick-song-${song.songId}'),
                  title: Text(song.title),
                  subtitle: Text(song.artistName),
                  value: _selected.contains(song.songId),
                  onChanged: _pending
                      ? null
                      : (value) => setState(() {
                          if (value == true) {
                            _selected.add(song.songId);
                          } else {
                            _selected.remove(song.songId);
                          }
                        }),
                ),
              Text('${_selected.length} selected'),
              if (_error != null) Text(_error!),
              TextButton(
                key: const ValueKey('add-selected-songs'),
                onPressed: _pending || _selected.isEmpty ? null : _save,
                child: Text(_pending ? 'Adding…' : 'Add Selected'),
              ),
              TextButton(
                onPressed: _pending ? null : () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Future<void> showPlaylistChooser(
  BuildContext context,
  FrontendActions actions,
  Song song,
) async {
  // Capture identities before awaiting. Failure leaves the chooser available.
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _PlaylistChooser(actions: actions, song: song),
  );
}

class _PlaylistChooser extends StatefulWidget {
  const _PlaylistChooser({required this.actions, required this.song});
  final FrontendActions actions;
  final Song song;
  @override
  State<_PlaylistChooser> createState() => _PlaylistChooserState();
}

class _PlaylistChooserState extends State<_PlaylistChooser> {
  bool _pending = true;
  String? _error;
  List<Playlist> _playlists = [];
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    try {
      final playlists = await widget.actions.dependencies.playlists
          .loadPlaylists();
      if (mounted) setState(() => _playlists = playlists);
    } catch (error) {
      if (mounted) setState(() => _error = actionError(error));
    } finally {
      if (mounted) setState(() => _pending = false);
    }
  }

  Future<void> _add(Playlist playlist) async {
    if (_pending) return;
    setState(() {
      _pending = true;
      _error = null;
    });
    try {
      await widget.actions.dependencies.playlists.addSong(
        playlist.playlistId,
        widget.song.songId,
      );
      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        Navigator.pop(context);
        messenger.showSnackBar(const SnackBar(content: Text('Song added.')));
      }
    } catch (error) {
      if (mounted) setState(() => _error = actionError(error));
    } finally {
      if (mounted) setState(() => _pending = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_pending,
    child: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Add to Playlist', style: headingStyle),
            if (!_pending && _playlists.isEmpty)
              const Text(
                'No playlists available. Create a playlist in Your Library first.',
              ),
            for (final playlist in _playlists)
              TextButton(
                onPressed: _pending ? null : () => _add(playlist),
                child: Text(playlist.name),
              ),
            if (_pending) const Text('Please wait…'),
            if (_error != null) Text(_error!),
            TextButton(
              onPressed: _pending ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    ),
  );
}
