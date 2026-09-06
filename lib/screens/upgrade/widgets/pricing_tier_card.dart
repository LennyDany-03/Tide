import 'package:flutter/material.dart';

import '../../../theme/tide_colors.dart';
import '../../../theme/tide_elevation.dart';
import '../../../theme/tide_motion.dart';
import '../../../theme/tide_typography.dart';
import '../../../widgets/press_scale.dart';

/// A pricing option.
class PricingTierCard extends StatelessWidget {
  const PricingTierCard({
    super.key,
    required this.title,
    required this.price,
    required this.note,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String price;
  final String note;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onTap,
      child: AnimatedContainer(
        duration: TideMotion.tabSwitch,
        curve: TideMotion.tabCurve,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        // Neutral selection, like every other picker in the app: accent
        // means progress here, not "you tapped this", and a warm wash under
        // the price would compete with the button that takes the payment.
        decoration: BoxDecoration(
          color: TideColors.bone.withValues(alpha: selected ? 0.10 : 0.035),
          borderRadius: TideElevation.radius12,
          border: Border.all(
            color: selected ? TideColors.bone.withValues(alpha: 0.35)
                : Colors.transparent,
            width: 1.4,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: TideType.labelMuted),
            const SizedBox(height: 8),
            Text(
              price,
              style: TideType.gauge(
                24,
                color: selected ? TideColors.bone : TideColors.silt,
              ),
            ),
            const SizedBox(height: 6),
            Text(note, style: TideType.labelMuted.copyWith(fontSize: 11.5)),
          ],
        ),
      ),
    );
  }
}
