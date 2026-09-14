import '../habits/habit_rows.dart';
import 'task.dart';

/// A task as the server holds it: the row, whether it was deleted, and when
/// the server last wrote it (the pull cursor).
class RemoteTask {
  const RemoteTask({required this.task, required this.deleted, this.syncedAt});

  final Task task;
  final bool deleted;
  final DateTime? syncedAt;
}

/// How a [Task] is written down: as a `public.tasks` row
/// (`supabase/tasks_setup.sql`) and as the copy this device keeps.
///
/// The device copy is the row plus `sync_status`, so both are read by the
/// same code. Parsing is forgiving, as it is for habits: an unknown
/// recurrence reads as none rather than losing the task.
abstract final class TaskRows {
  /// The `public.tasks` row. `user_id` is added by whoever sends it.
  static Map<String, dynamic> row(Task task) => {
    'id': task.id,
    'title': task.title,
    'description': task.description,
    'due_date': task.dueDate == null ? null : HabitRows.dayText(task.dueDate!),
    'is_completed': task.isCompleted,
    'completed_at': task.completedAt?.toUtc().toIso8601String(),
    'recurrence': task.recurrence.name,
    'custom_recurrence_months': task.customRecurrenceMonths,
    'reminders': [for (final r in task.reminders) r.toUtc().toIso8601String()],
    'tags': task.tags,
    'subtasks': [for (final s in task.subtasks) s.toJson()],
    'is_archived': task.isArchived,
    'created_at': task.createdAt.toUtc().toIso8601String(),
    'updated_at': task.updatedAt.toUtc().toIso8601String(),
    // A delete is a write like any other — the row stays, marked — so an
    // offline delete replays safely and reaches every other device.
    'deleted_at': task.isDeleted
        ? task.updatedAt.toUtc().toIso8601String()
        : null,
  };

  static Map<String, dynamic> cached(Task task) => {
    ...row(task),
    'sync_status': task.syncStatus.name,
  };

  /// A task from the device copy.
  static Task? parseCached(Map<String, dynamic> json) {
    final task = _parse(json);
    if (task == null) return null;
    final status =
        TaskSyncStatus.values.asNameMap()[json['sync_status']] ??
        TaskSyncStatus.pendingUpdate;
    return task.copyWith(syncStatus: status);
  }

  /// A task from a server row, already marked synced.
  static RemoteTask? parseRemote(Map<String, dynamic> json) {
    final task = _parse(json);
    if (task == null) return null;
    return RemoteTask(
      task: task.copyWith(syncStatus: TaskSyncStatus.synced),
      deleted: json['deleted_at'] != null,
      syncedAt: _instant(json['synced_at']),
    );
  }

  static Task? _parse(Map<String, dynamic> json) {
    final id = json['id'];
    final title = json['title'];
    if (id is! String || title is! String) return null;
    final created = _instant(json['created_at']) ?? DateTime.now();
    final months = json['custom_recurrence_months'];
    final description = json['description'];

    return Task(
      id: id,
      title: title,
      description: description is String && description.isNotEmpty
          ? description
          : null,
      dueDate: HabitRows.parseDay(json['due_date']),
      isCompleted: json['is_completed'] == true,
      completedAt: _instant(json['completed_at']),
      recurrence:
          TaskRecurrence.values.asNameMap()[json['recurrence']] ??
          TaskRecurrence.none,
      customRecurrenceMonths: months is num ? months.toInt() : null,
      reminders: [
        if (json['reminders'] is List)
          for (final r in json['reminders'] as List) _instant(r),
      ].nonNulls.toList()..sort(),
      tags: [
        if (json['tags'] is List)
          for (final t in json['tags'] as List)
            if (t is String && t.isNotEmpty) t,
      ],
      subtasks: [
        if (json['subtasks'] is List)
          for (final s in json['subtasks'] as List) Subtask.fromJson(s),
      ].nonNulls.toList(),
      isArchived: json['is_archived'] == true,
      createdAt: created,
      updatedAt: _instant(json['updated_at']) ?? created,
    );
  }

  static DateTime? _instant(Object? value) {
    if (value is! String) return null;
    return DateTime.tryParse(value)?.toLocal();
  }
}
