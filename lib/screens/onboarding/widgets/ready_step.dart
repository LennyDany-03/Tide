import 'package:flutter/material.dart';

import '../../../theme/tide_colors.dart';
import '../../../theme/tide_motion.dart';
import '../../../theme/tide_typography.dart';
import '../../../widgets/tide_ring.dart';

/// Step five, and the hand-off.
///
/// The ring that drew itself in on the welcome step grows here and carries
/// through to Home. [morph] is driven by the screen as it exits, so the
/// last thing onboarding does and the first thing Home shows are the same
/// object rather than two screens that happen to both have a circle.
class ReadyStep extends StatelessWidget {
  const ReadyStep({super.key, required this.habitCount, required this.morph});

  final int habitCount;

  /// 0..1 as the screen hands off to Home.
  final double morph;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Spacer(flex: 2),
        Transform.scale(
          // Grows and drifts up toward where Home's hero stat sits, so the
          // exit reads as travel rather than as a fade.
          scale: 1 + 1.6 * Curves.easeInCubic.transform(morph),
          child: Opacity(
            opacity: 1 - morph,
            child: TideRing(
              progress: 1,
              size: 150,
              strokeWidth: 4,
              animate: true,
              showTrack: false,
              duration: TideMotion.ringFill,
              child: Container(
                width: 13,
                height: 13,
                decoration: const BoxDecoration(
                  color: TideColors.lantern,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 44),
        Opacity(
          opacity: 1 - morph,
          child: Column(
            children: [
              Text('The loop is set', style: TideType.hero),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 34),
                child: Text(
                  habitCount == 1
                      ? 'One habit, starting today. Swipe it right when it '
                            'is done.'
                      : '$habitCount habits, starting today. Swipe one right '
                            'when it is done.',
                  style: TideType.bodyMuted,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
        const Spacer(flex: 3),
      ],
    );
  }
}
