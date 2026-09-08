import 'package:flutter/material.dart';

import '../services/models/habit.dart';
import '../services/models/tide_glyph.dart';

/// The demo history the app opens with.
///
/// Nothing here is hardcoded display text — these are real logs, and every
/// streak, percentage and heatmap cell on screen is computed from them by
/// `StreakCalculator`. The patterns below are tuned so those computed
/// figures land on the numbers in the design: a 12-day water streak with a
/// 23-day best, a 23-day movement streak on a 34-day all-time best, roughly
/// 82% for the week, and four of the nine milestones surfaced.
///
/// Because everything is relative to "today", the app reads correctly
/// whatever day it is run.
abstract final class SeedData {
  static List<Habit> habits() {
    return [
      _build(
        id: 'morning-water',
        name: 'Morning water',
        glyph: TideGlyph.water,
        type: HabitType.quantity,
        target: 8,
        unit: 'glasses',
        reminderTime: const TimeOfDay(hour: 7, minute: 30),
        // Today sits at 5 of 8 — partial, so it still reads as unfinished.
        recent: _pattern(52, {
          0: 5,
          ..._run(1, 12), //  current streak of 12
          ..._run(14, 19),
          ..._run(21, 25),
          ..._run(27, 49), //  the 23-day best
          51: 8,
        }),
        olderRate: 0.80,
        olderGap: 12,
      ),
      _build(
        id: 'read-pages',
        name: 'Read 20 pages',
        glyph: TideGlyph.read,
        type: HabitType.binary,
        target: 1,
        unit: '',
        reminderTime: const TimeOfDay(hour: 21, minute: 0),
        recent: _pattern(30, {
          ..._run(0, 4, value: 1), // logged today, streak of 5
          ..._run(6, 7, value: 1),
          // Two misses last week, so this week reads as an improvement.
          ..._run(9, 9, value: 1),
          ..._run(11, 11, value: 1),
          ..._run(13, 25, value: 1),
        }),
        olderRate: 0.70,
        olderGap: 9,
      ),
      _build(
        id: 'move-30',
        name: 'Move 30 min',
        glyph: TideGlyph.run,
        type: HabitType.duration,
        target: 30,
        unit: 'min',
        reminderTime: const TimeOfDay(hour: 18, minute: 0),
        recent: _pattern(60, {
          ..._run(0, 22, value: 30), // current streak of 23
          ..._run(24, 57, value: 30), // all-time best of 34
          59: 30,
        }),
        olderRate: 0.75,
        olderGap: 10,
      ),
      _build(
        id: 'no-screens',
        name: 'No screens after 10',
        glyph: TideGlyph.screenOff,
        type: HabitType.binary,
        target: 1,
        unit: '',
        reminderTime: const TimeOfDay(hour: 22, minute: 0),
        // Not yet logged today — this is the card the design shows waiting
        // for a swipe.
        recent: _pattern(24, {
          ..._run(1, 2, value: 1), // streak of 2
          ..._run(4, 5, value: 1),
          // A patchier week before this one — the screen the recap is
          // comparing against.
          ..._run(7, 7, value: 1),
          ..._run(9, 9, value: 1),
          ..._run(12, 12, value: 1),
          ..._run(14, 16, value: 1),
        }),
        olderRate: 0.55,
        olderGap: 8,
        freezesRemaining: 1,
        // One freeze spent ten days back, which is what the freeze-usage
        // summary on Insights reports.
        frozenDaysAgo: const {10},
      ),
    ];
  }

  // --- Pattern helpers --------------------------------------------------

  /// Marks days [from]..[to] (inclusive, in days-ago) as logged at [value].
  static Map<int, num> _run(int from, int to, {num value = 8}) {
    return {for (var i = from; i <= to; i++) i: value};
  }

  /// Expands a sparse days-ago map into a dense list where index 0 is today
  /// and a null entry is a missed day.
  static List<num?> _pattern(int length, Map<int, num> logged) {
    return List<num?>.generate(length, (i) => logged[i]);
  }

  static Habit _build({
    required String id,
    required String name,
    required TideGlyph glyph,
    required HabitType type,
    required num target,
    required String unit,
    required TimeOfDay reminderTime,
    required List<num?> recent,
    required double olderRate,
    required int olderGap,
    int historyDays = 150,
    int freezeAllowance = 2,
    int? freezesRemaining,
    Set<int> frozenDaysAgo = const {},
  }) {
    final today = DateUtils.dateOnly(DateTime.now());
    final logs = <DateTime, num>{};

    // The recent window is authored explicitly, because it is what the
    // visible streaks and rates are read from.
    for (var i = 0; i < recent.length; i++) {
      final amount = recent[i];
      if (amount != null && amount > 0) {
        logs[today.subtract(Duration(days: i))] = amount;
      }
    }

    // Older history is deterministic noise — enough texture to make the
    // heatmap and the month grid look lived-in. The forced gap every
    // [olderGap] days caps how long an older run can get, so back-history
    // can never accidentally beat the authored best streak.
    for (var i = recent.length; i < historyDays; i++) {
      if (i % olderGap == 0) continue;
      if (_noise(id, i) < olderRate) {
        logs[today.subtract(Duration(days: i))] = target;
      }
    }

    return Habit(
      id: id,
      name: name,
      glyph: glyph,
      type: type,
      target: target,
      unit: unit,
      reminderEnabled: true,
      reminderTime: reminderTime,
      freezeAllowance: freezeAllowance,
      freezesRemaining: freezesRemaining ?? freezeAllowance,
      createdAt: today.subtract(Duration(days: historyDays - 1)),
      logs: logs,
      frozenDays: {
        for (final daysAgo in frozenDaysAgo)
          today.subtract(Duration(days: daysAgo)),
      },
    );
  }

  /// FNV-1a, so the "random" older history is identical on every launch and
  /// on every device. A real random source would make the heatmap flicker
  /// between hot reloads.
  static double _noise(String seed, int index) {
    var hash = 0x811c9dc5;
    for (final code in '$seed:$index'.codeUnits) {
      hash ^= code;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return (hash % 1000) / 1000.0;
  }
}
