import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/tide_colors.dart';
import '../theme/tide_motion.dart';

/// The ring and tick Tide draws when something has finished for good.
///
/// One drawing with two owners: the code screen, where the envelope folds
/// away into it, and the farewell after an account is deleted. It is one
/// painting routine rather than two lookalikes so that the app's single way
/// of saying "that is done" cannot drift into two slightly different ones.
///
/// [paint] reads the code screen's whole acceptance clock, whose first fifth
/// belongs to the envelope leaving — nothing of the tick is drawn before
/// [start]. A screen with no envelope to fold away starts its clock there.
abstract final class TideTick {
  /// Where the ring begins to draw, and where a standalone tick starts.
  static const double start = 0.2;

  /// [t] eased through the stretch from [from] to [to].
  static double span(double t, double from, double to) => TideMotion
      .morphCurve
      .transform(((t - from) / (to - from)).clamp(0.0, 1.0));

  /// The first [t] of [source]'s length, across however many contours.
  static Path trace(Path source, double t) {
    if (t <= 0) return Path();
    if (t >= 1) return source;
    final metrics = source.computeMetrics().toList();
    var remaining = metrics.fold<double>(0, (sum, m) => sum + m.length) * t;
    final out = Path();
    for (final metric in metrics) {
      if (remaining <= 0) break;
      final take = math.min(remaining, metric.length);
      out.addPath(metric.extractPath(0, take), Offset.zero);
      remaining -= take;
    }
    return out;
  }

  /// The glow, the ring drawing round, the tick through it, and two rings
  /// leaving — at [t], 0..1.
  static void paint(Canvas canvas, Size size, double t, Color color) {
    if (t <= 0) return;

    final s = size.shortestSide;
    final c = size.center(Offset.zero);
    final stroke = s * 0.04;

    Paint line([double weight = 1]) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke * weight
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;

    final radius = s * 0.42;
    canvas.drawCircle(
      c,
      radius,
      Paint()..color = color.withValues(alpha: 0.14 * span(t, 0.3, 0.7)),
    );

    final ring = span(t, 0.2, 0.65);
    if (ring > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: radius),
        -math.pi / 2,
        ring * 2 * math.pi,
        false,
        line(),
      );
    }

    final tick = Path()
      ..moveTo(c.dx - s * 0.17, c.dy + s * 0.01)
      ..lineTo(c.dx - s * 0.05, c.dy + s * 0.13)
      ..lineTo(c.dx + s * 0.19, c.dy - s * 0.12);
    canvas.drawPath(trace(tick, span(t, 0.55, 0.9)), line(1.3));

    // Two rings leaving the mark, the second trailing the first. Painted
    // past the widget's bounds on purpose: a clipped ripple is a flicker.
    final ripple = span(t, 0.62, 1);
    for (final (delay, strength) in [(0.0, 0.4), (0.22, 0.24)]) {
      final p = ((ripple - delay) / (1 - delay)).clamp(0.0, 1.0);
      if (p <= 0 || p >= 1) continue;
      canvas.drawCircle(
        c,
        radius * (1 + 0.55 * p),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = color.withValues(alpha: strength * (1 - p)),
      );
    }
  }
}

/// [TideTick] on its own, drawn in lantern as [progress] runs.
class TideTickMark extends StatelessWidget {
  const TideTickMark({super.key, required this.progress, this.size = 84});

  /// On [TideTick]'s clock: nothing shows before [TideTick.start].
  final Animation<double> progress;

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _TickPainter(progress: progress, color: TideColors.lantern),
        ),
      ),
    );
  }
}

class _TickPainter extends CustomPainter {
  _TickPainter({required this.progress, required this.color})
    : super(repaint: progress);

  final Animation<double> progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) =>
      TideTick.paint(canvas, size, progress.value, color);

  @override
  bool shouldRepaint(_TickPainter old) =>
      old.progress != progress || old.color != color;
}
