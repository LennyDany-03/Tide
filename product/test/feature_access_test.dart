import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tide/config/app_constants.dart';
import 'package:tide/services/auth/demo_auth_service.dart';
import 'package:tide/services/device_flags.dart';
import 'package:tide/services/haptics.dart';
import 'package:tide/services/models/habit.dart';
import 'package:tide/services/tasks/task.dart';
import 'package:tide/services/models/tide_glyph.dart';
import 'package:tide/services/tasks/task_store.dart';
import 'package:tide/services/tide_store.dart';

/// Nothing in Tide is behind a plan.
///
/// This file is the inverse of what `pro_gating_test.dart` used to assert.
/// Tide shipped free, so every ceiling the paywall used to sell past is gone
/// — and the way that regresses is somebody reintroducing a limit constant
/// and quietly wiring a screen to it. Each group here holds one former gate
/// open.
void main() {
  // TaskStore opens an AppLifecycleListener, which needs a binding.
  TestWidgetsFlutterBinding.ensureInitialized();

  TideStore account() => TideStore(
    auth: DemoAuthService(signedIn: true),
    flags: DeviceFlags.memory(onboardingSeen: true),
  );

  group('habits', () {
    test('there is no ceiling on how many habits an account keeps', () {
      final store = account();
      final before = store.activeHabitCount;
      for (var i = 0; i < 12; i++) {
        store.addHabit(
          Habit(
            id: store.newHabitId(),
            name: 'Another $i',
            glyph: TideGlyph.dot,
            type: HabitType.binary,
            createdAt: DateTime.now(),
          ),
        );
      }
      expect(store.activeHabitCount, before + 12);
    });
  });

  group('history', () {
    test('every day ever logged is visible', () {
      final store = account();
      for (final days in [1, 30, 31, 400, 900]) {
        expect(
          store.canSee(DateTime.now().subtract(Duration(days: days))),
          isTrue,
          reason: '$days days ago',
        );
      }
    });

    test('tomorrow is still nobody\'s to see', () {
      // The one rule that survived: it was never about a plan.
      expect(account().canSee(DateTime.now().add(const Duration(days: 1))), isFalse);
      expect(account().canSee(DateUtils.dateOnly(DateTime.now())), isTrue);
    });
  });

  group('freezes', () {
    test('the stepper runs to the full allowance', () {
      expect(
        AppConstants.maxFreezeAllowance,
        greaterThan(AppConstants.defaultFreezeAllowance),
      );
    });
  });

  group('preferences', () {
    test('the weekly recap turns on and stays on', () {
      final store = account();
      store.setPreference(weeklyRecap: true);
      expect(store.weeklyRecap, isTrue);
      store.setPreference(weeklyRecap: false);
      expect(store.weeklyRecap, isFalse);
    });

    test('haptics default on, and turning them off silences the gate', () {
      final store = account();
      expect(store.haptics, isTrue);
      expect(TideHaptics.enabled, isTrue);

      store.setPreference(haptics: false);
      expect(store.haptics, isFalse);
      expect(TideHaptics.enabled, isFalse);

      store.setPreference(haptics: true);
      expect(TideHaptics.enabled, isTrue);
    });
  });

  group('to-dos', () {
    TaskStore tasks() => TaskStore(tide: account());

    test('a custom repeat is kept, clamped only to a sane number of months', () {
      final store = tasks();
      final task = store.add(title: 'Renew the licence');
      store.update(
        task.copyWith(
          recurrence: TaskRecurrence.custom,
          customRecurrenceMonths: 12,
        ),
      );
      final saved = store.byId(task.id)!;
      expect(saved.recurrence, TaskRecurrence.custom);
      expect(saved.customRecurrenceMonths, 12);
    });

    test('several reminders survive a save', () {
      final store = tasks();
      final task = store.add(title: 'Call the dentist');
      final now = DateTime.now();
      final reminders = [
        now.add(const Duration(hours: 1)),
        now.add(const Duration(hours: 5)),
        now.add(const Duration(days: 1)),
      ];
      store.update(task.copyWith(reminders: reminders));
      expect(store.byId(task.id)!.reminders, hasLength(3));
    });

    test('tags are kept, and the list filters by one', () {
      final store = tasks();
      final task = store.add(title: 'Post the forms');
      store.update(task.copyWith(tags: const ['errand']));
      expect(store.byId(task.id)!.tags, const ['errand']);

      expect(store.setTagFilter('errand'), isTrue);
      expect(store.activeTagFilter, 'errand');
    });

    test('completed tasks archive', () {
      final store = tasks();
      final task = store.add(title: 'Book the tickets');
      store.toggleComplete(task.id);
      expect(store.archiveCompleted(), isTrue);
      expect(store.archived, isNotEmpty);
    });
  });
}
