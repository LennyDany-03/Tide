import 'package:flutter/material.dart' show DateUtils;
import 'package:flutter_test/flutter_test.dart';
import 'package:tide/services/models/habit.dart';
import 'package:tide/services/models/tide_glyph.dart';
import 'package:tide/services/streak_calculator.dart';

/// A fixed "today" so these tests do not drift with the wall clock.
final DateTime today = DateTime(2026, 8, 30);

DateTime daysAgo(int n) => today.subtract(Duration(days: n));

Habit habit({
  Set<int> logged = const {},
  Set<int> frozen = const {},
  num target = 1,
  Set<int> days = const {1, 2, 3, 4, 5, 6, 7},
  int createdDaysAgo = 120,
}) {
  return Habit(
    id: 'test',
    name: 'Test',
    glyph: TideGlyph.dot,
    type: HabitType.binary,
    target: target,
    days: days,
    createdAt: daysAgo(createdDaysAgo),
    logs: {for (final n in logged) daysAgo(n): target},
    frozenDays: {for (final n in frozen) daysAgo(n)},
  );
}

void main() {
  group('currentStreak', () {
    test('counts back from today when today is logged', () {
      final subject = habit(logged: {0, 1, 2, 3});
      expect(StreakCalculator.currentStreak(subject, asOf: today), 4);
    });

    test('an unlogged today does not break the streak', () {
      // The grace period: at 9am, before you have logged anything, a
      // 12-day streak must still read as 12 rather than 0.
      final subject = habit(logged: {1, 2, 3, 4, 5});
      expect(StreakCalculator.currentStreak(subject, asOf: today), 5);
    });

    test('stops at the first missed day', () {
      final subject = habit(logged: {0, 1, 3, 4, 5});
      expect(StreakCalculator.currentStreak(subject, asOf: today), 2);
    });

    test('a frozen day preserves the streak across the gap', () {
      final subject = habit(logged: {0, 1, 3, 4}, frozen: {2});
      expect(StreakCalculator.currentStreak(subject, asOf: today), 5);
    });

    test('unscheduled days are skipped rather than counted as misses', () {
      // Weekdays only. 2026-08-30 is a Sunday, so the weekend either side
      // must not break a Mon–Fri streak.
      final subject = habit(
        logged: {2, 3, 4, 5, 6},
        days: const {1, 2, 3, 4, 5},
      );
      expect(StreakCalculator.currentStreak(subject, asOf: today), 5);
    });
  });

  group('bestStreak', () {
    test('finds the longest historical run, not the current one', () {
      final subject = habit(
        logged: {
          ...List.generate(3, (i) => i), // current run of 3
          ...List.generate(9, (i) => i + 10), // older run of 9
        },
      );
      expect(StreakCalculator.bestStreak(subject, asOf: today), 9);
    });

    test('is at least the current streak', () {
      final subject = habit(logged: {0, 1, 2, 3, 4});
      expect(StreakCalculator.bestStreak(subject, asOf: today), 5);
    });
  });

  group('completionRate', () {
    test('is the share of scheduled days completed in the window', () {
      final subject = habit(logged: List.generate(15, (i) => i).toSet());
      expect(
        StreakCalculator.completionRate(subject, days: 30, asOf: today),
        closeTo(0.5, 0.001),
      );
    });

    test('frozen days count as completed', () {
      final subject = habit(
        logged: List.generate(9, (i) => i).toSet(),
        frozen: {9},
      );
      expect(
        StreakCalculator.completionRate(subject, days: 10, asOf: today),
        1.0,
      );
    });

    test('does not count days before the habit existed', () {
      final subject = habit(logged: {0, 1, 2}, createdDaysAgo: 2);
      expect(
        StreakCalculator.completionRate(subject, days: 30, asOf: today),
        1.0,
      );
    });
  });

  group('daySummary', () {
    test('aggregates across habits and reports the ratio', () {
      final habits = [
        habit(logged: {0}),
        habit(logged: {0}),
        habit(logged: {1}),
        habit(logged: {1}),
      ];
      final summary = StreakCalculator.daySummary(habits, today);

      expect(summary.scheduled, 4);
      expect(summary.completed, 2);
      expect(summary.ratio, 0.5);
      expect(summary.isFullyLogged, isFalse);
    });

    test('a frozen habit counts toward the day being complete', () {
      final habits = [
        habit(logged: {0}),
        habit(frozen: {0}),
      ];
      final summary = StreakCalculator.daySummary(habits, today);

      expect(summary.completed, 2);
      expect(summary.frozen, 1);
      expect(summary.isFullyLogged, isTrue);
    });

    test('paused habits are excluded entirely', () {
      final habits = [
        habit(logged: {0}),
        habit().copyWith(paused: true),
      ];
      expect(StreakCalculator.daySummary(habits, today).scheduled, 1);
    });
  });

  test('weeklySeries returns one point per week, oldest first', () {
    final series = StreakCalculator.weeklySeries(
      [
        habit(logged: {0, 1, 2}),
      ],
      weeks: 8,
      asOf: today,
    );
    expect(series, hasLength(8));
    expect(series.every((v) => v >= 0 && v <= 1), isTrue);
  });

  test('freezesSpent only counts freezes inside the window', () {
    final subject = habit(frozen: {5, 40});
    expect(StreakCalculator.freezesSpent([subject], days: 30, asOf: today), 1);
  });

  test('log dates are normalised, so time of day never matters', () {
    final subject = habit(logged: {0});
    final afternoon = DateUtils.dateOnly(today).add(const Duration(hours: 15));
    expect(subject.isCompleteOn(afternoon), isTrue);
  });
}
