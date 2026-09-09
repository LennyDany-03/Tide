import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/tide_colors.dart';

/// A single sine wave whose amplitude responds to a gesture.
///
/// Two callers, one idea — water reacting to the finger: the tide-blue
/// trail behind a swipe-to-complete, and the horizontal wave that deforms
/// with pull distance instead of a generic refresh spinner.
class TideWave extends StatelessWidget {
  const TideWave({
    super.key,
    required this.amplitude,
    this.phase = 0,
    this.color,
    this.strokeWidth = 2,
    this.fill = false,
    this.waves = 1.6,
    this.taperStart = true,
    this.taperEnd = true,
  });

  /// 0..1 — how far the water has been pulled.
  final double amplitude;

  /// Advances the crest along the wave, so a held gesture keeps moving.
  final double phase;

  final Color? color;
  final double strokeWidth;

  /// Filled below the curve, for the swipe trail; stroked only, for pull.
  final bool fill;

  final double waves;

  /// Which ends of the curve are drawn down to the midline.
  ///
  /// Both by default, and both is right for the pull-to-refresh: a curve
  /// running off either side of the screen reads as clipped rather than as
  /// water.
  ///
  /// The swipe trail tapers only at its *outer* end. Flattened at the end
  /// against the card, the fill below the curve drops to half-height right
  /// at the seam, which leaves the darker tint above it as a band hugging
  /// the card's edge — and a dark band along one edge of a card is a drop
  /// shadow, whatever it was meant to be. Holding full amplitude there is
  /// also the truer reading: the water is deepest where the finger pulled
  /// it from.
  final bool taperStart;
  final bool taperEnd;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: TideWavePainter(
        amplitude: amplitude,
        phase: phase,
        color: color ?? TideColors.lantern,
        strokeWidth: strokeWidth,
        fill: fill,
        waves: waves,
        taperStart: taperStart,
        taperEnd: taperEnd,
      ),
      size: Size.infinite,
    );
  }
}

class TideWavePainter extends CustomPainter {
  const TideWavePainter({
    required this.amplitude,
    required this.phase,
    required this.color,
    this.strokeWidth = 2,
    this.fill = false,
    this.waves = 1.6,
    this.taperStart = true,
    this.taperEnd = true,
  });

  final double amplitude;
  final double phase;
  final Color color;
  final double strokeWidth;
  final bool fill;
  final double waves;
  final bool taperStart;
  final bool taperEnd;

  /// How much of the wave's amplitude survives at [t] along the curve.
  double _taperAt(double t) {
    if (taperStart && taperEnd) return math.sin(math.pi * t);
    if (taperStart) return math.sin(math.pi * t / 2);
    if (taperEnd) return math.sin(math.pi * (1 - t) / 2);
    return 1;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final peak = size.height * 0.34 * amplitude.clamp(0.0, 1.5);
    final midline = size.height / 2;
    final path = Path()..moveTo(0, midline);

    const steps = 48;
    for (var i = 0; i <= steps; i++) {
      final x = size.width * i / steps;
      final theta = (i / steps) * waves * 2 * math.pi + phase;
      path.lineTo(x, midline - math.sin(theta) * peak * _taperAt(i / steps));
    }

    if (fill) {
      final filled = Path.from(path)
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close();

      // Graded down from the surface rather than a flat wash. A single
      // alpha across the whole fill puts one solid value against another
      // solid value with the curve as a hard border between them, so the
      // trail read as two stacked slabs — and the darker one, being the
      // one at the top, read as shade. Light falls on water at the
      // surface and runs out with depth; drawing that is what makes the
      // boundary a waterline instead of an edge.
      canvas.drawPath(
        filled,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              color.withValues(alpha: 0.24),
              color.withValues(alpha: 0.10),
            ],
          ).createShader(Offset.zero & size),
      );
    }

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..color = color.withValues(
          alpha: 0.5 + 0.5 * amplitude.clamp(0.0, 1.0),
        ),
    );
  }

  @override
  bool shouldRepaint(TideWavePainter old) =>
      old.amplitude != amplitude ||
      old.phase != phase ||
      old.color != color ||
      old.fill != fill ||
      old.taperStart != taperStart ||
      old.taperEnd != taperEnd;
}
