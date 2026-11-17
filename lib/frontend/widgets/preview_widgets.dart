import 'package:flutter/material.dart';

import '../routes/app_screen.dart';
import '../theme/app_theme.dart';

class PreviewCard extends StatelessWidget {
  const PreviewCard({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: AppTheme.surface,
      border: Border.all(color: AppTheme.outline),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        child,
      ],
    ),
  );
}

class DestinationLink extends StatelessWidget {
  const DestinationLink({
    super.key,
    required this.screen,
    required this.label,
    this.description,
  });

  final AppScreen screen;
  final String label;
  final String? description;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: ListTile(
      key: ValueKey('open-${screen.name}'),
      tileColor: AppTheme.blue,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(label),
      subtitle: description == null ? null : Text(description!),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.of(context).pushNamed(screen.route),
    ),
  );
}

class MiniPlayerPreview extends StatelessWidget {
  const MiniPlayerPreview({super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
    child: Material(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: ListTile(
        key: const ValueKey('mini-player-preview'),
        leading: const Icon(Icons.music_note, color: AppTheme.crimson),
        title: const Text('Now Playing preview'),
        subtitle: const Text('No track selected'),
        trailing: const Icon(Icons.expand_less),
        onTap: () =>
            Navigator.of(context).pushNamed(AppScreen.nowPlaying.route),
      ),
    ),
  );
}
