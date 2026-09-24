import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../config/milestone_art.dart';
import '../../../services/models/milestone.dart';
import '../../../theme/tide_colors.dart';
import '../../../theme/tide_gradients.dart';

/// A milestone's scene, drawn to fill whatever box it is given.
///
/// Every figure is laid out in proportions of the box and every stroke in
/// units of its short side, so the same scene composes on the tall story
/// card and the shorter post card without a second drawing. Scattered
/// points come from a generator seeded by the scene, so a card is the same
/// picture every time it is drawn — a share is a keepsake, and a keepsake
/// that reshuffled itself would not be one.
class MilestoneScenery extends StatelessWidget {
  const MilestoneScenery({super.key, required this.milestone});

  final Milestone milestone;

  static Color inkOf(MilestoneInk ink) => switch (ink) {
    MilestoneInk.lantern => TideColors.lantern,
    MilestoneInk.flare => TideColors.flare,
    MilestoneInk.ember => TideColors.ember,
    MilestoneInk.frost => TideColors.frost,
    MilestoneInk.coral => TideColors.coral,
  };

  @override
  Widget build(BuildContext context) {
    final art = MilestoneArtCatalog.of(milestone);
    // Clipped: several scenes run to the edges and past them (the spiral,
    // the rings), and unclipped they carried on behind the card's title.
    return ClipRect(
      child: CustomPaint(
        size: Size.infinite,
        painter: _ScenePainter(
          scene: art.scene,
          ink: _Ink(
            a: inkOf(art.primary),
            b: inkOf(art.secondary),
            bone: TideColors.bone,
            ground: TideColors.deepWater,
            deep: TideColors.trench,
          ),
        ),
      ),
    );
  }
}

class _Ink {
  const _Ink({
    required this.a,
    required this.b,
    required this.bone,
    required this.ground,
    required this.deep,
  });

  final Color a;
  final Color b;
  final Color bone;
  final Color ground;
  final Color deep;

  @override
  bool operator ==(Object other) =>
      other is _Ink &&
      other.a == a &&
      other.b == b &&
      other.bone == bone &&
      other.ground == ground &&
      other.deep == deep;

  @override
  int get hashCode => Object.hash(a, b, bone, ground, deep);
}

class _ScenePainter extends CustomPainter {
  const _ScenePainter({required this.scene, required this.ink});

  final MilestoneScene scene;
  final _Ink ink;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final s = _Stage(canvas, size, ink, math.Random(1301 + scene.index * 97));
    switch (scene) {
      case MilestoneScene.drop:
        _drop(s);
      case MilestoneScene.interference:
        _interference(s);
      case MilestoneScene.swell:
        _swell(s);
      case MilestoneScene.slack:
        _slack(s);
      case MilestoneScene.moonWeek:
        _moonWeek(s);
      case MilestoneScene.ebbAndFlow:
        _ebbAndFlow(s);
      case MilestoneScene.fortnightChart:
        _fortnightChart(s);
      case MilestoneScene.thirdQuarter:
        _thirdQuarter(s);
      case MilestoneScene.fullMoon:
        _fullMoon(s);
      case MilestoneScene.undertow:
        _undertow(s);
      case MilestoneScene.halfHundred:
        _halfHundred(s);
      case MilestoneScene.springTide:
        _springTide(s);
      case MilestoneScene.headland:
        _headland(s);
      case MilestoneScene.openWater:
        _openWater(s);
      case MilestoneScene.hundred:
        _hundred(s);
      case MilestoneScene.tradeWind:
        _tradeWind(s);
      case MilestoneScene.meridian:
        _meridian(s);
      case MilestoneScene.solstice:
        _solstice(s);
      case MilestoneScene.gulfStream:
        _gulfStream(s);
      case MilestoneScene.blueWater:
        _blueWater(s);
      case MilestoneScene.stormGlass:
        _stormGlass(s);
      case MilestoneScene.deepWater:
        _deepWater(s);
      case MilestoneScene.abyssal:
        _abyssal(s);
      case MilestoneScene.twoYears:
        _twoYears(s);
      case MilestoneScene.cleanChain:
        _cleanChain(s);
      case MilestoneScene.unbroken:
        _unbroken(s);
      case MilestoneScene.thaw:
        _thaw(s);
      case MilestoneScene.glassWater:
        _glassWater(s);
    }
  }

  @override
  bool shouldRepaint(_ScenePainter old) => old.scene != scene || old.ink != ink;
}

/// The canvas and the handful of strokes every scene is built from.
class _Stage {
  _Stage(this.canvas, Size size, this.ink, this.random)
    : w = size.width,
      h = size.height,
      u = size.shortestSide / 360;

  final Canvas canvas;
  final _Ink ink;
  final math.Random random;

  final double w;
  final double h;

  /// One unit: a 360th of the short side. Every length is a multiple.
  final double u;

  double get cx => w / 2;

  Paint line(Color color, double width, [double alpha = 1]) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = width * u
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..color = color.withValues(alpha: alpha.clamp(0.0, 1.0));

  Paint fill(Color color, [double alpha = 1]) =>
      Paint()..color = color.withValues(alpha: alpha.clamp(0.0, 1.0));

  void glow(Offset centre, double radius, Color color, [double strength = 1]) {
    final rect = Rect.fromCircle(center: centre, radius: radius);
    canvas.drawCircle(
      centre,
      radius,
      Paint()
        ..shader = TideGradients.cardGlow(
          color,
          strength: strength,
        ).createShader(rect),
    );
  }

  /// A sine across [x0]..[x1] at [y]: [waves] whole periods.
  Path sine(
    double x0,
    double x1,
    double y,
    double amplitude,
    double waves, {
    double phase = 0,
    int steps = 96,
  }) {
    final path = Path();
    for (var i = 0; i <= steps; i++) {
      final t = i / steps;
      final point = Offset(
        x0 + (x1 - x0) * t,
        y + math.sin(t * waves * 2 * math.pi + phase) * amplitude,
      );
      i == 0
          ? path.moveTo(point.dx, point.dy)
          : path.lineTo(point.dx, point.dy);
    }
    return path;
  }

