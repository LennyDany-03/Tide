import 'dart:math' as math;
import 'dart:ui' show PointMode;

import 'package:flutter/material.dart';

import '../theme/tide_colors.dart';

/// A 1–2% noise wash over the page background.
///
/// Barely visible on its own, but it stops the large flat ground from
/// banding on OLED panels and gives the dark surfaces a slight materiality.
/// Painted in the palette's [TideColors.glint], so on a light palette — where
/// there is no banding to hide — it simply disappears into the page.
class GrainOverlay extends StatelessWidget {
  const GrainOverlay({super.key, this.opacity = 0.018, this.density = 2600});

  final double opacity;
  final int density;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _GrainPainter(
          opacity: opacity,
          density: density,
          color: TideColors.glint,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _GrainPainter extends CustomPainter {
  _GrainPainter({
    required this.opacity,
    required this.density,
    required this.color,
  });

  final double opacity;
  final int density;
  final Color color;

  /// Fixed seed: the grain must be stable, not crawl between frames.
  static final math.Random _random = math.Random(1401);
  static List<Offset>? _points;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    // Generated once in a unit square and scaled, so resizing the window
    // does not reshuffle the grain.
    _points ??= List<Offset>.generate(
      density,
      (_) => Offset(_random.nextDouble(), _random.nextDouble()),
    );

    final paint = Paint()
      ..color = color.withValues(alpha: opacity)
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.square;

    canvas.drawPoints(PointMode.points, [
      for (final point in _points!)
        Offset(point.dx * size.width, point.dy * size.height),
    ], paint);
  }

  @override
  bool shouldRepaint(_GrainPainter old) =>
      old.opacity != opacity || old.color != color;
}
