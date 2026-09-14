import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tide/services/tasks/task.dart';
import 'package:tide/services/tasks/task_rows.dart';

/// A fixed clock: Wednesday 16 September 2026, mid-morning.
final DateTime now = DateTime(2026, 9, 16, 10, 30);

Task task({
  DateTime? due,
  TaskRecurrence recurrence = TaskRecurrence.none,
  int? months,
  List<DateTime> reminders = const [],
}) => Task(
  id: 't1',
  title: 'Renew licence',
  dueDate: due,
  recurrence: recurrence,
  customRecurrenceMonths: months,
  reminders: reminders,
  subtasks: const [Subtask(id: 's1', title: 'Photo', isCompleted: true)],
  tags: const ['admin'],
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

void main() {
  group('the next occurrence', () {
    test('a task that does not repeat has none', () {
      expect(task(due: now).nextDueDate(now), isNull);
    });

    test('weekly is counted from the due date, not the day it was done', () {
      // Due Monday the 14th, done on Wednesday the 16th.
      final t = task(
        due: DateTime(2026, 9, 14),
        recurrence: TaskRecurrence.weekly,
      );
      expect(t.nextDueDate(now), DateTime(2026, 9, 21));
    });

    test('a late daily task skips the days already gone', () {
      final t = task(
        due: DateTime(2026, 9, 11),
        recurrence: TaskRecurrence.daily,
      );
      expect(t.nextDueDate(now), DateTime(2026, 9, 17));
    });

    test('with no due date it counts from the day it was completed', () {
      final t = task(recurrence: TaskRecurrence.daily);
      expect(t.nextDueDate(now), DateTime(2026, 9, 17));
    });

    test('monthly on the 31st lands on the last day of a short month', () {
      final t = task(
        due: DateTime(2027, 1, 31),
        recurrence: TaskRecurrence.monthly,
      );
      expect(t.nextDueDate(DateTime(2027, 1, 31)), DateTime(2027, 2, 28));
    });

    test('a custom 12-month repeat is the same date next year', () {
      final t = task(
        due: DateTime(2026, 9, 16),
        recurrence: TaskRecurrence.custom,
        months: 12,
      );
      expect(t.nextDueDate(now), DateTime(2027, 9, 16));
    });

    test('a custom repeat with no months set does not repeat', () {
      final t = task(due: now, recurrence: TaskRecurrence.custom);
      expect(t.nextDueDate(now), isNull);
    });
  });

  group('the successor', () {
    test('moves reminders with the due date and resets its steps', () {
      final t = task(
        due: DateTime(2026, 9, 16),
        recurrence: TaskRecurrence.weekly,
        reminders: [DateTime(2026, 9, 15, 18, 0)],
      );
      final next = t.successor(id: 't2', completedAt: now, now: now)!;

      expect(next.id, 't2');
      expect(next.dueDate, DateTime(2026, 9, 23));
      expect(next.reminders, [DateTime(2026, 9, 22, 18, 0)]);
      expect(next.isCompleted, isFalse);
      expect(next.subtasks.single.isCompleted, isFalse);
      expect(next.tags, ['admin']);
      expect(next.syncStatus, TaskSyncStatus.pendingCreate);
    });

    test('drops a reminder that would already have passed', () {
      final t = task(
        recurrence: TaskRecurrence.daily,
        reminders: [DateTime(2026, 9, 16, 7, 0)],
      );
      // Moved one day: 17 Sep 07:00 is still ahead.
      expect(t.successor(id: 'x', completedAt: now, now: now)!.reminders, [
        DateTime(2026, 9, 17, 7, 0),
      ]);
      // Seen from two days later, it is not.
      final later = DateTime(2026, 9, 18, 8);
      expect(
        t.successor(id: 'x', completedAt: now, now: later)!.reminders,
        isEmpty,
      );
    });
  });

  test('a task survives the device copy and the server row', () {
    final original =
        task(
          due: DateTime(2026, 9, 20),
          recurrence: TaskRecurrence.custom,
          months: 6,
          reminders: [DateTime(2026, 9, 19, 9, 15)],
        ).copyWith(
          description: 'Bring the old one',
          syncStatus: TaskSyncStatus.pendingUpdate,
        );

    final cached = TaskRows.parseCached(
      jsonDecode(jsonEncode(TaskRows.cached(original))) as Map<String, dynamic>,
    )!;
    expect(cached.sameContent(original), isTrue);
    expect(cached.syncStatus, TaskSyncStatus.pendingUpdate);
    expect(cached.updatedAt, original.updatedAt);

    final remote = TaskRows.parseRemote({
      ...jsonDecode(jsonEncode(TaskRows.row(original))) as Map<String, dynamic>,
      'synced_at': '2026-09-16T08:00:00Z',
    })!;
    expect(remote.task.sameContent(original), isTrue);
    expect(remote.task.syncStatus, TaskSyncStatus.synced);
    expect(remote.deleted, isFalse);
  });

  test('a deleted task is written as a tombstone, not left out', () {
    final gone = task().copyWith(syncStatus: TaskSyncStatus.pendingDelete);
    expect(TaskRows.row(gone)['deleted_at'], isNotNull);
    expect(TaskRows.row(task())['deleted_at'], isNull);
  });

  test('an unknown recurrence from a newer build still opens', () {
    final parsed = TaskRows.parseCached({
      ...TaskRows.cached(task()),
      'recurrence': 'lunar',
    })!;
    expect(parsed.recurrence, TaskRecurrence.none);
  });
}
