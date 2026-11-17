import 'package:flutter/material.dart';

import '../routes/app_screen.dart';
import '../theme/app_theme.dart';
import '../widgets/design_widgets.dart';
import '../widgets/presentation.dart';

class StatisticsPage extends StatefulWidget {
  const StatisticsPage({super.key, required this.data});
  final ScreenPresentation data;
  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  String _period = 'All Time';
  @override
  Widget build(BuildContext context) {
    final stats = widget.data.statistics;
    final duration = stats?.totalListeningDuration;
    final values = [
      (
        'LISTENING TIME',
        duration == null
            ? '—'
            : '${duration.inHours}h ${duration.inMinutes.remainder(60)}m',
        Icons.schedule,
      ),
      (
        'TOTAL PLAYS',
        stats?.totalCountedPlays.toString() ?? '—',
        Icons.graphic_eq,
      ),
      ('STORAGE USED', 'Unavailable', Icons.storage),
      ('CURRENT STREAK', 'Unavailable', Icons.local_fire_department_outlined),
    ];
    return PageBody(
      screen: AppScreen.statistics,
      children: [
        const Text(
          'LISTENING INSIGHTS',
          style: TextStyle(
            fontSize: 11,
            color: AppTheme.muted,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 16),
        ChoicePills(
          labels: const ['Week', 'Month', 'Year', 'All Time'],
          selected: _period,
          onSelected: (value) => setState(() => _period = value),
        ),
        const SizedBox(height: 16),
        const Text(
          'Period selection is a draft. Statistics are not connected.',
          style: mutedStyle,
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns =
                constraints.maxWidth < 350 ||
                    MediaQuery.textScalerOf(context).scale(14) > 20
                ? 1
                : 2;
            return Wrap(
              spacing: 12,
              runSpacing: 0,
              children: [
                for (final (label, value, icon) in values)
                  SizedBox(
                    width:
                        (constraints.maxWidth - 12 * (columns - 1)) / columns,
                    child: SurfaceCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(icon, color: AppTheme.crimson),
                          const SizedBox(height: 12),
                          Text(
                            label,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.muted,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            value,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Listening Activity', style: headingStyle),
              const SizedBox(height: 8),
              const Text('Weekly hours breakdown', style: mutedStyle),
              const SizedBox(height: 24),
              ActivityChart(hours: widget.data.activityHours),
              const SizedBox(height: 18),
              Text(
                widget.data.activityHours.isEmpty
                    ? 'No listening activity available.'
                    : 'Design sample · Weekly activity',
                style: mutedStyle,
              ),
            ],
          ),
        ),
        SectionTitle('Top Tracks · $_period'),
        if (stats == null || stats.topTracks.isEmpty)
          const SurfaceCard(
            child: Text('No top tracks available.', style: mutedStyle),
          ),
        if (stats != null)
          for (var i = 0; i < stats.topTracks.length; i++)
            SurfaceCard(
              child: SongRow(
                song: stats.topTracks[i].song,
                rank: i + 1,
                trailing: StatusPill(
                  '${stats.topTracks[i].countedPlays} plays',
                ),
              ),
            ),
        const SectionTitle('Top Artists'),
        SurfaceCard(
          child: widget.data.songs.isEmpty
              ? const Text('Artist summaries unavailable.', style: mutedStyle)
              : Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final song in widget.data.songs)
                      SizedBox(
                        width: 100,
                        child: Column(
                          children: [
                            const ClipOval(
                              child: IconTile(Icons.person_outline, size: 54),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              song.artistName,
                              style: mutedStyle,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
        const SectionTitle('Recent Listening Activity'),
        SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (stats == null || stats.recentHistory.isEmpty)
                const Text(
                  'No listening history available.',
                  style: mutedStyle,
                ),
              if (stats != null)
                for (final history in stats.recentHistory)
                  SettingsRow(
                    title: history.songId,
                    subtitle:
                        '${history.startedAt.toIso8601String().split('T').first} · ${history.listenedMs} ms',
                    icon: Icons.history,
                  ),
            ],
          ),
        ),
        const ActionPill('Export Statistics', icon: Icons.ios_share),
        const SizedBox(height: 16),
        PresentationNotice(
          data: widget.data,
          empty: 'No listening history',
          unconnected: 'Listening statistics are not connected yet.',
        ),
      ],
    );
  }
}

class ActivityChart extends StatelessWidget {
  const ActivityChart({super.key, required this.hours});
  final Map<String, double> hours;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Semantics(
        label: hours.isEmpty ? 'No chart data' : 'Design sample activity chart',
        child: SizedBox(
          height: 110,
          child: CustomPaint(
            size: const Size(double.infinity, 110),
            painter: _ActivityPainter(hours),
          ),
        ),
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          for (final day in ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
            Expanded(
              child: Text(day, textAlign: TextAlign.center, style: mutedStyle),
            ),
        ],
      ),
      for (final entry in hours.entries)
        Semantics(
          label: '${entry.key}: ${entry.value} hours',
          child: const SizedBox.shrink(),
        ),
    ],
  );
}

class _ActivityPainter extends CustomPainter {
  _ActivityPainter(this.hours);
  final Map<String, double> hours;
  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = AppTheme.outline
      ..strokeWidth = 1;
    for (var y = 0; y <= 4; y++) {
      canvas.drawLine(
        Offset(0, size.height * y / 4),
        Offset(size.width, size.height * y / 4),
        line,
      );
    }
    final values = hours.values.toList();
    if (values.isEmpty) return;
    final max = values.reduce((a, b) => a > b ? a : b);
    if (max <= 0) return;
    final slot = size.width / values.length;
    for (var i = 0; i < values.length; i++) {
      final height = (values[i] / max).clamp(0, 1) * size.height;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(i * slot + 4, size.height - height, slot - 8, height),
          const Radius.circular(3),
        ),
        Paint()
          ..color = i == 4
              ? AppTheme.crimson
              : i == 5
              ? AppTheme.blue
              : AppTheme.outline,
      );
    }
  }

  @override
  bool shouldRepaint(_ActivityPainter oldDelegate) =>
      oldDelegate.hours != hours;
}
