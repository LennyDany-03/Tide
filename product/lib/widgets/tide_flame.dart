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
/// **A mark, lit — not a glow.** The version before this was built entirely
/// out of blurred light: three soft tongues at low alpha over a bloom, on
/// the principle that fire has no edges. True to fire, and wrong for the
/// card. At this size on a dark shelf a shape with no silhouette reads as a
/// candle smudge, and nothing about it looked designed. This is one crisp
/// emblem instead: an outer teardrop with a second, smaller flame cut out of
/// its heart as negative space, filled with a flare-to-ember ramp. The light
/// did not go away — it moved *behind* the mark, as a bloom and a soft
/// halo, where softness adds depth instead of dissolving the thing you are
/// meant to be looking at.
///
/// It still moves, with restraint, because a flame that holds still is a
/// logo:
///
/// * **The two flames move separately.** The outer body sways from its tip
///   while the cut-out's tongues rise and lean on their own phases, so the
///   negative space appears to burn inside the shape.
/// * **The flicker is three sines, not one.** A single sine is a heartbeat
///   and the eye finds its period within two cycles. Summed at 3, 7 and 11
///   times the base rate there is no findable beat — but the multipliers are
///   whole numbers, so the loop still closes seamlessly.
/// * **The foot stays put.** Sway and stretch are weighted by the square of
///   the height above the foot, so the base is anchored and only the tip
///   travels. Amplitudes are a pixel or two: on a crisp edge that reads,
///   where the blurred version needed ten.
///
/// The fill is [TideGradients.flame], whose two ends are derived from
/// lantern in the theme layer. Coral is not available: it means destruction
/// and nothing else.
class TideFlame extends StatefulWidget {
  const TideFlame({super.key, this.intensity = 1});

  /// 0..1. Scales the height, the glow and how many embers come off the
  /// tip, so a two-day run is a small flame and a hundred-day run a tall one
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

class _FlamePainter extends CustomPainter {
  const _FlamePainter({required this.t, required this.intensity});

  /// 0..1 through one burn cycle.
  final double t;

  final double intensity;

  /// Width over height of the emblem.
  static const double _aspect = 0.78;

  /// The outer body, in the emblem's unit square: x across, y down, the foot
  /// at y = 1. A start point, then cubic segments of six.
  ///
  /// The tip sits right of centre and the right shoulder is concave just
  /// under it, so the flame has a direction — a symmetric teardrop is a
  /// water drop, and on this app's cards that is exactly the wrong reading.
  static const List<double> _outer = [
    0.50, 1.00,
    // Round the foot and out to the bulge, low on the left.
    0.20, 1.00, 0.04, 0.80, 0.05, 0.60,
    // Up the long left side to the tip.
    0.07, 0.38, 0.28, 0.20, 0.60, 0.00,
    // Off the tip, in under it, and out to the right shoulder.
    0.58, 0.20, 0.95, 0.36, 0.95, 0.64,
    // And back round to the foot.
    0.95, 0.86, 0.78, 1.00, 0.50, 1.00,
  ];

