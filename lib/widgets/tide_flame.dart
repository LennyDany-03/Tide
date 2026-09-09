import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/tide_colors.dart';
import '../theme/tide_gradients.dart';
import '../theme/tide_motion.dart';

/// A fire, burning for as long as the run it is measuring.
///
/// The streak used to be a ring filling toward the next milestone, which is
/// an accurate instrument answering the wrong question. A ring reports how
/// far through a leg you are; a streak's entire emotional content is that it
/// is *still alight* and that letting it go out would cost something.
///
/// **This is light, not a shape.** The first version of it was three opaque
/// teardrops drawn at three sizes, and it read exactly as what it was:
/// concentric outlines stacked into an onion, with a near-white core sitting
/// in the middle like a bulb. Everything about that was wrong, and all of it
/// for the same reason — fire has no edges. Nothing here is drawn without a
/// blur, no layer goes past 0.38 alpha, and the whole thing sits on a
/// seven-stop bloom whose falloff never terminates anywhere the eye can find
/// it. What you should be able to see is a warm glow with a brighter heart
/// moving inside it; what you should never be able to see is where any one
/// of those pieces begins.
///
/// Three things make the motion read as combustion rather than as a
/// flame-shaped icon breathing:
///
/// * **Nothing moves as one object.** Each tongue runs on its own flicker
///   phase, so the core darts while the outer body is still leaning the
///   other way. A single path scaled up and down is a logo pulsing.
/// * **The flicker is three sines, not one.** A single sine is a heartbeat
///   and the eye finds its period within two cycles. Summed at 3, 7 and 11
///   times the base rate there is no findable beat — but the multipliers are
///   whole numbers, so the loop still closes seamlessly.
/// * **The base stays put.** Real fire is anchored where it meets its fuel
///   and loose at the tip. The seat is a soft hot ellipse that barely moves;
///   everything above it does.
///
/// The palette rule holds and costs nothing here: this is
/// [TideColors.lantern] lerped a little toward [TideColors.bone] for the
/// heart, which is the one thing the app's single warm accent was always
/// going to be able to draw. It is deliberately *not* pushed far toward
/// bone — a white-hot centre is what made the first version look like a
/// lightbulb, and amber light on a near-black card is already the whole
/// effect. Coral is not available: it means destruction and nothing else.
class TideFlame extends StatefulWidget {
  const TideFlame({super.key, this.intensity = 1});

  /// 0..1. Scales the height, the brightness and how many embers come off
  /// the top, so a two-day run is an ember and a hundred-day run is a fire
  /// without either needing a different widget.
  final double intensity;

  @override
  State<TideFlame> createState() => _TideFlameState();
}

class _TideFlameState extends State<TideFlame>
    with SingleTickerProviderStateMixin {
  late final AnimationController _burn = AnimationController(
    vsync: this,
    duration: TideMotion.flameCycle,
  )..repeat();

  @override
  void dispose() {
    _burn.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Ambient and permanent, so it pays for its own layer rather than
    // dirtying the card it sits in sixty times a second. The shell already
    // pauses the ticker on tabs that are not showing.
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _burn,
        builder: (context, _) => CustomPaint(
          painter: _FlamePainter(
            t: _burn.value,
            intensity: widget.intensity.clamp(0.0, 1.0),
          ),
        ),
      ),
    );
  }
}

/// One soft body of light in the flame: how big, how bright, how warm, and
/// how far it is blurred past its own outline.
typedef _Layer = ({
  double scale,
  double phase,
  double alpha,
  double hot,
  double blur,
});

class _FlamePainter extends CustomPainter {
  const _FlamePainter({required this.t, required this.intensity});

  /// 0..1 through one burn cycle.
  final double t;

  final double intensity;

