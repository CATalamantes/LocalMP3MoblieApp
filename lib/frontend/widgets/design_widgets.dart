import 'package:flutter/material.dart';

import '../../backend/models/music_models.dart';
import '../routes/app_screen.dart';
import '../routes/frontend_navigation.dart';
import '../theme/app_theme.dart';
import 'presentation.dart';

const headingStyle = TextStyle(
  fontSize: 22,
  fontWeight: FontWeight.w700,
  height: 1.2,
);
const titleStyle = TextStyle(
  fontSize: 17,
  fontWeight: FontWeight.w600,
  height: 1.3,
);
const mutedStyle = TextStyle(color: AppTheme.muted, height: 1.45);

class PageBody extends StatelessWidget {
  const PageBody({super.key, required this.screen, required this.children});
  final AppScreen screen;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    key: ValueKey('screen-${screen.name}'),
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    ),
  );
}

class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    super.key,
    required this.child,
    this.emphasis = false,
    this.padding = 16,
  });
  final Widget child;
  final bool emphasis;
  final double padding;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 14),
    padding: EdgeInsets.all(padding),
    decoration: BoxDecoration(
      color: emphasis ? AppTheme.blue : AppTheme.surface,
      border: Border.all(color: AppTheme.outline),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Material(color: Colors.transparent, child: child),
  );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(2, 16, 2, 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Text(text, style: titleStyle)),
        ?trailing,
      ],
    ),
  );
}

class StatusPill extends StatelessWidget {
  const StatusPill(this.text, {super.key, this.accent = false});
  final String text;
  final bool accent;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: accent ? AppTheme.crimson.withValues(alpha: .12) : AppTheme.blue,
      borderRadius: BorderRadius.circular(7),
      border: Border.all(
        color: accent
            ? AppTheme.crimson.withValues(alpha: .55)
            : AppTheme.outline,
      ),
    ),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: accent ? AppTheme.text : AppTheme.muted,
      ),
    ),
  );
}

class IconTile extends StatelessWidget {
  const IconTile(this.icon, {super.key, this.size = 44});
  final IconData icon;
  final double size;
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: AppTheme.blue,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Icon(icon, color: AppTheme.crimson, size: size * .52),
  );
}

class ArtworkFrame extends StatelessWidget {
  const ArtworkFrame({super.key, this.size, this.collage = false});
  final double? size;
  final bool collage;
  @override
  Widget build(BuildContext context) {
    final art = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.outline),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.blue, AppTheme.surface, AppTheme.background],
        ),
      ),
      child: collage
          ? Column(
              children: [
                for (var row = 0; row < 2; row++)
                  Expanded(
                    child: Row(
                      children: [
                        for (var col = 0; col < 2; col++)
                          Expanded(
                            child: Center(
                              child: Icon(
                                row == col
                                    ? Icons.album_outlined
                                    : Icons.graphic_eq,
                                size: 42,
                                color: AppTheme.muted.withValues(alpha: .45),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            )
          : const Center(
              child: Icon(
                Icons.album_outlined,
                size: 60,
                color: AppTheme.muted,
              ),
            ),
    );
    return Semantics(
      label: 'Artwork unavailable',
      image: true,
      child: ExcludeSemantics(
        child: size == null
            ? AspectRatio(aspectRatio: 1, child: art)
            : SizedBox(width: size, height: size, child: art),
      ),
    );
  }
}

class PresentationNotice extends StatelessWidget {
  const PresentationNotice({
    super.key,
    required this.data,
    required this.empty,
    this.unconnected = 'Music data is not connected yet.',
  });
  final ScreenPresentation data;
  final String empty, unconnected;
  @override
  Widget build(BuildContext context) {
    if (data.mode == PresentationMode.ready) return const SizedBox.shrink();
    final (icon, title, message) = switch (data.mode) {
      PresentationMode.loading => (
        Icons.hourglass_empty,
        'Loading',
        'Waiting for data.',
      ),
      PresentationMode.error => (
        Icons.error_outline,
        'Unable to display data',
        'Please try again when this feature is connected.',
      ),
      PresentationMode.empty => (
        Icons.music_note_outlined,
        empty,
        'Your content will appear here.',
      ),
      PresentationMode.unavailable => (
        Icons.link_off,
        'Unavailable',
        unconnected,
      ),
      _ => (Icons.link_off, empty, unconnected),
    };
    return Semantics(
      liveRegion: true,
      child: SurfaceCard(
        child: Column(
          children: [
            Icon(icon, color: AppTheme.muted, size: 28),
            const SizedBox(height: 10),
            Text(title, style: titleStyle, textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(message, style: mutedStyle, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

void explainUnavailable(BuildContext context, [String action = 'This action']) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('$action is not connected. No changes were saved or sent.'),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

class ActionPill extends StatelessWidget {
  const ActionPill(
    this.label, {
    super.key,
    this.icon,
    this.onPressed,
    this.primary = false,
    this.reason = 'Not connected',
  });
  final String label, reason;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool primary;
  @override
  Widget build(BuildContext context) => Tooltip(
    message: onPressed == null ? '$label: $reason' : label,
    child: TextButton(
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        foregroundColor: AppTheme.text,
        disabledForegroundColor: AppTheme.muted,
        backgroundColor: primary
            ? (onPressed == null
                  ? AppTheme.crimson.withValues(alpha: .25)
                  : AppTheme.crimson)
            : AppTheme.blue,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(primary ? 12 : 28),
        ),
      ),
      onPressed: onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: 8)],
          Flexible(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    ),
  );
}

class ScreenLink extends StatelessWidget {
  const ScreenLink({
    super.key,
    required this.screen,
    required this.label,
    this.subtitle,
    this.icon = Icons.chevron_right,
  });
  final AppScreen screen;
  final String label;
  final String? subtitle;
  final IconData icon;
  @override
  Widget build(BuildContext context) => SettingsRow(
    key: ValueKey('open-${screen.name}'),
    title: label,
    subtitle: subtitle,
    icon: icon,
    onTap: () => openScreen(context, screen),
  );
}

class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.trailing,
    this.onTap,
  });
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? trailing;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (icon != null) ...[IconTile(icon!), const SizedBox(width: 12)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: titleStyle),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(subtitle!, style: mutedStyle),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing!,
          ] else if (onTap != null)
            const Icon(Icons.chevron_right, color: AppTheme.muted),
        ],
      ),
    ),
  );
}

class ChoicePills extends StatelessWidget {
  const ChoicePills({
    super.key,
    required this.labels,
    required this.selected,
    required this.onSelected,
  });
  final List<String> labels;
  final String selected;
  final ValueChanged<String> onSelected;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        for (final label in labels)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              shape: const StadiumBorder(),
              label: Text(label),
              selected: selected == label,
              onSelected: (_) => onSelected(label),
              showCheckmark: false,
              labelStyle: TextStyle(
                fontWeight: FontWeight.w600,
                color: selected == label ? AppTheme.text : AppTheme.muted,
              ),
              selectedColor: AppTheme.crimson.withValues(alpha: .22),
              side: BorderSide(
                color: selected == label ? AppTheme.crimson : AppTheme.outline,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            ),
          ),
      ],
    ),
  );
}

