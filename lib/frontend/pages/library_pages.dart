import 'package:flutter/material.dart';

import '../routes/app_screen.dart';
import '../routes/frontend_navigation.dart';
import '../widgets/design_widgets.dart';
import '../widgets/draft_editors.dart';
import '../widgets/presentation.dart';
import '../widgets/application_binding.dart';
import '../../backend/controllers/library_controller.dart';
import '../../backend/controllers/controller_state.dart';

class LibraryPage extends StatefulWidget {
  const LibraryPage({
    super.key,
    required this.data,
    this.searchExpanded = false,
    this.onSearchChanged,
    this.onSortChanged,
  });
  final ScreenPresentation data;
  final bool searchExpanded;
  final ValueChanged<String>? onSearchChanged, onSortChanged;
  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  String _category = 'Playlists', _sort = 'Recents';
  bool _categoryChosen = false;
  String get _selectedCategory =>
      !_categoryChosen &&
          widget.data.integrated &&
          widget.data.playlists.isEmpty &&
          widget.data.availableSongs.isNotEmpty
      ? 'Songs'
      : _category;
  void _selectCategory(String value) => setState(() {
    _category = value;
    _categoryChosen = true;
  });
  bool _grid = false;
  final _search = TextEditingController();
  final _focus = FocusNode();
  FrontendActions? get actions =>
      widget.data.integrated ? ApplicationScope.of(context) : null;
  @override
  void didUpdateWidget(LibraryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.searchExpanded && !oldWidget.searchExpanded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focus.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _search.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PageBody(
    screen: AppScreen.library,
    children: [
      Row(
        children: [
          IconButton(
            tooltip: 'Library filters',
            icon: const Icon(Icons.tune),
            onPressed:
                widget.data.integrated &&
                    widget.data.mode == PresentationMode.loading
                ? null
                : () => showModalBottomSheet<void>(
                    context: context,
                    builder: (context) => SafeArea(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'Library categories',
                              style: headingStyle,
                            ),
                            for (final value in [
                              'Playlists',
                              'Songs',
                              'Albums',
                              'Artists',
                            ])
                              TextButton(
                                onPressed: () {
                                  _selectCategory(value);
                                  Navigator.pop(context);
                                },
                                child: Text(value),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
          ),
          Expanded(
            child: ChoicePills(
              labels: const ['Playlists', 'Songs', 'Albums', 'Artists'],
              selected: _selectedCategory,
              onSelected: _selectCategory,
            ),
          ),
        ],
      ),
      if (widget.searchExpanded) ...[
        const SizedBox(height: 16),
        TextField(
          key: const ValueKey('library-search'),
          controller: _search,
          focusNode: _focus,
          enabled:
              !widget.data.integrated ||
              widget.data.mode != PresentationMode.loading,
          onChanged: (value) {
            widget.onSearchChanged?.call(value);
            actions?.dependencies.library.search(value);
          },
          decoration: InputDecoration(
            labelText: 'Search your library',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: IconButton(
              tooltip: 'Clear search',
              onPressed:
                  widget.data.integrated &&
                      widget.data.mode == PresentationMode.loading
                  ? null
                  : () {
                      _search.clear();
                      widget.onSearchChanged?.call('');
                      actions?.dependencies.library.search('');
                    },
              icon: const Icon(Icons.close),
            ),
          ),
        ),
      ],
      const SizedBox(height: 12),
      if (actions != null)
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ActionPill(
              'Create playlist',
              icon: Icons.add,
              onPressed: widget.data.mode == PresentationMode.loading
                  ? null
                  : () => showDraftEditor(
                      context,
                      title: 'Create playlist',
                      fields: const {'Title': '', 'Description': ''},
                      requiredFields: const {'Title'},
                      multiline: const {'Description'},
                      onSave: (fields) async {
                        await actions!.dependencies.playlists.createPlaylist(
                          fields['Title']!,
                          description: fields['Description']!.isEmpty
                              ? null
                              : fields['Description'],
                        );
                      },
                    ),
            ),
            ActionPill(
              'Refresh library',
              icon: Icons.refresh,
              onPressed: widget.data.mode == PresentationMode.loading
                  ? null
                  : () => actions!.quietly(actions!.refreshLibrary),
            ),
          ],
        ),
      Row(
        children: [
          const Icon(Icons.swap_vert),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButton<String>(
              isExpanded: true,
              value: actions == null
                  ? _sort
                  : switch (actions!.dependencies.library.state.data.sort) {
                      SongSort.title => 'Title',
                      SongSort.artist => 'Artist',
                      SongSort.dateAdded => 'Date added',
                    },
              underline: const SizedBox.shrink(),
              items: [
                for (final label in [
                  'Recents',
                  'Title',
                  'Artist',
                  'Date added',
                ])
                  DropdownMenuItem(value: label, child: Text(label)),
              ],
              onChanged:
                  widget.data.integrated &&
                      widget.data.mode == PresentationMode.loading
                  ? null
                  : (value) {
                      if (value != null) {
                        setState(() => _sort = value);
                        widget.onSortChanged?.call(value);
                        actions?.dependencies.library.sortBy(switch (value) {
                          'Title' => SongSort.title,
                          'Artist' => SongSort.artist,
                          _ => SongSort.dateAdded,
                        });
                      }
                    },
            ),
          ),
          IconButton(
            tooltip: _grid ? 'List layout' : 'Grid layout',
            icon: Icon(_grid ? Icons.view_list : Icons.grid_view),
            onPressed: () => setState(() => _grid = !_grid),
          ),
        ],
      ),
      PresentationNotice(
        data: widget.data,
        empty: 'No saved songs or playlists',
      ),
      if (widget.data.errorMessage != null)
        Text(widget.data.errorMessage!, style: mutedStyle),
      const SurfaceCard(
        child: ScreenLink(
          screen: AppScreen.sync,
          label: 'Radxa Device Sync',
          subtitle: 'No device connected · Storage unavailable',
          icon: Icons.sync,
        ),
      ),
      if (_selectedCategory == 'Playlists') ...[
        if (_grid && widget.data.playlists.isNotEmpty)
          LayoutBuilder(
            builder: (context, constraints) {
              final twoColumns =
                  constraints.maxWidth >= 350 &&
                  MediaQuery.textScalerOf(context).scale(14) < 20;
              return Wrap(
                spacing: 12,
                children: [
                  for (var i = 0; i < widget.data.playlists.length; i++)
                    SizedBox(
                      width: twoColumns
                          ? (constraints.maxWidth - 12) / 2
                          : constraints.maxWidth,
                      child: SurfaceCard(
                        child: InkWell(
                          key: i == 0 ? const ValueKey('open-playlist') : null,
                          onTap: () => openScreen(
                            context,
                            AppScreen.playlist,
                            presentation: widget.data.selecting(
                              playlist: widget.data.playlists[i],
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const ArtworkFrame(),
                              const SizedBox(height: 12),
                              Text(
                                widget.data.playlists[i].name,
                                style: titleStyle,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          )
        else
          for (var i = 0; i < widget.data.playlists.length; i++)
            SurfaceCard(
              child: SettingsRow(
                key: i == 0 ? const ValueKey('open-playlist') : null,
                title: widget.data.playlists[i].name,
                subtitle: widget.data.playlists[i].description,
                icon: Icons.queue_music,
                onTap: () => openScreen(
                  context,
                  AppScreen.playlist,
                  presentation: widget.data.selecting(
                    playlist: widget.data.playlists[i],
                  ),
                ),
              ),
            ),
        if (widget.data.playlists.isEmpty)
          const SurfaceCard(
            child: ScreenLink(
              screen: AppScreen.playlist,
              label: 'Playlist Details',
              subtitle: 'No playlist selected',
              icon: Icons.queue_music,
            ),
          ),
      ] else if (_selectedCategory == 'Songs') ...[
        for (final song in widget.data.songs)
          SurfaceCard(
            child: SongRow(
              song: song,
              onTap: actions != null
                  ? () => actions!.chooseSong(
                      context,
                      widget.data.songs,
                      widget.data.songs.indexOf(song),
                    )
                  : () => openScreen(
                      context,
                      AppScreen.nowPlaying,
                      presentation: widget.data.selecting(song: song),
                    ),
            ),
          ),
      ] else
        SurfaceCard(
          child: Text(
            widget.data.integrated
                ? '$_selectedCategory grouping is unavailable. Use Songs or Playlists.'
                : '$_selectedCategory will appear when library data is connected.',
            style: mutedStyle,
          ),
        ),
      if (_grid && !widget.data.integrated)
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text(
            'Grid layout selected. Library data is not connected.',
            style: mutedStyle,
          ),
        ),
      const ScreenLink(
        screen: AppScreen.nowPlaying,
        label: 'Now Playing',
        subtitle: 'No playback is started by opening the player',
        icon: Icons.play_circle_outline,
      ),
    ],
  );
}

class PlaylistPage extends StatefulWidget {
  const PlaylistPage({super.key, required this.data});
  final ScreenPresentation data;
  @override
  State<PlaylistPage> createState() => _PlaylistPageState();
}

class _PlaylistPageState extends State<PlaylistPage> {
  bool _reorder = false;
  FrontendActions? get actions =>
      widget.data.integrated ? ApplicationScope.of(context) : null;
  bool get busy => widget.data.mode == PresentationMode.loading;
  Future<void> editPlaylist() async {
    final a = actions;
    final playlist = widget.data.playlist!;
    var savedName = playlist.name;
    var savedDescription = playlist.description ?? '';
    await showDraftEditor(
      context,
      title: 'Edit playlist',
      fields: {'Title': savedName, 'Description': savedDescription},
      requiredFields: const {'Title'},
      multiline: const {'Description'},
      onSave: a == null
          ? null
          : (fields) async {
              var renamed = false;
              if (fields['Title']!.trim() != savedName) {
                final value = await a.dependencies.playlists.renamePlaylist(
                  playlist.playlistId,
                  fields['Title']!,
                );
                savedName = value.name;
                renamed = true;
              }
              if (fields['Description'] != savedDescription) {
                try {
                  await a.dependencies.playlists.updateDescription(
                    playlist.playlistId,
                    fields['Description']!.isEmpty
                        ? null
                        : fields['Description'],
                  );
                  savedDescription = fields['Description']!;
                } catch (error) {
                  throw ControllerFailure(
                    ControllerFailureKind.storage,
                    '${renamed ? 'Playlist name saved. ' : ''}Description was not saved: ${actionError(error)}',
                  );
                }
              }
            },
    );
  }

  @override
  Widget build(BuildContext context) => PageBody(
    screen: AppScreen.playlist,
    children: [
      const Center(
        child: SizedBox(
          width: 240,
          height: 240,
          child: ArtworkFrame(collage: true),
        ),
      ),
      const SizedBox(height: 24),
      Text(
        widget.data.playlist?.name ?? 'No playlist selected',
        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 8),
      Text(
        widget.data.playlist?.description ??
            'Your playlist description will appear here.',
        style: mutedStyle,
      ),
      const SizedBox(height: 12),
      const Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          StatusPill('Offline library'),
          StatusPill('Sync unavailable'),
        ],
      ),
      const SizedBox(height: 16),
      Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          const IconButton(
            onPressed: null,
            tooltip: 'Download playlist unavailable',
            icon: Icon(Icons.download_outlined),
          ),
          IconButton(
            onPressed: () => explainUnavailable(context, 'Sharing'),
            tooltip: 'Share playlist',
            icon: const Icon(Icons.ios_share),
          ),
          const IconButton(
            onPressed: null,
            tooltip: 'Shuffle unavailable',
            icon: Icon(Icons.shuffle),
          ),
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Theme.of(context).colorScheme.primary
                  .withValues(alpha: .4),
            ),
            child: IconButton(
              onPressed: actions == null || busy || widget.data.songs.isEmpty
                  ? null
                  : () => actions!.chooseSong(
                      context,
                      widget.data.songs,
                      0,
                      play: true,
                    ),
              tooltip: actions == null
                  ? 'Play playlist unavailable'
                  : 'Play playlist',
              iconSize: 38,
              padding: const EdgeInsets.all(16),
              icon: const Icon(Icons.play_arrow),
            ),
          ),
        ],
      ),
      const SizedBox(height: 14),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          ActionPill(
            'Add',
            icon: Icons.add,
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              builder: (context) => SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('Add songs', style: headingStyle),
                      const SizedBox(height: 12),
                      Text(
                        actions == null
                            ? 'Adding songs is not connected. No playlist will be changed.'
                            : 'Choose an existing library song. Repeated occurrences are allowed.',
                        style: mutedStyle,
                      ),
                      if ((actions == null
                              ? widget.data.songs
                              : widget.data.availableSongs)
                          .isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('No songs available'),
                        ),
                      for (final song
                          in actions == null
                              ? widget.data.songs
                              : widget.data.availableSongs)
                        SongRow(
                          song: song,
                          trailing:
                              actions == null || widget.data.playlist == null
                              ? null
                              : IconButton(
                                  tooltip: 'Add ${song.title}',
                                  icon: const Icon(Icons.add),
                                  onPressed: () {
                                    final a = actions!;
                                    final playlist = widget.data.playlist!;
                                    Navigator.pop(context);
                                    confirmAction(
                                      this.context,
                                      title: 'Add song?',
                                      message:
                                          'Add ${song.title} to ${playlist.name}?',
                                      action: 'Add',
                                      onConfirm: () async {
                                        await a.dependencies.playlists.addSong(
                                          playlist.playlistId,
                                          song.songId,
                                        );
                                        return 'Song added.';
                                      },
                                    );
                                  },
                                ),
                        ),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const ActionPill('Mix', icon: Icons.tune),
          ActionPill(
            'Edit',
            icon: Icons.edit_outlined,
            onPressed: widget.data.playlist == null
                ? null
                : busy
                ? null
                : editPlaylist,
          ),
          ActionPill(
            'Reorder',
            icon: Icons.swap_vert,
            onPressed: () => setState(() => _reorder = !_reorder),
          ),
        ],
      ),
      if (_reorder && actions == null)
        const Padding(
          padding: EdgeInsets.only(top: 12),
          child: Text(
            'Reorder handles are shown. Reordering is not connected.',
            style: mutedStyle,
          ),
        ),
      const SectionTitle('Songs'),
      if (widget.data.songs.isEmpty)
        const SurfaceCard(
          child: Text(
            'This playlist has no songs to display.',
            style: mutedStyle,
          ),
        ),
      if (_reorder && actions != null)
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          itemCount: widget.data.entries.length,
          onReorderItem: (oldIndex, newIndex) {
            if (!busy) {
              actions!.quietly(
                () => actions!.dependencies.playlists.reorder(
                  widget.data.entries[oldIndex].entryId,
                  newIndex,
                ),
              );
            }
          },
          itemBuilder: (context, index) => Column(
            key: ValueKey(widget.data.entries[index].entryId),
            children: [
              SongRow(
                song: widget.data.songs[index],
                trailing: ReorderableDragStartListener(
                  index: index,
                  enabled: !busy,
                  child: const Tooltip(
                    message: 'Drag occurrence',
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: Icon(Icons.drag_handle),
                    ),
                  ),
                ),
              ),
              Wrap(
                children: [
                  IconButton(
                    tooltip: 'Move occurrence ${index + 1} up',
                    onPressed: busy || index == 0
                        ? null
                        : () => actions!.quietly(
                            () => actions!.dependencies.playlists.reorder(
                              widget.data.entries[index].entryId,
                              index - 1,
                            ),
                          ),
                    icon: const Icon(Icons.arrow_upward),
                  ),
                  IconButton(
                    tooltip: 'Move occurrence ${index + 1} down',
                    onPressed: busy || index == widget.data.entries.length - 1
                        ? null
                        : () => actions!.quietly(
                            () => actions!.dependencies.playlists.reorder(
                              widget.data.entries[index].entryId,
                              index + 1,
                            ),
                          ),
                    icon: const Icon(Icons.arrow_downward),
                  ),
                ],
              ),
            ],
          ),
        ),
      if (!_reorder || actions == null)
        for (var index = 0; index < widget.data.songs.length; index++)
          SongRow(
            key: widget.data.integrated
                ? ValueKey(widget.data.entries[index].entryId)
                : null,
            song: widget.data.songs[index],
            entryId: widget.data.integrated
                ? widget.data.entries[index].entryId
                : null,
            reorder: _reorder,
            onTap: actions != null
                ? () => actions!.chooseSong(context, widget.data.songs, index)
                : () => openScreen(
                    context,
                    AppScreen.nowPlaying,
                    presentation: widget.data.selecting(
                      song: widget.data.songs[index],
                    ),
                  ),
          ),
      const SizedBox(height: 12),
      const ScreenLink(
        screen: AppScreen.nowPlaying,
        label: 'Now Playing',
        icon: Icons.play_circle_outline,
      ),
      ActionPill(
        'Remove playlist',
        icon: Icons.delete_outline,
        onPressed: widget.data.playlist == null
            ? null
            : actions != null
            ? () {
                final a = actions!;
                final id = widget.data.playlist!.playlistId;
                confirmAction(
                  context,
                  title: 'Remove playlist?',
                  message: 'Remove this playlist and its entries? Songs and physical audio files are preserved.',
                  action: 'Remove',
                  onConfirm: () async {
                    await a.dependencies.playlists.deletePlaylist(id);
                    return 'Playlist removed. Songs preserved.';
                  },
                );
              }
            : () => showUnavailableConfirmation(
                context,
                title: 'Remove playlist?',
                message: 'Playlist removal is not connected. No songs or playlists will be deleted.',
                action: 'Remove',
                enabled: true,
              ),
      ),
      const SizedBox(height: 16),
      PresentationNotice(data: widget.data, empty: 'No playlist selected'),
      if (widget.data.errorMessage != null)
        Text(widget.data.errorMessage!, style: mutedStyle),
    ],
  );
}
