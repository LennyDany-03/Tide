import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../theme/tide_colors.dart';
import '../../../theme/tide_gradients.dart';
import '../../../theme/tide_motion.dart';

/// Where the beam starts its pass: pointing left, just under the horizon.
/// It turns clockwise, up over the sky and down to the right.
const double _beamFrom = -math.pi - 0.12;

/// Where the pass ends: pointing right, just under the horizon. The rest of
/// the turn is round the back of the tower, dark.
const double _beamTo = 0.12;

/// The share of each turn the beam is in front.
const double _beamShown = (_beamTo - _beamFrom) / (2 * math.pi);

/// The beam's angle, in radians clockwise from pointing right, at [time]
/// seconds — or null while it is round the back of the tower.
///
/// It turns at a constant speed, as a real light does, and is in front for
/// the half of a turn that crosses the sky, from one horizon to the other.
/// The other half is dark, which is what makes each pass read as a pass.
double? beamAngleAt(double time) {
  final period = TideMotion.beamSweep.inMilliseconds / 1000;
  final turn = (time % period) / period;
  return turn <= _beamShown ? _beamFrom + turn * 2 * math.pi : null;
}

/// How close to pointing at the viewer the unseen part of the turn is, 0..1.
/// The lamp flares then — the flash you see from a ship.
double lampFlareAt(double time) {
  final period = TideMotion.beamSweep.inMilliseconds / 1000;
  final turn = (time % period) / period;
  final facing = (1 + _beamShown) / 2;
  return (1 - (turn - facing).abs() / 0.07).clamp(0.0, 1.0);
}

/// What the scene is composed round, measured from the laid-out call: the
/// slip the beam looks for, and the top of the controls, which the sea runs
/// under. Both in the coordinates of a box [size] big.
@immutable
class LighthouseStage {
  const LighthouseStage({
    required this.size,
    required this.slip,
    required this.shore,
  });

  final Size size;
  final Rect slip;
  final double shore;

  @override
  bool operator ==(Object other) =>
      other is LighthouseStage &&
      other.size == size &&
      other.slip == slip &&
      other.shore == shore;

  @override
  int get hashCode => Object.hash(size, slip, shore);
}

/// Where the lighthouse stands and what its beam is looking for.
///
/// Worked out from the [LighthouseStage] rather than fixed fractions of the
/// screen, so the picture holds together whatever the call is showing: the
/// horizon sits just above the controls, the tower stands on it at the left
/// as tall as the gap under the slip allows, and the beam locks onto the
/// middle of the slip wherever a long title or a list of steps has put it.
@immutable
class LighthouseGeometry {
  const LighthouseGeometry._({
    required this.lamp,
    required this.horizon,
    required this.height,
    required this.slip,
  });

  factory LighthouseGeometry.of(Size size, LighthouseStage? stage) {
    final slip =
        stage?.slip ??
        Rect.fromCenter(
          center: Offset(size.width * 0.5, size.height * 0.46),
          width: size.width * 0.86,
          height: size.height * 0.2,
        );
    // A strip of open sea above the controls, for the lamp's light to lie on.
    final horizon = stage == null ? size.height * 0.72 : stage.shore - 28;
    // As tall as the gap under the slip allows. A to-do with a long list of
    // steps leaves little room, and the light stands further off rather than
    // behind the card.
    final room = horizon - slip.bottom - 18;
    final tallest = math.max(
      _shortest,
      math.min(118.0, size.shortestSide * 0.3),
    );
    final height = (room / _reach).clamp(_shortest, tallest);
    final lamp = Offset(
      math.max(46.0, size.width * 0.15),
      horizon - height * _lampAbove,
    );
    return LighthouseGeometry._(
      lamp: lamp,
      horizon: horizon,
      height: height,
      slip: slip,
    );
  }

  /// How far above the horizon the whole light reaches — rock, tower,
  /// gallery, lantern room, dome and finial — in tower heights.
  static const double _reach = 1.33;

  /// The smallest the tower is drawn: still a lighthouse, just a far one.
  static const double _shortest = 34;

  /// The middle of the lantern room above the horizon, in tower heights.
  static const double _lampAbove = 1.15;