class SongRow extends StatelessWidget {
  const SongRow({
    super.key,
    required this.song,
    this.onTap,
    this.reorder = false,
    this.rank,
    this.trailing,
  });
  final Song song;
  final VoidCallback? onTap;
  final bool reorder;
  final int? rank;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        if (rank != null) ...[
          Text('$rank', style: titleStyle),
          const SizedBox(width: 12),
        ],
        const ArtworkFrame(size: 48),
        const SizedBox(width: 12),
        Expanded(
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(song.title, style: titleStyle),
                  Text(song.artistName, style: mutedStyle),
                  const SizedBox(height: 5),
                  StatusPill(song.audioFormat),
                ],
              ),
            ),
          ),
        ),
        if (trailing != null)
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 80),
            child: trailing!,
          )
        else
          IconButton(
            onPressed: reorder
                ? null
                : () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    builder: (context) => SafeArea(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(song.title, style: headingStyle),
                            const SizedBox(height: 16),
                            const Text(
                              'Song actions are not connected. No changes will be made.',
                              style: mutedStyle,
                            ),
                            const SizedBox(height: 16),
                            const ActionPill(
                              'Remove song',
                              icon: Icons.remove_circle_outline,
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Close'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
            tooltip: reorder ? 'Reordering unavailable' : 'Song actions',
            icon: Icon(reorder ? Icons.drag_handle : Icons.more_horiz),
          ),
      ],
    ),
  );
}

