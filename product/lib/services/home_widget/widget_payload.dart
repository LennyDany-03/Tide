import 'package:flutter/material.dart';

import '../models/habit.dart';
import '../streak_calculator.dart';
import '../tasks/task.dart';

/// The JSON each home-screen widget draws from — deliberately smaller than
/// [HabitRows.snapshot]: a widget draws a handful of fields per habit, never
/// the whole row, and it never round-trips back into a [Habit]. The Android
/// side decodes these exact shapes in `WidgetPayloadReader.kt`; the two must
/// be changed together.
abstract final class WidgetPayload {
  /// The most rows any list widget carries. The lists scroll, so this is a
  /// payload bound, not what fits on screen — past it the widget is not
  /// where anyone should be working through their day.
  static const int maxListRows = 30;

  /// The most weeks the Habit Heatmap can draw — a year. The native side
  /// sizes its cells to the widget's height and shows as many of the newest
  /// weeks as its width fits, so a wide widget is never left half empty.
  static const int heatmapWeeks = 53;

  /// Today's due habits, in the app's own order, and how many are kept.
  /// [total] counts every due habit, not just the rows sent, so a short
  /// widget can say "+2 more" truthfully.
  static Map<String, Object?> todayHabits(List<Habit> habits, {DateTime? asOf}) {
    final day = DateUtils.dateOnly(asOf ?? DateTime.now());
    final due = habits.where((h) => h.isDueOn(day)).toList();
    return {
      'signedIn': true,
      'done': due.where((h) => h.countsTowardStreak(day)).length,
      'total': due.length,
      'rows': [
        for (final h in due.take(maxListRows))
          {
            'id': h.id,
            'name': h.name,
            'type': h.type.name,
            'done': h.countsTowardStreak(day),
            'streak': StreakCalculator.currentStreak(h, asOf: day),
          },
      ],
    };
  }

  /// Active habits ranked by current streak, each with its last seven days.
  /// Carries [isPro] through — the native side draws the lock, so a cached
  /// payload can never show a lapsed plan as unlocked.
  static Map<String, Object?> habitDashboard(
    List<Habit> habits, {
    required bool isPro,
    DateTime? asOf,
  }) {
    final day = DateUtils.dateOnly(asOf ?? DateTime.now());
    final streaks = {
      for (final h in habits.where((h) => !h.paused))
        h: StreakCalculator.currentStreak(h, asOf: day),
    };
    final ranked = streaks.keys.toList()
      ..sort((a, b) => streaks[b]!.compareTo(streaks[a]!));
    return {
      'signedIn': true,
      'isPro': isPro,
      'best': ranked.isEmpty ? 0 : streaks[ranked.first],
      'rows': [
        for (final h in ranked.take(maxListRows))
          {
            'id': h.id,
            'name': h.name,
            'streak': streaks[h],
            'week': weekCodes(h, asOf: day),
          },
      ],
    };
  }

  /// One code per day for the last seven days, oldest first, for the
  /// dashboard's day strip: 2 kept, 1 missed, 0 nothing asked (a rest day,
  /// or before the habit existed), 3 today and still open. Today is its own
  /// code because an unlogged today is not a miss yet.
  static List<int> weekCodes(Habit habit, {DateTime? asOf}) {
    final today = DateUtils.dateOnly(asOf ?? DateTime.now());
    final created = DateUtils.dateOnly(habit.createdAt);
    return [
      for (var back = 6; back >= 0; back--)
        () {
          final day = DateUtils.addDaysToDate(today, -back);
          if (day.isBefore(created) || !habit.isDueOn(day)) return 0;
          if (habit.countsTowardStreak(day)) return 2;
          return back == 0 ? 3 : 1;
        }(),
    ];
  }

  /// One placed Streak widget's habit. `null` — nothing chosen yet, or the
  /// chosen habit is gone — reads as "not configured", and the widget asks.
  static Map<String, Object?> singleHabitStreak(Habit? habit, {DateTime? asOf}) {
    if (habit == null) {
      return const {'signedIn': true, 'configured': false};
    }
    final day = DateUtils.dateOnly(asOf ?? DateTime.now());
    return {
      'configured': true,
      'id': habit.id,
      'name': habit.name,
      'type': habit.type.name,
      'streak': StreakCalculator.currentStreak(habit, asOf: day),
      'doneToday': habit.countsTowardStreak(day),
      'dueToday': habit.isDueOn(day),
    };
  }

