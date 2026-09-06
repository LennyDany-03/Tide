import 'package:flutter/material.dart';

import '../../../services/models/milestone.dart';
import '../../../theme/tide_colors.dart';
import '../../../theme/tide_elevation.dart';
import '../../../theme/tide_typography.dart';
import '../../../widgets/habit_glyph.dart';
import '../../../widgets/press_scale.dart';
import '../../../widgets/tide_surface.dart';

/// One badge.
///
/// Locked badges sit dim and desaturated — still underwater. They are not
/// hidden or greyed to nothing, because seeing what is down there is the
/// point; they simply have not surfaced yet.
class BadgeTile extends StatelessWidget {
  const BadgeTile({super.key, required this.status, required this.onTap});

  final MilestoneStatus status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final unlocked = status.unlocked;
    final accent = unlocked
        ? TideColors.lantern
        : TideColors.drained(TideColors.lantern, 0.8);

    return PressScale(
      onTap: onTap,
      enabled: unlocked,
      child: Opacity(
        opacity: unlocked ? 1 : 0.42,
        child: TideSurface(
          radius: TideElevation.radius20,
          color: unlocked
              ? Color.lerp(TideColors.shelf, TideColors.lantern, 0.05)
              : TideColors.trench,
          highlight: unlocked,
          shadows: unlocked ? TideElevation.resting : const [],
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 18),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              HabitGlyph(
                glyph: status.milestone.glyph,
                size: 24,
                color: accent,
                strokeWidth: 1.8,
              ),
              const SizedBox(height: 14),
              Text(
                status.milestone.name,
                style: TideType.label.copyWith(
                  color: unlocked
                      ? TideColors.bone
                      : TideColors.silt,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 5),
              Text(
                status.milestone.caption,
                style: TideType.gauge(11, color: TideColors.silt),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
