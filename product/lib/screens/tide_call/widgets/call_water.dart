import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../theme/tide_colors.dart';
import '../../../theme/tide_gradients.dart';

/// The body of water a Tide Call stands in.
///
/// Three waves, far to near, each drifting at its own speed and in its own
/// direction — parallax, so the surface reads as depth rather than as one
/// line moving. Under the surface a few bands of light slide about like the
/// caustics on a pool floor, and bubbles rise through it.
///
/// It paints from two listenables and never rebuilds: [level] (0 empty, 1
/// the whole screen) moves with the entrance and the finger, [time] is the
/// screen's running clock in seconds. [still] is reduced motion — the water
/// holds its level and nothing drifts.
class CallWater extends StatelessWidget {
  const CallWater({
    super.key,
    required this.level,
    required this.time,
    this.still = false,
  });

  final ValueListenable<double> level;
  final ValueListenable<double> time;
  final bool still;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _WaterPainter(level: level, time: time, still: still),
        size: Size.infinite,
      ),
    );
  }
}

class _Layer {
  const _Layer(this.rise, this.amplitude, this.waves, this.speed);

  /// How far above the waterline this layer's crest sits, in pixels. The far
  /// layers stand a little higher, as a far swell does.
  final double rise;
  final double amplitude;
  final double waves;

  /// Radians per second, signed: layers drift in opposite directions.
  final double speed;
}

class _Bubble {
  const _Bubble(this.x, this.speed, this.size, this.offset, this.wobble);

  /// 0..1 across the screen.
  final double x;

  /// Pixels per second, upward.
  final double speed;
  final double size;
  final double offset;
  final double wobble;
}

class _WaterPainter extends CustomPainter {
  _WaterPainter({required this.level, required this.time, required this.still})
    : super(repaint: Listenable.merge([level, time]));

  final ValueListenable<double> level;
  final ValueListenable<double> time;
  final bool still;

  static const List<_Layer> _layers = [
    _Layer(16, 6, 1.15, 0.42),
    _Layer(7, 8, 1.7, -0.6),
    _Layer(0, 10, 0.85, 0.9),
  ];

  /// Seeded, so the bubbles are the same every call and never reshuffle.
  static final List<_Bubble> _bubbles = () {
    final random = math.Random(24);
    return List<_Bubble>.generate(18, (_) {
      return _Bubble(
        random.nextDouble(),
        14 + random.nextDouble() * 26,
        1.2 + random.nextDouble() * 2.4,
        random.nextDouble() * 900,
        4 + random.nextDouble() * 8,
      );
    });
  }();

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final fill = level.value;
    if (fill <= 0.001) return;
    final t = still ? 0.0 : time.value;
    final waterline = size.height * (1 - fill);

    for (var depth = 0; depth < _layers.length; depth++) {
      final layer = _layers[depth];
      final surface = _surface(size, waterline - layer.rise, layer, t);
      final body = Path.from(surface)
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close();
      final color = TideGradients.callWaterLayer(depth);
      canvas.drawPath(
        body,
        Paint()
          ..shader = TideGradients.callWater(color).createShader(
            Rect.fromLTRB(0, waterline - layer.rise, size.width, size.height),
          ),
      );
      if (depth == _layers.length - 1) {
        // The lit waterline on the near wave: the one bright edge, which is
        // what lets everything under it stay quiet.
        canvas.drawPath(
          surface,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6
            ..strokeCap = StrokeCap.round
            ..color = TideColors.lantern.withValues(alpha: 0.75),
        );
      }
    }

    if (!still) {
      _caustics(canvas, size, waterline, t);
      _rise(canvas, size, waterline, t);
    }
  }

  Path _surface(Size size, double baseline, _Layer layer, double t) {
    final path = Path()..moveTo(0, baseline);
    const steps = 56;
    for (var i = 0; i <= steps; i++) {
      final u = i / steps;
      final theta = u * 2 * math.pi * layer.waves + t * layer.speed;
      // Two incommensurate terms, so the crest never repeats inside a
      // glance — the same trick the Today level uses.
      final y =
          math.sin(theta) * layer.amplitude +
          math.sin(theta * 2.3 - t * layer.speed * 0.7) *
              layer.amplitude *
              0.35;
      path.lineTo(size.width * u, baseline + y);
    }
    return path;
  }

  /// Soft bands of light wandering under the surface.
  void _caustics(Canvas canvas, Size size, double waterline, double t) {
    final top = math.max(waterline + 18, 0.0);
    if (top >= size.height) return;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10)
      ..color = TideColors.lantern.withValues(
        alpha: TideColors.palette.isLight ? 0.03 : 0.06,
      );
    for (var i = 0; i < 5; i++) {
      final x = size.width * ((i + 0.5) / 5 + 0.07 * math.sin(t * 0.35 + i));
      final path = Path()..moveTo(x, top);
      final depth = size.height - top;
      for (var s = 1; s <= 8; s++) {
        final v = s / 8;
        path.lineTo(
          x + math.sin(t * 0.6 + i * 1.7 + v * 5) * 16,
          top + depth * v,
        );
      }
      canvas.drawPath(path, paint);
    }
  }

  /// Bubbles, rising from the floor and fading as they near the surface.
  void _rise(Canvas canvas, Size size, double waterline, double t) {
    final column = size.height - waterline;
    if (column < 30) return;
    final paint = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < _bubbles.length; i++) {
      final b = _bubbles[i];
      final travel = (t * b.speed + b.offset) % (column + 20);
      final y = size.height - travel;
      if (y < waterline + 6) continue;
      final x = size.width * b.x + math.sin(t * 1.3 + i) * b.wobble;
      final nearSurface = ((y - waterline) / 80).clamp(0.0, 1.0);
      paint.color = TideColors.lantern.withValues(alpha: 0.32 * nearSurface);
      canvas.drawCircle(Offset(x, y), b.size, paint);
    }
  }

  @override
  bool shouldRepaint(_WaterPainter old) =>
      old.level != level || old.time != time || old.still != still;
}
