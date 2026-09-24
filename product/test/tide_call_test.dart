import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tide/screens/tide_call/call_deck.dart';
import 'package:tide/services/auth/demo_auth_service.dart';
import 'package:tide/services/device_flags.dart';
import 'package:tide/services/reminders/call_controller.dart';
import 'package:tide/services/reminders/reminder_plan.dart';
import 'package:tide/services/reminders/reminder_platform.dart';
import 'package:tide/services/reminders/reminder_settings.dart';
import 'package:tide/services/reminders/reminder_store.dart';
import 'package:tide/services/tasks/task.dart';
import 'package:tide/services/tasks/task_local.dart';
import 'package:tide/services/tasks/task_store.dart';
import 'package:tide/services/tide_store.dart';
import 'package:tide/theme/tide_theme.dart';

/// Pumps in small steps: the call screens chain an animation into a
/// farewell timer into a retire, and never settle — the water keeps moving.
Future<void> _run(WidgetTester tester, [int ms = 2600]) async {
  for (var elapsed = 0; elapsed < ms; elapsed += 100) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

class _Harness {
  _Harness() {
    tide = TideStore(
      auth: DemoAuthService(signedIn: true),
      flags: DeviceFlags.memory(onboardingSeen: true),
    );
    platform = NoReminderPlatform();
    reminders = ReminderStore(
      tide: tide,
      platform: platform,
      prefs: ReminderPrefs.memory(),
      watchLifecycle: false,
    );
    tasks = TaskStore(
      tide: tide,
      local: MemoryTaskLocal(),
      reminders: reminders.taskReminders,
    );
    reminders.attachTasks(tasks);
  }

  late final TideStore tide;
  late final NoReminderPlatform platform;
  late final ReminderStore reminders;
  late final TaskStore tasks;
  bool closed = false;

  InAppCallController controller(List<PlannedReminder> calls) =>
      InAppCallController(
        reminders: reminders,
        calls: calls,
        onClose: () => closed = true,
      );

  PlannedReminder habitCall(String habitId) {
    final habit = tide.habitById(habitId)!;
    final now = DateTime.now();
    final call = ReminderPlanner.habitTest(
      habit,
      reminders.settings,
      now: now,
    ).last;
    // A real call, not a test: answers reach the store.
    return PlannedReminder.fromJson({
      ...call.toJson(),
      'key': 'h:$habitId:call',
      'test': false,
      'account': tide.account!.id,
    })!;
  }

  PlannedReminder taskCall(Task task) {
    final call = ReminderPlanner.taskTest(
      task,
      reminders.settings,
      now: DateTime.now(),
    ).last;
    return PlannedReminder.fromJson({
      ...call.toJson(),
      'key': 't:${task.id}:call',
      'test': false,
      'account': tide.account!.id,
    })!;
  }

  void dispose() {
    tasks.dispose();
    reminders.dispose();
    tide.dispose();
  }
}

Future<void> _show(WidgetTester tester, CallController controller) async {
  await tester.binding.setSurfaceSize(const Size(400, 860));
  await tester.pumpWidget(
    MaterialApp(
      theme: TideTheme.current,
      home: CallDeck(controller: controller),
    ),
  );
  await tester.pump(const Duration(milliseconds: 900));
}

void main() {
  late _Harness harness;

  setUp(() => harness = _Harness());
  tearDown(() => harness.dispose());

  group('Tide Call', () {
    testWidgets('shows the habit, its day and how to answer', (tester) async {
      final controller = harness.controller([
        harness.habitCall('morning-water'),
      ]);
      await _show(tester, controller);

      expect(find.text('Morning water'), findsOneWidget);
      expect(find.textContaining('Day '), findsOneWidget);
      expect(find.text('Swipe up to ride the wave'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
      expect(find.text('Skip today'), findsOneWidget);
      expect(find.text('Dismiss'), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp('Double-tap to mark done')),
        findsOneWidget,
      );
    });

    testWidgets('swiping up rides the habit in', (tester) async {
      final controller = harness.controller([
        harness.habitCall('morning-water'),
      ]);
      await _show(tester, controller);
      final today = DateTime.now();
      expect(
        harness.tide.habitById('morning-water')!.isCompleteOn(today),
        isFalse,
      );

      await tester.dragFrom(const Offset(200, 780), const Offset(0, -420));
      await _run(tester);

      expect(
        harness.tide.habitById('morning-water')!.isCompleteOn(today),
        isTrue,
      );
      expect(harness.tide.pendingHabitCue, isNull);
      expect(harness.closed, isTrue);
    });

    testWidgets('a short swipe springs back and changes nothing', (
      tester,
    ) async {
      final controller = harness.controller([
        harness.habitCall('morning-water'),
      ]);
      await _show(tester, controller);

      await tester.dragFrom(const Offset(200, 780), const Offset(0, -60));
      await _run(tester, 1200);

      expect(
        harness.tide.habitById('morning-water')!.isCompleteOn(DateTime.now()),
        isFalse,
      );
      expect(harness.closed, isFalse);
    });

    testWidgets('snooze hands the call back to the phone for later', (
      tester,
    ) async {
      final controller = harness.controller([
        harness.habitCall('morning-water'),
      ]);
      await _show(tester, controller);

      await tester.tap(find.text('Snooze 10 min'));
      await _run(tester);

      expect(find.text('Back in 10 min'), findsNothing, reason: 'closed');
      final snoozed = harness.platform.snoozes.single;
      expect(snoozed.after, const Duration(minutes: 10));
      expect(snoozed.snoozes, 1);
      expect(harness.closed, isTrue);
    });

    testWidgets('skip spends a freeze on the day', (tester) async {
      final controller = harness.controller([
        harness.habitCall('morning-water'),
      ]);
      await _show(tester, controller);

      await tester.tap(find.text('Skip today'));
      await _run(tester);

      expect(
        harness.tide.habitById('morning-water')!.isFrozenOn(DateTime.now()),
        isTrue,
      );
    });

    testWidgets('two habits at once ring as one call with Done all', (
      tester,
    ) async {
      final controller = harness.controller([
        harness.habitCall('morning-water'),
        harness.habitCall('read-pages'),
      ]);
      await _show(tester, controller);

      expect(find.text('Done all'), findsOneWidget);
      await tester.tap(find.text('Done all'));
      await _run(tester);

      expect(find.text('All 2 in'), findsNothing, reason: 'closed');
      expect(
        harness.tide.habitById('morning-water')!.isCompleteOn(DateTime.now()),
        isTrue,
      );
      expect(harness.closed, isTrue);
    });
  });

  group('Lighthouse', () {
    testWidgets('will not dock with steps open, and docks once they are', (
      tester,
    ) async {
      final task = harness.tasks.add(
        title: 'Post the parcel',
        subtasks: const [Subtask(id: 'label', title: 'Print the label')],
      );
      final controller = harness.controller([harness.taskCall(task)]);
      await _show(tester, controller);

      expect(find.text('Post the parcel'), findsOneWidget);
      expect(find.text('1 step left — tick it to dock'), findsOneWidget);

      await tester.drag(
        find.text('1 step left — tick it to dock'),
        const Offset(320, 0),
      );
      await _run(tester, 600);
      expect(harness.tasks.byId(task.id)!.isCompleted, isFalse);

      await tester.tap(find.text('Print the label'));
      await _run(tester, 400);
      expect(harness.tasks.byId(task.id)!.subtasksLeft, 0);
      expect(find.text('Slide to dock'), findsOneWidget);

      await tester.drag(find.text('Slide to dock'), const Offset(360, 0));
      await _run(tester);

      expect(harness.tasks.byId(task.id)!.isCompleted, isTrue);
      expect(harness.closed, isTrue);
    });

    testWidgets('tomorrow moves the to-do on a day', (tester) async {
      final task = harness.tasks.add(
        title: 'Water the plants',
        dueDate: DateTime.now(),
      );
      final controller = harness.controller([harness.taskCall(task)]);
      await _show(tester, controller);

      await tester.tap(find.text('Tomorrow'));
      await _run(tester);

      final moved = harness.tasks.byId(task.id)!;
      expect(
        moved.dueDate,
        DateUtils.addDaysToDate(DateUtils.dateOnly(DateTime.now()), 1),
      );
    });
  });

  testWidgets('habits ring before to-dos when both are due', (tester) async {
    final task = harness.tasks.add(title: 'Call the plumber');
    final controller = harness.controller([
      harness.taskCall(task),
      harness.habitCall('morning-water'),
    ]);
    await _show(tester, controller);

    expect(find.text('Morning water'), findsOneWidget);
    expect(find.text('Call the plumber'), findsNothing);

    await tester.tap(find.text('Done'));
    await _run(tester);

    expect(find.text('Call the plumber'), findsOneWidget);
    expect(harness.closed, isFalse);
  });
}
