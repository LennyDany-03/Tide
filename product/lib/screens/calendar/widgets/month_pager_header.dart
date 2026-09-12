import 'package:flutter/material.dart';

import '../../../config/app_constants.dart';
import '../../../theme/tide_colors.dart';
import '../../../theme/tide_motion.dart';
import '../../../theme/tide_typography.dart';
import '../../../widgets/press_scale.dart';

/// Month title with previous/next controls.
///
/// The title crossfades and slides in the direction of travel, the same
/// 200ms family as a tab switch — paging a month and switching a tab are
/// the same size of move, so they read the same.
class MonthPagerHeader extends StatelessWidget {
  const MonthPagerHeader({
    super.key,
    required this.month,
    required this.onPrevious,
    required this.onNext,
    required this.forward,
    this.canGoNext = true,
    this.canGoPrevious = true,
  });

  final DateTime month;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  /// Direction of the last change, so the title slides the right way.
  final bool forward;

  final bool canGoNext;

  /// False at the earliest month this plan can open. The arrow stays live —
  /// it opens the paywall rather than doing nothing — so [onPrevious] is
  /// still called; this only dims it, so the edge of the window is visible
  /// before it is reached.
  final bool canGoPrevious;

  @override
  Widget build(BuildContext context) {
    final label = '${AppConstants.monthNames[month.month - 1]} ${month.year}';

    return Row(
      children: [
        _Arrow(
          icon: Icons.chevron_left_rounded,
          onTap: onPrevious,
          dimmed: !canGoPrevious,
        ),
        Expanded(
          child: AnimatedSwitcher(
            duration: TideMotion.tabSwitch,
            switchInCurve: TideMotion.tabCurve,
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: Offset(forward ? 0.12 : -0.12, 0),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              );
            },
            child: Text(
              label,
              key: ValueKey(label),
              textAlign: TextAlign.center,
              style: TideType.hero.copyWith(fontSize: 19),
            ),
          ),
        ),
        _Arrow(
          icon: Icons.chevron_right_rounded,
          onTap: onNext,
          enabled: canGoNext,
        ),
      ],
    );
  }
}

class _Arrow extends StatelessWidget {
  const _Arrow({
    required this.icon,
    required this.onTap,
    this.enabled = true,
    this.dimmed = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool enabled;

  /// Drawn as unavailable but still pressable: what a gate looks like, as
  /// distinct from [enabled] false, which is what the end of time looks like.
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: enabled ? onTap : null,
      enabled: enabled,
      child: Opacity(
        opacity: enabled && !dimmed ? 1 : 0.25,
        // A bare glyph. The arrows were tiles in a surface colour, which
        // made two small panels flank the month name and read as heavier
        // than the title between them.
        child: SizedBox(
          width: 38,
          height: 38,
          child: Icon(icon, size: 22, color: TideColors.bone),
        ),
      ),
    );
  }
}
