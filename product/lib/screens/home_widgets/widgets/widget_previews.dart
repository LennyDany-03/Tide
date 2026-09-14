import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../services/home_widget/heatmap_export.dart';
import '../../../services/home_widget/widget_payload.dart';
import '../../../theme/tide_colors.dart';
import '../../../theme/tide_typography.dart';
import '../../../widgets/tide_flame.dart';

/// Flutter mocks of the native widget layouts in
/// `android/app/src/main/res/layout/widget_*.xml`, with sample content —
/// not a live preview of the account. Kept visually in step with those by
/// hand: same header, same rows, same flame.
class _Card extends StatelessWidget {
  const _Card({required this.child, this.width, this.height});

  final Widget child;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: width,
        height: height,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: TideColors.shelf,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: TideColors.bone.withValues(alpha: 0.08)),
        ),
        child: child,
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title, this.meta, this.metaColor, this.leading});

  final String title;
  final String? meta;
  final Color? metaColor;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ?leading,
        if (leading != null) const SizedBox(width: 6),
        Expanded(
          child: Text(
            title,
            style: TideType.label.copyWith(color: TideColors.bone),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (meta != null)
          Text(meta!, style: TideType.gauge(13, color: metaColor ?? TideColors.silt)),
      ],
    );
  }
}

class _Flame extends StatelessWidget {
  const _Flame({this.size = 14});

  final double size;

  @override
  Widget build(BuildContext context) =>
      SizedBox(width: size * 0.8, height: size, child: const TideFlame());
}

class _Check extends StatelessWidget {
  const _Check({required this.done, this.overdue = false});

  final bool done;
  final bool overdue;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: done ? TideColors.lantern : Colors.transparent,
        border: done
            ? null
            : Border.all(
                color: overdue ? TideColors.coral : TideColors.silt,
                width: 1.6,
              ),
      ),
      child: done
          ? Icon(Icons.check_rounded, size: 13, color: TideColors.onLantern)
          : null,
    );
  }
}

class TodayHabitsPreview extends StatelessWidget {
  const TodayHabitsPreview({super.key});

