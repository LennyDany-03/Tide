import 'package:flutter/material.dart';

import 'reminder_options.dart';
import 'tide_glyph.dart';

/// What "done" means for a habit, and therefore which gesture logs it.
///
/// Binary habits are swiped on the row itself. Quantity habits open a sheet
/// where the count is held out one unit at a time; duration habits open a
/// dial that is set to the time spent and confirmed in one tap.
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
    HabitType.binary => 'swipe right to mark',
    HabitType.quantity => 'tap to count up',
    HabitType.duration => 'tap to log time',
  };

  bool get isHeld => this != HabitType.binary;
}

/// How a length of time is written wherever the app shows one: "45 min",
/// "1 hr", "1 hr 30 min" — never a bare count of minutes past the hour,
/// which is not the form anybody plans a day in.
abstract final class Minutes {
  static String label(num minutes) {
    final total = minutes.round();
    if (total < 60) return '$total min';
    final hours = total ~/ 60;
    final rest = total % 60;
    return rest == 0 ? '$hours hr' : '$hours hr $rest min';
  }
}

/// A stretch of days a habit was set aside: [start] inclusive, [end]
/// exclusive, both local midnights. An open span ([end] null) is a pause
/// still running.
///
/// A pause is a range of days rather than a flag on the habit, because a
/// flag cannot say *when*. It used to be one boolean, and every question
/// that mattered had no answer: a paused week came back as seven misses the
/// moment the habit was resumed — the streak it was meant to protect was the
/// first thing it broke — and pausing a habit today rewrote last month's
/// calendar, which stopped counting it on days it had actually been done.
@immutable
class PauseSpan {
  const PauseSpan({required this.start, this.end});

  final DateTime start;

  /// The day the habit came back. Null while it is still paused.
  final DateTime? end;

  bool get open => end == null;

  bool covers(DateTime date) {
    final day = DateUtils.dateOnly(date);
    return !day.isBefore(start) && (end == null || day.isBefore(end!));
  }

  @override
  bool operator ==(Object other) =>
      other is PauseSpan && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);
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
    this.reminderOptions = const ReminderOptions(),
    this.freezeAllowance = 2,
    this.freezesRemaining = 2,
    this.pauses = const [],
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

  /// How the reminder arrives: its heads-up, full screen or gentle, the tone
  /// and the snooze. Read only while [reminderEnabled].
  final ReminderOptions reminderOptions;

  /// How many freezes this habit is allowed, and how many are left. A freeze
  /// skips a day without breaking the loop.
  final int freezeAllowance;
  final int freezesRemaining;

  /// Every pause this habit has had, oldest first. At most the last is open.
  final List<PauseSpan> pauses;

  /// Set aside right now: off Today, and asking nothing of anybody.
  bool get paused => pauses.isNotEmpty && pauses.last.open;

  /// The first day of the pause that is running, if one is.
  DateTime? get pausedSince => paused ? pauses.last.start : null;

  /// Date (normalised to midnight) → amount logged that day.
  final Map<DateTime, num> logs;

  /// Days where a freeze was spent rather than the habit being logged.
  final Set<DateTime> frozenDays;

  // --- Queries ----------------------------------------------------------

  bool isScheduledOn(DateTime date) => days.contains(date.weekday);

  bool isPausedOn(DateTime date) => pauses.any((span) => span.covers(date));

  /// Whether [date] asked anything of this habit: a scheduled weekday that
  /// was not inside a pause. Streaks, rates and summaries all count on this,
  /// so a paused day is a rest day — neither earned nor missed.
  bool isDueOn(DateTime date) => isScheduledOn(date) && !isPausedOn(date);

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

  /// "8 glasses" for quantity, "1 hr 30 min" for duration, '' for binary.
  String get targetLabel {
    return switch (type) {
      HabitType.binary => '',
      HabitType.quantity => '$target${unit.isEmpty ? '' : ' $unit'}',
      HabitType.duration =>
        unit.isEmpty || unit == 'min' ? Minutes.label(target) : '$target $unit',
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
    ReminderOptions? reminderOptions,
    int? freezeAllowance,
    int? freezesRemaining,
    List<PauseSpan>? pauses,
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
      reminderOptions: reminderOptions ?? this.reminderOptions,
      freezeAllowance: freezeAllowance ?? this.freezeAllowance,
      freezesRemaining: freezesRemaining ?? this.freezesRemaining,
      pauses: pauses ?? this.pauses,
      logs: logs ?? this.logs,
      frozenDays: frozenDays ?? this.frozenDays,
    );
  }
}
