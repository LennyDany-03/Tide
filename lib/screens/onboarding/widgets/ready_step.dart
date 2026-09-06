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
        Transform.translate(
          // The drift this comment has always described and never did. The
          // ring only ever scaled, so the exit read as a thing swelling in
          // place and dissolving — the opposite of a hand-off. Rising as it
          // grows is what makes it travel toward where Home's hero sits.
          offset: Offset(0, -110 * Curves.easeInCubic.transform(morph)),
          child: Transform.scale(
            scale: 1 + 1.15 * Curves.easeInCubic.transform(morph),
            child: Opacity(
              // Held opaque well into the move, then dropped fast. Fading
              // linearly from the first frame meant the ring was already
              // half gone before it had gone anywhere.
              opacity: (1 - Curves.easeInCubic.transform(morph) * 1.45).clamp(
                0.0,
                1.0,
              ),
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
        ),
        const SizedBox(height: 44),
        Opacity(
          // Gone by the time the ring is halfway up. Text travelling with a
          // morph reads as the whole page sliding; text leaving first reads
          // as the ring being handed on.
          opacity: (1 - morph * 2.2).clamp(0.0, 1.0),
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