  /// Level lines under a horizon, closing up toward it the way a water
  /// surface does with distance.
  void waterLines(
    double horizon,
    Color color, {
    int count = 10,
    double alpha = 0.12,
  }) {
    for (var i = 1; i <= count; i++) {
      final y = horizon + (i * i * 1.4 + i * 4) * u;
      if (y > h) break;
      canvas.drawLine(
        Offset(w * 0.06, y),
        Offset(w * 0.94, y),
        line(color, 0.8, alpha * (0.4 + i / count * 0.6)),
      );
    }
  }

  /// A few points of light scattered over [area], clear of [avoid].
  void stars(
    Rect area,
    int count,
    Color color, {
    Offset? avoid,
    double clear = 0,
  }) {
    for (var i = 0; i < count; i++) {
      final p = Offset(
        area.left + random.nextDouble() * area.width,
        area.top + random.nextDouble() * area.height,
      );
      if (avoid != null && (p - avoid).distance < clear) continue;
      canvas.drawCircle(
        p,
        (0.6 + random.nextDouble() * 1.3) * u,
        fill(color, 0.25 + random.nextDouble() * 0.6),
      );
    }
  }

  /// A four-pointed glint, the app's sparkle mark.
  void sparkle(Offset centre, double radius, Color color) {
    final r = radius;
    final k = r * 0.22;
    final path = Path()
      ..moveTo(centre.dx, centre.dy - r)
      ..quadraticBezierTo(
        centre.dx + k,
        centre.dy - k,
        centre.dx + r,
        centre.dy,
      )
      ..quadraticBezierTo(
        centre.dx + k,
        centre.dy + k,
        centre.dx,
        centre.dy + r,
      )
      ..quadraticBezierTo(
        centre.dx - k,
        centre.dy + k,
        centre.dx - r,
        centre.dy,
      )
      ..quadraticBezierTo(
        centre.dx - k,
        centre.dy - k,
        centre.dx,
        centre.dy - r,
      )
      ..close();
    canvas.drawPath(path, fill(color));
  }

  /// A disc lit to [lit] of its face, from the right (waxing) — the moon's
  /// terminator is an ellipse, so the dark side is a second disc slid across
  /// and clipped to the first.
  void moon(Offset centre, double radius, double lit, Color color) {
    final disc = Rect.fromCircle(center: centre, radius: radius);
    canvas
      ..save()
      ..clipPath(Path()..addOval(disc))
      ..drawCircle(centre, radius, fill(color, 0.95));
    if (lit < 1) {
      canvas.drawCircle(
        centre.translate(-lit * 2 * radius, 0),
        radius * 1.02,
        fill(ink.ground),
      );
    }
    canvas
      ..restore()
      ..drawCircle(centre, radius, line(color, 1.2, 0.55));
  }
}

// --- The first week -------------------------------------------------------

/// One drop, the water it lands in, and the first rings going out.
void _drop(_Stage s) {
  final c = s.canvas;
  final u = s.u;
  final horizon = s.h * 0.66;
  s.glow(Offset(s.cx, horizon), s.w * 0.5, s.ink.a, 0.7);
  s.waterLines(horizon, s.ink.a, alpha: 0.14);
  for (var i = 1; i <= 6; i++) {
    final rx = 20 * u * i * 1.3;
    c.drawOval(
      Rect.fromCenter(
        center: Offset(s.cx, horizon),
        width: rx * 2,
        height: rx * 0.56,
      ),
      s.line(s.ink.a, i == 1 ? 2 : 1.4, 0.95 - i * 0.14),
    );
  }

  // The drop, still falling.
  final top = s.h * 0.26;
  final bottom = s.h * 0.44;
  final r = 12 * u;
  final drop = Path()
    ..moveTo(s.cx, top)
    ..quadraticBezierTo(s.cx + r * 1.15, bottom - r * 0.9, s.cx + r, bottom)
    ..arcToPoint(Offset(s.cx - r, bottom), radius: Radius.circular(r))
    ..quadraticBezierTo(s.cx - r * 1.15, bottom - r * 0.9, s.cx, top)
    ..close();
  s.glow(Offset(s.cx, bottom - r * 0.4), r * 4, s.ink.b, 0.8);
  c.drawPath(drop, s.fill(s.ink.b));
  c.drawCircle(
    Offset(s.cx - r * 0.35, bottom - r * 0.2),
    r * 0.22,
    s.fill(s.ink.bone, 0.7),
  );
  for (var i = 0; i < 3; i++) {
    final y = top - (12 + i * 10) * u;
    c.drawLine(
      Offset(s.cx, y),
      Offset(s.cx, y - 5 * u),
      s.line(s.ink.b, 1.4, 0.5 - i * 0.11),
    );
  }
}

/// Two sources, and the pattern where their rings cross.
void _interference(_Stage s) {
  final left = Offset(s.w * 0.35, s.h * 0.5);
  final right = Offset(s.w * 0.65, s.h * 0.5);
  final reach = s.w * 0.72;
  for (final (source, color) in [(left, s.ink.a), (right, s.ink.b)]) {
    for (var r = 10 * s.u; r < reach; r += 13 * s.u) {
      s.canvas.drawCircle(
        source,
        r,
        s.line(color, 1.2, 0.62 * (1 - r / reach)),
      );
    }
  }
  s.glow(left, 40 * s.u, s.ink.a);
  s.glow(right, 40 * s.u, s.ink.b);
  s.canvas
    ..drawCircle(left, 4 * s.u, s.fill(s.ink.a))
    ..drawCircle(right, 4 * s.u, s.fill(s.ink.b));
}

/// Long swell stacking up to a single lit crest.
void _swell(_Stage s) {
  final c = s.canvas;
  for (var i = 8; i >= 0; i--) {
    final y = s.h * 0.34 + i * s.h * 0.07;
    final amp = (8 + i * 3.4) * s.u;
    final path = s.sine(
      -10,
      s.w + 10,
      y,
      amp,
      1.05 + i * 0.07,
      phase: 1.2 + i * 0.5,
    );
    if (i == 0) {
      final body = Path.from(path)
        ..lineTo(s.w + 10, s.h)
        ..lineTo(-10, s.h)
        ..close();
      c.drawPath(body, s.fill(s.ink.a, 0.06));
    }
    c.drawPath(
      path,
      s.line(s.ink.a, i == 0 ? 2.6 : 1.2, i == 0 ? 1 : 0.5 - i * 0.045),
    );
  }
  // The crest of the front wave: sin(...) = -1 is its highest point.
  const waves = 1.05;
  final t = ((1.5 * math.pi - 1.2) / (2 * math.pi * waves)) % 1;
  final crest = Offset(-10 + (s.w + 20) * t, s.h * 0.34 - 8 * s.u);
  s.glow(crest, 46 * s.u, s.ink.b);
  s.canvas.drawCircle(crest, 5 * s.u, s.fill(s.ink.b));
}

