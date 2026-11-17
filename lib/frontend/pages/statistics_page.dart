import 'package:flutter/material.dart';

import '../routes/app_screen.dart';
import '../theme/app_theme.dart';
import '../widgets/design_widgets.dart';
import '../widgets/presentation.dart';
import '../widgets/application_binding.dart';
import '../../backend/models/listening_statistics.dart';

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
    final a = widget.data.integrated ? ApplicationScope.of(context) : null;
    final selectedPeriod = a == null
        ? _period
        : switch (widget.data.period) {
            StatisticsPeriod.allTime => 'All Time',
            StatisticsPeriod.week => 'Week',
            StatisticsPeriod.month => 'Month',
            _ => 'Year',
          };
    final stats = widget.data.statistics;
    final duration = stats?.totalListeningDuration;
    final values = [
      (
        'LISTENING TIME',
        duration == null
            ? '—'
            : widget.data.integrated
            ? '${duration.inHours}h ${duration.inMinutes.remainder(60)}m ${duration.inSeconds.remainder(60)}s ${duration.inMilliseconds.remainder(1000)}ms'
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
        if (widget.data.errorMessage != null)
          Text(widget.data.errorMessage!, style: mutedStyle),
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
          selected: selectedPeriod,
          onSelected: (value) {
            if (a == null) {
              setState(() => _period = value);
            } else {
              a.quietly(
                () => a.loadStatistics(
                  selected: switch (value) {
                    'Week' => StatisticsPeriod.week,
                    'Month' => StatisticsPeriod.month,
                    'Year' => StatisticsPeriod.year,
                    _ => StatisticsPeriod.allTime,
                  },
                ),
              );
            }
          },
        ),
        const SizedBox(height: 16),
        Text(
          a == null
              ? 'Period selection is a draft. Statistics are not connected.'
              : 'Calendar-period totals from saved listening history.',
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
              Text(
                a == null
                    ? 'Weekly hours breakdown'
                    : 'Latest up to 20 sessions in this period · Hours',
                style: mutedStyle,
              ),
              const SizedBox(height: 24),
              ActivityChart(
                hours: widget.data.activityHours,
                recent: widget.data.integrated,
              ),
              const SizedBox(height: 18),
              Text(
                widget.data.activityHours.isEmpty
                    ? 'No listening activity available.'
                    : a == null
                    ? 'Design sample · Weekly activity'
                    : 'Recent sessions only; full-period totals shown above.',
                style: mutedStyle,
              ),
            ],
          ),
        ),
        SectionTitle('Top Tracks · $selectedPeriod'),
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
          child: widget.data.integrated || widget.data.songs.isEmpty
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
                    title: widget.data.integrated
                        ? widget.data.availableSongs
                                  .where(
                                    (song) => song.songId == history.songId,
                                  )
                                  .firstOrNull
                                  ?.title ??
                              history.songId
                        : history.songId,
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
  const ActivityChart({super.key, required this.hours, this.recent = false});
  final Map<String, double> hours;
  final bool recent;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final labels = recent
          ? hours.keys.map((day) => day.substring(5)).toList()
          : ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
      final minimumWidth =
          labels.length * MediaQuery.textScalerOf(context).scale(50);
      final width = recent && minimumWidth > constraints.maxWidth
          ? minimumWidth
          : constraints.maxWidth;
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: width,
          child: Column(
            children: [
              Semantics(
                label: hours.isEmpty
                    ? 'No chart data'
                    : recent
                    ? 'Recent sessions activity chart, not full-period totals'
                    : 'Design sample activity chart',
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
                  for (final label in labels)
                    Expanded(
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        style: mutedStyle,
                      ),
                    ),
                ],
              ),
              for (final entry in hours.entries)
                Semantics(
                  label: '${entry.key}: ${entry.value} hours',
                  child: const SizedBox.shrink(),
                ),
            ],
          ),
        ),
      );
    },
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
