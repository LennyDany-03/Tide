import 'package:flutter/material.dart';

import '../../../theme/tide_colors.dart';
import '../../../theme/tide_elevation.dart';
import '../../../theme/tide_typography.dart';
import '../../../widgets/press_scale.dart';

/// The way to add a habit, sitting where the next habit would go.
///
/// It was a 38px tile in the header, immediately beside the milestones
/// glyph — two unrelated destinations rendered as two small marks in the
/// same corner, which is how you get people opening the trophy case when
/// they meant to add something. The bottom-right corner was no better: a
/// floating disc there lands on the tab bar's glass and on whatever the
/// last card is trying to say.
///
/// So it lives in the list instead, one slot below the last habit, reading
/// as the empty row waiting to be filled. That is where the eye already is
/// after checking off the day, it is nowhere near the milestones control,
/// and it costs the screen no chrome at all.
class AddHabitTile extends StatelessWidget {
  const AddHabitTile({super.key, required this.onTap, this.atLimit = false});

  final VoidCallback onTap;

  /// The free plan is full, so this opens the paywall instead. Said plainly
  /// rather than by disabling the control and leaving the user to guess.
  final bool atLimit;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onTap,
      child: Container(
        height: 62,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          borderRadius: TideElevation.radius20,
          border: Border.all(color: TideColors.hairline),
        ),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: TideColors.lantern.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.add_rounded,
                size: 18,
                color: TideColors.lantern,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                'Add a habit',
                style: TideType.label.copyWith(color: TideColors.silt),
              ),
            ),
            // The free plan is full. Said here rather than by disabling the
            // control, which would leave the user to work out why.
            if (atLimit)
              Text(
                'Tide Pro',
                style: TideType.labelMuted.copyWith(
                  color: TideColors.lantern,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
