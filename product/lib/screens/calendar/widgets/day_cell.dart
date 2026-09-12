import 'package:flutter/material.dart';

import '../../../theme/tide_colors.dart';
import '../../../theme/tide_elevation.dart';
import '../../../theme/tide_motion.dart';
import '../../../theme/tide_typography.dart';
import '../../../widgets/press_scale.dart';

/// One day in the month grid.
///
/// The fill rises from the bottom in proportion to how much of that day was
/// completed — a water level, not a colour code. A day at 40% looks 40% full,
/// which is a more honest reading than a single "partial" tint, and it is the
/// same gesture as the tide on Home at a much smaller size.
///
/// Both layers are painted inside the clip, the empty ground first and the
/// water over it, rather than letting the empty state fall through to a
/// container's own background. Relying on the container meant a half-filled
/// day showed a band of bare page above its waterline while a wholly empty
/// day showed the cell colour — so a day that was 80% done looked damaged
/// rather than nearly finished.
class DayCell extends StatelessWidget {
  const DayCell({
    super.key,
    required this.day,
    required this.ratio,
    required this.delay,
    required this.onTap,
    this.outsideMonth = false,
    this.isToday = false,
    this.isFuture = false,
    this.beyondReach = false,
  });

  final int day;

  /// 0..1 aggregate completion for the day.
  final double ratio;

  final Duration delay;
  final VoidCallback onTap;
  final bool outsideMonth;
  final bool isToday;
  final bool isFuture;

  /// Outside the free plan's window. Drawn empty and dim like a day from the
  /// neighbouring month — the day is not gone, it is just not this plan's to
  /// look at — but still tappable, because the tap is what opens the paywall.
  /// Distinct from [isFuture], which is dead on every plan.
  final bool beyondReach;

  @override
  Widget build(BuildContext context) {
    final dim = outsideMonth || beyondReach ? 0.4 : 1.0;

    return PressScale(
      onTap: isFuture ? null : onTap,
      enabled: !isFuture,
      scale: 0.94,
      child: AspectRatio(
        aspectRatio: 1,
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(end: 1),
          duration: TideMotion.cellFill + delay,
          curve: Interval(
            (delay.inMilliseconds /
                    (TideMotion.cellFill.inMilliseconds + delay.inMilliseconds))
                .clamp(0.0, 0.85),
            1,
            curve: Curves.easeOutCubic,
          ),
          builder: (context, t, _) {
            final level = (ratio * t).clamp(0.0, 1.0);

            return ClipRRect(
              borderRadius: TideElevation.radius12,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // The empty ground, always full-bleed inside the clip.
                  ColoredBox(
                    color: TideColors.bone.withValues(alpha: 0.06 * dim),
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: FractionallySizedBox(
                      heightFactor: level,
                      child: ColoredBox(
                        color: TideColors.intensity(ratio).withValues(
                          alpha: TideColors.intensity(ratio).a * dim,
                        ),
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ),
                  if (isToday)
                    DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: TideElevation.radius12,
                        border: Border.all(
                          color: TideColors.lantern.withValues(alpha: 0.9),
                          width: 1.4,
                        ),
                      ),
                    ),
                  Center(
                    child: Text(
                      '$day',
                      style: TideType.gauge(
                        12.5,
                        // Once the water is over the middle of the cell the
                        // figure is sitting on solid lantern, and warm ink on
                        // a warm fill is unreadable. Past that point it flips
                        // to the ground colour.
                        color: level > 0.55
                            ? TideColors.onLantern
                            : outsideMonth || isFuture || beyondReach
                            ? TideColors.silt
                            : TideColors.bone,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
