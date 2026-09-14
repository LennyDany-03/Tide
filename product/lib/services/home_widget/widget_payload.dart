import 'package:flutter/material.dart';

import '../../config/app_constants.dart';
import '../models/habit.dart';
import '../streak_calculator.dart';

/// The JSON shape written for each home-screen widget — deliberately smaller
/// than [HabitRows.snapshot]: a widget draws a handful of fields per habit,
/// never the whole row, and it never round-trips back into a [Habit]. The
/// Android side decodes this exact shape in `WidgetPayloadReader.kt`; the
/// two must be changed together.
abstract final class WidgetPayload {
  /// The row budget [widget_today_habits.xml] was built for. Free habits are
  /// already capped at this, via [AppConstants.freeHabitLimit] — this is
  /// never actually a truncation on the free plan.
  static const int maxTodayRows = AppConstants.freeHabitLimit;

  /// The row budget [widget_habit_dashboard.xml] was built for.
  static const int maxDashboardRows = 6;

  /// Today's due habits, for the free "Today's Habits" widget. A binary row
  /// carries its [HabitType] so the native side can decide whether a tap
  /// logs it outright or opens its detail (a quantity/duration row has no
  /// amount to guess from a tap).
  static Map<String, Object?> todayHabits(List<Habit> habits, {DateTime? asOf}) {
    final day = DateUtils.dateOnly(asOf ?? DateTime.now());
    final due = habits.where((h) => h.isDueOn(day)).take(maxTodayRows);
    return {
      'signedIn': true,
      'rows': [
        for (final h in due)
          {
            'id': h.id,
            'name': h.name,
            'type': h.type.name,
            'done': h.isCompleteOn(day) || h.isFrozenOn(day),
          },
      ],
    };
  }

  /// Every habit ranked by current streak, for the Pro "Habit Dashboard"
  /// widget. Carries [isPro] through unchanged — the native side, not this
  /// codec, decides whether to draw the locked placeholder or the rows, so a
  /// stale cached payload never mis-renders a lapsed Pro account as still
  /// unlocked past its own last write.
  static Map<String, Object?> habitDashboard(
    List<Habit> habits, {
    required bool isPro,
    DateTime? asOf,
  }) {
    final day = DateUtils.dateOnly(asOf ?? DateTime.now());
    final ranked = [...habits]..sort(
      (a, b) => StreakCalculator.currentStreak(
        b,
        asOf: day,
      ).compareTo(StreakCalculator.currentStreak(a, asOf: day)),
    );
    return {
      'signedIn': true,
      'isPro': isPro,
      'rows': [
        for (final h in ranked.take(maxDashboardRows))
          {
            'id': h.id,
            'name': h.name,
            'streak': StreakCalculator.currentStreak(h, asOf: day),
            'dueToday': h.isDueOn(day),
            'doneToday': h.isCompleteOn(day) || h.isFrozenOn(day),
          },
      ],
    };
  }

  /// What both widgets show when nobody is signed in, or the repository
  /// behind them is the in-memory demo one.
  static Map<String, Object?> signedOut() => const {'signedIn': false};
}
