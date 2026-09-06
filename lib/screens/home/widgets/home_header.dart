import 'package:flutter/material.dart';

import '../../../config/app_constants.dart';
import '../../../services/models/tide_glyph.dart';
import '../../../theme/tide_colors.dart';
import '../../../theme/tide_typography.dart';
import '../../../widgets/habit_glyph.dart';
import '../../../widgets/press_scale.dart';

/// Date line, screen title, and the way through to milestones.
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
    required this.onAddHabit,
  });

  final DateTime date;
  final VoidCallback onMilestones;
  final VoidCallback onAddHabit;

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
            padding: EdgeInsets.all(10),
            child: HabitGlyph(
              glyph: TideGlyph.sparkle,
              size: 19,
              color: TideColors.bone,
            ),
          ),
        ),
        const SizedBox(width: 4),
        PressScale(
          onTap: onAddHabit,
          child: Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: TideColors.lantern.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: TideColors.lantern.withValues(alpha: 0.24),
              ),
            ),
            child: const Icon(
              Icons.add_rounded,
              size: 20,
              color: TideColors.lantern,
            ),
          ),
        ),
      ],
    );
  }
}
