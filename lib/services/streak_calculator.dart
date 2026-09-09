import 'package:flutter/material.dart' show DateUtils;

import 'models/day_summary.dart';
import 'models/habit.dart';

/// All the arithmetic behind the numbers on screen.
///
/// Deliberately pure: no widgets, no store, no state. Every readout in the
/// app — streaks, rates, heatmap intensities, trend series — resolves
/// through here, so two screens can never disagree about the same figure.
abstract final class StreakCalculator {
  /// Days that were neither logged nor frozen break a streak. A scheduled
  /// day that simply has not happened yet (today, before you log it) does
  /// not — otherwise every streak would read as broken each morning.
  static int currentStreak(Habit habit, {DateTime? asOf}) {
    final today = DateUtils.dateOnly(asOf ?? DateTime.now());
    var cursor = today;

    // Today gets a grace period: if it is scheduled but not yet logged,
    // start counting from yesterday instead of calling the streak broken.
    if (habit.isScheduledOn(cursor) && !habit.countsTowardStreak(cursor)) {
      cursor = cursor.subtract(const Duration(days: 1));
    }

    final floor = DateUtils.dateOnly(habit.createdAt);
    var streak = 0;

    while (!cursor.isBefore(floor)) {
      if (habit.isScheduledOn(cursor)) {
        if (!habit.countsTowardStreak(cursor)) break;
        streak++;
      }
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  /// The longest run of consecutive scheduled days ever completed.
  static int bestStreak(Habit habit, {DateTime? asOf}) {
    final end = DateUtils.dateOnly(asOf ?? DateTime.now());
    var cursor = DateUtils.dateOnly(habit.createdAt);
    var best = 0;
    var run = 0;

    while (!cursor.isAfter(end)) {
      if (habit.isScheduledOn(cursor)) {
        if (habit.countsTowardStreak(cursor)) {
          run++;
          if (run > best) best = run;
        } else if (cursor != end) {
          // An unlogged today is still in play, so it does not end the run.
          run = 0;
        }
      }
      cursor = cursor.add(const Duration(days: 1));
    }
    return best;
  }

  /// Share of scheduled days completed over the last [days] days.
  static double completionRate(Habit habit, {int days = 30, DateTime? asOf}) {
    final end = DateUtils.dateOnly(asOf ?? DateTime.now());
    final start = end.subtract(Duration(days: days - 1));
    final floor = DateUtils.dateOnly(habit.createdAt);

    var scheduled = 0;
    var done = 0;
    var cursor = start.isBefore(floor) ? floor : start;

    while (!cursor.isAfter(end)) {
      if (habit.isScheduledOn(cursor)) {
        scheduled++;
        if (habit.countsTowardStreak(cursor)) done++;
      }
      cursor = cursor.add(const Duration(days: 1));
    }
    return scheduled == 0 ? 0 : done / scheduled;
  }

  /// Aggregate completion for one day across a set of habits.
  static DaySummary daySummary(List<Habit> habits, DateTime date) {
    final day = DateUtils.dateOnly(date);
    var scheduled = 0;
    var completed = 0;
    var frozen = 0;

    for (final habit in habits) {
      if (habit.paused) continue;
      if (DateUtils.dateOnly(habit.createdAt).isAfter(day)) continue;
      if (!habit.isScheduledOn(day)) continue;

      scheduled++;
      if (habit.isFrozenOn(day)) {
        frozen++;
        completed++;
      } else if (habit.isCompleteOn(day)) {
        completed++;
      }
    }
    return DaySummary(
      date: day,
      scheduled: scheduled,
      completed: completed,
      frozen: frozen,
    );
  }

  /// Per-habit breakdown for the calendar day sheet.
  static List<HabitDayEntry> dayBreakdown(List<Habit> habits, DateTime date) {
    final day = DateUtils.dateOnly(date);
    return habits
        .where((h) => !h.paused && h.isScheduledOn(day))
        .map(
          (h) => HabitDayEntry(
            habit: h,
            amount: h.amountOn(day),
            complete: h.isCompleteOn(day),
            frozen: h.isFrozenOn(day),
          ),
        )
        .toList();
  }

  /// Completion rate across all habits for the week containing [asOf],
  /// counting only days up to and including that date.
  static double weeklyRate(List<Habit> habits, {DateTime? asOf}) {
    final today = DateUtils.dateOnly(asOf ?? DateTime.now());
    final monday = today.subtract(Duration(days: today.weekday - 1));

    var scheduled = 0;
    var completed = 0;
    for (var i = 0; i < 7; i++) {
      final day = monday.add(Duration(days: i));
      if (day.isAfter(today)) break;
      final summary = daySummary(habits, day);
      scheduled += summary.scheduled;
      completed += summary.completed;
    }
    return scheduled == 0 ? 0 : completed / scheduled;
  }

  /// One ratio per day for the last [days] days, oldest first, ending on
  /// [asOf] — the series behind History's year grid.
  ///
  /// Days with nothing scheduled come back as -1 rather than 0, because a
  /// grid has to be able to tell "nothing was asked of you" from "you were
  /// asked and did not". Zero is a miss; -1 is a rest day.
  static List<double> dailySeries(
    List<Habit> habits, {
    int days = 371,
    DateTime? asOf,
  }) {
    final today = DateUtils.dateOnly(asOf ?? DateTime.now());
    return List<double>.generate(days, (index) {
      final day = today.subtract(Duration(days: days - 1 - index));
      final summary = daySummary(habits, day);
      return summary.scheduled == 0 ? -1 : summary.ratio;
    });
  }

  /// The longest run of fully-logged days inside [month], and how many of
  /// its elapsed days were full.
  static ({int full, int elapsed, double carried, int longest}) monthShape(
    List<Habit> habits,
    DateTime month, {
    DateTime? asOf,
  }) {
    final today = DateUtils.dateOnly(asOf ?? DateTime.now());
    final days = DateUtils.getDaysInMonth(month.year, month.month);

    var elapsed = 0;
    var full = 0;
    var carried = 0.0;
    var run = 0;
    var longest = 0;

    for (var day = 1; day <= days; day++) {
      final date = DateTime(month.year, month.month, day);
      if (date.isAfter(today)) break;
      elapsed++;
      final ratio = daySummary(habits, date).ratio;
      carried += ratio;
      if (ratio >= 1) {
        full++;
        run++;
        if (run > longest) longest = run;
      } else {
        run = 0;
      }
    }

    return (full: full, elapsed: elapsed, carried: carried, longest: longest);
  }

  /// Weekly completion rates for the last [weeks] weeks, oldest first —
  /// the series behind the Insights eight-week chart.
  static List<double> weeklySeries(
    List<Habit> habits, {
    int weeks = 8,
    DateTime? asOf,
  }) {
    final today = DateUtils.dateOnly(asOf ?? DateTime.now());
    final thisMonday = today.subtract(Duration(days: today.weekday - 1));

    return List<double>.generate(weeks, (index) {
      final monday = thisMonday.subtract(
        Duration(days: 7 * (weeks - 1 - index)),
      );
      var scheduled = 0;
      var completed = 0;
      for (var i = 0; i < 7; i++) {
        final day = monday.add(Duration(days: i));
        if (day.isAfter(today)) break;
        final summary = daySummary(habits, day);
        scheduled += summary.scheduled;
        completed += summary.completed;
      }
      return scheduled == 0 ? 0 : completed / scheduled;
    });
  }

  /// A single habit rolling completion rate, one point per week — the
  /// completion-trend line on Habit detail.
  static List<double> habitTrend(Habit habit, {int weeks = 8, DateTime? asOf}) {
    final today = DateUtils.dateOnly(asOf ?? DateTime.now());
    return List<double>.generate(weeks, (index) {
      final end = today.subtract(Duration(days: 7 * (weeks - 1 - index)));
      return completionRate(habit, days: 14, asOf: end);
    });
  }

  /// Completion rate per weekday (index 0 = Monday), across [days] days
  /// back. Drives the best/worst day callouts on Insights.
  static List<double> weekdayRates(
    List<Habit> habits, {
    int days = 56,
    DateTime? asOf,
  }) {
    final today = DateUtils.dateOnly(asOf ?? DateTime.now());
    final scheduled = List<int>.filled(7, 0);
    final completed = List<int>.filled(7, 0);

    for (var i = 0; i < days; i++) {
      final day = today.subtract(Duration(days: i));
      final summary = daySummary(habits, day);
      if (summary.scheduled == 0) continue;
      scheduled[day.weekday - 1] += summary.scheduled;
      completed[day.weekday - 1] += summary.completed;
    }

    return List<double>.generate(
      7,
      (i) => scheduled[i] == 0 ? 0 : completed[i] / scheduled[i],
    );
  }

  /// Total freezes spent across every habit in the last [days] days.
  static int freezesSpent(List<Habit> habits, {int days = 30, DateTime? asOf}) {
    final today = DateUtils.dateOnly(asOf ?? DateTime.now());
    final start = today.subtract(Duration(days: days - 1));
    var count = 0;
    for (final habit in habits) {
      for (final day in habit.frozenDays) {
        if (!day.isBefore(start) && !day.isAfter(today)) count++;
      }
    }
    return count;
  }

  /// The longest streak any habit has ever reached — the best-streak figure
  /// in the Home hero stat.
  static int bestStreakAcross(List<Habit> habits, {DateTime? asOf}) {
    var best = 0;
    for (final habit in habits) {
      final value = bestStreak(habit, asOf: asOf);
      if (value > best) best = value;
    }
    return best;
  }

  /// Consecutive fully-logged days with no freeze spent — the basis for the
  /// no-freezes milestone.
  static int cleanStreak(List<Habit> habits, {DateTime? asOf}) {
    final today = DateUtils.dateOnly(asOf ?? DateTime.now());
    var cursor = today;
    var clean = 0;
    var guard = 0;

    while (guard++ < 400) {
      final summary = daySummary(habits, cursor);
      if (summary.scheduled == 0) {
        cursor = cursor.subtract(const Duration(days: 1));
        continue;
      }
      final usedFreeze = summary.frozen > 0;
      final allDone = summary.completed >= summary.scheduled;
      final isToday = cursor == today;

      if (usedFreeze) break;
      if (!allDone && !isToday) break;
      if (allDone) clean++;

      cursor = cursor.subtract(const Duration(days: 1));
    }
    return clean;
  }
}
