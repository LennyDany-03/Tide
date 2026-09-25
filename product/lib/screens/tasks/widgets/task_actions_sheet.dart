import 'package:flutter/material.dart';

import '../../../config/task_copy.dart';
import '../../../services/tasks/task.dart';
import 'task_sheet.dart';

/// What a long press on a task card can do.
enum TaskAction { edit, complete, dueToday, dueTomorrow, delete }

/// The long-press menu on a task card.
///
/// Every verb here is also reachable another way — the swipe completes and
/// deletes, a tap opens the editor — but a long press is the gesture people
/// reach for when they want to see what a thing can do, and a card that
/// answers it with nothing reads as broken. So it lists the verbs in words.
///
/// Returns the choice rather than acting on it: the sheet is gone by the
/// time the list acts, so its Undo snackbar lands on the list, not on a
/// closing sheet.
///
/// Delete is a plain row, not a hold. A deleted task comes back with Undo,
/// and a hold-to-confirm is for what cannot.
Future<TaskAction?> showTaskActionsSheet(
  BuildContext context, {
  required Task task,
}) {
  final today = DateUtils.dateOnly(DateTime.now());
  final tomorrow = DateTime(today.year, today.month, today.day + 1);
  final stepsLeft = task.isCompleted ? 0 : task.subtasksLeft;

  return showTaskSheet<TaskAction>(
    context,
    title: task.title,
    builder: (context) {
      void pick(TaskAction action) => Navigator.of(context).pop(action);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TaskSheetOption(
            icon: Icons.edit_outlined,
            label: 'Edit task',
            onTap: () => pick(TaskAction.edit),
          ),
          // A task with steps left finishes with its last step, so this row
          // says so and opens the editor, where the steps are.
          TaskSheetOption(
            icon: task.isCompleted
                ? Icons.undo_rounded
                : stepsLeft > 0
                ? Icons.checklist_rounded
                : Icons.check_rounded,
            label: task.isCompleted
                ? 'Mark as not done'
                : stepsLeft > 0
                ? 'Finish the steps'
                : 'Mark as complete',
            detail: stepsLeft > 0 ? '${TaskCopy.steps(stepsLeft)} left' : null,
            onTap: () =>
                pick(stepsLeft > 0 ? TaskAction.edit : TaskAction.complete),
          ),
          if (!task.isCompleted && task.dueDate != today)
            TaskSheetOption(
              icon: Icons.today_rounded,
              label: 'Move to today',
              onTap: () => pick(TaskAction.dueToday),
            ),
          if (!task.isCompleted && task.dueDate != tomorrow)
            TaskSheetOption(
              icon: Icons.event_rounded,
              label: 'Move to tomorrow',
              onTap: () => pick(TaskAction.dueTomorrow),
            ),
          TaskSheetOption(
            icon: Icons.delete_outline_rounded,
            label: 'Delete task',
            destructive: true,
            onTap: () => pick(TaskAction.delete),
          ),
        ],
      );
    },
  );
}
