import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/tide_gradients.dart';
import '../theme/tide_palette.dart';

/// Where the logo is in its entrance. Every field is 0..1 — some may run a
/// little past 1 on an overshoot — and [TideLogoFrame.complete] is the
/// finished, resting mark: the app icon.
@immutable
class TideLogoFrame {
  const TideLogoFrame({
    this.ring = 1,
    this.tide = 1,
    this.moon = 1,
    this.orbit = 1,
    this.orbitPhase = restingOrbit,
    this.swell = 0,
  });

  /// How much of the ring is drawn, clockwise from twelve o'clock.
  final double ring;

  /// How far the water has risen toward its resting level. Runs past 1 on
  /// the way in — the tide slops above its mark before it settles.
  final double tide;

  /// The moon's scale.
  final double moon;

  /// Opacity of the orbiting point and its wake.
  final double orbit;

  /// Where the orbiting point is, 0..1 clockwise from twelve o'clock.
  final double orbitPhase;

  /// The water surface's drift, 0..1 through one swell cycle.
  final double swell;

  /// Half past four, where the point rests on the still mark. A point at
  /// twelve reads as a clock hand or a loading spinner about to start; one
  /// part-way round reads as a loop already under way.
  static const double restingOrbit = 0.375;

  static const complete = TideLogoFrame();

  @override
  bool operator ==(Object other) =>
      other is TideLogoFrame &&
      other.ring == ring &&
      other.tide == tide &&
      other.moon == moon &&
      other.orbit == orbit &&
      other.orbitPhase == orbitPhase &&
      other.swell == swell;

  @override
  int get hashCode => Object.hash(ring, tide, moon, orbit, orbitPhase, swell);
}

/// The Tide logo.
///
/// Four parts, each one a claim about the product:
///
/// * **The ring** is the loop — a habit is something that comes round
///   again. It is lit from the top left like every surface in the app.
/// * **The tide** stands inside it at a little under half: the day filling
///   up, the same water that stands in Today's hero tile.
/// * **The moon** hangs above the water. The moon is what moves a tide, and
///   the one small steady thing you do daily is what moves a habit — so the
///   still point at the centre is the reason the water is there at all.
///   It throws a short broken reflection onto the surface, which is what
///   makes the water read as water at a glance rather than as a filled
///   semicircle.
/// * **The orbiting point** is the loop not stopping.
///
/// Everything is painted from one [TidePalette] passed in rather than read
/// from the active tokens, so the same painter draws the in-app mark in
/// whatever palette is on and the app icon in Midnight regardless.
class TideLogoPainter extends CustomPainter {
  const TideLogoPainter({
    required this.palette,
    this.frame = TideLogoFrame.complete,
    this.strokeWidth,
    this.moonRadius,
  });

  final TidePalette palette;
  final TideLogoFrame frame;

  /// The ring's weight. Defaults to 3% of the mark — icons pass more, since
  /// a hairline ring vanishes at 29px.
  final double? strokeWidth;

  /// Defaults to a proportion of the ring.
  final double? moonRadius;

  /// Where the water stands at rest, as a fraction of the ring's inner
  /// diameter. Under half, so the moon has sky to hang in.
  static const double _restingLevel = 0.42;

  @override
  void paint(Canvas canvas, Size size) {
    final extent = size.shortestSide;
    if (extent <= 0) return;

    final stroke = strokeWidth ?? extent * 0.03;
    final centre = size.center(Offset.zero);
    // Inset far enough that the orbiting point, which sits on the ring and
    // is wider than it, never leaves the box it was given.
    final radius = extent / 2 - stroke * 1.15;
    // The gap between ring and water: without it the water touches the
    // ring and the two read as one filled shape.
    final inner = radius - stroke * 2.2;

    _paintWater(canvas, centre, inner, stroke);
    _paintMoon(canvas, centre, inner);
    _paintRing(canvas, Rect.fromCircle(center: centre, radius: radius), stroke);
    _paintOrbit(canvas, centre, radius, stroke);
  }

  void _paintRing(Canvas canvas, Rect bounds, double stroke) {
    final sweep = frame.ring.clamp(0.0, 1.0);
    if (sweep <= 0) return;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..shader = TideGradients.markRing(palette).createShader(bounds);

    if (sweep >= 1) {
      canvas.drawCircle(bounds.center, bounds.width / 2, paint);
    } else {
      canvas.drawArc(bounds, -math.pi / 2, sweep * 2 * math.pi, false, paint);
    }
  }

  /// The surface height at [u] (0..1 across the water). Two sines at
  /// unrelated frequencies drifting in opposite directions, the same
  /// construction as Today's water, so the crest never repeats in a glance.
  double _surface(double u, double baseline, double amplitude, double phase) {
    return baseline +
        math.sin(u * 2 * math.pi * 1.1 + phase) * amplitude +
        math.sin(u * 2 * math.pi * 2.3 - phase * 0.6) * amplitude * 0.35;
  }