class PlaybackControls extends StatelessWidget {
  const PlaybackControls({super.key, this.compact = false});
  final bool compact;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Semantics(
        label: 'Playback position and duration unavailable',
        child: const ExcludeSemantics(child: Slider(value: 0, onChanged: null)),
      ),
      const Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('—:—', style: mutedStyle),
          Text('—:—', style: mutedStyle),
        ],
      ),
      const SizedBox(height: 12),
      Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: compact ? 0 : 4,
        children: [
          const IconButton(
            onPressed: null,
            tooltip: 'Shuffle unavailable',
            icon: Icon(Icons.shuffle),
          ),
          const IconButton(
            onPressed: null,
            tooltip: 'Previous unavailable',
            icon: Icon(Icons.skip_previous),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.crimson.withValues(alpha: .4),
            ),
            child: const IconButton(
              onPressed: null,
              tooltip: 'Playback unavailable',
              iconSize: 38,
              padding: EdgeInsets.all(12),
              icon: Icon(Icons.play_arrow),
            ),
          ),
          const IconButton(
            onPressed: null,
            tooltip: 'Next unavailable',
            icon: Icon(Icons.skip_next),
          ),
          const IconButton(
            onPressed: null,
            tooltip: 'Repeat unavailable',
            icon: Icon(Icons.repeat),
          ),
        ],
      ),
    ],
  );
}

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});
  @override
  Widget build(BuildContext context) {
    final song = PageNavigationScope.of(context)?.presentation.song;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
      child: Material(
        color: AppTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppTheme.outline),
        ),
        child: InkWell(
          key: const ValueKey('mini-player-preview'),
          borderRadius: BorderRadius.circular(14),
          onTap: () => openScreen(context, AppScreen.nowPlaying),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                const IconTile(Icons.album_outlined, size: 36),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        song?.title ?? 'No track selected',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const Text(
                        'Playback not connected',
                        style: TextStyle(fontSize: 11, color: AppTheme.muted),
                      ),
                    ],
                  ),
                ),
                const IconButton(
                  onPressed: null,
                  tooltip: 'Playback unavailable',
                  icon: Icon(Icons.play_arrow),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class PrimaryTabs extends StatelessWidget {
  const PrimaryTabs({
    super.key,
    required this.selected,
    required this.onSelected,
  });
  final int selected;
  final ValueChanged<int> onSelected;
  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      border: Border(top: BorderSide(color: AppTheme.outline)),
    ),
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < 4; i++)
          Expanded(
            child: Semantics(
              selected: selected == i,
              child: InkWell(
                key: ValueKey('tab-${AppScreen.mainScreens[i].name}'),
                onTap: () => onSelected(i),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 2,
                  ),
                  child: Column(
                    children: [
                      Icon(
                        [
                          Icons.library_music_outlined,
                          Icons.add_circle_outline,
                          Icons.speaker_outlined,
                          Icons.bar_chart,
                        ][i],
                        color: selected == i
                            ? AppTheme.crimson
                            : AppTheme.muted,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        ['Library', 'Add Music', 'Device', 'Statistics'][i],
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          height: 1.2,
                          fontWeight: FontWeight.w600,
                          color: selected == i ? AppTheme.text : AppTheme.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class ScreenFrame extends StatelessWidget {
  const ScreenFrame({
    super.key,
    required this.screen,
    required this.body,
    required this.selectedIndex,
    required this.onSelect,
    this.main = false,
    this.onSearch,
  });
  final AppScreen screen;
  final Widget body;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final bool main;
  final VoidCallback? onSearch;
  @override
  Widget build(BuildContext context) {
    final immersive = {AppScreen.nowPlaying, AppScreen.lyrics}.contains(screen);
    final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
    return Theme(
      data: AppTheme.frontend,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Scaffold(
            body: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0, .42, 1],
                  colors: screen == AppScreen.nowPlaying
                      ? [
                          Color.lerp(AppTheme.blue, AppTheme.crimson, .28)!,
                          AppTheme.blue.withValues(alpha: .35),
                          AppTheme.background,
                        ]
                      : screen == AppScreen.playlist
                      ? [
                          AppTheme.blue,
                          Color.lerp(AppTheme.surface, AppTheme.crimson, .1)!,
                          AppTheme.background,
                        ]
                      : [
                          AppTheme.blue.withValues(alpha: .2),
                          AppTheme.background,
                          AppTheme.background,
                        ],
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                      child: Row(
                        children: [
                          if (!main)
                            BackButton(
                              onPressed: () {
                                if (Navigator.of(context).canPop()) {
                                  Navigator.of(context).pop();
                                } else {
                                  selectPrimary(context, 0);
                                }
                              },
                            )
                          else
                            const Padding(
                              padding: EdgeInsets.only(right: 12),
                              child: ClipOval(
                                child: IconTile(Icons.music_note, size: 36),
                              ),
                            ),
                          Expanded(
                            child: Text(
                              screen == AppScreen.saveRecording
                                  ? 'Save to Library'
                                  : screen.title,
                              style: headingStyle,
                            ),
                          ),
                          if (screen == AppScreen.library)
                            IconButton(
                              tooltip: 'Search library',
                              onPressed: onSearch,
                              icon: const Icon(Icons.search),
                            ),
                          if (screen == AppScreen.saveRecording)
                            const SizedBox(
                              width: 96,
                              child: Tooltip(
                                message: 'Save All unavailable',
                                child: TextButton(
                                  onPressed: null,
                                  child: Text('Save All'),
                                ),
                              ),
                            )
                          else if ({
                            AppScreen.record,
                            AppScreen.connections,
                            AppScreen.bluetoothAudio,
                            AppScreen.batteryDisplay,
                          }.contains(screen))
                            const SizedBox(
                              width: 96,
                              child: StatusPill('Unavailable'),
                            )
                          else if (main)
                            IconButton(
                              tooltip: 'Add Music',
                              icon: const Icon(Icons.add),
                              onPressed: () => onSelect(1),
                            )
                          else
                            IconButton(
                              tooltip: 'Screen information',
                              icon: Icon(
                                screen == AppScreen.storage
                                    ? Icons.info_outline
                                    : screen == AppScreen.sync
                                    ? Icons.tune
                                    : Icons.more_horiz,
                              ),
                              onPressed: () => explainUnavailable(
                                context,
                                'Additional actions',
                              ),
                            ),
                        ],
                      ),
                    ),
                    Expanded(child: body),
                  ],
                ),
              ),
            ),
            bottomNavigationBar: immersive
                ? null
                : SafeArea(
                    top: false,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!keyboard) const MiniPlayer(),
                        PrimaryTabs(
                          selected: selectedIndex,
                          onSelected: onSelect,
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
