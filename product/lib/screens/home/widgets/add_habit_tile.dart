import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../theme/tide_colors.dart';
import '../../../theme/tide_elevation.dart';
import '../../../theme/tide_typography.dart';
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
  const AddHabitTile({super.key, required this.onTap});

  final VoidCallback onTap;

  static const double height = 62;

  @override
  Widget build(BuildContext context) {
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
                  child: Icon(
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
