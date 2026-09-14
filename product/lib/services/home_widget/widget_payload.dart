import 'package:flutter/material.dart';

import '../../config/app_constants.dart';
import '../models/habit.dart';
import '../streak_calculator.dart';
import '../tasks/task.dart';

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

  /// The row budget [widget_today_tasks.xml] was built for.
  static const int maxTaskRows = 5;

  /// How many days [heatmapSeries] covers — five weeks, so a 7-wide grid
  /// comes out even.
  static const int heatmapDays = 35;

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

  /// The pinned habit's name and streak, for the free "Single Habit Streak"
  /// widget. `null` when nothing is pinned yet, or the pinned id no longer
  /// resolves to a habit (an account switch, or the habit was deleted) —
  /// both read as "not configured" rather than an error.
  static Map<String, Object?> singleHabitStreak(Habit? habit, {DateTime? asOf}) {
    if (habit == null) return const {'signedIn': true, 'configured': false};
    final day = DateUtils.dateOnly(asOf ?? DateTime.now());
    return {
      'signedIn': true,
      'configured': true,
      'id': habit.id,
      'name': habit.name,
      'type': habit.type.name,
      'streak': StreakCalculator.currentStreak(habit, asOf: day),
      'doneToday': habit.isCompleteOn(day) || habit.isFrozenOn(day),
    };
  }

  /// Due-or-overdue, not-yet-completed tasks, for the free "Today's Tasks"
  /// widget — soonest due date first, undated tasks excluded (there is
  /// nothing to call overdue about one).
  static Map<String, Object?> todayTasks(List<Task> tasks, {DateTime? asOf}) {
    final today = DateUtils.dateOnly(asOf ?? DateTime.now());
    final due =
        tasks.where((t) {
          final due = t.dueDate;
          return !t.isCompleted &&
              !t.isArchived &&
              due != null &&
              !due.isAfter(today);
        }).toList()..sort((a, b) => a.dueDate!.compareTo(b.dueDate!));
    return {
      'signedIn': true,
      'rows': [
        for (final t in due.take(maxTaskRows))
          {
            'id': t.id,
            'title': t.title,
            'overdue': t.dueDate!.isBefore(today),
          },
      ],
    };
  }

  /// The pinned habit's last [heatmapDays] days, one ratio per day (-1 for a
  /// rest day, 0..1 for how much of that day's schedule was kept) — the
  /// series [HeatmapExport] paints into the image the Pro "Habit Heatmap"
  /// widget reads. Kept separate from [heatmapMeta] because this is a
  /// rendered image, not JSON the native side parses.
  static List<double> heatmapSeries(Habit habit, {DateTime? asOf}) =>
      StreakCalculator.dailySeries(
        [habit],
        days: heatmapDays,
        asOf: asOf ?? DateTime.now(),
      );

  /// What decides which layout the Habit Heatmap widget draws: [isPro]
  /// picks locked vs unlocked exactly like [habitDashboard], and
  /// [configured] separates "Pro, but no habit pinned yet" from an actual
  /// rendered heatmap.
  static Map<String, Object?> heatmapMeta({
    required bool isPro,
    required bool configured,
  }) => {'signedIn': true, 'isPro': isPro, 'configured': configured};

  /// This week's completion rate and the longest streak currently running
  /// across every habit, for the Pro "Weekly Recap" widget — the same two
  /// figures [TideStore.weeklyRate] and [StreakCalculator.bestStreakAcross]
  /// surface in the app, not a separate notion of "the recap".
  static Map<String, Object?> weeklyRecap(
    List<Habit> habits, {
    required bool isPro,
    DateTime? asOf,
  }) => {
    'signedIn': true,
    'isPro': isPro,
    'weekPercent': (StreakCalculator.weeklyRate(habits, asOf: asOf) * 100)
        .round(),
    'bestStreak': StreakCalculator.bestStreakAcross(habits, asOf: asOf),
  };

  /// What every widget shows when nobody is signed in, or the repository
  /// behind them is the in-memory demo one.
  static Map<String, Object?> signedOut() => const {'signedIn': false};
}
