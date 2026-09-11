import 'package:flutter/material.dart';

import '../../../theme/tide_colors.dart';
import '../../../theme/tide_typography.dart';

/// One line of the free-versus-Pro comparison.
///
/// The free-plan limit sits on the right in gauge type, so the row states
/// what you have as well as what you would get. A comparison that only
/// listed the upsides would be doing something other than informing.
class FeatureRow extends StatelessWidget {
  const FeatureRow({super.key, required this.label, required this.freeLimit});

  final String label;

  /// What the free plan gives — "5 free", "30 days", or "—" for nothing.
  final String freeLimit;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.check_rounded, size: 17, color: TideColors.lantern),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: TideType.body)),
        const SizedBox(width: 12),
        Text(freeLimit, style: TideType.gauge(12, color: TideColors.silt)),
      ],
    );
  }
}
