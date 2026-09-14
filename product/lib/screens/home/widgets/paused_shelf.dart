import 'package:flutter/material.dart';

import '../../../config/habit_copy.dart';
import '../../../services/models/habit.dart';
import '../../../services/streak_calculator.dart';
import '../../../theme/tide_colors.dart';
import '../../../theme/tide_elevation.dart';
import '../../../theme/tide_typography.dart';
import '../../../widgets/habit_glyph.dart';
import '../../../widgets/press_scale.dart';

/// Habits set aside, under Today's list.
///
/// A paused habit leaves the list, and before this shelf existed that was
/// the last anybody saw of it: pausing from the long-press sheet took the
/// card away, and with it the only gesture that led back to the habit. The
/// habit was not gone — it was unreachable, which from the outside is the
/// same thing.
///
/// Quieter than a card on purpose. These ask nothing of today, so they sit
/// flush on the page in drained ink, with one control each: Resume.
class PausedShelf extends StatelessWidget {
  const PausedShelf({
    super.key,
    required this.habits,
    required this.onOpen,
    required this.onMenu,
    required this.onResume,
  });

  final List<Habit> habits;
  final ValueChanged<Habit> onOpen;
  final ValueChanged<Habit> onMenu;
  final ValueChanged<Habit> onResume;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Text('Paused', style: TideType.sectionHeader),
            const SizedBox(width: 8),
            Text(
              '${habits.length}',
              style: TideType.gaugeSmall(color: TideColors.silt),
            ),
          ],
        ),
        const SizedBox(height: 8),
        DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: TideElevation.radius20,
            border: Border.all(color: TideColors.hairline),
          ),
          child: Column(
            children: [
              for (var i = 0; i < habits.length; i++) ...[
                if (i > 0)
                  Container(
                    height: 1,
                    margin: const EdgeInsets.only(left: 58),
                    color: TideColors.hairline,
                  ),
                _PausedRow(
                  habit: habits[i],
                  onOpen: () => onOpen(habits[i]),
                  onMenu: () => onMenu(habits[i]),
                  onResume: () => onResume(habits[i]),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _PausedRow extends StatelessWidget {
  const _PausedRow({
    required this.habit,
    required this.onOpen,
    required this.onMenu,
    required this.onResume,
  });

  final Habit habit;
  final VoidCallback onOpen;
  final VoidCallback onMenu;
  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    final streak = StreakCalculator.currentStreak(habit);
    // Short on purpose: it shares a line with the Resume control, and the
    // section is already titled Paused.
    final since = habit.pausedSince!;
    final today = DateUtils.dateOnly(DateTime.now());
    final when = since.isAfter(today)
        ? 'From ${HabitCopy.day(since)}'
        : 'Since ${HabitCopy.day(since)}';
    final detail = streak > 0 ? '$when · streak $streak' : when;

    return PressScale(
      scale: 0.985,
      onTap: onOpen,
      onLongPress: onMenu,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        child: Row(
          children: [
            SizedBox(
              width: 30,
              child: HabitGlyph(
                glyph: habit.glyph,
                size: 15,
                color: TideColors.drained(TideColors.lantern, 0.7),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    habit.name,
                    style: TideType.heading.copyWith(color: TideColors.silt),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    detail,
                    style: TideType.labelMuted.copyWith(
                      color: TideColors.silt.withValues(alpha: 0.75),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            PressScale(
              onTap: onResume,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: TideColors.lantern.withValues(alpha: 0.10),
                  borderRadius: TideElevation.radius12,
                ),
                child: Text(
                  'Resume',
                  style: TideType.label.copyWith(
                    color: TideColors.lantern,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
