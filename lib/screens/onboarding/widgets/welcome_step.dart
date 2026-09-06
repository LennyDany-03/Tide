import 'package:flutter/material.dart';

import '../../../theme/tide_colors.dart';
import '../../../theme/tide_typography.dart';
import '../../../widgets/tide_ring.dart';

/// Step one.
///
/// The ring draws itself in from empty as the screen loads, before any tap
/// happens — the app performing its central gesture once, unprompted, so
/// the ring is already familiar by the time it turns up on a habit card.
class WelcomeStep extends StatelessWidget {
  const WelcomeStep({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Spacer(flex: 2),
        TideRingDrawIn(
          size: 164,
          strokeWidth: 4,
          child: Container(
            width: 14,
            height: 14,
            decoration: const BoxDecoration(
              color: TideColors.lantern,
              shape: BoxShape.circle,
            ),
          ),
        ),
        const SizedBox(height: 44),
        Text('Tide', style: TideType.screenTitle.copyWith(fontSize: 38)),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Text(
            'Habits move like water. Small, daily, repeating. Pick two or '
            'three and we will set the rhythm.',
            style: TideType.bodyMuted,
            textAlign: TextAlign.center,
          ),
        ),
        const Spacer(flex: 3),
      ],
    );
  }
}
