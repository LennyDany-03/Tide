import 'package:flutter/material.dart';

import '../../../config/app_constants.dart';
import '../../../services/models/habit.dart';
import '../../../theme/tide_colors.dart';
import '../../../theme/tide_motion.dart';
import '../../../theme/tide_typography.dart';

/// One month of a single habit, as intensity of lantern.
///
/// Fixed-size cells, left-aligned, rather than seven columns stretched
/// across the page. Stretching made each square about 46 logical pixels, and
/// a month of empty 46px squares with no dates in them is a large dark grid
/// that dominates a screen it is only a supporting figure on. At this size
/// it reads as what it is — a small multiple you take in at a glance.
///
/// Cells fill in staggered by day rather than all at once, so the month reads
/// as filling the way it was actually lived: a ripple spreading across the
/// grid rather than a table being painted.
class MonthHeatmap extends StatelessWidget {
  const MonthHeatmap({super.key, required this.habit, required this.month});

  final Habit habit;
  final DateTime month;

  static const double _cellSize = 30;
  static const double _gap = 6;

  int get _daysInMonth => DateUtils.getDaysInMonth(month.year, month.month);

  /// Share of *scheduled* days in this month that were completed — the
  /// figure quoted in the card header.
  double get _rate {
    var scheduled = 0;
    var done = 0;
    final today = DateUtils.dateOnly(DateTime.now());

    for (var day = 1; day <= _daysInMonth; day++) {
      final date = DateTime(month.year, month.month, day);
      if (date.isAfter(today)) break;
      if (!habit.isScheduledOn(date)) continue;
      scheduled++;
      if (habit.countsTowardStreak(date)) done++;
    }
    return scheduled == 0 ? 0 : done / scheduled;
  }

  @override
  Widget build(BuildContext context) {
    final today = DateUtils.dateOnly(DateTime.now());
    final first = DateTime(month.year, month.month);

    // Monday-first leading blanks, so a month always lines up under the
    // same weekday columns as the calendar screen.
    final leading = first.weekday - 1;
    final cellCount = leading + _daysInMonth;
    final rows = (cellCount / 7).ceil();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              AppConstants.monthNames[month.month - 1],
              style: TideType.heading,
            ),
            const Spacer(),
            Text(
              '${(_rate * 100).round()}% of days marked',
              style: TideType.labelMuted,
            ),
          ],
        ),
        const SizedBox(height: 18),
        for (var row = 0; row < rows; row++) ...[
          if (row > 0) const SizedBox(height: _gap),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var col = 0; col < 7; col++) ...[
                if (col > 0) const SizedBox(width: _gap),
                _cell(index: row * 7 + col, leading: leading, today: today),
              ],
            ],
          ),
        ],
      ],
    );
  }

  Widget _cell({
    required int index,
    required int leading,
    required DateTime today,
  }) {
    final dayNumber = index - leading + 1;

    if (dayNumber < 1 || dayNumber > _daysInMonth) {
      return const SizedBox(width: _cellSize, height: _cellSize);
    }

    final date = DateTime(month.year, month.month, dayNumber);
    final future = date.isAfter(today);
    final scheduled = habit.isScheduledOn(date);

    final frozen = !future && scheduled && habit.isFrozenOn(date);
    final level = future || !scheduled
        ? 0.0
        : frozen
        ? 0.45
        : habit.progressOn(date);

    return _HeatCell(
      size: _cellSize,
      level: level,
      // A frozen day sits at the same level as a half-logged one, so the
      // hue is the only thing that separates them.
      frozen: frozen,
      // Staggering by day index is what makes the fill sweep across the
      // month instead of appearing all at once.
      delay: TideMotion.cellStep * index,
      dimmed: future,
      isToday: DateUtils.isSameDay(date, today),
    );
  }
}

class _HeatCell extends StatelessWidget {
  const _HeatCell({
    required this.size,
    required this.level,
    required this.delay,
    required this.dimmed,
    required this.frozen,
    required this.isToday,
  });

  final double size;
  final double level;
  final Duration delay;
  final bool dimmed;
  final bool frozen;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(end: 1),
        duration: TideMotion.cellFill + delay,
        curve: Interval(
          // Converting the delay into a curve interval keeps every cell on
          // one animation clock rather than scheduling dozens of timers.
          (delay.inMilliseconds /
                  (TideMotion.cellFill.inMilliseconds + delay.inMilliseconds))
              .clamp(0.0, 0.85),
          1,
          curve: Curves.easeOutCubic,
        ),
        builder: (context, t, _) {
          // An unlogged day is a faint ink wash, matching the calendar's
          // empty cell. Anything darker than the page reads as a hole.
          final empty = TideColors.bone.withValues(alpha: 0.06);
          final target = dimmed
              ? empty.withValues(alpha: 0.03)
              : TideColors.intensity(
                  level,
                  hue: frozen ? TideColors.frost : TideColors.lantern,
                );

          return Transform.scale(
            scale: 0.82 + 0.18 * t,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Color.lerp(empty, target, t),
                borderRadius: BorderRadius.circular(8),
                border: isToday
                    ? Border.all(
                        color: TideColors.lantern.withValues(alpha: 0.7),
                        width: 1.4,
                      )
                    : null,
              ),
            ),
          );
        },
      ),
    );
  }
}
