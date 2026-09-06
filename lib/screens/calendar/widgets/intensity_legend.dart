import 'package:flutter/material.dart';

import '../../../theme/tide_colors.dart';
import '../../../theme/tide_typography.dart';

/// The key for the grid's fill levels.
///
/// Five swatches at the same size and radius as a day cell, drawn from the
/// same [TideColors.intensity] ramp, so the legend cannot drift out of step
/// with what it explains — and so it reads as a sample of the grid rather
/// than as a gradient bar, which is a different object entirely.
class IntensityLegend extends StatelessWidget {
  const IntensityLegend({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text('None', style: TideType.labelMuted),
        const SizedBox(width: 10),
        for (final level in const [0.0, 0.25, 0.5, 0.75, 1.0]) ...[
          if (level > 0) const SizedBox(width: 4),
          Container(
            width: 13,
            height: 13,
            decoration: BoxDecoration(
              color: TideColors.intensity(level),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
        const SizedBox(width: 10),
        Text('All logged', style: TideType.labelMuted),
      ],
    );
  }
}
