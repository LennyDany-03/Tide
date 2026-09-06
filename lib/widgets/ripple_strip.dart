import 'package:flutter/material.dart';

import '../theme/tide_colors.dart';
import '../theme/tide_motion.dart';

/// The seven-cell week strip on a habit row.
///
/// One square per day, oldest on the left, today on the right, shaded by how
/// much of that day was logged.
///
/// Squares specifically. Round dashes at this size read as a loading
/// indicator, and full-height bars read as a barcode or a battery meter —
/// both were tried. A row of small squares reads as days, because it is the
/// same mark the calendar and the habit-detail heatmap use, at a smaller
/// size. Sharing the mark is what makes the three surfaces feel like one
/// instrument rather than three charts.
///
/// It shares [TideColors.intensity] with those grids too, so a half-shaded
/// cell here and a half-shaded cell on the calendar mean the same thing.
class RippleStrip extends StatelessWidget {
  const RippleStrip({
    super.key,
    required this.levels,
    this.height = 8,
    this.spacing = 3,
    this.color,
    this.animate = true,
  });

  /// Seven values in 0..1, oldest first.
  final List<double> levels;

  /// Cell size. Square, so this is the width too.
  final double height;

  final double spacing;

  /// Overridden while a row is washing after a log.
  final Color? color;

  final bool animate;

  @override
  Widget build(BuildContext context) {
    // Sizes itself from the cells rather than stretching to fill a parent.
    // Stretching is what turned these into bars: seven Expanded children in
    // a 48px slot are 3px wide and 8px tall, which is a barcode, not a week.
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < levels.length; i++) ...[
          if (i > 0) SizedBox(width: spacing),
          _Cell(
            level: levels[i],
            size: height,
            color: color,
            animate: animate,
            // Filling left to right, the way the week actually ran.
            delay: TideMotion.cellStep * i * 2,
          ),
        ],
      ],
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({
    required this.level,
    required this.size,
    required this.color,
    required this.animate,
    required this.delay,
  });

  final double level;
  final double size;
  final Color? color;
  final bool animate;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    final target = color == null
        ? TideColors.intensity(level)
        : Color.lerp(
            TideColors.bone.withValues(alpha: 0.07),
            color,
            level.clamp(0.0, 1.0),
          )!;


    if (!animate) return _paint(target);

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: 1),
      duration: TideMotion.cellFill,
      curve: Curves.easeOutCubic,
      builder: (context, t, _) => _paint(
        Color.lerp(TideColors.bone.withValues(alpha: 0.07), target, t)!,
      ),
    );
  }

  Widget _paint(Color fill) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}
