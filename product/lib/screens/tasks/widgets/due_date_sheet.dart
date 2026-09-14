import 'package:flutter/material.dart';

import '../../../config/task_copy.dart';
import 'task_sheet.dart';

/// What the due-date sheet came back with. Null from [showDueDateSheet]
/// means it was dismissed; a choice with a null [date] means "no date".
typedef DueChoice = ({DateTime? date});

/// The answers almost everybody wants, and a calendar for the rest.
///
/// Shortcuts rather than going straight to a date picker: "today",
/// "tomorrow" and "next week" are one tap here and three in a calendar, and
/// they are most of what a to-do list is ever given.
Future<DueChoice?> showDueDateSheet(BuildContext context, {DateTime? current}) {
  return showTaskSheet<DueChoice>(
    context,
    title: 'Due date',
    builder: (context) => _DueOptions(current: current),
  );
}

class _DueOptions extends StatelessWidget {
  const _DueOptions({required this.current});

  final DateTime? current;

  Future<void> _pick(BuildContext context) async {
    final today = DateUtils.dateOnly(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? today,
      firstDate: DateTime(today.year - 1),
      lastDate: DateTime(today.year + 10),
    );
    if (picked != null && context.mounted) {
      Navigator.of(context).pop<DueChoice>((date: picked));
    }
  }

  @override
  Widget build(BuildContext context) {
    final today = DateUtils.dateOnly(DateTime.now());
    final options = [
      (label: 'Today', icon: Icons.today_rounded, date: today),
      (
        label: 'Tomorrow',
        icon: Icons.wb_twilight_rounded,
        date: DateTime(today.year, today.month, today.day + 1),
      ),
      (
        label: 'This weekend',
        icon: Icons.weekend_outlined,
        date: DateTime(
          today.year,
          today.month,
          // Saturday — or today, if the weekend has already started.
          today.day +
              (today.weekday >= DateTime.saturday
                  ? 0
                  : DateTime.saturday - today.weekday),
        ),
      ),
      (
        label: 'Next week',
        icon: Icons.date_range_rounded,
        date: DateTime(
          today.year,
          today.month,
          today.day + (8 - today.weekday),
        ),
      ),
    ];
    final custom = current != null && !options.any((o) => o.date == current);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final option in options)
          TaskSheetOption(
            icon: option.icon,
            label: option.label,
            detail: TaskCopy.dayAndDate(option.date),
            selected: current == option.date,
            onTap: () =>
                Navigator.of(context).pop<DueChoice>((date: option.date)),
          ),
        TaskSheetOption(
          icon: Icons.calendar_month_rounded,
          label: 'Pick a date',
          detail: custom ? TaskCopy.dayAndDate(current!) : null,
          selected: custom,
          onTap: () => _pick(context),
        ),
        if (current != null)
          TaskSheetOption(
            icon: Icons.event_busy_rounded,
            label: 'No due date',
            onTap: () => Navigator.of(context).pop<DueChoice>((date: null)),
          ),
      ],
    );
  }
}