  /// The middle of the lantern room: where the beam comes from.
  final Offset lamp;
  final double horizon;

  /// The tower's body, rock to gallery.
  final double height;

  final Rect slip;

  /// The beam's angle when it is squarely on the slip.
  double get aim => _angleTo(slip.center);

  /// In the beam's own terms, which run from pointing left past the top to
  /// pointing right: a point low on the left is a little past -π, not
  /// nearly +π, or a slip overlapping the tower would seem to span the whole
  /// turn.
  double _angleTo(Offset point) {
    final angle = math.atan2(point.dy - lamp.dy, point.dx - lamp.dx);
    return angle > math.pi / 2 ? angle - 2 * math.pi : angle;
  }

  /// Where a beam at [angle] is across the slip: 0 as it reaches the first
  /// corner, 1 as it leaves the last, beyond either end when it is off it.
  double crossing(double angle) {
    final corners = [
      slip.topLeft,
      slip.topRight,
      slip.bottomLeft,
      slip.bottomRight,
    ].map(_angleTo);
    final first = corners.reduce(math.min);
    final last = corners.reduce(math.max);
    if (last - first < 1e-3) return 0.5;
    return (angle - first) / (last - first);
  }
}

/// The night a Lighthouse call stands in: stars over a still sea, the tower
/// on a headland at the horizon, its beam sweeping the sky and the light it
/// throws broken up on the water.
///
/// [lock] 0..1 swings the beam onto the slip and holds it there, brighter —
/// the to-do docked. [dim] 0..1 turns the light down — snoozed.
class LighthouseBeam extends StatelessWidget {
  const LighthouseBeam({
    super.key,
    required this.time,
    required this.lock,
    required this.dim,
    required this.stage,
    this.still = false,
  });

  final ValueListenable<double> time;
  final Animation<double> lock;
  final Animation<double> dim;
  final ValueListenable<LighthouseStage?> stage;
  final bool still;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _ScenePainter(
          time: time,
          lock: lock,
          dim: dim,
          stage: stage,
          still: still,
        ),
        size: Size.infinite,
      ),
    );
  }
}

/// A point of the sky or the sea, fixed by a seed so the night is the same
/// night every time the call rings.
@immutable
class _Speck {
  const _Speck(this.x, this.y, this.size, this.phase, this.rate);

  final double x;
  final double y;
  final double size;
  final double phase;
  final double rate;

  static List<_Speck> scatter(int seed, int count) {
    final random = math.Random(seed);
    return [
      for (var i = 0; i < count; i++)
        _Speck(
          random.nextDouble(),
          random.nextDouble(),
          random.nextDouble(),
          random.nextDouble() * 2 * math.pi,
          0.6 + random.nextDouble() * 1.6,
        ),
    ];
  }
}

class _ScenePainter extends CustomPainter {
  _ScenePainter({
    required this.time,
    required this.lock,
    required this.dim,
    required this.stage,
    required this.still,
  }) : super(repaint: Listenable.merge([time, lock, dim, stage]));

  final ValueListenable<double> time;
  final Animation<double> lock;
  final Animation<double> dim;
  final ValueListenable<LighthouseStage?> stage;
  final bool still;

  static final List<_Speck> _stars = _Speck.scatter(7, 64);
  static final List<_Speck> _glitter = _Speck.scatter(19, 42);

  /// The beam's half-width, in radians.
  static const double _spread = 0.22;

  /// How wide the beam already is where it leaves the glass, either side of
  /// its middle, in pixels. A beam from a point reads as a laser.
  static const double _lens = 4;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final t = still ? 0.0 : time.value;
    final geometry = LighthouseGeometry.of(size, stage.value);
    final horizon = geometry.horizon;
    final lamp = geometry.lamp;
    final aim = geometry.aim;

    // Where the beam points: its own sweep, pulled onto the slip by [lock].
    // Reduced motion holds it on the slip at part strength instead of
    // sweeping.
    final sweep = still ? aim : beamAngleAt(t);
    final locked = lock.value;
    final double? angle = sweep == null
        ? (locked > 0 ? aim : null)
        : sweep + (aim - sweep) * locked;
    final light = 1 - dim.value * 0.85;
    final strength = (still ? 0.6 : 1.0) * (1 + 0.4 * locked) * light;
    final flare = still ? 0.0 : lampFlareAt(t);
    final glow = ((0.4 + 0.6 * flare) * light + locked * 0.5).clamp(0.0, 1.0);