  @override
  Widget build(BuildContext context) {
    const rows = [('Morning water', true, 12), ('Read 20 pages', false, 5), ('Evening walk', true, 3)];
    return _Card(
      child: Column(
        children: [
          const _Header(title: 'Today', meta: '2/3'),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: 2 / 3,
              minHeight: 4,
              backgroundColor: TideColors.shoal,
              color: TideColors.lantern,
            ),
          ),
          const SizedBox(height: 6),
          for (final (name, done, streak) in rows)
            SizedBox(
              height: 36,
              child: Row(
                children: [
                  _Check(done: done),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      name,
                      style: TideType.label.copyWith(
                        color: done ? TideColors.silt : TideColors.bone,
                      ),
                    ),
                  ),
                  const _Flame(size: 12),
                  const SizedBox(width: 4),
                  Text('$streak', style: TideType.gauge(13, color: TideColors.silt)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class SingleHabitStreakPreview extends StatelessWidget {
  const SingleHabitStreakPreview({super.key});

  @override
  Widget build(BuildContext context) {
    return _Card(
      width: 150,
      height: 150,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const _Flame(size: 32),
          const SizedBox(height: 4),
          Text('12', style: TideType.gauge(30, color: TideColors.bone)),
          Text('day streak', style: TideType.labelMuted),
          const SizedBox(height: 6),
          Text(
            'Morning water',
            style: TideType.label.copyWith(color: TideColors.lantern),
          ),
        ],
      ),
    );
  }
}

class TodayTasksPreview extends StatelessWidget {
  const TodayTasksPreview({super.key});

  @override
  Widget build(BuildContext context) {
    const rows = [('Pay rent', 'Yesterday', true), ('Call dentist', 'Today', false), ('Buy groceries', 'Today', false)];
    return _Card(
      child: Column(
        children: [
          _Header(title: 'Tasks', meta: '1 overdue', metaColor: TideColors.coral),
          const SizedBox(height: 6),
          for (final (title, due, overdue) in rows)
            SizedBox(
              height: 36,
              child: Row(
                children: [
                  _Check(done: false, overdue: overdue),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: TideType.label.copyWith(color: TideColors.bone),
                    ),
                  ),
                  Text(
                    due,
                    style: TideType.labelMuted.copyWith(
                      color: overdue ? TideColors.coral : TideColors.silt,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class QuickAddPreview extends StatelessWidget {
  const QuickAddPreview({super.key});

  @override
  Widget build(BuildContext context) {
    return _Card(
      width: 180,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: TideColors.lantern,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.add_rounded, color: TideColors.onLantern),
          ),
          const SizedBox(width: 10),
          Text('New habit', style: TideType.label.copyWith(color: TideColors.bone)),
        ],
      ),
    );
  }
}

class HeatmapPreview extends StatelessWidget {
  const HeatmapPreview({super.key});

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now().weekday;
    final days = WidgetPayload.heatmapWeeks * 7 - (7 - today);
    final random = math.Random(7);
    final series = [
      for (var i = 0; i < days; i++)
        switch (random.nextInt(10)) {
          0 => -1.0,
          1 || 2 => 0.0,
          _ => 1.0,
        },
    ];
    return _Card(
      child: Column(
        children: [
          _Header(
            title: 'Morning water',
            meta: '12',
            metaColor: TideColors.lantern,
            leading: const _Flame(size: 14),
          ),
          const SizedBox(height: 12),
          FittedBox(child: HeatmapExport(series: series)),
        ],
      ),
    );
  }
}

class HabitDashboardPreview extends StatelessWidget {
  const HabitDashboardPreview({super.key});

  @override
  Widget build(BuildContext context) {
    const rows = [
      ('Morning water', 12, [2, 2, 2, 2, 2, 2, 2]),
      ('Read 20 pages', 5, [1, 2, 2, 0, 2, 2, 3]),
      ('Evening walk', 3, [2, 1, 1, 2, 2, 2, 2]),
    ];
    return _Card(
      child: Column(
        children: [
          _Header(title: 'Streaks', meta: 'Best 12', metaColor: TideColors.lantern),
          const SizedBox(height: 6),
          for (final (name, streak, week) in rows)
            SizedBox(
              height: 36,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      name,
                      style: TideType.label.copyWith(color: TideColors.bone),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  for (final code in week) ...[
                    Container(
                      width: 7,
                      height: 14,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        color: switch (code) {
                          2 => TideColors.lantern,
                          1 => TideColors.shoal,
                          3 => Colors.transparent,
                          _ => TideColors.bone.withValues(alpha: 0.04),
                        },
                        border: code == 3
                            ? Border.all(color: TideColors.lantern, width: 1)
                            : null,
                      ),
                    ),
                    const SizedBox(width: 3),
                  ],
                  const SizedBox(width: 8),
                  const _Flame(size: 12),
                  const SizedBox(width: 4),
                  SizedBox(
                    width: 22,
                    child: Text(
                      '$streak',
                      textAlign: TextAlign.end,
                      style: TideType.gauge(14, color: TideColors.bone),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class WeeklyRecapPreview extends StatelessWidget {
  const WeeklyRecapPreview({super.key});

  @override
  Widget build(BuildContext context) {
    Widget stat(Widget lead, String value, String label, {Color? color}) => Row(
      children: [
        lead,
        const SizedBox(width: 6),
        Text(value, style: TideType.gauge(15, color: color ?? TideColors.bone)),
        const SizedBox(width: 6),
        Text(label, style: TideType.labelMuted),
      ],
    );

    return _Card(
      child: Column(
        children: [
          const _Header(title: 'This week', meta: 'Sep 8 – 14'),
          const SizedBox(height: 14),
          Row(
            children: [
              SizedBox(
                width: 64,
                height: 64,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox.expand(
                      child: CircularProgressIndicator(
                        value: 0.82,
                        strokeWidth: 5,
                        backgroundColor: TideColors.shoal,
                        color: TideColors.lantern,
                      ),
                    ),
                    Text('82%', style: TideType.gauge(16, color: TideColors.bone)),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    stat(const _Flame(size: 13), '12', 'best streak'),
                    const SizedBox(height: 8),
                    stat(
                      Icon(Icons.trending_up_rounded, size: 14, color: TideColors.lantern),
                      '+6%',
                      'vs last week',
                      color: TideColors.lantern,
                    ),
                    const SizedBox(height: 8),
                    stat(
                      Icon(Icons.check_rounded, size: 14, color: TideColors.silt),
                      '18/22',
                      'check-ins',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
