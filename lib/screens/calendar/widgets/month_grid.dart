import 'package:flutter/material.dart';

import '../../../config/app_constants.dart';
import '../../../services/models/habit.dart';
import '../../../services/streak_calculator.dart';
import '../../../theme/tide_motion.dart';
import '../../../theme/tide_typography.dart';
import 'day_cell.dart';

/// A whole month of aggregate completion.
///
/// Always six weeks of cells, padded with the neighbouring months' days, so
/// paging between a 28-day February and a 31-day March does not change the
/// grid's height and make the page jump.
class MonthGrid extends StatelessWidget {
  const MonthGrid({
    super.key,
    required this.month,
    required this.habits,
    required this.onDayTapped,
  });

  final DateTime month;
  final List<Habit> habits;
  final ValueChanged<DateTime> onDayTapped;

  @override
  Widget build(BuildContext context) {
    final today = DateUtils.dateOnly(DateTime.now());
    final first = DateTime(month.year, month.month);
    final leading = first.weekday - 1;
    final gridStart = first.subtract(Duration(days: leading));

    // No panel around the grid. A month of cells is already a strongly
    // bounded shape; drawing a rounded rectangle around it adds an outline
    // nobody needed and pushes the cells inward for no reason.
    return Column(
      children: [
        Row(
          children: [
            for (final initial in AppConstants.weekdayInitials)
              Expanded(
                child: Center(
                  child: Text(initial, style: TideType.labelMuted),
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        for (var week = 0; week < 6; week++) ...[
          if (week > 0) const SizedBox(height: 6),
          Row(
            children: [
              for (var weekday = 0; weekday < 7; weekday++) ...[
                if (weekday > 0) const SizedBox(width: 6),
                Expanded(
                  child: _cell(
                    date: gridStart.add(Duration(days: week * 7 + weekday)),
                    index: week * 7 + weekday,
                    today: today,
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }

  Widget _cell({
    required DateTime date,
    required int index,
    required DateTime today,
  }) {
    final summary = StreakCalculator.daySummary(habits, date);
    final future = date.isAfter(today);

    return DayCell(
      key: ValueKey('${date.year}-${date.month}-${date.day}'),
      day: date.day,
      ratio: future ? 0 : summary.ratio,
      // Staggered across the grid, so the month ripples in reading order.
      delay: TideMotion.cellStep * index,
      outsideMonth: date.month != month.month,
      isToday: DateUtils.isSameDay(date, today),
      isFuture: future,
      onTap: () => onDayTapped(date),
    );
  }
}
