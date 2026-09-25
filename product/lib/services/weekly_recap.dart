import 'package:flutter/material.dart';

import 'models/habit.dart';
import 'streak_calculator.dart';

/// The week in one line — the sentence the Settings → Weekly recap switch
/// promises ("Sunday evening, the week in one line") and the numbers the
/// home-screen recap widget draws are the same figures, so the two cannot
/// tell the same week two different stories.
///
/// Pure like the rest of the recap: habits in, sentence out, no widgets and
/// no clock beyond the [asOf] a caller pins for a test.
abstract final class WeeklyRecapLine {
  static String forWeek(List<Habit> habits, {DateTime? asOf}) {
    final today = DateUtils.dateOnly(asOf ?? DateTime.now());
    final monday = DateUtils.addDaysToDate(today, 1 - today.weekday);

    var checkIns = 0, scheduled = 0;
    for (
      var day = monday;
      !day.isAfter(today);
      day = DateUtils.addDaysToDate(day, 1)
    ) {
      final summary = StreakCalculator.daySummary(habits, day);
      checkIns += summary.completed;
      scheduled += summary.scheduled;
    }

    if (scheduled == 0) {
      return 'Nothing on the calendar yet this week — mark a few '
          'days and the recap writes itself.';
    }

    final percent = (StreakCalculator.weeklyRate(habits, asOf: today) * 100)
        .round();
    final streak = StreakCalculator.bestStreakAcross(
      habits.where((h) => !h.paused).toList(),
      asOf: today,
    );
    final streakClause = streak > 0
        ? ', best streak $streak ${streak == 1 ? 'day' : 'days'}'
        : '';
    return '$percent% of the week kept — $checkIns of $scheduled '
        'check-ins$streakClause.';
  }
}