import 'package:flutter/material.dart';

import '../routes/app_screen.dart';
import '../routes/frontend_navigation.dart';
import '../widgets/design_widgets.dart';
import '../widgets/draft_editors.dart';
import '../widgets/presentation.dart';

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
  bool _grid = false;
  final _search = TextEditingController();
  final _focus = FocusNode();
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
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              builder: (context) => SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('Library categories', style: headingStyle),
                      for (final value in [
                        'Playlists',
                        'Songs',
                        'Albums',
                        'Artists',
                      ])
                        TextButton(
                          onPressed: () {
                            setState(() => _category = value);
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
              selected: _category,
              onSelected: (value) => setState(() => _category = value),
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
          onChanged: widget.onSearchChanged,
          decoration: InputDecoration(
            labelText: 'Search your library',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: IconButton(
              tooltip: 'Clear search',
              onPressed: () {
                _search.clear();
                widget.onSearchChanged?.call('');
              },
              icon: const Icon(Icons.close),
            ),
          ),
        ),
      ],
      const SizedBox(height: 12),
      Row(
        children: [
          const Icon(Icons.swap_vert),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButton<String>(
              isExpanded: true,
              value: _sort,
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
              onChanged: (value) {
                if (value != null) {
                  setState(() => _sort = value);
                  widget.onSortChanged?.call(value);
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
      SurfaceCard(
        child: const ScreenLink(
          screen: AppScreen.sync,
          label: 'Radxa Device Sync',
          subtitle: 'No device connected · Storage unavailable',
          icon: Icons.sync,
        ),
      ),
      if (_category == 'Playlists') ...[
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
      ] else if (_category == 'Songs') ...[
        for (final song in widget.data.songs)
          SurfaceCard(
            child: SongRow(
              song: song,
              onTap: () => openScreen(
                context,
                AppScreen.nowPlaying,
                presentation: widget.data.selecting(song: song),
              ),
            ),
          ),
      ] else
        SurfaceCard(
          child: Text(
            '$_category will appear when library data is connected.',
            style: mutedStyle,
          ),
        ),
      if (_grid)
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
            child: const IconButton(
              onPressed: null,
              tooltip: 'Play playlist unavailable',
              iconSize: 38,
              padding: EdgeInsets.all(16),
              icon: Icon(Icons.play_arrow),
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
                      const Text(
                        'Adding songs is not connected. No playlist will be changed.',
                        style: mutedStyle,
                      ),
                      if (widget.data.songs.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('No songs available'),
                        ),
                      for (final song in widget.data.songs) SongRow(song: song),
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
                : () => showDraftEditor(
                    context,
                    title: 'Edit playlist',
                    fields: {
                      'Title': widget.data.playlist!.name,
                      'Description': widget.data.playlist!.description ?? '',
                    },
                    requiredFields: const {'Title'},
                    multiline: const {'Description'},
                  ),
          ),
          ActionPill(
            'Reorder',
            icon: Icons.swap_vert,
            onPressed: () => setState(() => _reorder = !_reorder),
          ),
        ],
      ),
      if (_reorder)
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
      for (final song in widget.data.songs)
        SongRow(
          song: song,
          reorder: _reorder,
          onTap: () => openScreen(
            context,
            AppScreen.nowPlaying,
            presentation: widget.data.selecting(song: song),
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
    ],
  );
}