/// Water at the turn of the tide: nothing moving, the sky doubled in it.
void _slack(_Stage s) {
  final c = s.canvas;
  final u = s.u;
  final horizon = s.h * 0.56;
  for (var i = 1; i <= 12; i++) {
    final d = (i * i * 1.3 + i * 5) * u;
    for (final y in [horizon - d, horizon + d]) {
      if (y < 0 || y > s.h) continue;
      c.drawLine(
        Offset(0, y),
        Offset(s.w, y),
        s.line(s.ink.a, 0.7, y > horizon ? 0.13 : 0.06),
      );
    }
  }
  c.drawLine(
    Offset(0, horizon),
    Offset(s.w, horizon),
    s.line(s.ink.a, 1.4, 0.9),
  );

  final sun = Offset(s.cx, horizon - 62 * u);
  s.glow(sun, 90 * u, s.ink.b, 0.8);
  c
    ..drawCircle(sun, 26 * u, s.fill(s.ink.b, 0.16))
    ..drawCircle(sun, 26 * u, s.line(s.ink.b, 1.6));
  // Its reflection, unbroken: slack water does not shiver it apart.
  for (var i = 0; i < 9; i++) {
    final y = horizon + (12 + i * 9) * u;
    final half = 26 * u * (1 - i * 0.07);
    c.drawLine(
      Offset(s.cx - half, y),
      Offset(s.cx + half, y),
      s.line(s.ink.b, 2, 0.55 * (1 - i / 9)),
    );
  }
}

/// Seven nights of the moon filling in, on an arc over the water.
void _moonWeek(_Stage s) {
  final c = s.canvas;
  final centre = Offset(s.cx, s.h * 0.86);
  final radius = math.min(s.w * 0.4, s.h * 0.5);
  final path = Path()
    ..addArc(
      Rect.fromCircle(center: centre, radius: radius),
      math.pi * 1.1,
      math.pi * 0.8,
    );
  c.drawPath(path, s.line(s.ink.a, 1, 0.22));
  for (var i = 0; i < 7; i++) {
    final angle = math.pi * (1.14 + 0.72 * i / 6);
    final at = centre + Offset(math.cos(angle), math.sin(angle)) * radius;
    final lit = i / 6;
    if (i == 6) s.glow(at, 58 * s.u, s.ink.b);
    s.moon(at, (12 + i * 0.9) * s.u, lit, i == 6 ? s.ink.b : s.ink.a);
  }
  s.stars(Rect.fromLTWH(0, s.h * 0.16, s.w, s.h * 0.3), 18, s.ink.bone);
  s.waterLines(s.h * 0.88, s.ink.a, count: 4, alpha: 0.18);
}

/// The tide going out and the tide coming in, braided.
void _ebbAndFlow(_Stage s) {
  final c = s.canvas;
  final mid = s.h * 0.5;
  final amp = s.h * 0.17;
  const waves = 1.5;
  final x0 = s.w * 0.04;
  final x1 = s.w * 0.96;
  for (var i = 0; i <= 26; i++) {
    final t = i / 26;
    final x = x0 + (x1 - x0) * t;
    final dy = math.sin(t * waves * 2 * math.pi) * amp;
    c.drawLine(
      Offset(x, mid + dy),
      Offset(x, mid - dy),
      s.line(s.ink.bone, 1, 0.12),
    );
  }
  c
    ..drawPath(s.sine(x0, x1, mid, amp, waves), s.line(s.ink.a, 2.4))
    ..drawPath(
      s.sine(x0, x1, mid, amp, waves, phase: math.pi),
      s.line(s.ink.b, 2.4),
    );
  for (var k = 0; k <= 3; k++) {
    final x = x0 + (x1 - x0) * k / 3;
    c.drawCircle(Offset(x, mid), 3.6 * s.u, s.fill(s.ink.bone, 0.9));
  }
}

// --- The first month ------------------------------------------------------

/// A tide table: two cycles, and a mark for every one of the fourteen days.
void _fortnightChart(_Stage s) {
  final c = s.canvas;
  final base = s.h * 0.6;
  final x0 = s.w * 0.08;
  final x1 = s.w * 0.92;
  final amp = s.h * 0.17;
  for (var x = x0; x < x1; x += 10 * s.u) {
    c.drawLine(
      Offset(x, base),
      Offset(x + 4 * s.u, base),
      s.line(s.ink.a, 1, 0.3),
    );
  }
  c.drawPath(
    s.sine(x0, x1, base, amp, 2, phase: math.pi),
    s.line(s.ink.a, 2.2),
  );
  for (var i = 0; i < 14; i++) {
    final t = (i + 0.5) / 14;
    final p = Offset(
      x0 + (x1 - x0) * t,
      base + math.sin(t * 4 * math.pi + math.pi) * amp,
    );
    c.drawLine(p, Offset(p.dx, base), s.line(s.ink.a, 1, 0.16));
    if (i == 13) s.glow(p, 36 * s.u, s.ink.b);
    c
      ..drawCircle(p, 4.4 * s.u, s.fill(s.ink.b))
      ..drawCircle(p, 7.5 * s.u, s.line(s.ink.b, 1, 0.35));
  }
}

