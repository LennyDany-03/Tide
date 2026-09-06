import 'package:flutter/material.dart';

import '../../../theme/tide_colors.dart';
import '../../../theme/tide_motion.dart';

/// Onboarding progress, as a water level rather than dots.
///
/// Dots would say "five things to get through". A rising line says "this is
/// filling up", which is both more honest about a short flow and the same
/// metaphor the rest of the app runs on.
class TideLineGauge extends StatelessWidget {
  const TideLineGauge({super.key, required this.progress, this.height = 2.5});

  /// 0..1.
  final double progress;

  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: TideColors.silt.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(height),
              ),
            ),
          ),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(end: progress.clamp(0.0, 1.0)),
            duration: TideMotion.sheetIn,
            curve: TideMotion.sheetCurve,
            builder: (context, t, _) {
              return FractionallySizedBox(
                widthFactor: t,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: TideColors.lantern,
                    borderRadius: BorderRadius.circular(height),
                  ),
                  // As in the calendar day cell: a childless DecoratedBox
                  // collapses on the unconstrained axis, which would leave
                  // the gauge zero pixels tall.
                  child: const SizedBox.expand(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
