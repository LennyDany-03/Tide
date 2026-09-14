import 'package:flutter/material.dart';

import '../../../config/habit_copy.dart';
import '../../../services/models/habit.dart';
import '../../../theme/tide_colors.dart';
import '../../../theme/tide_typography.dart';
import '../../../widgets/habit_glyph.dart';
import '../../../widgets/press_scale.dart';

/// Back and edit on one line, then the habit's name as the screen's title.
///
/// The name used to share a row with the back arrow at card-heading size,
/// which made the screen's subject the same weight as its navigation. It is
/// the title now — display size, on its own line, under a quiet line that
/// says what the habit asks for. Edit moves up beside back, where a detail
/// screen's edit control is looked for, instead of waiting under the chart.
class DetailHeader extends StatelessWidget {
  const DetailHeader({
    super.key,
    required this.habit,
    required this.onBack,
    required this.onEdit,
    this.drain = 0,
  });

  final Habit habit;
  final VoidCallback onBack;
  final VoidCallback onEdit;

  /// 0..1 desaturation applied while a habit is being paused.
  final double drain;

  String get _subline {
    if (habit.paused) return HabitCopy.pausedSince(habit);
    final target = habit.targetLabel;
    final schedule = HabitCopy.schedule(habit);
    return target.isEmpty ? schedule : '$target · $schedule';
  }

  @override
  Widget build(BuildContext context) {
    final accent = TideColors.drained(TideColors.lantern, drain);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            _RoundControl(
              icon: Icons.arrow_back_rounded,
              semantics: 'Back',
              onTap: onBack,
            ),
            const Spacer(),
            _RoundControl(
              icon: Icons.tune_rounded,
              semantics: 'Edit habit',
              onTap: onEdit,
            ),
          ],
        ),
        const SizedBox(height: 26),
        Row(
          children: [
            HabitGlyph(glyph: habit.glyph, size: 14, color: accent),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                _subline,
                style: TideType.labelMuted,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          habit.name,
          style: TideType.screenTitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

/// A 40px round control with a hairline edge — present enough to find,
/// quiet enough that neither competes with the title under them.
class _RoundControl extends StatelessWidget {
  const _RoundControl({
    required this.icon,
    required this.semantics,
    required this.onTap,
  });

  final IconData icon;
  final String semantics;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semantics,
      child: PressScale(
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: TideColors.hairline),
          ),
          child: Icon(icon, size: 20, color: TideColors.bone),
        ),
      ),
    );
  }
}