  /// The negative flame cut out of the body: a main tongue and a smaller one
  /// to its left, open through the foot.
  ///
  /// Open rather than enclosed on purpose. A hole fully inside the body is a
  /// shape with a window in it; letting the cut-out run out of the base
  /// splits the foot into two points, and that is what makes it read as a
  /// second flame rising inside the first.
  static const List<double> _inner = [
    0.40, 1.08,
    // Up the left edge to the small tongue.
    0.27, 0.97, 0.25, 0.80, 0.35, 0.66,
    // Down into the notch between the two.
    0.38, 0.73, 0.42, 0.77, 0.47, 0.79,
    // Up to the main tongue's tip.
    0.44, 0.66, 0.50, 0.52, 0.62, 0.42,
    // Down the right side and out through the foot.
    0.62, 0.55, 0.76, 0.66, 0.75, 0.84,
    0.74, 0.96, 0.66, 1.00, 0.60, 1.08,
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

  /// [points] from the unit square into [box].
  ///
  /// [lean] is in widths and [stretch] in heights, and both are weighted by
  /// the square of the rise above the foot — the base holds still, the tip
  /// moves most.
  static Path _trace(
    Rect box,
    List<double> points, {
    required double lean,
    required double stretch,
  }) {
    Offset at(int i) {
      final rise = 1 - points[i + 1];
      return Offset(
        box.left + (points[i] + lean * rise * rise) * box.width,
        box.bottom - rise * (1 + stretch * rise) * box.height,
      );
    }

    final start = at(0);
    final path = Path()..moveTo(start.dx, start.dy);
    for (var i = 2; i + 5 < points.length; i += 6) {
      final a = at(i), b = at(i + 2), c = at(i + 4);
      path.cubicTo(a.dx, a.dy, b.dx, b.dy, c.dx, c.dy);
    }
    return path..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    // Standing on the bottom centre and growing upward, so a hotter run is a
    // taller fire on the same spot rather than a bigger icon. The headroom
    // left above it at full size is where the embers go.
    final height =
        math.min(size.height, size.width / _aspect) * (0.72 + 0.18 * intensity);
    final box = Rect.fromLTWH(
      (size.width - height * _aspect) / 2,
      size.height - height,
      height * _aspect,
      height,
    );

    final sway = 0.05 * _flicker(t, 0.5);
    final reach = 0.03 * _flicker(t, 0);
    final outer = _trace(box, _outer, lean: sway, stretch: reach);
    // The cut-out rides the body's sway and adds its own on top: the two
    // move together as one fire and apart as two tongues.
    final inner = _trace(
      box,
      _inner,
      lean: sway + 0.10 * _flicker(t, 0.71),
      stretch: reach + 0.16 * _flicker(t, 0.19),
    );
    final body = Path.combine(PathOperation.difference, outer, inner);

    _paintBloom(canvas, box);
    _paintHalo(canvas, body, box);
    canvas.drawPath(
      body,
      Paint()..shader = TideGradients.flame.createShader(box),
    );
    _paintSheen(canvas, body, box);
    _paintEmbers(canvas, box);
  }

  /// The light the fire throws onto the card.
  ///
  /// Drawn as a circle sized to the seven-stop ramp rather than as a rect
  /// filling the widget: the stops reach zero exactly at the rim, so a
  /// circle has no edge anywhere, where a rect would crop the ramp into a
  /// visible box of warm haze.
  void _paintBloom(Canvas canvas, Rect box) {
    final centre = Offset(box.center.dx, box.bottom - box.height * 0.40);
    final radius = box.height * 1.05;

    canvas.drawCircle(
      centre,
      radius,
      Paint()
        ..shader = TideGradients.bloom(
          color: TideColors.lantern,
          alpha: 0.07 + 0.10 * intensity,
          center: Alignment.center,
          radius: 0.5,
        ).createShader(Rect.fromCircle(center: centre, radius: radius)),
    );
  }

  /// The glow hugging the mark: its own silhouette, blurred in ember and
  /// dropped a little, so the flame sits *in* its light rather than on top
  /// of it. It breathes with the fire, faintly.
  ///
  /// Traced from the cut body, not the outer outline. Blurring the whole
  /// teardrop filled the negative space with a brown wash, and a cut-out
  /// that is not clearly empty stops reading as a second flame.
  void _paintHalo(Canvas canvas, Path body, Rect box) {
    final breath = 1 + 0.12 * _flicker(t, 0.9);

    canvas.drawPath(
      body.shift(Offset(0, box.height * 0.03)),
      Paint()
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, box.width * 0.16)
        ..color = TideColors.ember.withValues(
          alpha: ((0.26 + 0.20 * intensity) * breath).clamp(0.0, 1.0),
        ),
    );
  }

  /// A lit face on the side the app's one light comes from. Clipped to the
  /// mark, so it models the surface instead of spilling off it — the single
  /// detail that stops a gradient fill looking like a flat sticker.
  ///
  /// Kept faint. Bone is unsaturated, and at a third opacity it bleached the
  /// top of the flame to pastel; a fire's hot face is brighter, not paler.
  void _paintSheen(Canvas canvas, Path body, Rect box) {
    canvas
      ..save()
      ..clipPath(body)
      ..drawRect(
        box,
        Paint()
          ..shader = TideGradients.bloom(
            color: TideColors.glint,
            alpha: 0.14,
            center: const Alignment(-0.50, -0.20),
            radius: 0.50,
          ).createShader(box),
      )
      ..restore();
  }

  /// Fire sheds, a little. Staggered so one leaves as another arrives, and
  /// each completes exactly one flight per cycle, which keeps them inside
  /// the seamless loop the flicker is already built on.
  ///
  /// Painted in lantern with a whisper of blur, never in [TideColors.flare]:
  /// a pale yellow at low alpha over dark water mixes to khaki, and the
  /// embers came out as grey dots.
  void _paintEmbers(Canvas canvas, Rect box) {
    final count = (1 + intensity).round();

    for (var i = 0; i < count; i++) {
      final phase = i / count;
      final rise = (t + phase) % 1.0;
      // Nothing at either end of the flight and brightest in the middle: an
      // ember that appears at full strength is a dot being switched on.
      final fade = 4 * rise * (1 - rise);

      canvas.drawCircle(
        Offset(
          box.left +
              box.width *
                  (0.60 + 0.10 * math.sin((rise * 2 + phase) * math.pi * 2)),
          box.top + box.height * (0.08 - 0.30 * rise),
        ),
        box.width * 0.024 * (1 - rise * 0.5),
        Paint()
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.6)
          ..color = TideColors.lantern.withValues(
            alpha: (fade * 0.85 * intensity).clamp(0.0, 1.0),
          ),
      );
    }
  }

  @override
  bool shouldRepaint(_FlamePainter old) =>
      old.t != t || old.intensity != intensity;
}
