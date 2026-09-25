import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show DateUtils;

/// How a task comes back once it is done.
enum TaskRecurrence {
  none,
  daily,
  weekly,
  monthly,

  /// Every [Task.customRecurrenceMonths] months — licence renewals, gear
  /// servicing, the storm shutters. Pro.
  custom;

  String get label => switch (this) {
    TaskRecurrence.none => 'None',
    TaskRecurrence.daily => 'Daily',
    TaskRecurrence.weekly => 'Weekly',
    TaskRecurrence.monthly => 'Monthly',
    TaskRecurrence.custom => 'Custom',
  };
}

/// Where a task stands with the server.
///
/// Kept on the task itself rather than in a separate queue: the list on the
/// device *is* the queue, so there is no second structure that can fall out
/// of step with it, and a write can never be lost between the two.
enum TaskSyncStatus { synced, pendingCreate, pendingUpdate, pendingDelete }

/// One step inside a task. Not tier-gated.
@immutable
class Subtask {
  const Subtask({
    required this.id,
    required this.title,
    this.isCompleted = false,
  });

  final String id;
  final String title;
  final bool isCompleted;

  Subtask copyWith({String? title, bool? isCompleted}) => Subtask(
    id: id,
    title: title ?? this.title,
    isCompleted: isCompleted ?? this.isCompleted,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'is_completed': isCompleted,
  };

  static Subtask? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final title = json['title'];
    if (id is! String || title is! String) return null;
    return Subtask(
      id: id,
      title: title,
      isCompleted: json['is_completed'] == true,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Subtask &&
      other.id == id &&
      other.title == title &&
      other.isCompleted == isCompleted;

  @override
  int get hashCode => Object.hash(id, title, isCompleted);
}

/// Marks a `copyWith` argument that was not passed, so a nullable field can
/// be cleared by passing null.
const Object _keep = Object();

/// One item on the to-do list.
///
/// Immutable, like `Habit`: every change goes through [copyWith] and the
/// store replaces the whole row. [dueDate] is a calendar day (local
/// midnight); [reminders] are exact moments.
@immutable
class Task {
  const Task({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.description,
    this.dueDate,
    this.isCompleted = false,
    this.completedAt,
    this.recurrence = TaskRecurrence.none,
    this.customRecurrenceMonths,
    this.reminders = const [],
    this.tags = const [],
    this.subtasks = const [],
    this.isArchived = false,
    this.syncStatus = TaskSyncStatus.pendingCreate,
  });

  final String id;
  final String title;
  final String? description;
  final DateTime? dueDate;
  final bool isCompleted;
  final DateTime? completedAt;
  final TaskRecurrence recurrence;

  /// Only read when [recurrence] is [TaskRecurrence.custom].
  final int? customRecurrenceMonths;

  /// Sorted, soonest first.
  final List<DateTime> reminders;
  final List<String> tags;
  final List<Subtask> subtasks;
  final bool isArchived;
  final DateTime createdAt;

  /// The moment of the last edit on whichever device made it. Last write
  /// wins on this, here and on the server.
  final DateTime updatedAt;

  final TaskSyncStatus syncStatus;

  /// Deleted here, and the server has not heard yet. Hidden everywhere.
  bool get isDeleted => syncStatus == TaskSyncStatus.pendingDelete;

  bool get repeats => recurrence != TaskRecurrence.none;

  int get subtasksDone => subtasks.where((s) => s.isCompleted).length;

  /// Steps still open. A task with any left cannot be completed: it finishes
  /// when its last step does, not before.
  int get subtasksLeft => subtasks.length - subtasksDone;

  bool isOverdue(DateTime now) {
    final due = dueDate;
    return !isCompleted && due != null && due.isBefore(DateUtils.dateOnly(now));
  }

