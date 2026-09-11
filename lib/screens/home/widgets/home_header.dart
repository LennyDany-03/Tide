import 'package:flutter/material.dart';

import '../../../config/app_constants.dart';
import '../../../services/models/tide_glyph.dart';
import '../../../theme/tide_colors.dart';
import '../../../theme/tide_elevation.dart';
import '../../../theme/tide_typography.dart';
import '../../../widgets/gauge_number.dart';
import '../../../widgets/habit_glyph.dart';
import '../../../widgets/press_scale.dart';
import '../../../widgets/tide_surface.dart';

/// Date line, screen title, and the way through to milestones.
///
/// The date sits *above* the title now, as the eyebrow. Read top-down it is
/// the context ("Friday, 11 September") and then the subject ("Today"),
/// which is the order a person takes them in; below the title it read as a
/// caption that had slipped.
///
/// The milestones control is a chip with an edge and a count, where it used
/// to be a bare 21px sparkle floating in the corner. Removing the tile round
/// it was right while the tile was a gradient pretending to be glass — but
/// with nothing round it the glyph read as decoration rather than as a
/// control, and it said nothing about what was behind it. A flat surface, a
/// hairline, the lit top edge every raised thing in the app carries, and the
/// number of milestones already surfaced: now it is plainly a button, and it
/// gives a reason to press it.
///
/// The add control used to sit here too, four pixels from the milestones
/// glyph: two small marks in the same corner going to two entirely
/// unrelated places. Adding a habit lives in the list itself, which is where
/// the next habit would go anyway.
class HomeHeader extends StatelessWidget {
  const HomeHeader({
    super.key,
    required this.date,
    required this.milestonesUnlocked,
    required this.onMilestones,
  });

  final DateTime date;

  /// Shown on the chip, so the way through to the route carries its own
  /// reason to be pressed.
  final int milestonesUnlocked;

  final VoidCallback onMilestones;

  /// "Sunday, 6 September" — written the way a person says it. The previous
  /// line was `SUN · 6 SEP`, which is chrome: abbreviated, tracked out,
  /// capitalised and joined with a middle dot, all to say the same thing.
  String get _dateLine {
    final weekday = AppConstants.weekdayNames[date.weekday - 1];
    final month = AppConstants.monthNames[date.month - 1];
    return '$weekday, ${date.day} $month';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      // The chip sits on the title's line rather than the date's, so the two
      // heaviest things in the header share one horizon.
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_dateLine, style: TideType.labelMuted),
              const SizedBox(height: 6),
              const Text('Today', style: TideType.screenTitle),
            ],
          ),
        ),
        const SizedBox(width: 12),
        _MilestonesChip(count: milestonesUnlocked, onTap: onMilestones),
      ],
    );
  }
}

class _MilestonesChip extends StatelessWidget {
  const _MilestonesChip({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Milestones, $count surfaced',
      excludeSemantics: true,
      child: PressScale(
        onTap: onTap,
        child: TideSurface(
          radius: TideElevation.radius20,
          color: TideColors.shelf,
          border: Border.all(color: TideColors.hairline),
          padding: const EdgeInsets.fromLTRB(11, 9, 14, 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const HabitGlyph(
                glyph: TideGlyph.sparkle,
                size: 14,
                color: TideColors.lantern,
              ),
              const SizedBox(width: 8),
              GaugeNumber(value: count, style: TideType.gauge(15)),
            ],
          ),
        ),
      ),
    );
  }
}
