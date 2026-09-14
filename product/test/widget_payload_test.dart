import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tide/config/app_constants.dart';
import 'package:tide/services/home_widget/widget_payload.dart';
import 'package:tide/services/models/habit.dart';
import 'package:tide/services/models/tide_glyph.dart';
import 'package:tide/services/streak_calculator.dart';

final _today = DateTime(2026, 9, 14);

Habit _habit(
  String id,
  String name, {
  HabitType type = HabitType.binary,
  Set<int>? days,
  Map<DateTime, num> logs = const {},
  Set<DateTime> frozenDays = const {},
  List<PauseSpan> pauses = const [],
}) => Habit(
  id: id,
  name: name,
  glyph: TideGlyph.dot,
  type: type,
  createdAt: DateTime(2026, 1, 1),
  days: days ?? const {1, 2, 3, 4, 5, 6, 7},
  logs: logs,
  frozenDays: frozenDays,
  pauses: pauses,
);

/// [streakDays] consecutive completed days ending on [_today], so
/// [StreakCalculator.currentStreak] returns [streakDays] for the result.
Habit _streakHabit(String id, String name, int streakDays) => _habit(
  id,
  name,
  logs: {
    for (var i = 0; i < streakDays; i++)
      DateUtils.addDaysToDate(_today, -i): 1,
  },
);

void main() {
  group('WidgetPayload.todayHabits', () {
    test('includes only habits due today', () {
      final due = _habit('1', 'Water', days: {_today.weekday});
      final notDue = _habit('2', 'Guitar', days: {(_today.weekday % 7) + 1});
      final paused = _habit(
        '3',
        'Reading',
        pauses: [PauseSpan(start: DateUtils.addDaysToDate(_today, -1))],
      );

      final payload = WidgetPayload.todayHabits([
        due,
        notDue,
        paused,
      ], asOf: _today);

      final rows = payload['rows'] as List;
      expect(rows, hasLength(1));
      expect((rows.single as Map)['id'], '1');
    });

    test('caps at the free habit limit', () {
      final habits = [
        for (var i = 0; i < AppConstants.freeHabitLimit + 3; i++)
          _habit('$i', 'Habit $i'),
      ];

      final payload = WidgetPayload.todayHabits(habits, asOf: _today);

      expect(payload['rows'], hasLength(AppConstants.freeHabitLimit));
    });

    test('marks a completed habit and a frozen habit both done', () {
      final completed = _habit(
        'c',
        'Completed',
        type: HabitType.quantity,
        logs: {_today: 1},
      );
      final frozen = _habit('f', 'Frozen', frozenDays: {_today});
      final untouched = _habit('u', 'Untouched');

      final payload = WidgetPayload.todayHabits([
        completed,
        frozen,
        untouched,
      ], asOf: _today);
      final rows = (payload['rows'] as List).cast<Map<String, Object?>>();

      bool doneOf(String id) => rows.firstWhere((r) => r['id'] == id)['done'] as bool;
      expect(doneOf('c'), isTrue);
      expect(doneOf('f'), isTrue);
      expect(doneOf('u'), isFalse);
    });

    test('carries each habit\'s type through, for the native tap decision', () {
      final quantity = _habit('q', 'Water', type: HabitType.quantity);

      final payload = WidgetPayload.todayHabits([quantity], asOf: _today);
      final row = (payload['rows'] as List).single as Map<String, Object?>;

      expect(row['type'], 'quantity');
    });
  });

  group('WidgetPayload.habitDashboard', () {
    test('carries isPro through unchanged', () {
      final proPayload = WidgetPayload.habitDashboard(
        [],
        isPro: true,
        asOf: _today,
      );
      final freePayload = WidgetPayload.habitDashboard(
        [],
        isPro: false,
        asOf: _today,
      );

      expect(proPayload['isPro'], isTrue);
      expect(freePayload['isPro'], isFalse);
    });

    test('orders rows by current streak, longest first', () {
      final habits = [
        _streakHabit('a', 'A', 2),
        _streakHabit('b', 'B', 5),
        _streakHabit('c', 'C', 1),
      ];

      final payload = WidgetPayload.habitDashboard(
        habits,
        isPro: true,
        asOf: _today,
      );
      final rows = (payload['rows'] as List).cast<Map<String, Object?>>();

      expect(rows.map((r) => r['id']), ['b', 'a', 'c']);
      expect(rows.first['streak'], 5);
    });

    test('caps at the dashboard row budget', () {
      final habits = [
        for (var i = 0; i < WidgetPayload.maxDashboardRows + 2; i++)
          _streakHabit('$i', 'Habit $i', i),
      ];

      final payload = WidgetPayload.habitDashboard(
        habits,
        isPro: true,
        asOf: _today,
      );

      expect(payload['rows'], hasLength(WidgetPayload.maxDashboardRows));
      // The longest streaks survive the cap, not the first N in list order.
      final rows = (payload['rows'] as List).cast<Map<String, Object?>>();
      expect(rows.map((r) => r['streak']), isNot(contains(0)));
    });
  });

  test('WidgetPayload.signedOut carries no habit data', () {
    expect(WidgetPayload.signedOut(), {'signedIn': false});
  });

  group('both payloads survive a JSON round trip', () {
    test('todayHabits', () {
      final payload = WidgetPayload.todayHabits([
        _habit('1', 'Water'),
      ], asOf: _today);

      final back = jsonDecode(jsonEncode(payload)) as Map<String, dynamic>;

      expect(back, payload);
    });

    test('habitDashboard', () {
      final payload = WidgetPayload.habitDashboard([
        _streakHabit('1', 'Water', 3),
      ], isPro: true, asOf: _today);

      final back = jsonDecode(jsonEncode(payload)) as Map<String, dynamic>;

      expect(back, payload);
    });
  });
}
