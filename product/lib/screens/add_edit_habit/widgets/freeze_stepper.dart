import 'package:flutter/material.dart';

import '../../../config/app_constants.dart';
import '../../../config/pro_features.dart';
import '../../../theme/tide_colors.dart';
import '../../../theme/tide_elevation.dart';
import '../../../theme/tide_typography.dart';
import '../../../widgets/gauge_number.dart';
import '../../../widgets/press_scale.dart';
import '../../../widgets/pro_lock.dart';
import '../../../widgets/tide_surface.dart';

/// How many freezes this habit gets.
///
/// The count rolls rather than swapping, like every other number in the
/// app — even a small stepper is an instrument readout here.
///
/// [ceiling] is where + stops. It is the free allowance without Pro, and the
/// full allowance with it — so the gate is a number the stepper will not go
/// past rather than a control that disappears. Pressing + at a free ceiling
/// opens the paywall instead of doing nothing, because a button that ignores
/// you reads as broken and a button that explains itself reads as a price.
class FreezeStepper extends StatelessWidget {
  const FreezeStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.ceiling = AppConstants.maxFreezeAllowance,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final int ceiling;

  bool get _capped => ceiling < AppConstants.maxFreezeAllowance;

  /// At the free ceiling with more available on Pro.
  bool get _atGate => _capped && value >= ceiling;

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
                Row(
                  children: [
                    // Flexible, not bare: a Row hands its children unbounded
                    // width, so a title that fits the column happily runs
                    // past the stepper the moment a badge joins it.
                    Flexible(
                      child: Text(
                        'Streak freezes',
                        style: TideType.heading,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (_atGate) ...[
                      const SizedBox(width: 8),
                      const ProBadge(compact: true),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _atGate
                      ? ProFeatures.of(ProFeature.carryOverFreezes).blurb
                      : 'Skip a day without breaking the loop',
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
            // Live at the gate, so the press has somewhere to go. Only a
            // habit already holding the full allowance has nothing left to
            // offer, and that one is properly dead.
            enabled: value < ceiling || _atGate,
            onTap: _atGate
                ? () => askForPro(context, ProFeature.carryOverFreezes)
                : () => onChanged(value + 1),
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
