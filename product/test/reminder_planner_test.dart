import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tide/services/models/habit.dart';
import 'package:tide/services/models/reminder_options.dart';
import 'package:tide/services/models/tide_glyph.dart';
import 'package:tide/services/reminders/reminder_plan.dart';
import 'package:tide/services/reminders/reminder_settings.dart';
import 'package:tide/services/reminders/reminder_store.dart';
import 'package:tide/services/tasks/task.dart';

/// Thursday 24 September 2026, 08:00.
final DateTime _now = DateTime(2026, 9, 24, 8);

Habit _habit({
  String id = 'gym',
  String name = 'Go to Gym',
  Set<int> days = const {1, 2, 3, 4, 5, 6, 7},
  TimeOfDay time = const TimeOfDay(hour: 10, minute: 0),
  ReminderOptions options = const ReminderOptions(),
  bool enabled = true,
  Map<DateTime, num> logs = const {},
  Set<DateTime> frozen = const {},
  List<PauseSpan> pauses = const [],
}) {
  return Habit(
    id: id,
    name: name,
    glyph: TideGlyph.water,
    type: HabitType.binary,
    createdAt: DateTime(2026, 1, 1),
    days: days,
    reminderEnabled: enabled,
    reminderTime: time,
    reminderOptions: options,
    logs: logs,
    frozenDays: frozen,
    pauses: pauses,
  );
}

Task _task({
  String id = 'parcel',
  List<DateTime> reminders = const [],
  bool completed = false,
  List<Subtask> steps = const [],
}) {
  return Task(
    id: id,
    title: 'Post the parcel',
    createdAt: _now,
    updatedAt: _now,
    reminders: reminders,
    isCompleted: completed,
    subtasks: steps,
  );
}

