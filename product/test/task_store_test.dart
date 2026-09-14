import 'package:flutter/material.dart' show DateUtils;
import 'package:flutter_test/flutter_test.dart';
import 'package:tide/config/app_constants.dart';
import 'package:tide/services/auth/demo_auth_service.dart';
import 'package:tide/services/billing/demo_billing_service.dart';
import 'package:tide/services/device_flags.dart';
import 'package:tide/services/tasks/task.dart';
import 'package:tide/services/tasks/task_local.dart';
import 'package:tide/services/tasks/task_remote.dart';
import 'package:tide/services/tasks/task_reminders.dart';
import 'package:tide/services/tasks/task_rows.dart';
import 'package:tide/services/tasks/task_store.dart';
import 'package:tide/services/tide_store.dart';

/// A server that can be switched off, and that enforces last-write-wins the
/// way the trigger in `supabase/tasks_setup.sql` does.
class FakeTaskRemote implements TaskRemote {
  bool online = true;
  final Map<String, RemoteTask> rows = {};
  int pushes = 0;
  int _clock = 0;

  DateTime _stamp() => DateTime.utc(2026).add(Duration(microseconds: ++_clock));

  @override
  Future<void> push(String accountId, Task task) async {
    if (!online) throw StateError('no network');
    pushes++;
    final existing = rows[task.id];
    if (existing != null && task.updatedAt.isBefore(existing.task.updatedAt)) {
      return;
    }
    rows[task.id] = RemoteTask(
      task: task.copyWith(syncStatus: TaskSyncStatus.synced),
      deleted: task.isDeleted,
      syncedAt: _stamp(),
    );
  }

  /// A write from another device.
  void writeElsewhere(Task task, {bool deleted = false}) {
    rows[task.id] = RemoteTask(
      task: task.copyWith(syncStatus: TaskSyncStatus.synced),
      deleted: deleted,
      syncedAt: _stamp(),
    );
  }