  void _paintWater(Canvas canvas, Offset centre, double inner, double stroke) {
    final rise = frame.tide;
    if (rise <= 0) return;

    final level = _restingLevel * rise;
    final floor = centre.dy + inner;
    final baseline = floor - 2 * inner * level;
    final amplitude = inner * 0.055;
    final left = centre.dx - inner;
    final width = inner * 2;
    final phase = frame.swell * 2 * math.pi;

    Path surface(double lift, double offset, double gain) {
      final path = Path();
      const steps = 48;
      for (var i = 0; i <= steps; i++) {
        final u = i / steps;
        final point = Offset(
          left + width * u,
          _surface(u, baseline - lift, amplitude * gain, phase + offset),
        );
        if (i == 0) {
          path.moveTo(point.dx, point.dy);
        } else {
          path.lineTo(point.dx, point.dy);
        }
      }
      return path;
    }

    Path body(Path top) => Path.from(top)
      ..lineTo(left + width, floor + stroke)
      ..lineTo(left, floor + stroke)
      ..close();

    canvas
      ..save()
      ..clipPath(
        Path()..addOval(Rect.fromCircle(center: centre, radius: inner)),
      );

    // A second, fainter swell behind the first and slightly higher: the
    // depth that stops the water being one flat cut-out.
    canvas.drawPath(
      body(surface(inner * 0.07, 2.1, 0.8)),
      Paint()..color = palette.lantern.withValues(alpha: 0.24),
    );

    final front = surface(0, 0, 1);
    canvas.drawPath(
      body(front),
      Paint()
        ..shader = TideGradients.markWater(palette).createShader(
          Rect.fromLTRB(left, baseline - amplitude, left + width, floor),
        ),
    );

    // The lit waterline — the brightest edge inside the ring.
    canvas.drawPath(
      front,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke * 0.45
        ..strokeCap = StrokeCap.round
        ..color = palette.glint.withValues(alpha: 0.7),
    );

    // The moon's reflection: two short broken dashes under it on the
    // surface, the longer one nearer the top.
    final shine = frame.moon.clamp(0.0, 1.0) * rise.clamp(0.0, 1.0);
    if (shine > 0) {
      final waterline = _surface(0.5, baseline, amplitude, phase);
      final dash = Paint()..color = palette.glint;
      for (final (depth, length, alpha) in [
        (1.9, 0.34, 0.42),
        (3.4, 0.18, 0.26),
      ]) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset(centre.dx, waterline + stroke * depth),
              width: inner * length * shine,
              height: stroke * 0.5,
            ),
            Radius.circular(stroke),
          ),
          dash..color = palette.glint.withValues(alpha: alpha * shine),
        );
      }
    }

    canvas.restore();
  }

  void _paintMoon(Canvas canvas, Offset centre, double inner) {
    final scale = frame.moon;
    if (scale <= 0) return;

    final radius = (moonRadius ?? inner * 0.15) * scale;
    final position = Offset(centre.dx, centre.dy - inner * 0.34);

    // Its light first, wide and gone before it reaches the ring.
    final halo = radius * 3.2;
    canvas.drawCircle(
      position,
      halo,
      Paint()
        ..shader = TideGradients.bloom(
          color: palette.lantern,
          alpha: 0.34 * scale.clamp(0.0, 1.0),
          center: Alignment.center,
          radius: 0.5,
        ).createShader(Rect.fromCircle(center: position, radius: halo)),
    );

    canvas.drawCircle(
      position,
      radius,
      Paint()
        ..shader = TideGradients.markMoon(
          palette,
        ).createShader(Rect.fromCircle(center: position, radius: radius)),
    );
  }

  void _paintOrbit(Canvas canvas, Offset centre, double radius, double stroke) {
    final presence = frame.orbit.clamp(0.0, 1.0);
    if (presence <= 0) return;

    final angle = -math.pi / 2 + frame.orbitPhase * 2 * math.pi;
    final bounds = Rect.fromCircle(center: centre, radius: radius);

    // The wake is a few short arcs of falling alpha rather than one sweep
    // gradient: a SweepGradient has a seam where it wraps, and the seam
    // would park somewhere different every frame as the point travels.
    // Short, too — a long tail turns the mark into a loading spinner.
    const wake = 0.12;
    const segments = 7;
    for (var i = 0; i < segments; i++) {
      canvas.drawArc(
        bounds,
        angle - wake * 2 * math.pi * (i + 1) / segments,
        wake * 2 * math.pi / segments + 0.01,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round
          ..color = palette.glint.withValues(
            alpha: 0.45 * (1 - i / segments) * presence,
          ),
      );
    }

    canvas.drawCircle(
      Offset(
        centre.dx + radius * math.cos(angle),
        centre.dy + radius * math.sin(angle),
      ),
      stroke * 1.05,
      Paint()..color = palette.glint.withValues(alpha: presence),
    );
  }

  @override
  bool shouldRepaint(TideLogoPainter old) =>
      !identical(old.palette, palette) ||
      old.frame != frame ||
      old.strokeWidth != strokeWidth ||
      old.moonRadius != moonRadius;
}
