import 'package:flutter/material.dart' show DateUtils, TimeOfDay;

import '../services/tasks/task.dart';
import 'app_constants.dart';
import 'habit_copy.dart';

/// How the to-do list says dates, repeats and reminders — once, for the list,
/// the editor and the archive.
abstract final class TaskCopy {
  static String _short(DateTime date) =>
      '${date.day} ${AppConstants.monthNames[date.month - 1].substring(0, 3)}';

  /// "Today", "Tomorrow", "Yesterday", "Fri", or "12 Sep".
  static String due(DateTime date, {DateTime? now}) {
    final today = DateUtils.dateOnly(now ?? DateTime.now());
    final offset = DateUtils.dateOnly(date).difference(today).inDays;
    if (offset == 0) return 'Today';
    if (offset == 1) return 'Tomorrow';
    if (offset == -1) return 'Yesterday';
    if (offset > 1 && offset < 7) {
      return AppConstants.weekdayNames[date.weekday - 1].substring(0, 3);
    }
    return _short(date);
  }

  /// "Today", "Tomorrow", or "Friday, 18 Sep" — for the editor, where there
  /// is room to say which Friday.
  static String dueLong(DateTime date, {DateTime? now}) {
    final short = due(date, now: now);
    if (short == 'Today' || short == 'Tomorrow' || short == 'Yesterday') {
      return short;
    }
    return '${AppConstants.weekdayNames[date.weekday - 1]}, ${_short(date)}';
  }

  /// "Mon 21 Sep" — beside a shortcut, so "next week" says which day.
  static String dayAndDate(DateTime date) =>
      '${AppConstants.weekdayNames[date.weekday - 1].substring(0, 3)} '
      '${_short(date)}';

  /// "Every day", "Every week", "Every month", "Every 6 months", "Every year".
  static String repeat(Task task) => switch (task.recurrence) {
    TaskRecurrence.none => 'Never',
    TaskRecurrence.daily => 'Every day',
    TaskRecurrence.weekly => 'Every week',
    TaskRecurrence.monthly => 'Every month',
    TaskRecurrence.custom => months(task.customRecurrenceMonths ?? 1),
  };

  static String months(int count) {
    if (count == 12) return 'Every year';
    if (count % 12 == 0) return 'Every ${count ~/ 12} years';
    return count == 1 ? 'Every month' : 'Every $count months';
  }

  static String time(DateTime moment) {
    final t = TimeOfDay.fromDateTime(moment);
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m ${t.period.name.toUpperCase()}';
  }

  /// "Today, 9:00 AM" or "12 Sep, 9:00 AM".
  static String reminder(DateTime moment, {DateTime? now}) =>
      '${due(moment, now: now)}, ${time(moment)}';

  /// "Completed today" or "Completed 12 Sep".
  static String completed(DateTime moment) =>
      'Completed ${HabitCopy.day(moment)}';
}
