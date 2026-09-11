import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tide/services/habits/habit_rows.dart';
import 'package:tide/services/models/habit.dart';
import 'package:tide/services/models/tide_glyph.dart';
import 'package:tide/services/tide_store.dart';

/// Built from calendar dates rather than by subtracting days from now, so a
/// daylight-saving change inside the history cannot move a key off midnight.
Habit _water() => Habit(
  id: '5b0c3f7e-1d2a-4c8e-9f10-2a3b4c5d6e7f',
  name: 'Morning water',
  glyph: TideGlyph.water,
  type: HabitType.quantity,
  target: 8,
  unit: 'glasses',
  days: const {1, 3, 5},
  reminderEnabled: true,
  reminderTime: const TimeOfDay(hour: 7, minute: 30),
  freezeAllowance: 3,
  freezesRemaining: 1,
  paused: true,
  createdAt: DateTime(2026, 3, 2, 9, 41),
  logs: {DateTime(2026, 9, 9): 8, DateTime(2026, 9, 11): 5.5},
  frozenDays: {DateTime(2026, 9, 10), DateTime(2026, 9, 11)},
);

void main() {
  group('a habit written down and read back', () {
    test('keeps every setting and its whole history', () {
      final original = _water();
      // Through JSON, the way both the server's snapshot and the device copy
      // arrive.
      final row =
          jsonDecode(jsonEncode(HabitRows.snapshot(original)))
              as Map<String, dynamic>;
      final back = HabitRows.parseHabit(row)!;

      expect(back.id, original.id);
      expect(back.name, original.name);
      expect(back.glyph, original.glyph);
      expect(back.type, original.type);
      expect(back.target, original.target);
      expect(back.unit, original.unit);
      expect(back.days, original.days);
      expect(back.reminderEnabled, isTrue);
      expect(back.reminderTime, original.reminderTime);
      expect(back.freezeAllowance, 3);
      expect(back.freezesRemaining, 1);
      expect(back.paused, isTrue);
      expect(back.createdAt, original.createdAt);
      expect(back.logs, original.logs);
      expect(back.frozenDays, original.frozenDays);
    });

    test('an undone day is written as an empty entry, not left out', () {
      final row = HabitRows.entry(_water(), DateTime(2026, 9, 12, 18, 5));

      expect(row['day'], '2026-09-12', reason: 'the calendar date, no time');
      expect(row['amount'], isNull);
      expect(row['frozen'], isFalse);
    });

    test('a whole number stays whole, so a target never reads "8.0"', () {
      final back = HabitRows.parseHabit({
        ...HabitRows.habit(_water()),
        'target': 8.0,
      })!;

      expect(back.target, isA<int>());
      expect(back.targetLabel, '8 glasses');
    });

    test('a glyph or kind from a newer build still opens', () {
      final back = HabitRows.parseHabit({
        ...HabitRows.habit(_water()),
        'glyph': 'kelp',
        'kind': 'streaks',
        'weekdays': <int>[],
      })!;

      expect(back.glyph, TideGlyph.dot);
      expect(back.type, HabitType.binary);
      expect(back.days, {1, 2, 3, 4, 5, 6, 7});
    });
  });

  test('an entry row becomes that day of the habit it names', () {
    final entry = HabitRows.parseEntry({
      'habit_id': _water().id,
      'day': '2026-09-11',
      'amount': null,
      'frozen': false,
    })!;

    final after = entry.applyTo(_water());

    expect(after.logs.containsKey(DateTime(2026, 9, 11)), isFalse);
    expect(after.isFrozenOn(DateTime(2026, 9, 11)), isFalse);
    expect(after.amountOn(DateTime(2026, 9, 9)), 8, reason: 'others untouched');
  });

  test('habit ids are version 4 UUIDs, which is what habits.id holds', () {
    final store = TideStore();
    addTearDown(store.dispose);
    final id = store.newHabitId();

    expect(
      id,
      matches(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-'
          r'[0-9a-f]{12}$',
        ),
      ),
    );
    expect(store.newHabitId(), isNot(id));
  });
}
