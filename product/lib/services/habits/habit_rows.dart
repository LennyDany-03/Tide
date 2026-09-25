import 'dart:convert';

import 'package:flutter/material.dart';

import '../../config/app_constants.dart';
import '../models/habit.dart';
import '../models/reminder_options.dart';
import '../models/tide_glyph.dart';

/// How a [Habit] is written down: as rows in the tables
/// `supabase/habits_setup.sql` creates, and as the copy this device keeps
/// between launches.
///
/// The device copy is kept in exactly the shape `habits_snapshot()` returns —
/// a habit row with its `entries` folded in — so reading last launch's copy
/// and reading the server's answer are the same code, and a column added to
/// one cannot be forgotten in the other.
///
/// Parsing is forgiving on purpose. A row written by a newer build may name a
/// glyph this one has never heard of; that habit should still open, wearing a
/// plain mark, rather than vanish from the list.
abstract final class HabitRows {
  /// The `public.habits` row for [habit]. `user_id` is added by whoever sends
  /// it, which is the only code that knows whose session the request carries.
  static Map<String, dynamic> habit(Habit habit, {String? origin}) {
    final weekdays = habit.days.toList()..sort();
    return {
      'id': habit.id,
      'name': habit.name,
      'glyph': habit.glyph.name,
      'kind': habit.type.name,
      'target': habit.target,
      'unit': habit.unit,
      'weekdays': weekdays,
      'reminder_enabled': habit.reminderEnabled,
      'reminder_time': _timeText(habit.reminderTime),
      'reminder_options': habit.reminderOptions.toJson(),
      'freeze_allowance': habit.freezeAllowance,
      'freezes_remaining': habit.freezesRemaining,
      // Both, on purpose. `pauses` is what this build reads; `paused` stays
      // true to it so a build from before pause spans still hides the habit.
      'paused': habit.paused,
      'pauses': [
        for (final span in habit.pauses)
          {
            'start': dayText(span.start),
            'end': span.end == null ? null : dayText(span.end!),
          },
      ],
      'created_at': habit.createdAt.toUtc().toIso8601String(),
      'origin': origin,
    };
  }

  /// The `public.habit_entries` row for [habit] on [day]: everything that day
  /// now holds, including nothing. An undone day is written back empty rather
  /// than deleted — the table's comment says why.
  static Map<String, dynamic> entry(
    Habit habit,
    DateTime day, {
    String? origin,
  }) {
    final date = DateUtils.dateOnly(day);
    return {
      'habit_id': habit.id,
      'day': dayText(date),
      'amount': habit.logs[date],
      'frozen': habit.frozenDays.contains(date),
      'origin': origin,
    };
  }

  /// [habit] with its whole history, in `habits_snapshot()`'s shape.
  static Map<String, dynamic> snapshot(Habit habit) {
    final days = {...habit.logs.keys, ...habit.frozenDays}.toList()..sort();
    return {
      ...HabitRows.habit(habit),
      'entries': [
        for (final day in days)
          {
            'day': dayText(day),
            'amount': habit.logs[day],
            'frozen': habit.frozenDays.contains(day),
          },
      ],
    };
  }

  /// Where this device keeps [accountId]'s copy in `SharedPreferences`.
  ///
  /// Public because two readers need it: the repository, and the Tide Call
  /// shown on the lock screen, which runs in its own isolate with no
  /// repository and reads the copy to show today's streak rather than the
  /// one the reminder was planned with.
  static String cacheKey(String accountId) => 'tide.habits.$accountId';

  /// The habits in a device copy written by [snapshot]. Empty for anything
  /// unreadable — a copy is a convenience, never worth failing over.
  static List<Habit> decodeCache(String? source) {
    if (source == null) return const [];
    try {
      final rows = jsonDecode(source);
      if (rows is! List) return const [];
      return [
        for (final row in rows)
          if (row is Map) parseHabit(Map<String, dynamic>.from(row)),
      ].nonNulls.toList();
    } on FormatException {
      return const [];
    }
  }

  /// A habit from a `habits` row, with its history when the row carries
  /// `entries`. Null when the row has no id or name to show.
  static Habit? parseHabit(Map<String, dynamic> row) {
    final id = row['id'];
    final name = row['name'];
    if (id is! String || name is! String) return null;

    final logs = <DateTime, num>{};
    final frozenDays = <DateTime>{};
    final entries = row['entries'];
    if (entries is List) {
      for (final raw in entries) {
        if (raw is! Map) continue;
        final day = parseDay(raw['day']);
        if (day == null) continue;
        final amount = _number(raw['amount']);
        if (amount != null) logs[day] = amount;
        if (raw['frozen'] == true) frozenDays.add(day);
      }
    }

    final unit = row['unit'];
    final allowance =
        _whole(row['freeze_allowance']) ?? AppConstants.defaultFreezeAllowance;
    return Habit(
      id: id,
      name: name,
      glyph: TideGlyph.values.asNameMap()[row['glyph']] ?? TideGlyph.dot,
      type: HabitType.values.asNameMap()[row['kind']] ?? HabitType.binary,
      createdAt: _instant(row['created_at']),
      target: _number(row['target']) ?? 1,
      unit: unit is String ? unit : '',
      days: _weekdays(row['weekdays']),
      reminderEnabled: row['reminder_enabled'] == true,
      reminderTime: _time(row['reminder_time']),
      reminderOptions: ReminderOptions.fromJson(row['reminder_options']),
      freezeAllowance: allowance,
      freezesRemaining: _whole(row['freezes_remaining']) ?? allowance,
      pauses: _pauses(row),
      logs: logs,
      frozenDays: frozenDays,
    );
  }

