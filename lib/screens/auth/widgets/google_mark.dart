import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../theme/tide_colors.dart';

/// The Google G, drawn rather than imported, and in one colour.
///
/// Monochrome is a deliberate call and the only one this palette allows.
/// `TideColors` is the whole colour vocabulary and no file outside
/// `lib/theme` may introduce a hue; dropping a four-colour logo onto the
/// one screen whose entire chromatic budget is a single warm accent would
/// make the provider button the loudest object on the page — louder than
/// the primary action beside it, which is the opposite of what a secondary
/// control should be. Drawn in [TideColors.bone] it sits at exactly the
/// weight of the label next to it, which is the weight it deserves.
///
/// Drawn as an arc and a bar rather than shipped as an asset so it scales
/// with the button and picks up the ink colour, the same way every other
/// glyph in the app does.
class GoogleMark extends StatelessWidget {
  const GoogleMark({super.key, this.size = 18, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _GoogleMarkPainter(color: color ?? TideColors.bone),
      ),
    );
  }
}

class _GoogleMarkPainter extends CustomPainter {
  const _GoogleMarkPainter({required this.color});

  final Color color;

  /// How much of the ring is drawn. The gap is the lower right, where the
  /// crossbar comes out.
  static const double _sweepDegrees = 310;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.shortestSide * 0.17;
    final radius = (size.shortestSide - stroke) / 2;
    final center = size.center(Offset.zero);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt
      ..color = color;

    // From three o'clock, anticlockwise the long way round, stopping short
    // of where it started so the opening lands under the bar.
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      0,
      -_sweepDegrees * math.pi / 180,
      false,
      paint,
    );

    // The bar, running in from the arc's terminus to just past the middle.
    canvas.drawLine(
      Offset(center.dx + radius * 0.05, center.dy),
      Offset(center.dx + radius + stroke / 2, center.dy),
      paint,
    );
  }

  @override
  bool shouldRepaint(_GoogleMarkPainter old) => old.color != color;
}