  @override
  Future<List<RemoteTask>> pull(
    String accountId, {
    DateTime? since,
    int limit = 500,
  }) async {
    if (!online) throw StateError('no network');
    final list =
        rows.values
            .where(
              (r) => since == null ? !r.deleted : !r.syncedAt!.isBefore(since),
            )
            .toList()
          ..sort((a, b) => a.syncedAt!.compareTo(b.syncedAt!));
    return list.take(limit).toList();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  TideStore tide({bool pro = false}) => TideStore(
    auth: DemoAuthService(signedIn: true),
    flags: DeviceFlags.memory(onboardingSeen: true),
    billing: pro ? DemoBillingService.pro() : DemoBillingService(),
  );

  late FakeTaskRemote remote;
  late MemoryTaskLocal local;
  late NoTaskReminders reminders;

  setUp(() {
    remote = FakeTaskRemote();
    local = MemoryTaskLocal();
    reminders = NoTaskReminders();
  });

  TaskStore store(TideStore tide) {
    final s = TaskStore(
      tide: tide,
      local: local,
      remote: remote,
      reminders: reminders,
    );
    addTearDown(() {
      s.dispose();
      tide.dispose();
    });
    return s;
  }

  group('offline', () {
    test('add, edit, complete and delete all work with no network', () async {
      remote.online = false;
      final tasks = store(tide());

      final milk = tasks.add(title: 'Buy milk');
      final bins = tasks.add(title: 'Bins out', dueDate: DateTime.now());
      tasks.update(tasks.byId(milk.id)!.copyWith(title: 'Buy oat milk'));
      tasks.toggleComplete(bins.id);
      final shed = tasks.add(title: 'Paint the shed');
      tasks.delete(shed.id);
      await tasks.sync();

      expect(tasks.open.map((t) => t.title), ['Buy oat milk']);
      expect(tasks.completed.single.title, 'Bins out');
      expect(remote.rows, isEmpty);
      expect(tasks.hasPendingChanges, isTrue);

      // And it is all on the device, for a relaunch with no network either.
      final saved = local.load('demo-jules');
      expect(saved, hasLength(3), reason: 'two tasks and one tombstone');
    });

    test('a relaunch reads the list back from the device', () async {
      remote.online = false;
      final first = store(tide());
      first.add(title: 'Call the dentist');
      await first.sync();

      final second = store(tide());
      expect(second.open.single.title, 'Call the dentist');
      expect(second.open.single.syncStatus, TaskSyncStatus.pendingCreate);
    });
  });

  group('back online', () {
    test('offline changes reach the server once, with no duplicates', () async {
      remote.online = false;
      final tasks = store(tide());
      final a = tasks.add(title: 'A');
      tasks.update(tasks.byId(a.id)!.copyWith(title: 'A, edited'));
      tasks.update(tasks.byId(a.id)!.copyWith(title: 'A, edited twice'));
      final b = tasks.add(title: 'B');
      final c = tasks.add(title: 'C');
      tasks.delete(c.id);
      await tasks.sync();

      remote.online = true;
      await tasks.sync();

      expect(remote.rows.keys.toSet(), {a.id, b.id, c.id});
      expect(remote.rows[a.id]!.task.title, 'A, edited twice');
      expect(remote.rows[c.id]!.deleted, isTrue);
      expect(tasks.hasPendingChanges, isFalse);
      expect(tasks.all.map((t) => t.id).toSet(), {a.id, b.id});
      expect(tasks.open, hasLength(2));
    });

    test(
      'a push that fails keeps the task pending, and a later one sends it',
      () async {
        final tasks = store(tide());
        remote.online = false;
        final a = tasks.add(title: 'Kept');
        await tasks.sync();
        expect(tasks.byId(a.id)!.syncStatus, TaskSyncStatus.pendingCreate);

        remote.online = true;
        await tasks.sync();
        expect(tasks.byId(a.id)!.syncStatus, TaskSyncStatus.synced);
        expect(remote.rows[a.id]!.task.title, 'Kept');
      },
    );
  });

  group('last write wins', () {
    test(
      'a newer edit from another device replaces an older one here',
      () async {
        final tasks = store(tide());
        final a = tasks.add(title: 'Original');
        await tasks.sync();

        remote.online = false;
        tasks.update(tasks.byId(a.id)!.copyWith(title: 'Edited here'));
        await tasks.sync();

        remote.writeElsewhere(
          tasks
              .byId(a.id)!
              .copyWith(
                title: 'Edited on the tablet, later',
                updatedAt: DateTime.now().add(const Duration(minutes: 5)),
              ),
        );
        remote.online = true;
        await tasks.sync();

        expect(tasks.byId(a.id)!.title, 'Edited on the tablet, later');
        expect(remote.rows[a.id]!.task.title, 'Edited on the tablet, later');
      },
    );

    test(
      'a newer edit here survives an older one from another device',
      () async {
        final tasks = store(tide());
        final a = tasks.add(title: 'Original');
        await tasks.sync();

        remote.writeElsewhere(
          tasks
              .byId(a.id)!
              .copyWith(
                title: 'Stale tablet edit',
                updatedAt: DateTime.now().subtract(const Duration(hours: 1)),
              ),
        );
        tasks.update(tasks.byId(a.id)!.copyWith(title: 'Fresh edit here'));
        await tasks.sync();

        expect(tasks.byId(a.id)!.title, 'Fresh edit here');
        expect(remote.rows[a.id]!.task.title, 'Fresh edit here');
      },
    );

    test('tasks added and deleted on another device arrive here', () async {
      final tasks = store(tide());
      final mine = tasks.add(title: 'Mine');
      await tasks.sync();

      final now = DateTime.now().add(const Duration(seconds: 1));
      remote.writeElsewhere(
        Task(
          id: 'from-tablet',
          title: 'From the tablet',
          createdAt: now,
          updatedAt: now,
        ),
      );
      remote.writeElsewhere(
        tasks.byId(mine.id)!.copyWith(updatedAt: now),
        deleted: true,
      );
      await tasks.sync();

      expect(tasks.open.map((t) => t.title), ['From the tablet']);
    });
  });

  group('repeating tasks', () {
    test('completing one puts the next occurrence on the list', () {
      final tasks = store(tide());
      final today = DateUtils.dateOnly(DateTime.now());
      final a = tasks.add(title: 'Water plants', dueDate: today);
      tasks.update(
        tasks.byId(a.id)!.copyWith(recurrence: TaskRecurrence.daily),
      );

      final completion = tasks.toggleComplete(a.id)!;

      expect(tasks.completed.single.id, a.id);
      final next = tasks.open.single;
      expect(next.id, completion.spawnedId);
      expect(next.dueDate, DateTime(today.year, today.month, today.day + 1));
    });

    test('undo takes the next occurrence back off the list', () {
      final tasks = store(tide());
      final a = tasks.add(title: 'Water plants', dueDate: DateTime.now());
      tasks.update(
        tasks.byId(a.id)!.copyWith(recurrence: TaskRecurrence.weekly),
      );

      final completion = tasks.toggleComplete(a.id)!;
      tasks.undoCompletion(completion);

      expect(tasks.open.single.id, a.id);
      expect(tasks.completed, isEmpty);
    });
  });

  group('reminders', () {
    test('open tasks with reminders are handed to the scheduler', () async {
      final tasks = store(tide());
      final at = DateTime.now().add(const Duration(days: 1));
      final a = tasks.add(title: 'Call');
      tasks.update(tasks.byId(a.id)!.copyWith(reminders: [at]));
      await Future<void>.delayed(const Duration(milliseconds: 400));

      final latest = reminders.scheduled.last;
      expect(latest.single.reminders, [at]);
    });
  });

  group('the free plan', () {
    Task base(TaskStore tasks) =>
        tasks.byId(tasks.add(title: 'Gear service').id)!;

    test('cannot add a custom repeat, a second reminder, tags or archive', () {
      final tasks = store(tide());
      final t = base(tasks);
      final soon = DateTime.now().add(const Duration(days: 1));

      tasks.update(
        t.copyWith(
          recurrence: TaskRecurrence.custom,
          customRecurrenceMonths: 6,
          reminders: [soon, soon.add(const Duration(hours: 1))],
          tags: ['gear'],
        ),
      );
      final saved = tasks.byId(t.id)!;
      expect(saved.recurrence, TaskRecurrence.none);
      expect(saved.reminders, hasLength(AppConstants.freeTaskReminders));
      expect(saved.tags, isEmpty);

      tasks.toggleComplete(t.id);
      expect(tasks.archiveCompleted(), isFalse);
      expect(tasks.archived, isEmpty);
      expect(tasks.setTagFilter('gear'), isFalse);
    });

    test('basic repeats and one reminder are free', () {
      final tasks = store(tide());
      final t = base(tasks);
      final soon = DateTime.now().add(const Duration(days: 1));
      tasks.update(
        t.copyWith(recurrence: TaskRecurrence.monthly, reminders: [soon]),
      );

      final saved = tasks.byId(t.id)!;
      expect(saved.recurrence, TaskRecurrence.monthly);
      expect(saved.reminders, [soon]);
    });

    test('keeps what a lapsed plan set up, without letting it grow', () {
      final tasks = store(tide());
      final soon = DateTime.now().add(const Duration(days: 1));
      final before = base(tasks).copyWith(
        recurrence: TaskRecurrence.custom,
        customRecurrenceMonths: 12,
        reminders: [soon, soon.add(const Duration(hours: 1))],
        tags: ['gear', 'boat'],
      );
      final edited = before.copyWith(
        title: 'Gear service, renamed',
        reminders: [...before.reminders, soon.add(const Duration(hours: 2))],
        tags: ['gear', 'new'],
      );

      final allowed = tasks.withinPlan(edited, before);
      expect(allowed.recurrence, TaskRecurrence.custom);
      expect(allowed.reminders, hasLength(2));
      expect(allowed.tags, ['gear']);
    });
  });

  group('Pro', () {
    test('custom repeats, several reminders, tags and the archive', () {
      final tasks = store(tide(pro: true));
      final t = tasks.byId(tasks.add(title: 'Storm prep').id)!;
      final soon = DateTime.now().add(const Duration(days: 1));

      tasks.update(
        t.copyWith(
          recurrence: TaskRecurrence.custom,
          customRecurrenceMonths: 12,
          reminders: [soon, soon.add(const Duration(hours: 1))],
          tags: ['home'],
        ),
      );
      final saved = tasks.byId(t.id)!;
      expect(saved.recurrence, TaskRecurrence.custom);
      expect(saved.reminders, hasLength(2));
      expect(saved.tags, ['home']);

      expect(tasks.setTagFilter('home'), isTrue);
      expect(tasks.open.single.id, t.id);

      tasks.toggleComplete(t.id);
      expect(tasks.archiveCompleted(), isTrue);
      expect(tasks.archived.map((a) => a.id), contains(t.id));
    });
  });

  group('today', () {
    test('counts what is due or overdue, and what was finished today', () {
      final tasks = store(tide());
      final today = DateUtils.dateOnly(DateTime.now());
      tasks.add(title: 'Due today', dueDate: today);
      tasks.add(
        title: 'Overdue',
        dueDate: today.subtract(const Duration(days: 2)),
      );
      tasks.add(
        title: 'Next week',
        dueDate: today.add(const Duration(days: 7)),
      );
      tasks.add(title: 'Someday');
      final early = tasks.add(
        title: 'Done early',
        dueDate: today.add(const Duration(days: 3)),
      );
      tasks.toggleComplete(early.id);

      final summary = tasks.today;
      expect(summary.total, 3, reason: 'due today, overdue, and done today');
      expect(summary.done, 1);
      expect(summary.overdue, 1);
    });

    test('the swipe tip is dismissed once, for the device', () {
      final tasks = store(tide());
      expect(tasks.swipeHintSeen, isFalse);
      tasks.dismissSwipeHint();
      expect(tasks.swipeHintSeen, isTrue);
      expect(local.swipeHintSeen, isTrue);
    });
  });
}
