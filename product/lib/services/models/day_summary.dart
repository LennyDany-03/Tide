import 'package:flutter/foundation.dart';

import 'habit.dart';

/// Aggregate completion for one calendar day across every scheduled habit.
///
/// The calendar grid, the Home hero stat and the Insights trend all read
/// this, so a day's fill level means exactly the same thing everywhere.
@immutable
class DaySummary {
  const DaySummary({
    required this.date,
    required this.scheduled,
    required this.completed,
    required this.frozen,
  });

  final DateTime date;

  /// How many habits were scheduled on this day.
  final int scheduled;

  /// How many of them were completed.
  final int completed;

  /// How many were covered by a freeze rather than logged.
  final int frozen;

  /// 0..1 — the value that drives every intensity ramp.
  double get ratio => scheduled == 0 ? 0 : completed / scheduled;

  bool get isFullyLogged => scheduled > 0 && completed >= scheduled;

  bool get isEmpty => scheduled == 0;
}

/// One habit's state on a given day, for the calendar's day-breakdown sheet.
@immutable
class HabitDayEntry {
  const HabitDayEntry({
    required this.habit,
    required this.amount,
    required this.complete,
    required this.frozen,
  });

  final Habit habit;
  final num amount;
  final bool complete;
  final bool frozen;
}
