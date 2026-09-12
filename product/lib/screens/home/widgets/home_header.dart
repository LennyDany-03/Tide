import 'package:flutter/material.dart';

import '../../../config/app_constants.dart';
import '../../../services/models/tide_glyph.dart';
import '../../../theme/tide_colors.dart';
import '../../../theme/tide_elevation.dart';
import '../../../theme/tide_typography.dart';
import '../../../widgets/gauge_number.dart';
import '../../../widgets/habit_glyph.dart';
import '../../../widgets/press_scale.dart';
import '../../../widgets/tide_mark.dart';
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
/// The logo leads the date line, small and alive. Today is the screen the
/// app is opened into every day, and until now it never showed the mark at
/// all — the splash drew it, and then the product it belongs to carried no
/// trace of it. At this size it reads as the ring with its lit point still
/// going round, which is the part of the logo that means something on a
/// daily screen: the loop is running. It sits in the eyebrow rather than
/// beside the title so it signs the page without competing with "Today".
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
              Row(
                children: [
                  Semantics(
                    label: AppConstants.appName,
                    image: true,
                    excludeSemantics: true,
                    // Whole on arrival: the splash has just drawn it, and a
                    // header that redraws its logo every time Today is built
                    // would be performing at the one screen used daily.
                    child: const TideMark(
                      size: 26,
                      strokeWidth: 1.8,
                      drawIn: false,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Flexible(
                    child: Text(
                      _dateLine,
                      style: TideType.labelMuted,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text('Today', style: TideType.screenTitle),
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
              HabitGlyph(
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
