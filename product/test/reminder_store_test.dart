import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tide/services/auth/demo_auth_service.dart';
import 'package:tide/services/device_flags.dart';
import 'package:tide/services/reminders/reminder_plan.dart';
import 'package:tide/services/reminders/reminder_platform.dart';
import 'package:tide/services/reminders/reminder_settings.dart';
import 'package:tide/services/reminders/reminder_store.dart';
import 'package:tide/services/tasks/task.dart';
import 'package:tide/services/tasks/task_local.dart';
import 'package:tide/services/tide_store.dart';
import 'package:tide/services/tasks/task_store.dart';

/// Six in the morning today: every seed habit's reminder is still to come.
final DateTime _dawn = DateUtils.dateOnly(
  DateTime.now(),
).add(const Duration(hours: 6));

/// Long enough for the store's debounce to run out.
Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 450));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TideStore tide;
  late NoReminderPlatform platform;
  late ReminderStore reminders;
  late TaskStore tasks;

  void build({
    NoReminderPlatform? phone,
    ReminderSettings settings = const ReminderSettings(),
    bool signedIn = true,
  }) {
    tide = TideStore(
      auth: DemoAuthService(signedIn: signedIn),
      flags: DeviceFlags.memory(onboardingSeen: true),
    );
    platform = phone ?? NoReminderPlatform();
    reminders = ReminderStore(
      tide: tide,
      platform: platform,
      prefs: ReminderPrefs.memory(settings: settings),
      clock: () => _dawn,
      watchLifecycle: false,
    );
    tasks = TaskStore(
      tide: tide,
      local: MemoryTaskLocal(),
      reminders: reminders.taskReminders,
      clock: () => _dawn,
    );
    reminders.attachTasks(tasks);
    addTearDown(() {
      tasks.dispose();
      reminders.dispose();
      tide.dispose();
    });
  }

  List<PlannedReminder> habitPlan() =>
      platform.scheduled[ReminderGroup.habits] ?? const [];

  group('plans', () {
    test('the signed-in account\'s habits are handed to the phone', () async {
      build();
      await _settle();

      final subjects = habitPlan().map((r) => r.subjectId).toSet();
      expect(subjects, contains('morning-water'));
      expect(habitPlan().every((r) => r.accountId == 'demo-jules'), isTrue);
    });

    test('keeping a habit today takes today\'s reminder away', () async {
      build();
      await _settle();
      bool owedToday() => habitPlan().any(
        (r) =>
            r.subjectId == 'morning-water' &&
            DateUtils.isSameDay(r.dueAt, _dawn),
      );
      expect(owedToday(), isTrue);

      tide.log('morning-water', date: _dawn);
      await _settle();

      expect(owedToday(), isFalse);
      expect(
        platform.openSubjects[ReminderGroup.habits],
        isNot(contains('morning-water')),
      );
    });

    test('nobody signed in, nothing scheduled', () async {
      build(signedIn: false);
      await _settle();
      expect(habitPlan(), isEmpty);
    });

    test('switching reminders off empties both plans', () async {
      build();
      tasks.add(
        title: 'Call the plumber',
        reminders: [_dawn.add(const Duration(hours: 3))],
      );
      await _settle();
      expect(platform.scheduled[ReminderGroup.tasks], isNotEmpty);

      reminders.updateSettings(reminders.settings.copyWith(enabled: false));
      await _settle();

      expect(habitPlan(), isEmpty);
      expect(platform.scheduled[ReminderGroup.tasks], isEmpty);
    });

    test('a to-do reminder becomes a Beacon and a Lighthouse', () async {
      build();
      tasks.add(
        title: 'Call the plumber',
        reminders: [_dawn.add(const Duration(hours: 3))],
      );
      await _settle();

      expect(platform.scheduled[ReminderGroup.tasks]!.map((r) => r.kind), [
        ReminderKind.taskHeadsUp,
        ReminderKind.taskCall,
      ]);
    });
  });

  group('answers from the lock screen', () {
    ReminderAction action(
      ReminderActionType type,
      String subject, {
      String? account = 'demo-jules',
      String? step,
      bool value = true,
    }) => ReminderAction(
      id: '${type.name}-$subject',
      type: type,
      subjectId: subject,
      at: _dawn,
      day: DateUtils.dateOnly(_dawn),
      accountId: account,
      stepId: step,
      value: value,
    );

    test('done logs the habit without a celebration', () async {
      build();
      expect(tide.habitById('morning-water')!.isCompleteOn(_dawn), isFalse);

      platform.queue(action(ReminderActionType.habitDone, 'morning-water'));
      await _settle();

      expect(tide.habitById('morning-water')!.isCompleteOn(_dawn), isTrue);
      expect(tide.pendingHabitCue, isNull);
    });

    test('skip spends a freeze on the day', () async {
      build();
      final before = tide.habitById('morning-water')!.freezesRemaining;

      platform.queue(action(ReminderActionType.habitSkip, 'morning-water'));
      await _settle();

      final habit = tide.habitById('morning-water')!;
      expect(habit.isFrozenOn(_dawn), isTrue);
      expect(habit.freezesRemaining, before - 1);
    });

    test('an answer from another account is not applied', () async {
      build();
      platform.queue(
        action(
          ReminderActionType.habitDone,
          'morning-water',
          account: 'somebody-else',
        ),
      );
      await _settle();

      expect(tide.habitById('morning-water')!.isCompleteOn(_dawn), isFalse);
    });

    test('a to-do is ticked step by step, then docked', () async {
      build();
      final task = tasks.add(
        title: 'Post the parcel',
        subtasks: const [Subtask(id: 'label', title: 'Print the label')],
      );

      platform.queue(action(ReminderActionType.taskDone, task.id));
      await _settle();
      expect(tasks.byId(task.id)!.isCompleted, isFalse, reason: 'a step open');

      platform
        ..queue(action(ReminderActionType.taskStep, task.id, step: 'label'))
        ..queue(action(ReminderActionType.taskDone, task.id));
      await _settle();

      expect(tasks.byId(task.id)!.subtasksLeft, 0);
      expect(tasks.byId(task.id)!.isCompleted, isTrue);
    });

    test('tomorrow moves the to-do and its reminder', () async {
      build();
      final rang = _dawn.subtract(const Duration(minutes: 1));
      final task = tasks.add(
        title: 'Water the plants',
        dueDate: _dawn,
        reminders: [rang],
      );

      platform.queue(action(ReminderActionType.taskTomorrow, task.id));
      await _settle();

      final moved = tasks.byId(task.id)!;
      expect(
        moved.dueDate,
        DateUtils.addDaysToDate(DateUtils.dateOnly(_dawn), 1),
      );
      expect(moved.reminders.single, rang.add(const Duration(days: 1)));
    });
  });

  group('permissions', () {
    test(
      'a refused permission raises the banner until it is granted',
      () async {
        build(
          phone: NoReminderPlatform(
            permissionsAsked: const [
              ReminderPermission.notifications,
              ReminderPermission.battery,
            ],
          ),
        );
        await _settle();
        expect(reminders.missing, [ReminderPermission.notifications]);
        expect(reminders.needsAttention, isTrue);

        await reminders.request(ReminderPermission.notifications);

        expect(reminders.missing, isEmpty);
        expect(reminders.needsAttention, isFalse);
        expect(reminders.grantedCount, 1, reason: 'battery is still to ask');
      },
    );

    test('no reminders in use, no banner', () async {
      build(
        phone: NoReminderPlatform(
          permissionsAsked: const [ReminderPermission.notifications],
        ),
        settings: const ReminderSettings(enabled: false),
      );
      await _settle();
      expect(reminders.needsAttention, isFalse);
    });

    test('the banner can be waved away for the session', () async {
      build(
        phone: NoReminderPlatform(
          permissionsAsked: const [ReminderPermission.notifications],
        ),
      );
      await _settle();
      reminders.dismissBanner();
      expect(reminders.needsAttention, isFalse);
    });
  });

  test(
    'the test button rings a heads-up and a call for a real habit',
    () async {
      build();
      await reminders.testHabit();

      final rung = platform.tests.single;
      expect(rung.map((r) => r.kind), [
        ReminderKind.habitHeadsUp,
        ReminderKind.habitCall,
      ]);
      expect(rung.every((r) => r.test), isTrue);
      expect(tide.habitById(rung.first.subjectId), isNotNull);
    },
  );
}