  /// One day of one habit, from a `habit_entries` row.
  static HabitEntry? parseEntry(Map<String, dynamic> row) {
    final habitId = row['habit_id'];
    final day = parseDay(row['day']);
    if (habitId is! String || day == null) return null;
    return HabitEntry(
      habitId: habitId,
      day: day,
      amount: _number(row['amount']),
      frozen: row['frozen'] == true,
    );
  }

  /// `2026-09-11` — the form a Postgres `date` takes on the wire.
  static String dayText(DateTime day) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${day.year.toString().padLeft(4, '0')}-'
        '${two(day.month)}-${two(day.day)}';
  }

  /// Local midnight on the date [value] names — the key every log map uses.
  static DateTime? parseDay(Object? value) {
    if (value is! String || value.length < 10) return null;
    final parsed = DateTime.tryParse(value.substring(0, 10));
    return parsed == null ? null : DateUtils.dateOnly(parsed);
  }

  /// Postgres `numeric` arrives as whatever JSON made of it. A whole number is
  /// kept whole, so a target still reads "8 glasses", never "8.0 glasses".
  static num? _number(Object? value) {
    final number = value is String ? num.tryParse(value) : value;
    if (number is! num) return null;
    if (number is double && number.isFinite && number == number.truncate()) {
      return number.toInt();
    }
    return number;
  }

  static int? _whole(Object? value) => _number(value)?.toInt();

  /// The pause history, oldest first, with at most the last span open.
  ///
  /// A row from before spans existed carries only `paused: true`. It has no
  /// record of when the pause began, so the best reading is the last time
  /// the row changed — the pause is very likely the change that was made —
  /// and failing that, today. Either way the habit stays paused.
  static List<PauseSpan> _pauses(Map<String, dynamic> row) {
    final spans = <PauseSpan>[];
    final raw = row['pauses'];
    if (raw is List) {
      for (final item in raw) {
        if (item is! Map) continue;
        final start = parseDay(item['start']);
        if (start == null) continue;
        final end = parseDay(item['end']);
        if (end != null && !end.isAfter(start)) continue;
        spans.add(PauseSpan(start: start, end: end));
      }
    }
    spans.sort((a, b) => a.start.compareTo(b.start));
    // Only the newest span may still be running.
    for (var i = 0; i < spans.length - 1; i++) {
      if (spans[i].open) {
        spans[i] = PauseSpan(start: spans[i].start, end: spans[i + 1].start);
      }
    }

    final flagged = row['paused'] == true;
    final running = spans.isNotEmpty && spans.last.open;
    if (flagged && !running) {
      final updated = row['updated_at'];
      final since = updated is String
          ? DateUtils.dateOnly(_instant(updated))
          : DateUtils.dateOnly(DateTime.now());
      final floor = spans.isEmpty ? null : spans.last.end;
      spans.add(
        PauseSpan(
          start: floor != null && since.isBefore(floor) ? floor : since,
        ),
      );
    }
    return spans;
  }

  static DateTime _instant(Object? value) {
    final parsed = value is String ? DateTime.tryParse(value) : null;
    return parsed?.toLocal() ?? DateTime.now();
  }

  static Set<int> _weekdays(Object? value) {
    final days = <int>{
      if (value is List)
        for (final day in value)
          if (day is int && day >= DateTime.monday && day <= DateTime.sunday)
            day,
    };
    // A habit scheduled on no day could never be logged again. Every day is
    // the reading that hides nothing.
    return days.isEmpty ? {1, 2, 3, 4, 5, 6, 7} : days;
  }

  static String _timeText(TimeOfDay time) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(time.hour)}:${two(time.minute)}:00';
  }

  static TimeOfDay _time(Object? value) {
    if (value is String) {
      final parts = value.split(':');
      if (parts.length >= 2) {
        final hour = int.tryParse(parts[0]);
        final minute = int.tryParse(parts[1]);
        if (hour != null &&
            minute != null &&
            hour >= 0 &&
            hour < 24 &&
            minute >= 0 &&
            minute < 60) {
          return TimeOfDay(hour: hour, minute: minute);
        }
      }
    }
    return const TimeOfDay(hour: 8, minute: 0);
  }
}

/// One day of one habit: what was logged on it, and whether a freeze was
/// spent on it.
@immutable
class HabitEntry {
  const HabitEntry({
    required this.habitId,
    required this.day,
    this.amount,
    this.frozen = false,
  });

  final String habitId;

  /// Local midnight.
  final DateTime day;

  /// Null when nothing is logged that day.
  final num? amount;

  final bool frozen;

  /// [habit] with this day replaced by what the entry says.
  Habit applyTo(Habit habit) {
    final logs = Map<DateTime, num>.from(habit.logs);
    final frozenDays = Set<DateTime>.from(habit.frozenDays);
    final logged = amount;
    if (logged == null) {
      logs.remove(day);
    } else {
      logs[day] = logged;
    }
    if (frozen) {
      frozenDays.add(day);
    } else {
      frozenDays.remove(day);
    }
    return habit.copyWith(logs: logs, frozenDays: frozenDays);
  }
}