  /// Outer body, middle, heart.
  ///
  /// The alphas are low and the blurs are wide, and the two are tied: the
  /// bigger a layer is, the less of it you should be able to locate. The
  /// heart is smallest, brightest and warmest — the hot part of a fire is
  /// the middle, and painting the outside brightest is what makes a drawn
  /// flame read as plastic.
  /// The blurs fall off fast — 0.30 of the flame's width on the outer haze,
  /// 0.04 on the heart. Blurring all three heavily was the correction that
  /// overshot: with every layer soft there is no silhouette left, and a
  /// flame with no silhouette is a cone of light. The outer body is
  /// atmosphere and should have no locatable edge; the heart is the thing
  /// you are actually looking at and has to keep its shape, including the
  /// neck where it pinches on its way to the tip.
  static const List<_Layer> _layers = [
    (scale: 1.00, phase: 0.00, alpha: 0.10, hot: 0.00, blur: 0.30),
    (scale: 0.66, phase: 0.37, alpha: 0.24, hot: 0.14, blur: 0.11),
    (scale: 0.36, phase: 0.71, alpha: 0.55, hot: 0.26, blur: 0.04),
  ];

  /// Three sines at 3, 7 and 11 times the cycle rate, summed.
  ///
  /// Whole-number multipliers on purpose: every term completes a whole
  /// number of turns per cycle, so the sum is exactly periodic and the loop
  /// has no seam. Primes, so the three never line up and reinforce into a
  /// beat you can count. Returns roughly -1..1.
  static double _flicker(double t, double phase) =>
      math.sin((t * 3 + phase) * math.pi * 2) * 0.50 +
      math.sin((t * 7 + phase * 1.7) * math.pi * 2) * 0.30 +
      math.sin((t * 11 + phase * 2.9) * math.pi * 2) * 0.20;

  /// One tongue.
  ///
  /// Not a teardrop, which is what this was and which rendered as a paper
  /// cone: straight sides running from a wide flat foot to a point. A flame
  /// is the other shape entirely — it is *pinched at the fuel*, bulges to
  /// its widest about a third of the way up, then necks in and runs out to
  /// a thin tip. The foot here is half the body width and the bulge is the
  /// full width, which is the whole difference between fire and a triangle.
  ///
  /// [lean] is applied as the square of the height fraction, so the foot
  /// barely moves and the tip swings. That is the same reason a real flame
  /// is legible as fire from across a room: it is anchored where it burns
  /// and loose everywhere else.
  static Path _tongue({
    required Offset base,
    required double halfWidth,
    required double height,
    required double lean,
  }) {
    // Horizontal position at height fraction [f], offset sideways by [dx].
    double x(double f, double dx) => base.dx + lean * f * f + dx;
    double y(double f) => base.dy - height * f;

    return Path()
      ..moveTo(x(0, -halfWidth * 0.50), base.dy)
      // Out to the widest point, low down.
      ..cubicTo(
        x(0.08, -halfWidth * 0.98), y(0.08),
        x(0.30, -halfWidth * 1.00), y(0.30),
        x(0.55, -halfWidth * 0.62), y(0.55),
      )
      // Neck in, and run out to the tip.
      ..cubicTo(
        x(0.76, -halfWidth * 0.34), y(0.76),
        x(0.92, -halfWidth * 0.12), y(0.92),
        x(1, 0), y(1),
      )
      // And back down the other side.
      ..cubicTo(
        x(0.92, halfWidth * 0.12), y(0.92),
        x(0.76, halfWidth * 0.34), y(0.76),
        x(0.55, halfWidth * 0.62), y(0.55),
      )
      ..cubicTo(
        x(0.30, halfWidth * 1.00), y(0.30),
        x(0.08, halfWidth * 0.98), y(0.08),
        x(0, halfWidth * 0.50), base.dy,
      )
      // The foot is rounded *below* the baseline rather than closed flat. A
      // flat bottom edge is a straight line, and a straight line is the one
      // thing fire never has.
      ..quadraticBezierTo(
        base.dx, base.dy + halfWidth * 0.42,
        x(0, -halfWidth * 0.50), base.dy,
      )
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final base = Offset(size.width / 2, size.height * 0.92);
    final reach = size.height * (0.50 + 0.42 * intensity);
    final width = size.width * (0.26 + 0.12 * intensity);

    _paintBloom(canvas, base, reach);

    for (final layer in _layers) {
      final flick = _flicker(t, layer.phase);
      canvas.drawPath(
        _tongue(
          base: base,
          // Taller and narrower on the same beat, so a tongue necks as it
          // reaches rather than inflating like a balloon.
          halfWidth: width * layer.scale * (1 - 0.10 * flick),
          height: reach * layer.scale * (1 + 0.13 * flick),
          lean: width * 0.46 * _flicker(t, layer.phase + 0.5),
        ),
        Paint()
          ..maskFilter = MaskFilter.blur(
            BlurStyle.normal,
            width * layer.blur + 0.6,
          )
          ..color = Color.lerp(
            TideColors.lantern,
            TideColors.bone,
            layer.hot,
          )!.withValues(alpha: layer.alpha),
      );
    }

    _paintSeat(canvas, base, reach, width);
    _paintEmbers(canvas, base, reach, width);
  }