    _sky(canvas, size, horizon, t);
    _sea(canvas, size, geometry, glow, t);
    if (angle != null && strength > 0.02) {
      _graze(canvas, size, geometry, angle, strength);
      _beam(canvas, size, lamp, angle, strength);
    }
    _tower(canvas, geometry, glow);
    _lamp(canvas, geometry, glow, flare * light);
  }

  /// The sky down to the horizon, and the stars in it.
  void _sky(Canvas canvas, Size size, double horizon, double t) {
    final sky = Rect.fromLTRB(0, 0, size.width, horizon);
    canvas.drawRect(
      sky,
      Paint()..shader = TideGradients.lighthouseSky.createShader(sky),
    );
    // On a light palette the night is a pale ground and "bright" ink is
    // dark; stars there would read as dust on the glass, not as stars.
    if (TideColors.palette.isLight) return;
    final paint = Paint();
    for (final star in _stars) {
      final y = star.y * horizon * 0.9;
      // Thinner toward the horizon, where the haze is.
      final clear = 1 - (y / horizon);
      final twinkle = still
          ? 0.7
          : 0.55 + 0.45 * math.sin(t * star.rate + star.phase);
      paint.color = TideColors.bone.withValues(
        alpha: (0.1 + 0.45 * star.size) * twinkle * clear,
      );
      canvas.drawCircle(
        Offset(star.x * size.width, y),
        0.5 + star.size * 0.9,
        paint,
      );
    }
  }

  /// The sea, the line where it meets the sky, and the lamp's light broken
  /// up on it in a path toward the viewer — wider and slower the nearer it
  /// comes, the way light lies on real water.
  void _sea(
    Canvas canvas,
    Size size,
    LighthouseGeometry geometry,
    double glow,
    double t,
  ) {
    final horizon = geometry.horizon;
    final sea = Rect.fromLTRB(0, horizon, size.width, size.height);
    canvas.drawRect(
      sea,
      Paint()..shader = TideGradients.lighthouseSea.createShader(sea),
    );

    // The haze the lamp lights where the air sits on the water.
    final haze = size.width * 0.7;
    canvas.save();
    canvas.translate(geometry.lamp.dx, horizon);
    canvas.scale(1, 0.18);
    canvas.drawCircle(
      Offset.zero,
      haze,
      Paint()
        ..shader = TideGradients.bloom(
          color: TideColors.lantern,
          alpha: 0.16 * glow,
          center: Alignment.center,
          radius: 0.5,
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: haze)),
    );
    canvas.restore();

    canvas.drawLine(
      Offset(0, horizon),
      Offset(size.width, horizon),
      Paint()
        ..strokeWidth = 1
        ..color = TideColors.bone.withValues(alpha: 0.1),
    );

    final depth = size.height - horizon;
    if (depth <= 0) return;
    final paint = Paint()..strokeCap = StrokeCap.round;
    for (final fleck in _glitter) {
      final near = math.pow(fleck.y, 1.5).toDouble();
      final y = horizon + 3 + near * depth;
      final spread = 4 + near * size.width * 0.2;
      final x = geometry.lamp.dx + (fleck.x * 2 - 1) * spread;
      final half = 1.5 + near * (6 + 12 * fleck.size);
      final twinkle = still
          ? 0.6
          : 0.3 +
                0.7 *
                    (0.5 + 0.5 * math.sin(t * fleck.rate * 1.4 + fleck.phase));
      paint
        ..strokeWidth = 1 + near * 1.4
        ..color = TideColors.lantern.withValues(
          alpha: (0.5 * (1 - near * 0.8) * twinkle * glow).clamp(0.0, 1.0),
        );
      canvas.drawLine(Offset(x - half, y), Offset(x + half, y), paint);
    }
  }

  /// When the beam comes down to the horizon at either end of its pass, it
  /// lights a long stretch of the water it grazes.
  void _graze(
    Canvas canvas,
    Size size,
    LighthouseGeometry geometry,
    double angle,
    double strength,
  ) {
    final right = angle.abs();
    final left = (angle + math.pi).abs();
    final low = math.min(left, right);
    final graze = (1 - low / 0.4).clamp(0.0, 1.0);
    if (graze <= 0) return;
    final lamp = geometry.lamp.dx;
    final x = right < left ? lamp + (size.width - lamp) * 0.62 : lamp * 0.3;
    final reach = right < left ? size.width - lamp : lamp + 40;
    canvas.save();
    canvas.translate(x, geometry.horizon);
    canvas.scale(1, 0.1);
    canvas.drawCircle(
      Offset.zero,
      reach,
      Paint()
        ..shader = TideGradients.bloom(
          color: TideColors.lantern,
          alpha: 0.3 * graze * strength,
          center: Alignment.center,
          radius: 0.5,
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: reach)),
    );
    canvas.restore();
  }

  /// The beam: a shaft leaving the lantern room as wide as its glass and
  /// opening out across the sky, soft at its edges, brightest down its
  /// middle, thinning with distance.
  void _beam(
    Canvas canvas,
    Size size,
    Offset lamp,
    double angle,
    double strength,
  ) {
    final reach = size.longestSide * 1.3;
    final along = Offset(math.cos(angle), math.sin(angle));
    // The sweep turns round a point just behind the glass, so the beam is
    // already [_lens] either side of its middle where it comes out.
    final origin = lamp - along * (_lens / math.tan(_spread));
    final end = origin + along * reach;
    final across = Offset(-along.dy, along.dx) * (reach * math.tan(_spread));
    final wedge = Path()
      ..moveTo(origin.dx, origin.dy)
      ..lineTo(end.dx + across.dx, end.dy + across.dy)
      ..lineTo(end.dx - across.dx, end.dy - across.dy)
      ..close();
    // A layer of its own: the sweep gives the beam its soft edges, and the
    // reach, masked over it, thins it with distance. One layer a frame is
    // far cheaper than blurring a shape the size of the screen, and has none
    // of the banding that stacking hard-edged wedges left.
    canvas.saveLayer(Offset.zero & size, Paint());
    canvas.drawPath(
      wedge,
      Paint()
        ..shader = TideGradients.beam(
          angle: angle,
          spread: _spread,
          strength: strength,
        ).createShader(Rect.fromCircle(center: origin, radius: reach)),
    );
    canvas.drawPath(
      wedge,
      Paint()
        ..blendMode = BlendMode.dstIn
        ..shader = TideGradients.beamReach.createShader(
          Rect.fromCircle(center: lamp, radius: reach),
        ),
    );
    canvas.restore();
  }

  /// The lighthouse as a silhouette on its headland: a tapering tower with
  /// two faint bands, a lit window, the gallery and its rail, the lantern
  /// room and its dome.
  void _tower(Canvas canvas, LighthouseGeometry geometry, double glow) {
    final h = geometry.height;
    final x = geometry.lamp.dx;
    final horizon = geometry.horizon;
    final foot = horizon - h * 0.05;
    final gallery = foot - h;
    final bottom = h * 0.17;
    final top = h * 0.105;
    final ink = Paint()..color = TideColors.trench;
    final rim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = TideColors.bone.withValues(alpha: 0.12);

    // The headland, low and uneven, running in from the edge of the screen.
    final rock = Path()
      ..moveTo(x - h * 0.9, horizon)
      ..quadraticBezierTo(x - h * 0.5, horizon - h * 0.09, x - h * 0.22, foot)
      ..lineTo(x + h * 0.24, foot)
      ..quadraticBezierTo(
        x + h * 0.52,
        horizon - h * 0.1,
        x + h * 0.95,
        horizon,
      )
      ..close();
    canvas.drawPath(rock, ink);

    final body = Path()
      ..moveTo(x - bottom, foot)
      ..lineTo(x - top, gallery)
      ..lineTo(x + top, gallery)
      ..lineTo(x + bottom, foot)
      ..close();
    canvas.drawPath(
      body,
      Paint()
        ..shader = TideGradients.lighthouseTower.createShader(body.getBounds()),
    );
    canvas.save();
    canvas.clipPath(body);
    final band = Paint()..color = TideColors.bone.withValues(alpha: 0.05);
    for (final at in const [0.28, 0.6]) {
      final y = foot - h * at;
      canvas.drawRect(
        Rect.fromLTRB(x - bottom, y - h * 0.11, x + bottom, y),
        band,
      );
    }
    canvas.restore();
    // The edge the app's one light falls on.
    canvas.drawLine(
      Offset(x - bottom, foot),
      Offset(x - top, gallery),
      Paint()
        ..strokeWidth = 1
        ..color = TideColors.bone.withValues(alpha: 0.16),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(x, foot - h * 0.46),
          width: math.max(2, h * 0.04),
          height: math.max(3, h * 0.075),
        ),
        const Radius.circular(1),
      ),
      Paint()..color = TideColors.lantern.withValues(alpha: 0.2 + 0.25 * glow),
    );

    // The gallery, the lantern room standing on it, and the rail in front.
    final deck = Rect.fromLTRB(
      x - top - h * 0.07,
      gallery - h * 0.03,
      x + top + h * 0.07,
      gallery,
    );
    canvas.drawRect(deck, ink);
    canvas.drawLine(deck.topLeft, deck.topRight, rim);
    final room = Rect.fromLTRB(
      x - top * 0.8,
      deck.top - h * 0.14,
      x + top * 0.8,
      deck.top,
    );
    canvas.drawRect(
      room,
      Paint()
        ..color = TideColors.flare.withValues(
          alpha: (0.5 + 0.5 * glow).clamp(0.0, 1.0),
        ),
    );
    final bars = Paint()
      ..strokeWidth = 1
      ..color = TideColors.trench.withValues(alpha: 0.7);
    for (final at in const [-0.34, 0.34]) {
      final bar = x + room.width * at;
      canvas.drawLine(Offset(bar, room.top), Offset(bar, room.bottom), bars);
    }
    final rail = deck.top - h * 0.055;
    canvas.drawLine(
      Offset(deck.left + 1, rail),
      Offset(deck.right - 1, rail),
      rim,
    );
    for (final at in const [0.0, 0.5, 1.0]) {
      final post = deck.left + 1 + (deck.width - 2) * at;
      canvas.drawLine(Offset(post, rail), Offset(post, deck.top), rim);
    }
    final dome = Path()
      ..moveTo(room.left - h * 0.03, room.top)
      ..quadraticBezierTo(
        x,
        room.top - h * 0.15,
        room.right + h * 0.03,
        room.top,
      )
      ..close();
    canvas.drawPath(dome, ink);
    canvas.drawLine(
      Offset(x, room.top - h * 0.06),
      Offset(x, room.top - h * 0.12),
      Paint()
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round
        ..color = TideColors.trench,
    );
  }

  /// The light itself: a bloom round the glass, and when the lamp turns to
  /// face you, a streak through it.
  void _lamp(
    Canvas canvas,
    LighthouseGeometry geometry,
    double glow,
    double flare,
  ) {
    final lamp = geometry.lamp;
    final radius = geometry.height * (0.34 + flare * 0.5);
    canvas.drawCircle(
      lamp,
      radius,
      Paint()
        ..shader = TideGradients.lampBloom(
          glow,
        ).createShader(Rect.fromCircle(center: lamp, radius: radius)),
    );
    if (flare > 0.01) {
      final half = geometry.height * (0.6 + 1.6 * flare);
      final streak = Rect.fromCenter(center: lamp, width: half * 2, height: 2);
      canvas.drawRect(
        streak,
        Paint()
          ..shader = TideGradients.lampStreak(0.8 * flare).createShader(streak),
      );
    }
    canvas.drawCircle(
      lamp,
      math.max(1.5, geometry.height * 0.03),
      Paint()..color = TideColors.flare,
    );
  }

  @override
  bool shouldRepaint(_ScenePainter old) =>
      old.time != time ||
      old.lock != lock ||
      old.dim != dim ||
      old.stage != stage ||
      old.still != still;
}