  /// One placed Heatmap widget: its header, and [heatmapSeries] as `series`
  /// for `WidgetHeatmap.kt` to draw at the widget's own size. Ratios are
  /// rounded to two places — the grid has five tiers, and a year of full
  /// doubles is most of the payload.
  static Map<String, Object?> heatmapHeader(Habit? habit, {DateTime? asOf}) {
    if (habit == null) {
      return const {'signedIn': true, 'configured': false};
    }
    final day = DateUtils.dateOnly(asOf ?? DateTime.now());
    return {
      'configured': true,
      'id': habit.id,
      'type': habit.type.name,
      'name': habit.name,
      'streak': StreakCalculator.currentStreak(habit, asOf: day),
      'series': [
        for (final t in heatmapSeries(habit, asOf: day))
          t < 0 ? -1.0 : (t * 100).round() / 100,
      ],
    };
  }

  /// [heatmapWeeks] whole Monday-to-Sunday columns ending with this week,
  /// as one ratio per day up to today (-1 rest day, 0..1 kept). The days of
  /// this week still to come are left off the end rather than sent as
  /// misses; the grid draws them empty.
  static List<double> heatmapSeries(Habit habit, {DateTime? asOf}) {
    final today = DateUtils.dateOnly(asOf ?? DateTime.now());
    return StreakCalculator.dailySeries(
      [habit],
      days: heatmapWeeks * 7 - (7 - today.weekday),
      asOf: today,
    );
  }

  /// Due-or-overdue, open tasks, soonest due first, with the label each row
  /// shows on its right. Undated tasks are left out — nothing is late about
  /// one.
  static Map<String, Object?> todayTasks(List<Task> tasks, {DateTime? asOf}) {
    final today = DateUtils.dateOnly(asOf ?? DateTime.now());
    final due =
        tasks.where((t) {
          final date = t.dueDate;
          return !t.isCompleted &&
              !t.isArchived &&
              date != null &&
              !date.isAfter(today);
        }).toList()..sort((a, b) => a.dueDate!.compareTo(b.dueDate!));
    return {
      'signedIn': true,
      'overdue': due.where((t) => t.dueDate!.isBefore(today)).length,
      'total': due.length,
      'rows': [
        for (final t in due.take(maxListRows))
          {
            'id': t.id,
            'title': t.title,
            'overdue': t.dueDate!.isBefore(today),
            'due': dueLabel(t.dueDate!, asOf: today),
          },
      ],
    };
  }

  static String dueLabel(DateTime due, {DateTime? asOf}) {
    final today = DateUtils.dateOnly(asOf ?? DateTime.now());
    final late = DateUtils.dateOnly(due).difference(today).inDays.abs();
    return switch (late) {
      0 => 'Today',
      1 => 'Yesterday',
      _ => '${late}d late',
    };
  }

  /// This week so far: the rate, last week's rate for comparison, the best
  /// streak running, and the raw check-ins behind the rate — the same
  /// figures Insights shows, not a separate notion of "the recap".
  static Map<String, Object?> weeklyRecap(
    List<Habit> habits, {
    required bool isPro,
    DateTime? asOf,
  }) {
    final today = DateUtils.dateOnly(asOf ?? DateTime.now());
    final monday = DateUtils.addDaysToDate(today, 1 - today.weekday);
    var checkIns = 0, scheduled = 0;
    final days = <double>[];
    for (var day = monday; !day.isAfter(today); day = DateUtils.addDaysToDate(day, 1)) {
      final summary = StreakCalculator.daySummary(habits, day);
      checkIns += summary.completed;
      scheduled += summary.scheduled;
      days.add(
        summary.scheduled == 0 ? -1.0 : (summary.ratio * 100).round() / 100,
      );
    }
    return {
      'signedIn': true,
      'isPro': isPro,
      'weekPercent': (StreakCalculator.weeklyRate(habits, asOf: today) * 100)
          .round(),
      'lastWeekPercent':
          (StreakCalculator.weeklyRate(
                    habits,
                    asOf: DateUtils.addDaysToDate(today, -7),
                  ) *
                  100)
              .round(),
      'bestStreak': StreakCalculator.bestStreakAcross(
        habits.where((h) => !h.paused).toList(),
        asOf: today,
      ),
      'checkIns': checkIns,
      'scheduled': scheduled,
      'range': weekRange(monday),
      // Monday through today, for the day strip: -1 nothing asked, else the
      // share kept. The days still to come are left off, not sent as misses.
      'days': days,
    };
  }

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  /// "Sep 8 – 14", or "Sep 29 – Oct 5" across a month end.
  static String weekRange(DateTime monday) {
    final sunday = DateUtils.addDaysToDate(monday, 6);
    final start = '${_months[monday.month - 1]} ${monday.day}';
    final end = sunday.month == monday.month
        ? '${sunday.day}'
        : '${_months[sunday.month - 1]} ${sunday.day}';
    return '$start – $end';
  }

  /// What every account-bound widget shows with nobody signed in, or with
  /// the in-memory demo repository behind the app.
  static Map<String, Object?> signedOut() => const {'signedIn': false};
}
