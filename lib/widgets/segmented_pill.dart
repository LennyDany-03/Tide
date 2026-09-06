import 'package:flutter/material.dart';

import '../theme/tide_colors.dart';
import '../theme/tide_elevation.dart';
import '../theme/tide_motion.dart';
import '../theme/tide_typography.dart';
import 'press_scale.dart';

/// A segmented control whose selection is a pill that slides between
/// options rather than a highlight that jumps.
///
/// The same sliding-pill mechanic sits under the bottom tab bar's active
/// indicator, so switching a habit's type and switching tabs feel like the
/// same control at two sizes.
class SegmentedPill extends StatelessWidget {
  const SegmentedPill({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onChanged,
    this.height = 44,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final double height;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final segmentWidth = constraints.maxWidth / labels.length;

        return SizedBox(
          height: height,
          child: Stack(
            children: [
              // The recessed track.
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: TideColors.trench,
                    borderRadius: TideElevation.radius12,
                  ),
                ),
              ),

              // The pill.
              AnimatedPositioned(
                duration: TideMotion.pillSlide,
                curve: TideMotion.pillCurve,
                left: segmentWidth * selectedIndex,
                top: 0,
                bottom: 0,
                width: segmentWidth,
                child: Padding(
                  padding: const EdgeInsets.all(3),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: TideColors.bone.withValues(alpha: 0.14),
                      borderRadius: TideElevation.radius12,
                    ),
                  ),
                ),
              ),

              Row(
                children: [
                  for (var i = 0; i < labels.length; i++)
                    Expanded(
                      child: PressScale(
                        onTap: () => onChanged(i),
                        child: SizedBox.expand(
                          child: Center(
                            child: AnimatedDefaultTextStyle(
                              duration: TideMotion.pillSlide,
                              style: TideType.label.copyWith(
                                color: i == selectedIndex
                                    ? TideColors.bone
                                    : TideColors.silt,
                                fontWeight: i == selectedIndex
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                              child: Text(labels[i]),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
