import 'package:flutter/material.dart';

import '../routes/app_screen.dart';
import '../routes/frontend_navigation.dart';
import '../theme/app_theme.dart';
import '../widgets/design_widgets.dart';
import '../widgets/draft_editors.dart';
import '../widgets/presentation.dart';

void _showQueue(BuildContext context, ScreenPresentation data) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Queue', style: headingStyle),
              const SizedBox(height: 12),
              const Text('Playback queue is not connected.', style: mutedStyle),
              if (data.songs.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No queued songs'),
                ),
              for (final song in data.songs) SongRow(song: song),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      ),
    );

class NowPlayingPage extends StatelessWidget {
  const NowPlayingPage({super.key, required this.data});
  final ScreenPresentation data;
  @override
  Widget build(BuildContext context) => PageBody(
    screen: AppScreen.nowPlaying,
    children: [
      Text(
        data.playlist == null ? 'YOUR MUSIC' : 'FROM PLAYLIST',
        textAlign: TextAlign.center,
        style: const TextStyle(
          letterSpacing: 2,
          color: AppTheme.muted,
          fontSize: 12,
        ),
      ),
      const SizedBox(height: 6),
      Text(
        data.playlist?.name ?? 'No playlist selected',
        style: titleStyle,
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 18),
      Wrap(
        alignment: WrapAlignment.spaceBetween,
        spacing: 12,
        runSpacing: 8,
        children: [
          StatusPill(
            data.song?.audioFormat ?? 'Format unavailable',
            accent: true,
          ),
          const StatusPill('Audio output unavailable'),
        ],
      ),
      const SizedBox(height: 12),
      const ArtworkFrame(),
      const SizedBox(height: 24),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.song?.title ?? 'No track selected',
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  data.song?.artistName ?? 'Choose your music',
                  style: mutedStyle,
                ),
              ],
            ),
          ),
          const IconButton(
            onPressed: null,
            tooltip: 'Like song unavailable',
            icon: Icon(Icons.favorite_border),
          ),
        ],
      ),
      const SizedBox(height: 14),
      const PlaybackControls(),
      const SizedBox(height: 18),
      const Text(
        'Playback not connected · Awaiting MP3 File',
        style: mutedStyle,
      ),
      PresentationNotice(data: data, empty: 'No track selected'),
      const SizedBox(height: 16),
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          const StatusPill('No device connected'),
          ActionPill(
            'Queue',
            icon: Icons.queue_music,
            onPressed: () => _showQueue(context, data),
          ),
          ActionPill(
            'Share',
            icon: Icons.ios_share,
            onPressed: () => explainUnavailable(context, 'Sharing'),
          ),
        ],
      ),
      const SizedBox(height: 16),
      SurfaceCard(
        emphasis: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ScreenLink(
              screen: AppScreen.songDetails,
              label: 'Lyrics & Song Details',
              icon: Icons.notes,
            ),
            const SizedBox(height: 12),
            Text(
              data.song?.lyricsText ?? 'No manual lyrics available.',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: titleStyle,
            ),
          ],
        ),
      ),
    ],
  );
}

class SongDetailsPage extends StatelessWidget {
  const SongDetailsPage({super.key, required this.data});
  final ScreenPresentation data;
  @override
  Widget build(BuildContext context) => PageBody(
    screen: AppScreen.songDetails,
    children: [
      SurfaceCard(
        emphasis: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                Text('Lyrics', style: headingStyle),
                StatusPill('MANUAL TEXT'),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              data.song?.lyricsText ?? 'No lyrics available.',
              style: const TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w600,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 20),
            const ScreenLink(
              screen: AppScreen.lyrics,
              label: 'Fullscreen Lyrics',
              icon: Icons.open_in_full,
            ),
            ActionPill(
              'Edit lyrics',
              icon: Icons.edit_outlined,
              onPressed: data.song == null
                  ? null
                  : () => showDraftEditor(
                      context,
                      title: 'Edit manual lyrics',
                      fields: {'Lyrics': data.song!.lyricsText ?? ''},
                      multiline: const {'Lyrics'},
                    ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Manually entered text. Timed lyrics and line-to-audio navigation are unavailable.',
              style: mutedStyle,
            ),
          ],
        ),
      ),
      SurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Song information', style: titleStyle),
            const SizedBox(height: 12),
            SettingsRow(
              title: 'Title',
              subtitle: data.song?.title ?? 'Unavailable',
            ),
            SettingsRow(
              title: 'Artist',
              subtitle: data.song?.artistName ?? 'Unavailable',
            ),
            const SettingsRow(
              title: 'Credits',
              subtitle: 'Additional credits unavailable',
            ),
          ],
        ),
      ),
      SurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Audio Architecture & File', style: titleStyle),
            const SizedBox(height: 12),
            SettingsRow(
              title: 'Format',
              subtitle: data.song?.audioFormat ?? 'Unavailable',
            ),
            SettingsRow(
              title: 'Stored duration',
              subtitle: data.song == null
                  ? 'Unavailable'
                  : '${data.song!.durationMs} ms',
            ),
            SettingsRow(
              title: 'Date added',
              subtitle:
                  data.song?.dateAdded.toIso8601String().split('T').first ??
                  'Unavailable',
            ),
            const SizedBox(height: 12),
            const Text(
              'FILE REFERENCE',
              style: TextStyle(fontSize: 11, color: AppTheme.muted),
            ),
            const SizedBox(height: 8),
            SelectableText(
              data.song?.filePath ?? 'No file selected',
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ],
        ),
      ),
      SurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Listening Insights', style: titleStyle),
            const SizedBox(height: 14),
            Text(
              data.statistics == null
                  ? 'No listening history loaded.'
                  : '${data.statistics!.totalCountedPlays} counted plays',
              style: mutedStyle,
            ),
            TextButton(
              onPressed: () => selectPrimary(context, 3),
              child: const Text('View Detailed Statistics'),
            ),
          ],
        ),
      ),
      SurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Up next', style: titleStyle),
            if (data.songs.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('No queued songs', style: mutedStyle),
              ),
            if (data.songs.isNotEmpty) SongRow(song: data.songs.first),
            ActionPill(
              'Open Queue',
              icon: Icons.queue_music,
              onPressed: () => _showQueue(context, data),
            ),
          ],
        ),
      ),
      PresentationNotice(data: data, empty: 'No song selected'),
    ],
  );
}

class FullscreenLyricsPage extends StatelessWidget {
  const FullscreenLyricsPage({super.key, required this.data});
  final ScreenPresentation data;
  @override
  Widget build(BuildContext context) => PageBody(
    screen: AppScreen.lyrics,
    children: [
      Text(
        data.song?.title ?? 'No song selected',
        style: headingStyle,
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 8),
      Text(
        data.song?.artistName ?? 'Manual lyrics',
        style: mutedStyle,
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 18),
      const Center(child: StatusPill('Manual lyrics · No synchronization')),
      const SizedBox(height: 28),
      Text(
        data.song?.lyricsText ?? 'No lyrics available.\n\nAdd manual lyrics to a selected song when music data is connected.',
        style: const TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          height: 1.65,
        ),
      ),
      const SizedBox(height: 40),
      const PlaybackControls(compact: true),
      const SizedBox(height: 12),
      const Text(
        'Playback unavailable',
        style: mutedStyle,
        textAlign: TextAlign.center,
      ),
      if (data.mode != PresentationMode.ready) ...[
        const SizedBox(height: 16),
        PresentationNotice(data: data, empty: 'No manual lyrics to display'),
      ],
    ],
  );
}
