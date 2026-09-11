import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../config/app_constants.dart';
import '../../../theme/tide_colors.dart';
import '../../../theme/tide_elevation.dart';
import '../../../theme/tide_typography.dart';
import '../../../widgets/gauge_number.dart';
import '../../../widgets/press_scale.dart';

/// The way to add a habit, sitting where the next habit would go.
///
/// It was a 38px tile in the header, immediately beside the milestones
/// glyph — two unrelated destinations rendered as two small marks in the
/// same corner, which is how you get people opening the trophy case when
/// they meant to add something. The bottom-right corner was no better: a
/// floating disc there lands on the tab bar's glass and on whatever the
/// last card is trying to say.
///
/// So it lives in the list instead, one slot below the last habit, drawn as
/// the empty slot it is: no fill, and a *dashed* edge. A solid hairline made
/// it one more card in a stack of cards, differing from the habits above
/// only by being dimmer. A dashed outline is the universal mark for
/// "something goes here", and it reads as a space rather than a thing
/// before the label has been read.
class AddHabitTile extends StatelessWidget {
  const AddHabitTile({
    super.key,
    required this.onTap,
    this.atLimit = false,
    this.used,
    this.limit = AppConstants.freeHabitLimit,
  });

  final VoidCallback onTap;

  /// The free plan is full, so this opens the paywall instead. Said plainly
  /// rather than by disabling the control and leaving the user to guess.
  final bool atLimit;

  /// Habits in use on the free plan, or null on Pro — where there is no
  /// ceiling and counting toward one would be noise.
  final int? used;

  final int limit;

  static const double height = 62;

  @override
  Widget build(BuildContext context) {
    final count = used;

    return PressScale(
      onTap: onTap,
      child: CustomPaint(
        painter: _DashedOutline(color: TideColors.bone.withValues(alpha: 0.16)),
        child: SizedBox(
          height: height,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: TideColors.lantern.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.add_rounded,
                    size: 18,
                    color: TideColors.lantern,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'Add a habit',
                    style: TideType.label.copyWith(
                      color: TideColors.bone.withValues(alpha: 0.78),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (atLimit)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: TideColors.lantern.withValues(alpha: 0.12),
                      borderRadius: TideElevation.radius12,
                    ),
                    child: Text(
                      'Tide Pro',
                      style: TideType.labelMuted.copyWith(
                        fontSize: 12,
                        color: TideColors.lantern,
                      ),
                    ),
                  )
                else if (count != null)
                  // How much of the free plan is used, before it runs out
                  // rather than only at the moment it does.
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      GaugeNumber(
                        value: count,
                        style: TideType.gauge(13, color: TideColors.silt),
                      ),
                      Text(
                        ' of $limit free',
                        style: TideType.labelMuted.copyWith(fontSize: 12),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A 1px dashed rounded rectangle at the card radius, so the empty slot is
/// exactly the shape of the card that would fill it.
class _DashedOutline extends CustomPainter {
  const _DashedOutline({required this.color});

  final Color color;

  static const double _dash = 5;
  static const double _gap = 4;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final outline = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          (Offset.zero & size).deflate(0.5),
          const Radius.circular(TideElevation.r20),
        ),
      );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = color;

    for (final metric in outline.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += _dash + _gap) {
        canvas.drawPath(
          metric.extractPath(d, math.min(d + _dash, metric.length)),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_DashedOutline old) => old.color != color;
}
