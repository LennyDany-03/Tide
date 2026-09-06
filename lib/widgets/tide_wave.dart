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
  });

  final double amplitude;
  final double phase;
  final Color color;
  final double strokeWidth;
  final bool fill;
  final double waves;

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
      // Taper the wave at both ends so it reads as water inside the card
      // rather than a curve that has been clipped off.
      final taper = math.sin(math.pi * i / steps);
      path.lineTo(x, midline - math.sin(theta) * peak * taper);
    }

    if (fill) {
      final filled = Path.from(path)
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close();
      canvas.drawPath(filled, Paint()..color = color.withValues(alpha: 0.18));
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
      old.fill != fill;
}
