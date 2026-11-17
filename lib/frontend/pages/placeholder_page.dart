import 'package:flutter/material.dart';

import '../routes/app_screen.dart';
import '../theme/app_theme.dart';
import '../widgets/preview_widgets.dart';

class PlaceholderPage extends StatelessWidget {
  const PlaceholderPage({super.key, required this.screen});

  final AppScreen screen;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: BackButton(onPressed: () => Navigator.of(context).maybePop()),
      title: Text(screen.title, maxLines: 2, overflow: TextOverflow.ellipsis),
    ),
    body: SafeArea(child: PlaceholderContent(screen: screen)),
  );
}

/// Wireframe-shaped presentation only. Domain data and operations are added
/// in their assigned later increments, through controllers and services.
class PlaceholderContent extends StatelessWidget {
  const PlaceholderContent({super.key, required this.screen});

  final AppScreen screen;

  Widget _card(String title, String body) => PreviewCard(
    title: title,
    child: Text(body, style: const TextStyle(color: AppTheme.muted)),
  );

  Widget _link(AppScreen destination, String label) =>
      DestinationLink(screen: destination, label: label);

  Widget _disabled(String label) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: OutlinedButton(onPressed: null, child: Text(label)),
  );

  List<Widget> _sections() => switch (screen) {
    AppScreen.library => [
      const TextField(
        enabled: false,
        decoration: InputDecoration(
          hintText: 'Search library · available in a later increment',
          prefixIcon: Icon(Icons.search),
        ),
      ),
      const SizedBox(height: 16),
      const Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          Chip(label: Text('Playlists')),
          Chip(label: Text('Songs')),
          Chip(label: Text('Albums')),
          Chip(label: Text('Artists')),
        ],
      ),
      const SizedBox(height: 16),
      _card(
        'Your music, offline',
        'Your library is empty. Music management will be connected in later increments.',
      ),
      _link(AppScreen.playlist, 'Playlist Details preview'),
      _link(AppScreen.nowPlaying, 'Now Playing preview'),
      _link(AppScreen.sync, 'Music Sync'),
    ],
    AppScreen.playlist => [
      const _ArtworkPreview(),
      _card(
        'Playlist preview',
        'No playlist selected. Tracks and playlist editing are not available yet.',
      ),
      _disabled('Add songs · unavailable'),
      _disabled('Edit playlist · unavailable'),
      _link(AppScreen.nowPlaying, 'Now Playing preview'),
    ],
    AppScreen.nowPlaying => [
      const _ArtworkPreview(),
      _card(
        'No track selected',
        'Local playback is planned for Increment 4. Playback controls are unavailable.',
      ),
      const Slider(value: 0, onChanged: null),
      const Wrap(
        alignment: WrapAlignment.center,
        children: [
          IconButton(
            onPressed: null,
            tooltip: 'Previous unavailable',
            icon: Icon(Icons.skip_previous),
          ),
          IconButton(
            onPressed: null,
            tooltip: 'Playback unavailable',
            icon: Icon(Icons.play_circle, size: 56),
          ),
          IconButton(
            onPressed: null,
            tooltip: 'Next unavailable',
            icon: Icon(Icons.skip_next),
          ),
        ],
      ),
      _link(AppScreen.songDetails, 'Lyrics & Song Details'),
    ],
    AppScreen.songDetails => [
      _card(
        'Manual lyrics',
        'No song selected. Lyrics viewing and editing will use optional saved text in a later increment.',
      ),
      _link(AppScreen.lyrics, 'Fullscreen Lyrics'),
      _disabled('Edit lyrics · unavailable'),
      _card(
        'Audio & file information',
        'Format, duration, file reference, and date added will appear here.',
      ),
      _card('Listening insights', 'No listening history available.'),
    ],
    AppScreen.lyrics => [
      _card(
        'No lyrics available',
        'Select a song and add manual lyrics when music management is implemented.',
      ),
      _disabled('Playback · unavailable'),
    ],
    AppScreen.addMusic => [
      const Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          Chip(label: Text('Download from URL')),
          Chip(label: Text('Record Audio')),
        ],
      ),
      const SizedBox(height: 16),
      _card(
        'Paste Audio URL',
        'Downloads require a Radxa connection. Hardware integration is not implemented.',
      ),
      const TextField(
        enabled: false,
        decoration: InputDecoration(
          labelText: 'Audio URL',
          prefixIcon: Icon(Icons.link),
        ),
      ),
      const SizedBox(height: 12),
      _disabled('Download Song · unavailable'),
      _card(
        'Import Local Audio File',
        'Importing and transferring files are unavailable in this increment.',
      ),
      _disabled('Browse files · unavailable'),
      _link(AppScreen.record, 'Record Audio'),
      _card('Recent Downloads', 'No downloads available.'),
    ],
    AppScreen.record => [
      _card(
        'Vinyl & CD Digitization',
        'Requires external audio hardware and a Radxa connection. No recording is active.',
      ),
      _card('Audio capture', 'Elapsed time and input levels are unavailable.'),
      _disabled('Start recording · unavailable'),
      _disabled('Mark track split · unavailable'),
      _card('Captured Track Splits', 'No captured tracks.'),
      _link(
        AppScreen.saveRecording,
        'Save Recording / Track Information preview',
      ),
    ],
    AppScreen.saveRecording => [
      _card(
        'Recording session',
        'Preview only. No recording has been captured.',
      ),
      _card(
        'Album & Metadata',
        'Track information will be editable when recording support is implemented.',
      ),
      _card('Divided Tracks', 'No recorded tracks.'),
      _card(
        'Destination & Sync',
        'Saving to the MP3 player and exporting to the phone are unavailable.',
      ),
      _disabled('Save & Add to Library · unavailable'),
    ],
    AppScreen.device => [
      _card(
        'MP3 Capsule',
        'No device connected. Hardware integration is unavailable in this development phase.',
      ),
      const _SectionHeading('Connectivity & storage'),
      _link(AppScreen.connections, 'Connections'),
      _link(AppScreen.sync, 'Music Sync'),
      _link(AppScreen.storage, 'Storage'),
      _link(AppScreen.files, 'File Manager'),
      const _SectionHeading('Hardware & audio'),
      _link(AppScreen.bluetoothAudio, 'Bluetooth Audio'),
      _link(AppScreen.batteryDisplay, 'Battery & Display'),
      _link(AppScreen.aboutDevice, 'About Device'),
    ],
    AppScreen.connections => [
      _card(
        'No device connected',
        'Wi-Fi and BLE discovery, authorization, and pairing are not implemented.',
      ),
      _card(
        'Connection methods',
        'Wi-Fi: unavailable\nBluetooth Low Energy: unavailable\nUSB-C device operations: unavailable',
      ),
      _card(
        'Connection preferences',
        'Automatic reconnect and preferred transport settings require future device integration.',
      ),
      _disabled('Find My MP3 Player · unavailable'),
      _disabled('Reconnect · unavailable'),
      _disabled('Forget Device · unavailable'),
    ],
    AppScreen.sync => [
      _card(
        'Music Sync',
        'No device connected. No synchronization is running.',
      ),
      _card(
        'What Gets Synced',
        'Music and playlists will be selectable when device integration is implemented.',
      ),
      _disabled('Sync Now · unavailable'),
    ],
    AppScreen.storage => [
      _card(
        'Device storage',
        'Capacity and available space are unknown. Connect a supported device in a future phase.',
      ),
      _card(
        'Storage Breakdown',
        'Music, recordings, and other file sizes are unavailable.',
      ),
      _link(AppScreen.files, 'File Manager'),
    ],
    AppScreen.files => [
      _card(
        'MP3 Capsule files',
        'No device connected. No device file list is available.',
      ),
      const Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          Chip(label: Text('Music')),
          Chip(label: Text('Recordings')),
          Chip(label: Text('Other')),
        ],
      ),
      _disabled('Delete files · unavailable'),
      _disabled('Transfer to Phone · unavailable'),
    ],
    AppScreen.bluetoothAudio => [
      _card(
        'Bluetooth Audio',
        'This screen manages the MP3 player’s audio accessories. It does not control phone Bluetooth.',
      ),
      _card(
        'Connected & paired devices',
        'No device information available. Accessory discovery is unavailable.',
      ),
      _disabled('Pair New Audio Device · unavailable'),
      _card(
        'Audio Output Mode',
        '3.5 mm headphones, Bluetooth audio, and USB audio require device support.',
      ),
    ],
    AppScreen.batteryDisplay => [
      _card(
        'Battery Status & Power',
        'Battery level, charging state, and health are unavailable without hardware.',
      ),
      _disabled('Battery Saver · unavailable'),
      _card(
        'Display & Atmosphere',
        'Brightness, screen timeout, and always-on display require device support.',
      ),
      const Slider(value: 0, onChanged: null),
    ],
    AppScreen.aboutDevice => [
      _card(
        'Device Information',
        'No device connected. Model, software version, capacity, identifier, and last connection are unknown.',
      ),
      _disabled('Check for Updates · unavailable'),
      _card(
        'Hardware Power Controls',
        'Power operations require future authorized device communication.',
      ),
      _disabled('Restart Device · unavailable'),
      _disabled('Shut Down · unavailable'),
    ],
    AppScreen.statistics => [
      const Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          Chip(label: Text('Week')),
          Chip(label: Text('Month')),
          Chip(label: Text('Year')),
          Chip(label: Text('All Time')),
        ],
      ),
      const SizedBox(height: 16),
      _card(
        'Listening Statistics',
        'No listening history available. Listening time and track counts will appear after playback integration.',
      ),
      _card('Listening Activity', 'No activity to display.'),
      _card('Top Tracks & Artists', 'No listening data available.'),
      _disabled('Export Statistics · unavailable'),
    ],
  };

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    key: PageStorageKey(screen),
    padding: const EdgeInsets.all(20),
    child: Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Column(
          key: ValueKey('screen-${screen.name}'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'INCREMENT 1 · NAVIGATION PREVIEW',
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(color: AppTheme.muted),
            ),
            const SizedBox(height: 16),
            ..._sections(),
          ],
        ),
      ),
    ),
  );
}

class _ArtworkPreview extends StatelessWidget {
  const _ArtworkPreview();

  @override
  Widget build(BuildContext context) => Container(
    height: 200,
    margin: const EdgeInsets.only(bottom: 20),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(24),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [AppTheme.blue, Color(0xFF442137), AppTheme.background],
      ),
    ),
    child: const Center(
      child: Icon(Icons.album_outlined, size: 88, color: AppTheme.muted),
    ),
  );
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 16),
    child: Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.labelLarge
          ?.copyWith(color: AppTheme.muted),
    ),
  );
}