  Task copyWith({
    String? title,
    Object? description = _keep,
    Object? dueDate = _keep,
    bool? isCompleted,
    Object? completedAt = _keep,
    TaskRecurrence? recurrence,
    Object? customRecurrenceMonths = _keep,
    List<DateTime>? reminders,
    List<String>? tags,
    List<Subtask>? subtasks,
    bool? isArchived,
    DateTime? updatedAt,
    TaskSyncStatus? syncStatus,
  }) {
    return Task(
      id: id,
      createdAt: createdAt,
      title: title ?? this.title,
      description: identical(description, _keep)
          ? this.description
          : description as String?,
      dueDate: identical(dueDate, _keep)
          ? this.dueDate
          : (dueDate == null ? null : DateUtils.dateOnly(dueDate as DateTime)),
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: identical(completedAt, _keep)
          ? this.completedAt
          : completedAt as DateTime?,
      recurrence: recurrence ?? this.recurrence,
      customRecurrenceMonths: identical(customRecurrenceMonths, _keep)
          ? this.customRecurrenceMonths
          : customRecurrenceMonths as int?,
      reminders: reminders == null ? this.reminders : ([...reminders]..sort()),
      tags: tags ?? this.tags,
      subtasks: subtasks ?? this.subtasks,
      isArchived: isArchived ?? this.isArchived,
      updatedAt: updatedAt ?? this.updatedAt,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  /// Everything but sync bookkeeping is the same — what the editor compares
  /// to decide whether there is anything to save.
  bool sameContent(Task other) =>
      title == other.title &&
      description == other.description &&
      dueDate == other.dueDate &&
      isCompleted == other.isCompleted &&
      recurrence == other.recurrence &&
      customRecurrenceMonths == other.customRecurrenceMonths &&
      listEquals(reminders, other.reminders) &&
      listEquals(tags, other.tags) &&
      listEquals(subtasks, other.subtasks) &&
      isArchived == other.isArchived;

  // --- Recurrence -----------------------------------------------------------

  /// The due day of the occurrence after this one, completed on [completedOn].
  ///
  /// Counted from the due date when there is one, so a weekly Monday task
  /// finished on Wednesday is next due on Monday, not Wednesday. Occurrences
  /// that are already in the past are skipped: finishing a daily task four
  /// days late produces tomorrow's, not a backlog of four.
  ///
  /// Months are counted from the original day each step rather than from the
  /// previous result, so the 31st goes to the 28th in February and back to
  /// the 31st in March instead of drifting to the 28th for good.
  DateTime? nextDueDate(DateTime completedOn) {
    if (!repeats) return null;
    final today = DateUtils.dateOnly(completedOn);
    final base = dueDate ?? today;
    final months = recurrence == TaskRecurrence.custom
        ? (customRecurrenceMonths ?? 0)
        : 0;
    if (recurrence == TaskRecurrence.custom && months < 1) return null;

    DateTime step(int k) => switch (recurrence) {
      TaskRecurrence.daily => DateTime(base.year, base.month, base.day + k),
      TaskRecurrence.weekly => DateTime(
        base.year,
        base.month,
        base.day + 7 * k,
      ),
      TaskRecurrence.monthly => addMonths(base, k),
      TaskRecurrence.custom => addMonths(base, k * months),
      TaskRecurrence.none => base,
    };

    var k = 1;
    var next = step(k);
    while (!next.isAfter(today)) {
      next = step(++k);
    }
    return next;
  }

  /// The next occurrence of a repeating task, made when this one is completed.
  ///
  /// A new task rather than this one rolled forward, so what was done stays in
  /// the completed list and the archive. Reminders move with the due date —
  /// same time of day, same number of days before — and any that would land
  /// in the past are dropped. Subtasks come back unticked.
  Task? successor({
    required String id,
    required DateTime completedAt,
    required DateTime now,
  }) {
    final nextDue = nextDueDate(completedAt);
    if (nextDue == null) return null;
    final base = dueDate ?? DateUtils.dateOnly(completedAt);
    final shift = DateUtils.dateOnly(nextDue).difference(base).inDays;

    return Task(
      id: id,
      title: title,
      description: description,
      dueDate: nextDue,
      recurrence: recurrence,
      customRecurrenceMonths: customRecurrenceMonths,
      reminders: [
        for (final r in reminders)
          DateTime(r.year, r.month, r.day + shift, r.hour, r.minute),
      ].where((r) => r.isAfter(now)).toList()..sort(),
      tags: tags,
      subtasks: [for (final s in subtasks) s.copyWith(isCompleted: false)],
      createdAt: now,
      updatedAt: now,
    );
  }

  /// [date] plus [months] calendar months, the day clamped to the length of
  /// the month it lands in.
  static DateTime addMonths(DateTime date, int months) {
    final index = date.year * 12 + (date.month - 1) + months;
    final year = index ~/ 12;
    final month = index % 12 + 1;
    final last = DateUtils.getDaysInMonth(year, month);
    return DateTime(year, month, date.day > last ? last : date.day);
  }
}
