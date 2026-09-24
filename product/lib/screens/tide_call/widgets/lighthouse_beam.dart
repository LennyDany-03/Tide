import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../theme/tide_colors.dart';
import '../../../theme/tide_gradients.dart';
import '../../../theme/tide_motion.dart';

/// Where the lamp stands, as fractions of the screen: low on the left, just
/// above the horizon. The beam swings up and over the slip from there.
const Offset lighthouseLamp = Offset(0.13, 0.7);

/// Where the horizon lies, as a fraction of the screen's height.
const double lighthouseHorizon = 0.735;

/// The beam's angle, in radians clockwise from pointing right, at [time]
/// seconds — or null while it is round the back of the tower.
///
/// It turns at a constant speed, as a real light does, and is only in front
/// for the quarter of a turn that crosses the screen, from nearly straight up
/// to just below the horizon. The rest of the turn is dark, which is what
/// makes each pass read as a pass.
double? beamAngleAt(double time) {
  final period = TideMotion.beamSweep.inMilliseconds / 1000;
  final turn = (time % period) / period;
  const start = -1.5;
  const end = 0.16;
  final angle = start + turn * 2 * math.pi;
  return angle <= end ? angle : null;
}

/// How close to pointing at the viewer the unseen part of the turn is, 0..1.
/// The lamp flares then — the flash you see from a ship.
double lampFlareAt(double time) {
  final period = TideMotion.beamSweep.inMilliseconds / 1000;
  final turn = (time % period) / period;
  final distance = (turn - 0.66).abs();
  return (1 - distance / 0.07).clamp(0.0, 1.0);
}

/// The night a Lighthouse call stands in: the tower on the horizon, its beam
/// sweeping the sky, and the light it throws broken up on the sea.
///
/// [lock] 0..1 swings the beam onto [target] and holds it there, brighter —
/// the to-do docked. [dim] 0..1 turns the light down — snoozed.
class LighthouseBeam extends StatelessWidget {
  const LighthouseBeam({
    super.key,
    required this.time,
    required this.lock,
    required this.dim,
    required this.target,
    this.still = false,
  });

  final ValueListenable<double> time;
  final Animation<double> lock;
  final Animation<double> dim;

