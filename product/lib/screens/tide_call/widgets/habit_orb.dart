import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../services/models/tide_glyph.dart';
import '../../../theme/tide_colors.dart';
import '../../../theme/tide_gradients.dart';
import '../../../theme/tide_motion.dart';
import '../../../widgets/habit_glyph.dart';

/// The habit at the centre of a Tide Call: a glass sphere most of the way
/// full, the water inside sloshing gently, the habit's mark under it.
///
/// It is the logo's own recipe — the ring's ramp, the water's ramp — drawn
/// as a globe, so a call reads as Tide before a word of it is read. There is
/// no per-habit colour in this app and so none here: the accent is the
/// water, and the habit is its mark.
///
/// [hold] is the hold-to-skip filling around the rim, in frost, because a
/// skipped day is a frozen one and frost is the only colour that means it.
class HabitOrb extends StatelessWidget {
  const HabitOrb({
    super.key,
    required this.glyph,
    required this.size,
    required this.time,
    this.hold = 0,
    this.still = false,
  });

  final TideGlyph glyph;
  final double size;
  final ValueListenable<double> time;
  final double hold;
  final bool still;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _OrbPainter(time: time, hold: hold, still: still),
            ),
          ),
          // Below the waterline, in the ink that sits on the accent.
          Padding(
            padding: EdgeInsets.only(top: size * 0.08),
            child: HabitGlyph(
              glyph: glyph,
              size: size * 0.3,
              color: TideColors.onLantern,
              strokeWidth: 2.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _OrbPainter extends CustomPainter {
  _OrbPainter({required this.time, required this.hold, required this.still})
    : super(repaint: time);

  final ValueListenable<double> time;
  final double hold;
  final bool still;

  /// How full the globe stands at rest: high enough that the mark sits
  /// wholly under the water however it sloshes.
  static const double _fill = 0.7;

  @override
  void paint(Canvas canvas, Size size) {
    final t = still ? 0.0 : time.value;
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 4;
    final palette = TideColors.palette;
    final globe = Rect.fromCircle(center: center, radius: radius);

    // Light pooled around the globe, falling to nothing.
    canvas.drawCircle(
      center,
      radius * 1.5,
      Paint()
        ..shader = TideGradients.bloom(
          color: TideColors.lantern,
          alpha: palette.isLight ? 0.12 : 0.22,
          center: Alignment.center,
          radius: 0.5,
        ).createShader(Rect.fromCircle(center: center, radius: radius * 1.5)),
    );

    canvas.save();
    canvas.clipPath(Path()..addOval(globe));
    canvas.drawRect(globe, Paint()..color = TideColors.trench);

    // The slosh: the surface tips one way and back on the bob's period, with
    // a small wave running along it.
    final period = TideMotion.callBob.inMilliseconds / 1000;
    final tilt = math.sin(t * 2 * math.pi / period) * 0.07;
    final surfaceY = globe.bottom - globe.height * _fill;
    final surface = Path()..moveTo(globe.left, surfaceY);
    const steps = 32;
    for (var i = 0; i <= steps; i++) {
      final u = i / steps;
      final x = globe.left + globe.width * u;
      final y =
          surfaceY +
          (u - 0.5) * globe.width * tilt +
          math.sin(u * math.pi * 3 + t * 2.1) * radius * 0.025;
      surface.lineTo(x, y);
    }
    final water = Path.from(surface)
      ..lineTo(globe.right, globe.bottom)
      ..lineTo(globe.left, globe.bottom)
      ..close();
    canvas.drawPath(
      water,
      Paint()..shader = TideGradients.markWater(palette).createShader(globe),
    );
    canvas.drawPath(
      surface,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = palette.flare.withValues(alpha: 0.8),
    );

    // The glass catching the one light, top left.
    canvas.drawArc(
      globe.deflate(radius * 0.14),
      math.pi * 1.08,
      math.pi * 0.42,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.06
        ..strokeCap = StrokeCap.round
        ..color = TideColors.glint.withValues(alpha: 0.16),
    );
    canvas.restore();

    // The rim, in the mark's ramp.
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..shader = TideGradients.markRing(palette).createShader(globe),
    );

    if (hold > 0) {
      canvas.drawArc(
        globe.inflate(7),
        -math.pi / 2,
        2 * math.pi * hold.clamp(0.0, 1.0),
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round
          ..color = TideColors.frost,
      );
    }
  }

  @override
  bool shouldRepaint(_OrbPainter old) =>
      old.hold != hold || old.time != time || old.still != still;
}
