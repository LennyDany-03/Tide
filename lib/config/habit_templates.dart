import 'package:flutter/material.dart';

import '../services/models/habit.dart';
import '../services/models/tide_glyph.dart';

/// A starter habit offered on the onboarding grid.
///
/// Each carries a *smart default* rhythm so the "set the rhythm" step can be
/// a one-line row the user only expands if they disagree with it.
@immutable
class HabitTemplate {
  const HabitTemplate({
    required this.name,
    required this.glyph,
    required this.type,
    required this.reminderTime,
    this.target = 1,
    this.unit = '',
    this.days = const {1, 2, 3, 4, 5, 6, 7},
  });

  final String name;
  final TideGlyph glyph;
  final HabitType type;
  final num target;
  final String unit;
  final Set<int> days;
  final TimeOfDay reminderTime;

  /// The smart-default summary shown on the collapsed rhythm row.
  String get rhythmSummary {
    final schedule = days.length == 7
        ? 'Daily'
        : days.length == 5 && !days.contains(6) && !days.contains(7)
        ? 'Weekdays'
        : '${days.length}x a week';
    final hour = reminderTime.hour.toString().padLeft(2, '0');
    final minute = reminderTime.minute.toString().padLeft(2, '0');
    return '$schedule at $hour:$minute';
  }

  static const List<HabitTemplate> all = [
    HabitTemplate(
      name: 'Morning water',
      glyph: TideGlyph.crescent,
      type: HabitType.quantity,
      target: 8,
      unit: 'glasses',
      reminderTime: TimeOfDay(hour: 7, minute: 30),
    ),
    HabitTemplate(
      name: 'Read 20 pages',
      glyph: TideGlyph.lines,
      type: HabitType.binary,
      reminderTime: TimeOfDay(hour: 21, minute: 0),
    ),
    HabitTemplate(
      name: 'Move 30 min',
      glyph: TideGlyph.peak,
      type: HabitType.duration,
      target: 30,
      unit: 'min',
      reminderTime: TimeOfDay(hour: 18, minute: 0),
    ),
    HabitTemplate(
      name: 'No screens after 10',
      glyph: TideGlyph.square,
      type: HabitType.binary,
      reminderTime: TimeOfDay(hour: 22, minute: 0),
    ),
    HabitTemplate(
      name: 'Meditate 10 min',
      glyph: TideGlyph.halfMoon,
      type: HabitType.duration,
      target: 10,
      unit: 'min',
      reminderTime: TimeOfDay(hour: 7, minute: 0),
    ),
    HabitTemplate(
      name: 'Stretch',
      glyph: TideGlyph.diamond,
      type: HabitType.binary,
      reminderTime: TimeOfDay(hour: 8, minute: 30),
    ),
    HabitTemplate(
      name: 'Journal',
      glyph: TideGlyph.diamondOutline,
      type: HabitType.binary,
      days: {1, 2, 3, 4, 5},
      reminderTime: TimeOfDay(hour: 20, minute: 30),
    ),
    HabitTemplate(
      name: 'Early night',
      glyph: TideGlyph.dot,
      type: HabitType.binary,
      reminderTime: TimeOfDay(hour: 22, minute: 30),
    ),
  ];
}
