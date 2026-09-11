import 'package:flutter/material.dart';

import '../../../services/models/habit.dart';
import '../../../services/models/tide_glyph.dart';
import '../../../theme/tide_colors.dart';
import '../../../theme/tide_elevation.dart';
import '../../../theme/tide_typography.dart';
import '../../../widgets/habit_glyph.dart';
import '../../../widgets/tide_surface.dart';
import 'day_selector.dart';

/// A miniature of the real habit card, updating as the form is filled in.
///
/// Not a mock-up drawn for this screen — it is the same glyph, ring shape,
/// name and gesture hint the card on Home will carry, so the user is
/// editing the thing itself rather than describing it and hoping.
class LiveHabitPreview extends StatelessWidget {
  const LiveHabitPreview({
    super.key,
    required this.name,
    required this.glyph,
    required this.type,
    required this.days,
  });

  final String name;
  final TideGlyph glyph;
  final HabitType type;
  final Set<int> days;

  String get _schedule {
    if (days.isEmpty) return 'no days yet';
    if (days.length == 7) return 'daily';
    final named = DaySchedule.nameOf(days);
    if (named != null) return named.toLowerCase();
    return '${days.length}x a week';
  }

  @override
  Widget build(BuildContext context) {
    final shown = name.trim().isEmpty ? 'New habit' : name.trim();

    return TideSurface(
      radius: TideElevation.radius12,
      color: TideColors.trench,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
        children: [
          // A static ring at rest: a preview should not be mid-animation.
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: TideColors.lantern, width: 2.5),
            ),
            child: Center(child: HabitGlyph(glyph: glyph, size: 14)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  shown,
                  style: TideType.heading,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '$_schedule, ${type.gestureHint}',
                  style: TideType.labelMuted,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text('Preview', style: TideType.labelMuted),
        ],
      ),
    );
  }
}