/// The moon at its third quarter, and the road it lays on the sea.
void _thirdQuarter(_Stage s) {
  final c = s.canvas;
  final u = s.u;
  final centre = Offset(s.cx, s.h * 0.38);
  final r = 46 * u;
  final horizon = s.h * 0.72;
  s.stars(
    Rect.fromLTRB(0, s.h * 0.16, s.w, horizon - 20 * u),
    21,
    s.ink.bone,
    avoid: centre,
    clear: r * 1.8,
  );
  s.glow(centre, r * 2.6, s.ink.a, 0.8);
  final disc = Rect.fromCircle(center: centre, radius: r);
  c
    ..save()
    ..clipPath(Path()..addOval(disc))
    ..drawRect(
      Rect.fromLTRB(disc.left, disc.top, centre.dx, disc.bottom),
      s.fill(s.ink.a, 0.95),
    );
  for (final (dx, dy, cr) in [
    (-0.5, -0.3, 0.16),
    (-0.25, 0.35, 0.1),
    (-0.62, 0.22, 0.08),
  ]) {
    c.drawCircle(
      centre + Offset(dx * r, dy * r),
      cr * r,
      s.fill(s.ink.ground, 0.22),
    );
  }
  c
    ..restore()
    ..drawCircle(centre, r, s.line(s.ink.a, 1.2, 0.45))
    ..drawLine(
      Offset(0, horizon),
      Offset(s.w, horizon),
      s.line(s.ink.a, 1, 0.35),
    );
  for (var i = 0; i < 10; i++) {
    final y = horizon + (8 + i * 8) * u;
    final half = 10 * u * (1 + i * 0.4);
    final x = centre.dx - r * 0.3 + (i.isEven ? -3 : 3) * u;
    c.drawLine(
      Offset(x - half, y),
      Offset(x + half, y),
      s.line(s.ink.b, 2, 0.6 * (1 - i / 10)),
    );
  }
}

/// Thirty days round a full moon.
void _fullMoon(_Stage s) {
  final c = s.canvas;
  final u = s.u;
  final centre = Offset(s.cx, s.h * 0.42);
  final r = 50 * u;
  s.glow(centre, r * 3.2, s.ink.a);
  c
    ..drawCircle(centre, r, s.fill(s.ink.a, 0.95))
    ..drawCircle(
      centre + Offset(-r * 0.3, -r * 0.2),
      r * 0.18,
      s.fill(s.ink.ground, 0.12),
    )
    ..drawCircle(
      centre + Offset(r * 0.25, r * 0.3),
      r * 0.12,
      s.fill(s.ink.ground, 0.1),
    );
  for (var i = 0; i < 30; i++) {
    final a = -math.pi / 2 + i * 2 * math.pi / 30;
    final dir = Offset(math.cos(a), math.sin(a));
    c.drawLine(
      centre + dir * (r + 14 * u),
      centre + dir * (r + 24 * u),
      s.line(s.ink.b, 1.6, 0.75),
    );
  }
  final horizon = s.h * 0.8;
  c.drawLine(Offset(0, horizon), Offset(s.w, horizon), s.line(s.ink.a, 1, 0.3));
  for (var i = 0; i < 8; i++) {
    final y = horizon + (7 + i * 7) * u;
    final half = 14 * u * (1 + i * 0.5);
    c.drawLine(
      Offset(s.cx - half, y),
      Offset(s.cx + half, y),
      s.line(s.ink.a, 2, 0.55 * (1 - i / 8)),
    );
  }
}

// --- The long middle ------------------------------------------------------

