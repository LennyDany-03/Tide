import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tide/services/models/habit.dart';
import 'package:tide/services/models/tide_glyph.dart';
import 'package:tide/services/weekly_recap.dart';

/// The Friday this week's figures are pinned to, so the sentences never
/// drift with the wall clock. 14 September 2026 is the Monday before it.
final _friday = DateTime(2026, 9, 18);

Habit _habit(
  String id,
  String name, {
  Set<int>? days,
  Map<DateTime, num> logs = const {},
}) => Habit(
  id: id,
  name: name,
  glyph: TideGlyph.dot,
  type: HabitType.binary,
  createdAt: DateTime(2026, 1, 1),
  days: days ?? const {1, 2, 3, 4, 5, 6, 7},
  logs: logs,
  frozenDays: const {},
  pauses: const [],
);

void main() {
  group('WeeklyRecapLine', () {
    test('a fully kept week reads as one whole line', () {
      final habits = [
        _habit(
          '1',
          'Water',
          logs: {
            for (var i = 0; i < 5; i++)
              DateUtils.addDaysToDate(_friday, -i): 1,
          },
        ),
      ];

      expect(
        WeeklyRecapLine.forWeek(habits, asOf: _friday),
        '100% of the week kept — 5 of 5 check-ins, best streak 5 days.',
      );
    });

    test('a partial week names the kept share, not the missed one', () {
      final habits = [
        _habit('1', 'Water', days: const {1, 2, 3, 4, 5}, logs: {
          DateUtils.addDaysToDate(_friday, -4): 1,
          DateUtils.addDaysToDate(_friday, -3): 1,
        }),
      ];

      expect(
        WeeklyRecapLine.forWeek(habits, asOf: _friday),
        '40% of the week kept — 2 of 5 check-ins, best streak 2 days.',
      );
    });

    test('a single day logged says "day", not "days"', () {
      final habits = [
        _habit('1', 'Water', logs: {
          DateUtils.addDaysToDate(_friday, -4): 1,
        }),
      ];

      expect(
        WeeklyRecapLine.forWeek(habits, asOf: _friday),
        '20% of the week kept — 1 of 5 check-ins, best streak 1 day.',
      );
    });

    test('a week nothing was scheduled for is spoken for, not scored', () {
      final habits = [
        _habit('1', 'Water', days: const {6}, logs: {
          DateUtils.addDaysToDate(_friday, -8): 1,
        }),
      ];

      expect(
        WeeklyRecapLine.forWeek(habits, asOf: _friday),
        'Nothing on the calendar yet this week — mark a few '
            'days and the recap writes itself.',
      );
    });

    test('no habits at all reads as the same empty week', () {
      expect(
        WeeklyRecapLine.forWeek(const [], asOf: _friday),
        'Nothing on the calendar yet this week — mark a few '
            'days and the recap writes itself.',
      );
    });
  });
}