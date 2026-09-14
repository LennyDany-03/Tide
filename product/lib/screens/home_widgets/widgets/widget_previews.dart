import 'package:flutter/material.dart';

import '../../../theme/tide_colors.dart';
import '../../../theme/tide_typography.dart';

/// Static stand-ins for the native RemoteViews layouts — mocks, not a live
/// preview of real data. Deliberately simple next to the real widgets:
/// there is no glyph rendering on the home screen either (see
/// widget_status_done.xml's comment), so no preview here should promise one.
class TodayHabitsPreview extends StatelessWidget {
  const TodayHabitsPreview({super.key});

  @override
  Widget build(BuildContext context) {
    return const PreviewRows(
      rows: [('Morning water', true), ('Evening walk', false)],
    );
  }
}

class HabitDashboardPreview extends StatelessWidget {
  const HabitDashboardPreview({super.key});

  @override
  Widget build(BuildContext context) {
    return const PreviewRows(
      rows: [('Morning water', true), ('Evening walk', false)],
      streaks: [12, 4],
    );
  }
}

class TodayTasksPreview extends StatelessWidget {
  const TodayTasksPreview({super.key});

  @override
  Widget build(BuildContext context) {
    return const PreviewRows(
      rows: [('Pay rent', false), ('Call dentist', false)],
      overdue: [true, false],
    );
  }
}

/// One row per habit/task; [overdue] recolours the leading dot coral
/// instead of the usual done/due look, for Today's Tasks.
class PreviewRows extends StatelessWidget {
  const PreviewRows({super.key, required this.rows, this.streaks, this.overdue});

  final List<(String, bool)> rows;
  final List<int>? streaks;
  final List<bool>? overdue;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: TideColors.shoal,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: rows[i].$2 ? TideColors.lantern : Colors.transparent,
                    border: rows[i].$2
                        ? null
                        : Border.all(
                            color: overdue != null && overdue![i]
                                ? TideColors.coral
                                : TideColors.silt,
                            width: 1.2,
                          ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    rows[i].$1,
                    style: TideType.label.copyWith(color: TideColors.bone),
                  ),
                ),
                if (streaks != null)
                  Text(
                    '${streaks![i]}',
                    style: TideType.gauge(12, color: TideColors.lantern),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// The Single Habit Streak widget, 1x1: a big streak number and a name.
class SingleHabitStreakPreview extends StatelessWidget {
  const SingleHabitStreakPreview({super.key, required this.habitName});

  final String? habitName;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: TideColors.shoal,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text('12', style: TideType.gauge(24, color: TideColors.lantern)),
          const SizedBox(height: 4),
          Text(
            habitName ?? 'No habit pinned',
            style: TideType.labelMuted,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// The Quick Add widget, 1x1: a single "+" tap target.
class QuickAddPreview extends StatelessWidget {
  const QuickAddPreview({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: TideColors.shoal,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: TideColors.lantern,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '+',
              style: TideType.gauge(22, color: TideColors.onLantern),
            ),
          ),
        ),
      ),
    );
  }
}

/// The Habit Heatmap widget: a small grid standing in for the rendered PNG
/// the real widget shows (see `HeatmapExport`) — the same four intensity
/// tiers, just drawn in Flutter here instead of native XML.
class HeatmapPreview extends StatelessWidget {
  const HeatmapPreview({super.key});

  static const _pattern = [
    [1, 2, 3, 0, 2, 3, 1],
    [3, 3, 0, 2, 3, 2, 3],
    [0, 2, 3, 3, 1, 3, 2],
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: TideColors.shoal,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          for (final row in _pattern) ...[
            if (row != _pattern.first) const SizedBox(height: 3),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final tier in row) ...[
                  if (tier != row.first) const SizedBox(width: 3),
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: TideColors.intensity(tier / 3),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// The Weekly Recap widget: two stat blocks side by side.
class WeeklyRecapPreview extends StatelessWidget {
  const WeeklyRecapPreview({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: TideColors.shoal,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                Text('82%', style: TideType.gauge(20, color: TideColors.lantern)),
                Text('this week', style: TideType.labelMuted),
              ],
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Text('12', style: TideType.gauge(20, color: TideColors.bone)),
                Text('best streak', style: TideType.labelMuted),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
