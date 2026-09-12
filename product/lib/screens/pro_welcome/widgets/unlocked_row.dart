import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../config/pro_features.dart';
import '../../../theme/tide_colors.dart';
import '../../../theme/tide_typography.dart';

/// One thing that has just been unlocked, arriving.
///
/// The tick draws itself rather than fading in — a checkmark that appears
/// between two frames has not *happened*, it was simply always there. Two
/// strokes over a short arc is the same gesture `TideTick` makes on the code
/// screen, at the size a list row can afford.
///
/// The free allowance is struck through beside it, which is the whole point of
/// the row: the person is not being told what Pro includes, they are being
/// shown what just stopped applying to them.
class UnlockedRow extends StatelessWidget {
  const UnlockedRow({super.key, required this.feature, required this.progress});

  final ProFeature feature;

  /// 0..1 for this row alone — the parent staggers them.
  final double progress;

  @override
  Widget build(BuildContext context) {
    final spec = ProFeatures.of(feature);
    final t = progress.clamp(0.0, 1.0);
    // The row arrives over the first half, the tick draws through the second.
    final arrive = (t / 0.55).clamp(0.0, 1.0);
    final tick = ((t - 0.45) / 0.55).clamp(0.0, 1.0);

    return Opacity(
      opacity: Curves.easeOut.transform(arrive),
      child: Transform.translate(
        offset: Offset(0, 10 * (1 - Curves.easeOutCubic.transform(arrive))),
        child: Row(
          children: [
            SizedBox(
              width: 26,
              height: 26,
              child: CustomPaint(painter: _TickPainter(progress: tick)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                spec.label,
                style: TideType.body,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 12),
            // The old ceiling, struck out. Nothing says "this no longer
            // applies to you" as economically as a line through it.
            Text(
              spec.freeAllowance,
              style: TideType.gauge(11.5, color: TideColors.silt).copyWith(
                decoration: TextDecoration.lineThrough,
                decorationColor: TideColors.silt.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TickPainter extends CustomPainter {
  const _TickPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final radius = size.width / 2;

    canvas.drawCircle(
      centre,
      radius,
      Paint()..color = TideColors.lantern.withValues(alpha: 0.14 * progress),
    );

    if (progress <= 0) return;

    // Two strokes, drawn in order: the short down-stroke, then the long one.
    final short = Offset(size.width * 0.28, size.height * 0.52);
    final corner = Offset(size.width * 0.44, size.height * 0.68);
    final long = Offset(size.width * 0.74, size.height * 0.34);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = TideColors.lantern;

    // The first third of the progress draws the short stroke; the rest draws
    // the long one, so the corner is a real turn rather than a scale.
    final first = (progress / 0.34).clamp(0.0, 1.0);
    final second = ((progress - 0.34) / 0.66).clamp(0.0, 1.0);

    final path = Path()..moveTo(short.dx, short.dy);
    path.lineTo(
      short.dx + (corner.dx - short.dx) * first,
      short.dy + (corner.dy - short.dy) * first,
    );
    if (second > 0) {
      path.lineTo(
        corner.dx + (long.dx - corner.dx) * second,
        corner.dy + (long.dy - corner.dy) * second,
      );
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_TickPainter old) => old.progress != progress;
}

/// The crown of light the sequence opens on.
///
/// Spokes rather than rings, for the reason `UnlockCelebration` gives: a ring
/// spreading outward is what the app does every time somebody logs a habit,
/// and the rarest moment in the product must not open with the commonest
/// animation at a larger size.
class LightCrown extends StatelessWidget {
  const LightCrown({super.key, required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _CrownPainter(progress: progress));
}

class _CrownPainter extends CustomPainter {
  const _CrownPainter({required this.progress});

  final double progress;

  static const int _spokes = 14;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;

    final centre = size.center(Offset.zero);
    final eased = Curves.easeOutCubic.transform(progress);
    // Opens outward and fades as it goes, so the light leaves rather than
    // being switched off.
    final fade = (1 - progress) * (1 - progress);
    final inner = size.shortestSide * (0.10 + 0.22 * eased);
    final outer = inner + size.shortestSide * 0.20 * (1 - eased * 0.4);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.4
      ..color = TideColors.lantern.withValues(alpha: 0.55 * fade);

    for (var i = 0; i < _spokes; i++) {
      final angle = (i / _spokes) * 2 * math.pi;
      final dx = math.cos(angle);
      final dy = math.sin(angle);
      canvas.drawLine(
        centre + Offset(dx * inner, dy * inner),
        centre + Offset(dx * outer, dy * outer),
        paint,
      );
    }

    // A soft pool at the centre, so the spokes look thrown by something.
    canvas.drawCircle(
      centre,
      inner * 0.9,
      Paint()
        ..shader = RadialGradient(
          colors: [
            TideColors.lantern.withValues(alpha: 0.30 * fade),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: centre, radius: inner * 0.9)),
    );
  }

  @override
  bool shouldRepaint(_CrownPainter old) => old.progress != progress;
}