/// Five arms of current pulling down to one point.
void _undertow(_Stage s) {
  final c = s.canvas;
  final centre = Offset(s.cx, s.h * 0.48);
  final reach = s.w * 0.62;
  for (var ring = 1; ring <= 4; ring++) {
    c.drawCircle(centre, reach * ring / 4.6, s.line(s.ink.a, 0.8, 0.07));
  }
  for (var arm = 0; arm < 5; arm++) {
    final path = Path();
    for (var i = 0; i <= 160; i++) {
      final theta = i / 160 * 4.2 * math.pi;
      final r = reach * math.exp(-0.2 * theta);
      final a = theta + arm * 2 * math.pi / 5;
      final p = centre + Offset(math.cos(a), math.sin(a)) * r;
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    c.drawPath(path, s.line(s.ink.a, 1.8 - arm * 0.12, 0.7));
  }
  s.glow(centre, 50 * s.u, s.ink.b);
  c.drawCircle(centre, 5 * s.u, s.fill(s.ink.b));
}

/// Fifty days as fifty points, the grid itself in swell.
void _halfHundred(_Stage s) {
  final c = s.canvas;
  final u = s.u;
  final x0 = s.w * 0.1;
  final dx = s.w * 0.8 / 9;
  final y0 = s.h * 0.26;
  final dy = s.h * 0.1;
  Offset at(int col, int row) => Offset(
    x0 + col * dx,
    y0 + row * dy + math.sin(col * 0.75 + row * 0.6) * 9 * u,
  );
  for (var row = 0; row < 5; row++) {
    final path = Path();
    for (var col = 0; col < 10; col++) {
      final p = at(col, row);
      col == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    c.drawPath(path, s.line(s.ink.a, 0.8, 0.14));
  }
  for (var row = 0; row < 5; row++) {
    for (var col = 0; col < 10; col++) {
      final last = row == 4 && col == 9;
      final p = at(col, row);
      if (last) s.glow(p, 34 * u, s.ink.b);
      c.drawCircle(
        p,
        (last ? 6.5 : 5) * u,
        s.fill(last ? s.ink.b : s.ink.a, last ? 1 : 0.5 + row * 0.1),
      );
    }
  }
}

/// Sun and moon in a line, and the tide they raise together.
void _springTide(_Stage s) {
  final c = s.canvas;
  final u = s.u;
  final sun = Offset(s.cx, s.h * 0.27);
  final moon = Offset(s.cx, s.h * 0.5);
  for (var i = 1; i <= 5; i++) {
    c.drawArc(
      Rect.fromCircle(center: sun, radius: (34 + i * 18) * u),
      math.pi * 0.15,
      math.pi * 0.7,
      false,
      s.line(s.ink.a, 1, 0.3 - i * 0.05),
    );
  }
  for (var y = sun.dy; y < s.h * 0.72; y += 9 * u) {
    c.drawLine(
      Offset(s.cx, y),
      Offset(s.cx, y + 4 * u),
      s.line(s.ink.bone, 1, 0.25),
    );
  }
  s.glow(sun, 110 * u, s.ink.a);
  c.drawCircle(sun, 34 * u, s.fill(s.ink.a, 0.92));
  s.glow(moon, 40 * u, s.ink.b, 0.8);
  s.moon(moon, 13 * u, 1, s.ink.b);
  final tide = s.sine(-10, s.w + 10, s.h * 0.8, 24 * u, 1, phase: math.pi / 2);
  c
    ..drawPath(
      Path.from(tide)
        ..lineTo(s.w + 10, s.h)
        ..lineTo(-10, s.h)
        ..close(),
      s.fill(s.ink.a, 0.08),
    )
    ..drawPath(tide, s.line(s.ink.a, 2.4));
}

/// A headland with its light burning, and the sea at its foot.
void _headland(_Stage s) {
  final c = s.canvas;
  final u = s.u;
  final w = s.w;
  final h = s.h;
  final lamp = Offset(w * 0.8, h * 0.22);

  final beam = Path()
    ..moveTo(lamp.dx, lamp.dy)
    ..lineTo(-10, h * 0.16)
    ..lineTo(-10, h * 0.36)
    ..close();
  c.drawPath(beam, s.fill(s.ink.b, 0.1));
  for (final t in [0.35, 0.6]) {
    c.drawLine(
      lamp,
      Offset(-10, h * (0.16 + 0.2 * t)),
      s.line(s.ink.b, 0.8, 0.25),
    );
  }

  final cliff = Path()
    ..moveTo(w + 2, h * 0.24)
    ..lineTo(w * 0.86, h * 0.25)
    ..lineTo(w * 0.74, h * 0.33)
    ..lineTo(w * 0.69, h * 0.45)
    ..lineTo(w * 0.6, h * 0.53)
    ..lineTo(w * 0.57, h * 0.68)
    ..lineTo(w * 0.5, h * 0.76)
    ..lineTo(w * 0.5, h + 2)
    ..lineTo(w + 2, h + 2)
    ..close();
  c
    ..drawPath(cliff, s.fill(s.ink.deep))
    ..drawPath(cliff, s.line(s.ink.a, 1.2, 0.6))
    ..drawRect(
      Rect.fromLTWH(
        lamp.dx - 5 * u,
        lamp.dy,
        10 * u,
        h * 0.25 - lamp.dy + 2 * u,
      ),
      s.fill(s.ink.a, 0.85),
    );
  s.glow(lamp, 44 * u, s.ink.b);
  c.drawCircle(lamp, 5 * u, s.fill(s.ink.b));

  for (var i = 0; i < 4; i++) {
    final y = h * 0.72 + i * 12 * u;
    c.drawPath(
      s.sine(-10, w * 0.55, y, 3 * u, 3, phase: i * 1.3),
      s.line(s.ink.a, 1.4, 0.7 - i * 0.14),
    );
  }
  for (var i = 0; i < 16; i++) {
    final p = Offset(
      w * (0.44 + s.random.nextDouble() * 0.1),
      h * (0.6 + s.random.nextDouble() * 0.12),
    );
    c.drawCircle(
      p,
      (0.8 + s.random.nextDouble() * 1.4) * u,
      s.fill(s.ink.bone, 0.5),
    );
  }
}

/// Nothing but sea to the horizon, and a sun half down behind it.
void _openWater(_Stage s) {
  final c = s.canvas;
  final u = s.u;
  final horizon = s.h * 0.74;
  final sun = Offset(s.cx, horizon);
  s.glow(sun, 150 * u, s.ink.a, 0.8);
  c
    ..save()
    ..clipRect(Rect.fromLTRB(0, 0, s.w, horizon))
    ..drawCircle(sun, 44 * u, s.fill(s.ink.a, 0.14))
    ..drawCircle(sun, 44 * u, s.line(s.ink.a, 2))
    ..drawCircle(sun, 60 * u, s.line(s.ink.a, 1, 0.3))
    ..restore()
    ..drawLine(
      Offset(0, horizon),
      Offset(s.w, horizon),
      s.line(s.ink.a, 1.2, 0.8),
    );
  s.waterLines(horizon, s.ink.a, count: 8, alpha: 0.2);
  final sail = Path()
    ..moveTo(s.w * 0.8, horizon - 16 * u)
    ..lineTo(s.w * 0.8 + 7 * u, horizon - 3 * u)
    ..lineTo(s.w * 0.8 - 1 * u, horizon - 3 * u)
    ..close();
  c.drawPath(sail, s.fill(s.ink.b, 0.9));
}

/// A hundred rays, every tenth one long and lit.
void _hundred(_Stage s) {
  final c = s.canvas;
  final u = s.u;
  final centre = Offset(s.cx, s.h * 0.52);
  s.glow(centre, 150 * u, s.ink.a, 0.7);
  for (var i = 0; i < 100; i++) {
    final a = -math.pi / 2 + i * 2 * math.pi / 100;
    final dir = Offset(math.cos(a), math.sin(a));
    final tenth = i % 10 == 0;
    final length = tenth ? 110 * u : (34 + s.random.nextDouble() * 58) * u;
    c.drawLine(
      centre + dir * 30 * u,
      centre + dir * (30 * u + length),
      s.line(
        tenth ? s.ink.b : s.ink.a,
        tenth ? 1.8 : 1,
        tenth ? 0.9 : 0.25 + s.random.nextDouble() * 0.45,
      ),
    );
  }
  s.glow(centre, 44 * u, s.ink.b);
  s.sparkle(centre, 20 * u, s.ink.b);
}

// --- Past the hundred -----------------------------------------------------

/// Steady wind: streamlines all leaning the same way.
void _tradeWind(_Stage s) {
  final c = s.canvas;
  final u = s.u;
  for (var i = 0; i < 15; i++) {
    final y = s.h * (0.22 + i * 0.047);
    final rise = s.h * 0.1;
    final path = Path()
      ..moveTo(-10, y)
      ..cubicTo(
        s.w * 0.3,
        y - rise * 0.2,
        s.w * 0.55,
        y + rise * 0.5,
        s.w + 10,
        y - rise,
      );
    final strong = i % 4 == 1;
    c.drawPath(
      path,
      s.line(
        strong ? s.ink.b : s.ink.a,
        strong ? 1.8 : 1,
        strong ? 0.85 : 0.2 + (i % 3) * 0.12,
      ),
    );
    for (final metric in path.computeMetrics()) {
      final at = metric.getTangentForOffset(
        metric.length * (0.2 + s.random.nextDouble() * 0.7),
      );
      if (at != null) {
        c.drawCircle(
          at.position,
          2.4 * u,
          s.fill(s.ink.bone, strong ? 0.9 : 0.35),
        );
      }
    }
  }
}

/// A globe, and the one line on it you are standing on.
void _meridian(_Stage s) {
  final c = s.canvas;
  final u = s.u;
  final centre = Offset(s.cx, s.h * 0.52);
  final r = math.min(s.w, s.h) * 0.28;
  s.glow(centre, r * 1.7, s.ink.a, 0.5);
  c
    ..save()
    ..clipPath(Path()..addOval(Rect.fromCircle(center: centre, radius: r)));
  for (final lat in [-60.0, -30.0, 0.0, 30.0, 60.0]) {
    final y = centre.dy + r * math.sin(lat * math.pi / 180);
    final half = r * math.cos(lat * math.pi / 180);
    c.drawLine(
      Offset(centre.dx - half, y),
      Offset(centre.dx + half, y),
      s.line(s.ink.a, 1, 0.22),
    );
  }
  for (var k = 1; k <= 5; k++) {
    final width = 2 * r * math.cos(k * math.pi / 12);
    c.drawOval(
      Rect.fromCenter(center: centre, width: width, height: 2 * r),
      s.line(s.ink.a, 1, 0.22),
    );
  }
  c
    ..restore()
    ..drawCircle(centre, r, s.line(s.ink.a, 1.6, 0.85))
    ..drawLine(
      centre.translate(0, -r - 18 * u),
      centre.translate(0, r + 18 * u),
      s.line(s.ink.b, 2.2),
    );
  s.glow(centre, 30 * u, s.ink.b);
  c.drawCircle(centre, 5 * u, s.fill(s.ink.b));
}

/// The longest day: the sun at the top of its highest arc.
void _solstice(_Stage s) {
  final c = s.canvas;
  final u = s.u;
  final horizon = s.h * 0.74;
  final top = s.h * 0.28;
  final arc = Rect.fromLTRB(
    s.w * 0.08,
    top,
    s.w * 0.92,
    horizon + (horizon - top),
  );
  c.drawArc(arc, math.pi, math.pi, true, s.fill(s.ink.a, 0.05));
  for (var i = 0; i <= 12; i++) {
    final a = math.pi + i * math.pi / 12;
    final p =
        arc.center +
        Offset(math.cos(a) * arc.width / 2, math.sin(a) * arc.height / 2);
    // Hour marks along the day; the noon mark is under the sun.
    if (i != 6) c.drawCircle(p, 2.4 * u, s.fill(s.ink.b, 0.7));
  }
  final sun = Offset(s.cx, top);
  s.glow(sun, 120 * u, s.ink.a);
  c.drawCircle(sun, 22 * u, s.fill(s.ink.a));
  for (var i = 0; i < 12; i++) {
    final a = i * math.pi / 6;
    final dir = Offset(math.cos(a), math.sin(a));
    c.drawLine(
      sun + dir * 30 * u,
      sun + dir * 40 * u,
      s.line(s.ink.a, 1.8, 0.8),
    );
  }
  c.drawLine(
    Offset(0, horizon),
    Offset(s.w, horizon),
    s.line(s.ink.a, 1.2, 0.7),
  );
  s.waterLines(horizon, s.ink.a, count: 6, alpha: 0.18);
}

/// A warm current running through cold water.
void _gulfStream(_Stage s) {
  final c = s.canvas;
  final u = s.u;
  double y(double x, double shift) =>
      s.h * 0.66 -
      (x / s.w) * s.h * 0.34 +
      math.sin(x / s.w * 2 * math.pi * 1.2) * s.h * 0.08 +
      shift;
  for (var k = -4; k <= 4; k++) {
    final path = Path();
    for (var i = 0; i <= 80; i++) {
      final x = -10 + (s.w + 20) * i / 80;
      i == 0
          ? path.moveTo(x, y(x, k * 7 * u))
          : path.lineTo(x, y(x, k * 7 * u));
    }
    final core = k.abs() <= 1;
    c.drawPath(
      path,
      s.line(
        core ? s.ink.a : s.ink.b,
        core ? 2.2 : 1.2,
        core ? 0.95 : 0.55 - k.abs() * 0.1,
      ),
    );
  }
  for (final (fx, side) in [(0.26, -1.0), (0.58, 1.0), (0.82, -1.0)]) {
    final x = s.w * fx;
    final centre = Offset(x, y(x, side * 44 * u));
    for (var r = 5.0; r <= 17; r += 6) {
      c.drawCircle(centre, r * u, s.line(s.ink.b, 1, 0.4 - r * 0.015));
    }
  }
}

/// Deep blue offshore: a honeycomb of swell, brightest where you are.
void _blueWater(_Stage s) {
  final c = s.canvas;
  final u = s.u;
  final r = 22 * u;
  final focus = Offset(s.cx, s.h * 0.46);
  final reach = math.min(s.w, s.h) * 0.62;
  final dx = r * math.sqrt(3);
  final dy = r * 1.5;
  for (var row = -1; row * dy < s.h + r; row++) {
    for (var col = -1; col * dx < s.w + r; col++) {
      final centre = Offset(col * dx + (row.isOdd ? dx / 2 : 0), row * dy);
      final nearness = 1 - (centre - focus).distance / reach;
      if (nearness <= 0) continue;
      final hex = Path();
      for (var i = 0; i < 6; i++) {
        final a = math.pi / 6 + i * math.pi / 3;
        final p = centre + Offset(math.cos(a), math.sin(a)) * (r - 2 * u);
        i == 0 ? hex.moveTo(p.dx, p.dy) : hex.lineTo(p.dx, p.dy);
      }
      hex.close();
      if (nearness > 0.7) {
        c.drawPath(hex, s.fill(s.ink.b, 0.12 + (nearness - 0.7)));
      }
      c.drawPath(hex, s.line(s.ink.a, 1.1, nearness * 0.8));
    }
  }
  s.glow(focus, 40 * u, s.ink.b);
}

/// A storm glass, its crystals grown tall, weather beating outside.
void _stormGlass(_Stage s) {
  final c = s.canvas;
  final u = s.u;
  for (var i = 0; i < 46; i++) {
    final x = s.random.nextDouble() * s.w;
    final y = s.random.nextDouble() * s.h;
    c.drawLine(
      Offset(x, y),
      Offset(x - 6 * u, y + 16 * u),
      s.line(s.ink.a, 1, 0.14),
    );
  }
  final bolt = Path()
    ..moveTo(s.w * 0.14, s.h * 0.16)
    ..lineTo(s.w * 0.22, s.h * 0.28)
    ..lineTo(s.w * 0.17, s.h * 0.29)
    ..lineTo(s.w * 0.25, s.h * 0.42);
  c.drawPath(bolt, s.line(s.ink.b, 2, 0.9));

  final left = s.cx - 40 * u;
  final right = s.cx + 40 * u;
  final floor = s.h * 0.84;
  final shoulder = s.h * 0.36;
  final glass = Path()
    ..moveTo(s.cx - 11 * u, s.h * 0.17)
    ..lineTo(s.cx - 11 * u, shoulder - 20 * u)
    ..quadraticBezierTo(left, shoulder - 8 * u, left, shoulder + 20 * u)
    ..lineTo(left, floor - 14 * u)
    ..quadraticBezierTo(left, floor, left + 14 * u, floor)
    ..lineTo(right - 14 * u, floor)
    ..quadraticBezierTo(right, floor, right, floor - 14 * u)
    ..lineTo(right, shoulder + 20 * u)
    ..quadraticBezierTo(
      right,
      shoulder - 8 * u,
      s.cx + 11 * u,
      shoulder - 20 * u,
    )
    ..lineTo(s.cx + 11 * u, s.h * 0.17);
  c
    ..drawPath(Path.from(glass)..close(), s.fill(s.ink.deep, 0.8))
    ..save()
    ..clipPath(Path.from(glass)..close());

  void branch(Offset from, double angle, double length, int depth) {
    final to = from + Offset(math.cos(angle), math.sin(angle)) * length;
    c.drawLine(
      from,
      to,
      s.line(s.ink.b, 0.6 + depth * 0.3, 0.35 + depth * 0.13),
    );
    if (depth == 0) return;
    for (final turn in [-0.55, 0.55]) {
      branch(
        Offset.lerp(from, to, 0.55)!,
        angle + turn,
        length * 0.55,
        depth - 1,
      );
    }
    branch(
      to,
      angle + (s.random.nextDouble() - 0.5) * 0.2,
      length * 0.72,
      depth - 1,
    );
  }

  for (final x in [-18.0, 0.0, 17.0]) {
    branch(
      Offset(s.cx + x * u, floor),
      -math.pi / 2 + x * 0.008,
      (x == 0 ? 60 : 44) * u,
      4,
    );
  }
  c
    ..restore()
    ..drawPath(glass, s.line(s.ink.a, 1.6, 0.9))
    ..drawLine(
      Offset(left + 8 * u, shoulder + 26 * u),
      Offset(left + 8 * u, floor - 30 * u),
      s.line(s.ink.bone, 1.4, 0.3),
    );
}

// --- The far water --------------------------------------------------------

/// A year of days, laid out the way a seed head packs them.
void _deepWater(_Stage s) {
  final c = s.canvas;
  final u = s.u;
  final centre = Offset(s.cx, s.h * 0.52);
  final reach = math.min(s.w, s.h) * 0.38;
  const golden = 2.39996322972865332;
  final step = reach / math.sqrt(365);
  s.glow(centre, reach * 1.25, s.ink.a, 0.45);
  for (var n = 1; n <= 365; n++) {
    final r = step * math.sqrt(n);
    final a = n * golden;
    final p = centre + Offset(math.cos(a), math.sin(a)) * r;
    final t = n / 365;
    if (n == 365) {
      s.glow(p, 30 * u, s.ink.b);
      c.drawCircle(p, 4.4 * u, s.fill(s.ink.b));
    } else {
      c.drawCircle(p, (0.9 + t * 2.2) * u, s.fill(s.ink.a, 0.3 + t * 0.65));
    }
  }
}

/// The dark below the light, and the one living thing carrying its own.
void _abyssal(_Stage s) {
  final c = s.canvas;
  final u = s.u;
  final floor = Offset(s.cx, s.h * 1.08);
  for (var k = 0; k < 8; k++) {
    final base = math.min(s.w, s.h) * (0.28 + k * 0.13);
    final path = Path();
    for (var i = 0; i <= 120; i++) {
      final a = math.pi + i / 120 * math.pi;
      final r = base + math.sin(a * 5 + k) * 4 * u;
      final p = floor + Offset(math.cos(a), math.sin(a)) * r;
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    c.drawPath(path, s.line(s.ink.b, 1, 0.3 - k * 0.03));
  }
  for (var i = 0; i < 70; i++) {
    final p = Offset(
      s.random.nextDouble() * s.w,
      s.random.nextDouble() * s.h * 0.9,
    );
    final bright = s.random.nextDouble() > 0.9;
    if (bright) s.glow(p, 10 * u, s.ink.a, 0.8);
    c.drawCircle(
      p,
      (bright ? 1.8 : 0.5 + s.random.nextDouble()) * u,
      s.fill(s.ink.a, bright ? 0.9 : 0.25 + s.random.nextDouble() * 0.4),
    );
  }
  final lure = Offset(s.w * 0.58, s.h * 0.5);
  final stalk = Path()
    ..moveTo(s.w * 0.1, s.h * 0.18)
    ..quadraticBezierTo(s.w * 0.62, s.h * 0.1, lure.dx, lure.dy - 8 * u);
  c.drawPath(stalk, s.line(s.ink.a, 1.4, 0.55));
  s.glow(lure, 70 * u, s.ink.a);
  c.drawCircle(lure, 7 * u, s.fill(s.ink.a));
}

/// Two rings of 365 days, one inside the other.
void _twoYears(_Stage s) {
  final c = s.canvas;
  final u = s.u;
  final centre = Offset(s.cx, s.h * 0.53);
  final outer = math.min(s.w, s.h) * 0.33;
  final inner = outer * 0.74;
  s.glow(centre, outer * 1.2, s.ink.a, 0.4);
  for (final (radius, color) in [(outer, s.ink.a), (inner, s.ink.b)]) {
    for (var i = 0; i < 365; i++) {
      final a = -math.pi / 2 + i * 2 * math.pi / 365;
      final dir = Offset(math.cos(a), math.sin(a));
      final month = i % 30 == 0;
      c.drawLine(
        centre + dir * radius,
        centre + dir * (radius - (month ? 12 : 6) * u),
        s.line(color, month ? 1.4 : 0.8, month ? 0.95 : 0.5),
      );
    }
  }
  for (final (radius, color) in [
    (outer + 10 * u, s.ink.a),
    (inner + 10 * u, s.ink.b),
  ]) {
    final p = centre + Offset(0, -radius);
    s.glow(p, 22 * u, color);
    c.drawCircle(p, 4 * u, s.fill(color));
  }
  s.sparkle(centre, 14 * u, s.ink.bone);
}

// --- Clean days -----------------------------------------------------------

/// Fourteen links, none of them missing.
void _cleanChain(_Stage s) {
  final c = s.canvas;
  final u = s.u;
  Offset at(int i) {
    final t = i / 13;
    return Offset(
      s.w * (0.08 + 0.84 * t),
      s.h * 0.5 - math.sin(t * math.pi) * s.h * 0.16,
    );
  }

  final path = Path();
  for (var i = 0; i < 14; i++) {
    final p = at(i);
    i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
  }
  c.drawPath(path, s.line(s.ink.b, 1.4, 0.6));
  for (var i = 0; i < 14; i++) {
    final p = at(i);
    final d = 9 * u;
    final diamond = Path()
      ..moveTo(p.dx, p.dy - d)
      ..lineTo(p.dx + d, p.dy)
      ..lineTo(p.dx, p.dy + d)
      ..lineTo(p.dx - d, p.dy)
      ..close();
    if (i == 13) s.glow(p, 34 * u, s.ink.a);
    c
      ..drawPath(diamond, s.fill(s.ink.a, i == 13 ? 0.95 : 0.2))
      ..drawPath(diamond, s.line(s.ink.a, 1.4))
      ..drawCircle(
        p.translate(-d * 0.3, -d * 0.3),
        1.2 * u,
        s.fill(s.ink.bone, 0.8),
      );
  }
  s.waterLines(s.h * 0.72, s.ink.a, count: 6, alpha: 0.14);
}

/// One line, drawn without lifting the pen.
void _unbroken(_Stage s) {
  final c = s.canvas;
  final u = s.u;
  final centre = Offset(s.cx, s.h * 0.52);
  final ax = s.w * 0.36;
  final ay = math.min(s.h * 0.3, s.w * 0.36);
  final path = Path();
  for (var i = 0; i <= 720; i++) {
    final t = i / 720 * 2 * math.pi;
    final p =
        centre +
        Offset(math.sin(3 * t + math.pi / 2) * ax, math.sin(4 * t) * ay);
    i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
  }
  c
    ..drawPath(path, s.line(s.ink.a, 6, 0.1))
    ..drawPath(path, s.line(s.ink.a, 1.8, 0.95));
  final start = centre + Offset(ax, 0);
  s.glow(start, 30 * u, s.ink.b);
  c.drawCircle(start, 5 * u, s.fill(s.ink.b));
}

/// A frost crystal giving way to warmth — ninety days and not one freeze.
void _thaw(_Stage s) {
  final c = s.canvas;
  final u = s.u;
  final centre = Offset(s.cx, s.h * 0.5);
  final arm = math.min(s.w, s.h) * 0.24;
  s.glow(centre, arm * 2.2, s.ink.b, 0.9);
  for (var k = 0; k < 6; k++) {
    final a = -math.pi / 2 + k * math.pi / 3;
    final dir = Offset(math.cos(a), math.sin(a));
    // The three arms pointing down are the ones melting.
    final melting = dir.dy > 0.1;
    final alpha = melting ? 0.35 : 0.95;
    final tip = centre + dir * arm;
    if (melting) {
      for (var t = 0.0; t < 1; t += 0.14) {
        c.drawLine(
          centre + dir * arm * t,
          centre + dir * arm * (t + 0.07),
          s.line(s.ink.a, 1.8, alpha),
        );
      }
    } else {
      c.drawLine(centre, tip, s.line(s.ink.a, 1.8, alpha));
    }
    for (final (at, spread) in [(0.45, 0.32), (0.72, 0.2)]) {
      final root = centre + dir * arm * at;
      for (final side in [-1.0, 1.0]) {
        final b = a + side * math.pi / 3;
        c.drawLine(
          root,
          root + Offset(math.cos(b), math.sin(b)) * arm * spread,
          s.line(s.ink.a, 1.3, alpha),
        );
      }
    }
    if (melting) {
      final drop = tip + dir * 14 * u;
      c.drawCircle(drop, 3.2 * u, s.fill(s.ink.a, 0.7));
    }
  }
  c.drawCircle(centre, 5 * u, s.fill(s.ink.a));
}

/// Water so still the square above it is drawn twice.
void _glassWater(_Stage s) {
  final c = s.canvas;
  final u = s.u;
  final horizon = s.h * 0.56;
  final side = 58 * u;
  for (var i = 1; i <= 9; i++) {
    final d = (i * i * 1.5 + i * 6) * u;
    for (final y in [horizon - d, horizon + d]) {
      if (y < 0 || y > s.h) continue;
      c.drawLine(Offset(0, y), Offset(s.w, y), s.line(s.ink.a, 0.6, 0.06));
    }
  }
  final above = Rect.fromCenter(
    center: Offset(s.cx, horizon - side * 0.9),
    width: side,
    height: side,
  );
  final below = Rect.fromCenter(
    center: Offset(s.cx, horizon + side * 0.9),
    width: side,
    height: side,
  );
  s.glow(above.center, side * 1.6, s.ink.a, 0.7);
  c
    ..drawRect(above, s.fill(s.ink.a, 0.12))
    ..drawRect(above, s.line(s.ink.a, 2))
    ..drawRect(below, s.fill(s.ink.a, 0.05))
    ..drawRect(below, s.line(s.ink.a, 1.4, 0.35))
    ..drawLine(
      Offset(0, horizon),
      Offset(s.w, horizon),
      s.line(s.ink.b, 1.2, 0.9),
    );
  s.sparkle(above.topRight.translate(-6 * u, 6 * u), 7 * u, s.ink.b);
}
