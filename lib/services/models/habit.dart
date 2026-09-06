import 'package:flutter/material.dart';

import 'tide_glyph.dart';

/// What "done" means for a habit, and therefore which gesture logs it.
///
/// Binary habits are swiped on the row itself; quantity and duration habits
/// open a sheet where the count is held out one unit at a time.
enum HabitType {
  binary,
  quantity,
  duration;

  String get label => switch (this) {
    HabitType.binary => 'Yes / no',
    HabitType.quantity => 'Quantity',
    HabitType.duration => 'Duration',
  };

  /// The one-line hint shown under a habit name on Home.
  String get gestureHint => switch (this) {
    HabitType.binary => 'swipe right to log',
    HabitType.quantity => 'tap to count up',
    HabitType.duration => 'tap to count up',
  };

  bool get isHeld => this != HabitType.binary;
}

/// A single habit and its complete log history.
///
/// Immutable — every mutation goes through [copyWith] so the store can hand
/// out values without callers being able to reach in and change them.
@immutable
class Habit {
  const Habit({
    required this.id,
    required this.name,
    required this.glyph,
    required this.type,
    required this.createdAt,
    this.target = 1,
    this.unit = '',
    this.days = const {1, 2, 3, 4, 5, 6, 7},
    this.reminderEnabled = false,
    this.reminderTime = const TimeOfDay(hour: 8, minute: 0),
    this.freezeAllowance = 2,
    this.freezesRemaining = 2,
    this.paused = false,
    this.logs = const {},
    this.frozenDays = const {},
  });

  final String id;
  final String name;
  final TideGlyph glyph;
  final HabitType type;
  final DateTime createdAt;

  /// 1 for binary; the goal amount for quantity (8 glasses) and duration
  /// (30 minutes).
  final num target;

  /// '' for binary, otherwise 'glasses', 'min', 'pages'…
  final String unit;

  /// Scheduled weekdays, using [DateTime.monday]..[DateTime.sunday].
  final Set<int> days;

  final bool reminderEnabled;
  final TimeOfDay reminderTime;

  /// How many freezes this habit is allowed, and how many are left. A freeze
  /// skips a day without breaking the loop.
  final int freezeAllowance;
  final int freezesRemaining;

  final bool paused;

  /// Date (normalised to midnight) → amount logged that day.
  final Map<DateTime, num> logs;

  /// Days where a freeze was spent rather than the habit being logged.
  final Set<DateTime> frozenDays;

  // --- Queries ----------------------------------------------------------

  bool isScheduledOn(DateTime date) => days.contains(date.weekday);

  num amountOn(DateTime date) => logs[DateUtils.dateOnly(date)] ?? 0;

  bool isFrozenOn(DateTime date) =>
      frozenDays.contains(DateUtils.dateOnly(date));

  /// 0..1 progress toward the day's target.
  double progressOn(DateTime date) {
    if (target <= 0) return 0;
    return (amountOn(date) / target).clamp(0.0, 1.0).toDouble();
  }

  bool isCompleteOn(DateTime date) => amountOn(date) >= target;

  /// A day counts toward the streak if it was completed *or* frozen.
  bool countsTowardStreak(DateTime date) =>
      isCompleteOn(date) || isFrozenOn(date);

  /// "5/8" for quantity, "23 min / 30 min" for duration, '' for binary.
  String get targetLabel {
    return switch (type) {
      HabitType.binary => '',
      HabitType.quantity => '$target${unit.isEmpty ? '' : ' $unit'}',
      HabitType.duration => '$target ${unit.isEmpty ? 'min' : unit}',
    };
  }

  /// The reminder copy shown honestly in the add/edit sheet and onboarding —
  /// the exact text the notification will carry, never a placeholder.
  String reminderPreview(int streak) {
    final subject = name.trim().isEmpty ? 'New habit' : name.trim();
    return streak > 0
        ? '"$subject — day $streak of your streak."'
        : '"$subject — start the loop today."';
  }

  Habit copyWith({
    String? name,
    TideGlyph? glyph,
    HabitType? type,
    num? target,
    String? unit,
    Set<int>? days,
    bool? reminderEnabled,
    TimeOfDay? reminderTime,
    int? freezeAllowance,
    int? freezesRemaining,
    bool? paused,
    Map<DateTime, num>? logs,
    Set<DateTime>? frozenDays,
  }) {
    return Habit(
      id: id,
      createdAt: createdAt,
      name: name ?? this.name,
      glyph: glyph ?? this.glyph,
      type: type ?? this.type,
      target: target ?? this.target,
      unit: unit ?? this.unit,
      days: days ?? this.days,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      reminderTime: reminderTime ?? this.reminderTime,
      freezeAllowance: freezeAllowance ?? this.freezeAllowance,
      freezesRemaining: freezesRemaining ?? this.freezesRemaining,
      paused: paused ?? this.paused,
      logs: logs ?? this.logs,
      frozenDays: frozenDays ?? this.frozenDays,
    );
  }
}
