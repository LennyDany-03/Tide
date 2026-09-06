import 'package:flutter/material.dart';

import '../../../config/app_constants.dart';
import '../../../theme/tide_colors.dart';
import '../../../theme/tide_elevation.dart';
import '../../../theme/tide_typography.dart';
import '../../../widgets/gauge_number.dart';
import '../../../widgets/press_scale.dart';
import '../../../widgets/tide_surface.dart';

/// How many freezes this habit gets.
///
/// The count rolls rather than swapping, like every other number in the
/// app — even a small stepper is an instrument readout here.
class FreezeStepper extends StatelessWidget {
  const FreezeStepper({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return TideSurface(
      color: TideColors.trench,
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Streak freezes', style: TideType.heading),
                const SizedBox(height: 4),
                Text(
                  'Skip a day without breaking the loop',
                  style: TideType.labelMuted,
                ),
              ],
            ),
          ),
          _Button(
            icon: Icons.remove_rounded,
            enabled: value > 0,
            onTap: () => onChanged(value - 1),
          ),
          SizedBox(
            width: 40,
            child: Center(
              child: GaugeNumber(
                value: value,
                style: TideType.gauge(17, color: TideColors.bone),
              ),
            ),
          ),
          _Button(
            icon: Icons.add_rounded,
            enabled: value < AppConstants.maxFreezeAllowance,
            onTap: () => onChanged(value + 1),
          ),
        ],
      ),
    );
  }
}

class _Button extends StatelessWidget {
  const _Button({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: enabled ? onTap : null,
      enabled: enabled,
      child: Opacity(
        opacity: enabled ? 1 : 0.35,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: TideColors.shelf,
            borderRadius: TideElevation.radius12,
          ),
          child: Icon(icon, size: 17, color: TideColors.bone),
        ),
      ),
    );
  }
}
