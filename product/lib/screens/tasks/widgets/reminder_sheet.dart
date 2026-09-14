import 'package:flutter/material.dart';

import '../../../config/task_copy.dart';
import 'task_sheet.dart';

/// When to be reminded, from a handful of moments that cover most asks.
///
/// The old flow was a date picker followed by a time picker for every
/// reminder, two full-screen dialogs to say "tomorrow morning". These are one
/// tap each, and "Pick a date and time" is still there for everything else.
/// Moments that have already passed today are left off rather than offered
/// and refused.
Future<DateTime?> showReminderSheet(BuildContext context, {DateTime? due}) {
  return showTaskSheet<DateTime>(
    context,
    title: 'Remind me',
    builder: (context) => _ReminderOptions(due: due),
  );
}

class _ReminderOptions extends StatelessWidget {
  const _ReminderOptions({required this.due});

  final DateTime? due;

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final today = DateUtils.dateOnly(now);
    final start = due != null && !due!.isBefore(today) ? due! : today;
    final day = await showDatePicker(
      context: context,
      initialDate: start,
      firstDate: today,
      lastDate: DateTime(now.year + 10),
    );
    if (day == null || !context.mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
    );
    if (time == null || !context.mounted) return;
    final at = DateTime(day.year, day.month, day.day, time.hour, time.minute);
    Navigator.of(context).pop(at.isAfter(DateTime.now()) ? at : null);
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateUtils.dateOnly(now);
    DateTime at(DateTime day, int hour) =>
        DateTime(day.year, day.month, day.day, hour);

    final inAnHour = DateTime(now.year, now.month, now.day, now.hour + 1);
    final tomorrow = DateTime(today.year, today.month, today.day + 1);
    final options = <({IconData icon, String label, DateTime moment})>[
      (icon: Icons.schedule_rounded, label: 'In an hour', moment: inAnHour),
      if (at(today, 18).isAfter(inAnHour))
        (
          icon: Icons.nights_stay_outlined,
          label: 'This evening',
          moment: at(today, 18),
        ),
      (
        icon: Icons.wb_twilight_rounded,
        label: 'Tomorrow morning',
        moment: at(tomorrow, 9),
      ),
      if (due != null &&
          at(due!, 9).isAfter(now) &&
          !DateUtils.isSameDay(due, tomorrow))
        (
          icon: Icons.event_available_rounded,
          label: 'On the due date',
          moment: at(due!, 9),
        ),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final option in options)
          TaskSheetOption(
            icon: option.icon,
            label: option.label,
            detail: TaskCopy.reminder(option.moment),
            onTap: () => Navigator.of(context).pop(option.moment),
          ),
        TaskSheetOption(
          icon: Icons.edit_calendar_rounded,
          label: 'Pick a date and time',
          onTap: () => _pick(context),
        ),
      ],
    );
  }
}
