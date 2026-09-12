import 'package:flutter/material.dart';

import '../../../services/models/habit.dart';
import '../../../theme/tide_colors.dart';
import '../../../theme/tide_elevation.dart';
import '../../../theme/tide_typography.dart';
import '../../../widgets/habit_glyph.dart';
import '../../../widgets/press_scale.dart';

/// Back control, glyph and habit name.
class DetailHeader extends StatelessWidget {
  const DetailHeader({
    super.key,
    required this.habit,
    required this.onBack,
    this.drain = 0,
  });

  final Habit habit;
  final VoidCallback onBack;

  /// 0..1 desaturation applied while a habit is being paused.
  final double drain;

  @override
  Widget build(BuildContext context) {
    final accent = TideColors.drained(TideColors.lantern, drain);

    return Row(
      children: [
        // A bare glyph, not a tile. Back is the least interesting control
        // on the screen and should not be the only filled shape in the row.
        PressScale(
          onTap: onBack,
          child: SizedBox(
            width: 38,
            height: 38,
            child: Icon(
              Icons.arrow_back_rounded,
              size: 21,
              color: TideColors.bone,
            ),
          ),
        ),
        const SizedBox(width: 8),
        HabitGlyph(glyph: habit.glyph, size: 17, color: accent),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            habit.name,
            style: TideType.hero,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (habit.paused)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: TideColors.silt.withValues(alpha: 0.14),
              borderRadius: TideElevation.radius12,
            ),
            child: Text('Paused', style: TideType.labelMuted),
          ),
      ],
    );
  }
}