  /// Where the slip sits, as fractions of the screen.
  final Offset target;
  final bool still;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _BeamPainter(
          time: time,
          lock: lock,
          dim: dim,
          target: target,
          still: still,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _BeamPainter extends CustomPainter {
  _BeamPainter({
    required this.time,
    required this.lock,
    required this.dim,
    required this.target,
    required this.still,
  }) : super(repaint: Listenable.merge([time, lock, dim]));

  final ValueListenable<double> time;
  final Animation<double> lock;
  final Animation<double> dim;
  final Offset target;
  final bool still;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final t = time.value;
    final lamp = Offset(
      size.width * lighthouseLamp.dx,
      size.height * lighthouseLamp.dy,
    );
    final horizon = size.height * lighthouseHorizon;
    final aim = math.atan2(
      size.height * target.dy - lamp.dy,
      size.width * target.dx - lamp.dx,
    );

    // Where the beam points: its own sweep, pulled onto the slip by [lock].
    // Reduced motion holds it on the slip at half strength instead of
    // sweeping.
    final sweep = still ? aim : beamAngleAt(t);
    final locked = lock.value;
    final double? angle = sweep == null
        ? (locked > 0 ? aim : null)
        : sweep + (aim - sweep) * locked;
    final strength =
        (still ? 0.6 : 1.0) * (1 + 0.35 * locked) * (1 - dim.value * 0.85);

    _sea(canvas, size, horizon);

    if (angle != null && strength > 0.02) {
      final reach = size.longestSide * 1.5;
      final beamPaint = Paint()
        ..shader = TideGradients.beam(
          strength: strength,
        ).createShader(Rect.fromCircle(center: lamp, radius: reach));
      // Three widths laid over each other: a soft edge without a blur over
      // the whole screen on every frame.
      for (final spread in const [0.2, 0.13, 0.07]) {
        canvas.drawPath(_wedge(lamp, angle, spread, reach), beamPaint);
      }
      _reflection(canvas, size, lamp, angle, horizon, strength, t);
    }

    _tower(canvas, size, lamp, horizon, t);
  }

  Path _wedge(Offset lamp, double angle, double spread, double reach) {
    return Path()
      ..moveTo(lamp.dx, lamp.dy)
      ..lineTo(
        lamp.dx + math.cos(angle - spread) * reach,
        lamp.dy + math.sin(angle - spread) * reach,
      )
      ..lineTo(
        lamp.dx + math.cos(angle + spread) * reach,
        lamp.dy + math.sin(angle + spread) * reach,
      )
      ..close();
  }

  /// The sea: one step lighter than the sky, and a hairline where they meet.
  void _sea(Canvas canvas, Size size, double horizon) {
    canvas.drawRect(
      Rect.fromLTRB(0, horizon, size.width, size.height),
      Paint()..color = TideColors.shelf.withValues(alpha: 0.55),
    );
    canvas.drawLine(
      Offset(0, horizon),
      Offset(size.width, horizon),
      Paint()
        ..strokeWidth = 1
        ..color = TideColors.bone.withValues(alpha: 0.08),
    );
  }

  /// Light broken up on the water under wherever the beam meets the sea — or,
  /// when it is up in the sky, under the lamp.
  void _reflection(
    Canvas canvas,
    Size size,
    Offset lamp,
    double angle,
    double horizon,
    double strength,
    double t,
  ) {
    final reach = angle > 0.02
        ? (horizon - lamp.dy) / math.tan(angle)
        : size.width * (0.2 + 0.6 * (1 + angle / 1.5).clamp(0.0, 1.0));
    final x = (lamp.dx + reach).clamp(0.0, size.width);
    final paint = Paint()..strokeCap = StrokeCap.round;
    for (var i = 0; i < 12; i++) {
      final y = horizon + 7 + i * 10.0;
      if (y > size.height) break;
      final half = 10 + i * 4.0;
      final jitter = still ? 0.0 : math.sin(t * 3 + i * 1.9) * (3 + i * 0.8);
      paint
        ..strokeWidth = 2
        ..color = TideColors.lantern.withValues(
          alpha: (0.26 - i * 0.02).clamp(0.0, 1.0) * strength,
        );
      canvas.drawLine(
        Offset(x - half + jitter, y),
        Offset(x + half * 0.6 + jitter, y),
        paint,
      );
    }
  }

  /// The tower as a silhouette on the horizon, and its lamp.
  void _tower(Canvas canvas, Size size, Offset lamp, double horizon, double t) {
    final base = size.shortestSide * 0.05;
    final tower = Path()
      ..moveTo(lamp.dx - base * 0.55, horizon)
      ..lineTo(lamp.dx - base * 0.3, lamp.dy + 6)
      ..lineTo(lamp.dx + base * 0.3, lamp.dy + 6)
      ..lineTo(lamp.dx + base * 0.55, horizon)
      ..close();
    canvas.drawPath(tower, Paint()..color = TideColors.trench);
    canvas.drawPath(
      tower,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = TideColors.bone.withValues(alpha: 0.1),
    );

    final flare = still ? 0.0 : lampFlareAt(t);
    final glow =
        (0.35 + 0.65 * flare) * (1 - dim.value * 0.7) + lock.value * 0.4;
    canvas.drawCircle(
      lamp,
      base * (1.4 + flare * 2.2),
      Paint()
        ..shader =
            TideGradients.bloom(
              color: TideColors.lantern,
              alpha: 0.5 * glow.clamp(0.0, 1.0),
              center: Alignment.center,
              radius: 0.5,
            ).createShader(
              Rect.fromCircle(center: lamp, radius: base * (1.4 + flare * 2.2)),
            ),
    );
    canvas.drawCircle(
      lamp,
      base * 0.26,
      Paint()
        ..color = TideColors.palette.flare.withValues(
          alpha: (0.7 + 0.3 * glow).clamp(0.0, 1.0),
        ),
    );
  }

  @override
  bool shouldRepaint(_BeamPainter old) =>
      old.time != time ||
      old.lock != lock ||
      old.dim != dim ||
      old.target != target ||
      old.still != still;
}
