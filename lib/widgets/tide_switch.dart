import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/tide_colors.dart';
import '../theme/tide_motion.dart';

/// The toggle.
///
/// Settings is the screen that deliberately holds back on animation, so its
/// one flourish is here: the knob slides with a touch of overshoot. That
/// small spring is the whole personality budget for that screen.
class TideSwitch extends StatelessWidget {
  const TideSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.width = 42,
    this.height = 24,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final knob = height - 6;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        onChanged(!value);
      },
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(end: value ? 1 : 0),
        duration: TideMotion.pillSlide,
        curve: TideMotion.overshoot,
        builder: (context, t, _) {
          // The overshoot curve runs past 1 and back; clamping only the
          // colour keeps the spring visible in the knob's travel while the
          // fill stays a legal colour.
          final colorT = t.clamp(0.0, 1.0);

          return Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              // No border. An outlined track plus a filled track plus a
              // knob is three edges describing one control.
              color: Color.lerp(
                TideColors.bone.withValues(alpha: 0.10),
                TideColors.lantern,
                colorT,
              ),
              borderRadius: BorderRadius.circular(height),
            ),
            child: Stack(
              children: [
                Positioned(
                  top: 2.5,
                  left: 2.5 + (width - knob - 6) * t,
                  child: Container(
                    width: knob,
                    height: knob,
                    decoration: BoxDecoration(
                      color: Color.lerp(
                        TideColors.silt,
                        TideColors.deepWater,
                        colorT,
                      ),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
