import 'package:flutter/material.dart';

import '../../../config/app_constants.dart';
import '../../../services/models/tide_glyph.dart';
import '../../../theme/tide_colors.dart';
import '../../../theme/tide_typography.dart';
import '../../../widgets/habit_glyph.dart';
import '../../../widgets/press_scale.dart';

/// Date line, screen title, and the way through to milestones.
///
/// The add control used to sit here too, four pixels from the milestones
/// glyph: two small marks in the same corner going to two entirely
/// unrelated places. Adding a habit now lives in the list itself, which is
/// where the next habit would go anyway.
///
/// Three things removed here, all of them the same mistake — decoration
/// standing in for hierarchy. The lit dot before the date, the gradient
/// shader across the word "Today", and the glass tile around the milestones
/// glyph were each trying to make an element feel important by adding
/// material to it. The title is important because it is 34px and nothing
/// near it is; that costs nothing and works better.
class HomeHeader extends StatelessWidget {
  const HomeHeader({
    super.key,
    required this.date,
    required this.onMilestones,
  });

  final DateTime date;
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Today', style: TideType.screenTitle),
              const SizedBox(height: 6),
              Text(_dateLine, style: TideType.labelMuted),
            ],
          ),
        ),
        PressScale(
          onTap: onMilestones,
          child: const Padding(
            padding: EdgeInsets.fromLTRB(10, 10, 4, 10),
            child: HabitGlyph(
              glyph: TideGlyph.sparkle,
              size: 21,
              color: TideColors.bone,
            ),
          ),
        ),
      ],
    );
  }
}