  /// The light the fire throws, before the fire itself.
  ///
  /// A plain two-stop radial fades its alpha linearly and the eye finds the
  /// exact circle where the ramp hits zero — a disc pasted on the card
  /// rather than light coming off something. This is the same seven-stop
  /// falloff the page blooms use, for the same reason.
  ///
  /// Painted as a circle sized to the ramp rather than as a rect filling the
  /// widget, which is not a detail. The seven stops reach zero alpha exactly
  /// at the rim, so a circle has no edge anywhere — but a rect crops that
  /// ramp wherever the box happens to be, and the box is square. Filling the
  /// bounds drew a visible rectangle of warm haze around the fire, which is
  /// the single most expensive-looking mistake available here.
  void _paintBloom(Canvas canvas, Offset base, double reach) {
    final heart = Offset(base.dx, base.dy - reach * 0.30);
    final radius = reach * 0.95;
    final bounds = Rect.fromCircle(center: heart, radius: radius);

    canvas.drawCircle(
      heart,
      radius,
      Paint()
        ..shader = TideGradients.bloom(
          color: TideColors.lantern,
          alpha: 0.09 + 0.13 * intensity,
          center: Alignment.center,
          radius: 0.5,
        ).createShader(bounds),
    );
  }

  /// The seat: hottest where the fire meets its surface, and the one part
  /// that holds still while everything above it moves. Without it the
  /// tongues look like they are floating.
  void _paintSeat(Canvas canvas, Offset base, double reach, double width) {
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(base.dx, base.dy - reach * 0.08),
        width: width * 1.25,
        height: reach * 0.22,
      ),
      Paint()
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, width * 0.20)
        ..color = Color.lerp(TideColors.lantern, TideColors.bone, 0.28)!
            .withValues(alpha: 0.20 + 0.10 * intensity),
    );
  }

  /// Fire sheds. Staggered so one leaves as another arrives, and each
  /// completes exactly one flight per cycle, which keeps them inside the
  /// seamless loop the flicker is already built on.
  void _paintEmbers(Canvas canvas, Offset base, double reach, double width) {
    final count = (2 + 3 * intensity).round();

    for (var i = 0; i < count; i++) {
      final phase = i / count;
      final rise = (t + phase) % 1.0;
      // Nothing at either end of the flight and brightest in the middle: an
      // ember that appears at full strength is a dot being switched on.
      final fade = 4 * rise * (1 - rise);

      canvas.drawCircle(
        Offset(
          base.dx + width * 0.95 * math.sin((rise * 2 + phase) * math.pi * 2),
          base.dy - reach * (0.70 + 0.80 * rise),
        ),
        1.4 * (1 - rise * 0.55),
        Paint()
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.8)
          ..color = TideColors.lantern.withValues(
            alpha: (fade * 0.42 * intensity).clamp(0.0, 1.0),
          ),
      );
    }
  }

  @override
  bool shouldRepaint(_FlamePainter old) =>
      old.t != t || old.intensity != intensity;
}