void main() {
  const settings = ReminderSettings();

  group('habit reminders', () {
    test('a daily habit gets a heads-up and a call on every day ahead', () {
      final plan = ReminderPlanner.habits(
        [_habit()],
        settings,
        now: _now,
        days: 3,
      );

      expect(plan.map((r) => (r.kind, r.at)), [
        (ReminderKind.habitHeadsUp, DateTime(2026, 9, 24, 9, 50)),
        (ReminderKind.habitCall, DateTime(2026, 9, 24, 10)),
        (ReminderKind.habitHeadsUp, DateTime(2026, 9, 25, 9, 50)),
        (ReminderKind.habitCall, DateTime(2026, 9, 25, 10)),
        (ReminderKind.habitHeadsUp, DateTime(2026, 9, 26, 9, 50)),
        (ReminderKind.habitCall, DateTime(2026, 9, 26, 10)),
      ]);
      // The heads-up counts down to the habit's own time.
      expect(plan.first.dueAt, DateTime(2026, 9, 24, 10));
      expect(plan.first.occurrence, plan[1].occurrence);
      expect(plan.first.floating, isTrue);
    });

    test('keys are unique and stable from one plan to the next', () {
      final first = ReminderPlanner.habits([_habit()], settings, now: _now);
      final again = ReminderPlanner.habits([_habit()], settings, now: _now);

      expect(first.map((r) => r.key).toSet(), hasLength(first.length));
      expect(again.map((r) => r.key), first.map((r) => r.key));
      expect(again.map((r) => r.copy), first.map((r) => r.copy));
    });

    test('a time already gone today is left out', () {
      final plan = ReminderPlanner.habits(
        [_habit(time: const TimeOfDay(hour: 7, minute: 0))],
        settings,
        now: _now,
        days: 2,
      );
      expect(plan.every((r) => r.dueAt.day == 25), isTrue);
    });

    test('a heads-up already past still leaves the call', () {
      final plan = ReminderPlanner.habits(
        [_habit(time: const TimeOfDay(hour: 8, minute: 5))],
        settings,
        now: _now,
        days: 1,
      );
      expect(plan.map((r) => r.kind), [ReminderKind.habitCall]);
    });

    test('only scheduled days are reminded', () {
      // Mondays and Fridays. The 24th is a Thursday.
      final plan = ReminderPlanner.habits(
        [
          _habit(days: {1, 5}),
        ],
        settings,
        now: _now,
        days: 7,
      );
      final calls = plan.where((r) => r.kind.isCall).map((r) => r.dueAt.day);
      expect(calls, [25, 28]);
    });

    test('a day already kept or frozen is not reminded', () {
      final today = DateTime(2026, 9, 24);
      final kept = ReminderPlanner.habits(
        [
          _habit(logs: {today: 1}),
        ],
        settings,
        now: _now,
        days: 1,
      );
      final frozen = ReminderPlanner.habits(
        [
          _habit(frozen: {today}),
        ],
        settings,
        now: _now,
        days: 1,
      );
      expect(kept, isEmpty);
      expect(frozen, isEmpty);
    });

    test(
      'a paused habit rests, and a habit with its reminder off is quiet',
      () {
        final paused = ReminderPlanner.habits(
          [
            _habit(pauses: [PauseSpan(start: DateTime(2026, 9, 20))]),
          ],
          settings,
          now: _now,
        );
        final off = ReminderPlanner.habits(
          [_habit(enabled: false)],
          settings,
          now: _now,
        );
        expect(paused, isEmpty);
        expect(off, isEmpty);
      },
    );

    test('a pause ending mid-week picks the reminders back up', () {
      final plan = ReminderPlanner.habits(
        [
          _habit(
            pauses: [
              PauseSpan(
                start: DateTime(2026, 9, 20),
                end: DateTime(2026, 9, 26),
              ),
            ],
          ),
        ],
        settings,
        now: _now,
        days: 4,
      );
      final calls = plan.where((r) => r.kind.isCall).map((r) => r.dueAt.day);
      expect(calls, [26, 27]);
    });

    test('gentle style is a notification; no lead means no heads-up', () {
      final plan = ReminderPlanner.habits(
        [
          _habit(
            options: const ReminderOptions(
              style: AlarmStyle.gentle,
              leadMinutes: 0,
            ),
          ),
        ],
        settings,
        now: _now,
        days: 1,
      );
      expect(plan.map((r) => r.kind), [ReminderKind.habitGentle]);
    });

    test('inside quiet hours the call is quiet and has no heads-up', () {
      final quiet = settings.copyWith(
        quietHours: true,
        quietStart: const TimeOfDay(hour: 22, minute: 0),
        quietEnd: const TimeOfDay(hour: 7, minute: 0),
      );
      final plan = ReminderPlanner.habits(
        [_habit(time: const TimeOfDay(hour: 22, minute: 30))],
        quiet,
        now: _now,
        days: 1,
      );
      expect(plan.map((r) => (r.kind, r.quiet)), [
        (ReminderKind.habitCall, true),
      ]);
    });

    test('a heads-up that would land in quiet hours is dropped', () {
      final quiet = settings.copyWith(
        quietHours: true,
        quietEnd: const TimeOfDay(hour: 10, minute: 0),
      );
      final plan = ReminderPlanner.habits(
        [_habit(time: const TimeOfDay(hour: 10, minute: 5))],
        quiet,
        now: _now,
        days: 1,
      );
      expect(plan.map((r) => (r.kind, r.quiet)), [
        (ReminderKind.habitCall, false),
      ]);
    });

    test('switching reminders off plans nothing at all', () {
      final plan = ReminderPlanner.habits(
        [_habit()],
        settings.copyWith(enabled: false),
        now: _now,
      );
      expect(plan, isEmpty);
    });

    test('the plan is soonest first and capped', () {
      final plan = ReminderPlanner.habits(
        [
          _habit(id: 'late', time: const TimeOfDay(hour: 20, minute: 0)),
          _habit(id: 'early', time: const TimeOfDay(hour: 9, minute: 0)),
        ],
        settings,
        now: _now,
        limit: 5,
      );
      expect(plan, hasLength(5));
      for (var i = 1; i < plan.length; i++) {
        expect(plan[i].at.isBefore(plan[i - 1].at), isFalse);
      }
      expect(plan.first.subjectId, 'early');
    });

    test('the call carries the streak, the week and the words', () {
      final logs = {
        for (var back = 1; back <= 4; back++) DateTime(2026, 9, 24 - back): 1,
      };
      final call = ReminderPlanner.habits(
        [_habit(logs: logs)],
        settings,
        now: _now,
        days: 1,
      ).last;

      expect(call.details['streak'], 4);
      expect(call.details['day'], '2026-09-24');
      expect(call.details['week'], [
        WeekMark.missed.index,
        WeekMark.missed.index,
        WeekMark.kept.index,
        WeekMark.kept.index,
        WeekMark.kept.index,
        WeekMark.kept.index,
        WeekMark.open.index,
      ]);
      expect(call.copy['subtitle'], 'Day 5 · Your tide is at its highest');
      expect(call.copy['done'], 'Streak: 5 days');
      expect(call.copy['headsUp'], 'Tide rises in 10 min');
      expect(call.copy['missed'], contains('Go to Gym'));
    });

    test('habits still owed today are the only open subjects', () {
      final today = DateTime(2026, 9, 24);
      final open = ReminderPlanner.openHabitSubjects([
        _habit(id: 'owed'),
        _habit(id: 'kept', logs: {today: 1}),
        _habit(id: 'off', enabled: false),
        _habit(id: 'rest', days: {1}),
      ], _now);
      expect(open, {'owed'});
    });

    test('a reminder survives the trip to the phone and back', () {
      final call = ReminderPlanner.habits(
        [_habit()],
        settings,
        now: _now,
        accountId: 'demo',
      ).first;
      final back = PlannedReminder.fromJson(call.toJson())!;

      expect(back.key, call.key);
      expect(back.kind, call.kind);
      expect(back.at, call.at);
      expect(back.dueAt, call.dueAt);
      expect(back.accountId, 'demo');
      expect(back.options, call.options);
      expect(back.copy, call.copy);
      expect(back.details['week'], call.details['week']);
    });
  });

  group('to-do reminders', () {
    test(
      'each future reminder on an open task is a Beacon and a Lighthouse',
      () {
        final plan = ReminderPlanner.tasks(
          [
            _task(
              reminders: [DateTime(2026, 9, 24, 7), DateTime(2026, 9, 24, 12)],
            ),
          ],
          settings,
          now: _now,
        );
        expect(plan.map((r) => (r.kind, r.at)), [
          (ReminderKind.taskHeadsUp, DateTime(2026, 9, 24, 11, 50)),
          (ReminderKind.taskCall, DateTime(2026, 9, 24, 12)),
        ]);
        expect(plan.first.floating, isFalse);
      },
    );

    test('finished and deleted tasks ring for nothing', () {
      final plan = ReminderPlanner.tasks(
        [
          _task(completed: true, reminders: [DateTime(2026, 9, 24, 12)]),
          _task(
            id: 'gone',
            reminders: [DateTime(2026, 9, 24, 12)],
          ).copyWith(syncStatus: TaskSyncStatus.pendingDelete),
        ],
        settings,
        now: _now,
      );
      expect(plan, isEmpty);
    });

    test('the to-do defaults decide the style', () {
      final plan = ReminderPlanner.tasks(
        [
          _task(reminders: [DateTime(2026, 9, 24, 12)]),
        ],
        settings.copyWith(
          taskDefaults: const ReminderOptions(
            style: AlarmStyle.gentle,
            leadMinutes: 0,
          ),
        ),
        now: _now,
      );
      expect(plan.map((r) => r.kind), [ReminderKind.taskGentle]);
    });

    test('the call carries its steps', () {
      final call = ReminderPlanner.tasks(
        [
          _task(
            reminders: [DateTime(2026, 9, 24, 12)],
            steps: const [
              Subtask(id: 'a', title: 'Tape it', isCompleted: true),
              Subtask(id: 'b', title: 'Label it'),
            ],
          ),
        ],
        settings,
        now: _now,
      ).last;
      expect(call.details['steps'], [
        {'id': 'a', 'title': 'Tape it', 'done': true},
        {'id': 'b', 'title': 'Label it', 'done': false},
      ]);
      expect(call.copy['steps'], '1 of 2 steps done');
    });

    test('moving to tomorrow brings the rung reminder back tomorrow', () {
      final task = _task(
        reminders: [DateTime(2026, 9, 24, 7), DateTime(2026, 9, 30, 9)],
      ).copyWith(dueDate: DateTime(2026, 9, 24));
      final moved = ReminderStore.movedToTomorrow(task, _now);

      expect(moved.dueDate, DateTime(2026, 9, 25));
      expect(moved.reminders, [
        DateTime(2026, 9, 25, 7),
        DateTime(2026, 9, 30, 9),
      ]);
    });
  });

  group('the test button', () {
    test('a heads-up, then the call, marked as a test', () {
      final plan = ReminderPlanner.habitTest(null, settings, now: _now);
      expect(plan.map((r) => r.kind), [
        ReminderKind.habitHeadsUp,
        ReminderKind.habitCall,
      ]);
      expect(plan.every((r) => r.test), isTrue);
      expect(plan.first.at, _now.add(const Duration(seconds: 10)));
      expect(plan.last.at, _now.add(const Duration(seconds: 20)));
      expect(plan.first.key, isNot(plan.last.key));
    });

    test('works for a to-do too', () {
      final plan = ReminderPlanner.taskTest(null, settings, now: _now);
      expect(plan.map((r) => r.kind), [
        ReminderKind.taskHeadsUp,
        ReminderKind.taskCall,
      ]);
    });
  });

  group('settings', () {
    test('quiet hours can cross midnight', () {
      final quiet = settings.copyWith(quietHours: true);
      expect(quiet.isQuietAt(DateTime(2026, 9, 24, 23, 30)), isTrue);
      expect(quiet.isQuietAt(DateTime(2026, 9, 24, 6, 59)), isTrue);
      expect(quiet.isQuietAt(DateTime(2026, 9, 24, 7)), isFalse);
      expect(settings.isQuietAt(DateTime(2026, 9, 24, 23, 30)), isFalse);
    });

    test('settings and options survive a round trip', () {
      final custom = settings.copyWith(
        quietHours: true,
        quietStart: const TimeOfDay(hour: 21, minute: 15),
        habitDefaults: const ReminderOptions(
          leadMinutes: 15,
          tone: ReminderTone.deepBell,
          snoozeMinutes: 5,
          throughDnd: true,
        ),
      );
      expect(ReminderSettings.fromJson(custom.toJson()), custom);
    });

    test('an option this build does not know falls back', () {
      final read = ReminderOptions.fromJson({
        'lead': 20,
        'style': 'siren',
        'tone': 'foghorn',
        'snooze': 7,
      });
      expect(read, const ReminderOptions());
    });
  });
}
