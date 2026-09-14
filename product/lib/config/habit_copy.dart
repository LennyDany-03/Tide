import 'package:flutter/material.dart' show DateUtils;

import '../services/models/habit.dart';
import 'app_constants.dart';

/// The short sentences that describe a habit's shape and its pause, said the
/// same way on the long-press sheet, Habit detail and Today's paused shelf.
abstract final class HabitCopy {
  /// "Every day", "Weekdays", "Weekends", or "Mon · Wed · Fri".
  static String schedule(Habit habit) {
    final days = habit.days.toList()..sort();
    if (days.length == 7) return 'Every day';
    if (_same(days, const [1, 2, 3, 4, 5])) return 'Weekdays';
    if (_same(days, const [6, 7])) return 'Weekends';
    return days
        .map((d) => AppConstants.weekdayNames[d - 1].substring(0, 3))
        .join(' · ');
  }

  /// "today", "tomorrow", "yesterday", or "12 Sep".
  static String day(DateTime date, {DateTime? asOf}) {
    final today = DateUtils.dateOnly(asOf ?? DateTime.now());
    final target = DateUtils.dateOnly(date);
    final offset = target.difference(today).inDays;
    if (offset == 0) return 'today';
    if (offset == 1) return 'tomorrow';
    if (offset == -1) return 'yesterday';
    final month = AppConstants.monthNames[target.month - 1].substring(0, 3);
    return '${target.day} $month';
  }

  /// "Paused since 12 Sep", or "Paused from tomorrow" for a pause that was
  /// set after today was already marked.
  static String pausedSince(Habit habit, {DateTime? asOf}) {
    final since = habit.pausedSince;
    if (since == null) return '';
    final today = DateUtils.dateOnly(asOf ?? DateTime.now());
    return since.isAfter(today)
        ? 'Paused from ${day(since, asOf: asOf)}'
        : 'Paused since ${day(since, asOf: asOf)}';
  }

  /// What a pause does, in one line, for the place the verb is offered.
  static const pauseExplainer =
      'Leaves Today and holds your streak. Paused days are not misses.';

  static bool _same(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
