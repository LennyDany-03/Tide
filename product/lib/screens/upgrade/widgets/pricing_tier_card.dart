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
    this.badge,
  });

  final String title;
  final String price;
  final String note;

  /// A figure worth putting on the card — "Save 37%". Only ever on the plan
  /// it is true of: a badge on both tiers is decoration, and a badge on the
  /// one that saves nothing is a lie.
  final String? badge;

  final bool selected;

  /// Null while a payment is in flight, so the tier cannot be switched under
  /// an order that has already been opened for the other one.
  final VoidCallback? onTap;

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
            Row(
              children: [
                Expanded(child: Text(title, style: TideType.labelMuted)),
                if (badge != null) _Badge(label: badge!, lit: selected),
              ],
            ),
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

/// The saving, in the one place it is true.
class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.lit});

  final String label;
  final bool lit;

  @override
  Widget build(BuildContext context) {
    // Lantern, because it is the app's one accent and this is the only
    // chromatic mark on the sheet outside the button. It dims rather than
    // disappears when the tier is not selected: the saving is true either
    // way, and a badge that vanishes on tap looks like a bug.
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: TideColors.lantern.withValues(alpha: lit ? 0.18 : 0.10),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TideType.gauge(
          10,
          color: TideColors.lantern.withValues(alpha: lit ? 1 : 0.62),
        ),
      ),
    );
  }
}
