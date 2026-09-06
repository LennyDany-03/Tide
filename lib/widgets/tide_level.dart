import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/tide_colors.dart';
import '../theme/tide_gradients.dart';
import '../theme/tide_motion.dart';

/// Water standing at a level, with a surface that moves.
///
/// This is the app's one hero object. It replaces a progress ring beside a
/// big number, which is two renderings of the same fact competing for the
/// same glance — the ring told you nothing the figure had not already said.
/// A water level says it once, and says it in the vocabulary the product is
/// named after: the day fills, and when you log something the tide comes in.
///
/// The surface is two sine waves at different frequencies and speeds rather
/// than one. A single sine is legible as a mathematical curve and reads as
/// a chart decoration; summing two incommensurate ones gives a crest that
/// never repeats within a glance, which is what water does.
class TideLevel extends StatefulWidget {
  const TideLevel({
    super.key,
    required this.level,
    this.color = TideColors.lantern,
    this.amplitude = 5,
  });

  /// 0..1 — how high the water stands.
  final double level;

  final Color color;

  /// Crest height in logical pixels. Small on purpose: this is a tide, not
  /// surf, and a big wave would read as a loading animation.
  final double amplitude;

  @override
  State<TideLevel> createState() => _TideLevelState();
}

class _TideLevelState extends State<TideLevel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _drift = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 9),
  );

  @override
  void initState() {
    super.initState();
    _drift.repeat();
  }

  @override
  void dispose() {
    _drift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The only looping animation in the app, so it is also the only one
    // that has to answer for itself when a user has asked for less motion.
    // Still water still reads as a level; it just stops breathing.
    final still = MediaQuery.disableAnimationsOf(context);

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: widget.level.clamp(0.0, 1.0)),
      duration: TideMotion.ringFill,
      curve: TideMotion.overshoot,
      builder: (context, level, _) {
        if (still) {
          return CustomPaint(
            painter: _TidePainter(
              level: level,
              phase: 0,
              color: widget.color,
              amplitude: 0,
            ),
            size: Size.infinite,
          );
        }
        return AnimatedBuilder(
          animation: _drift,
          builder: (context, _) => CustomPaint(
            painter: _TidePainter(
              level: level,
              phase: _drift.value * 2 * math.pi,
              color: widget.color,
              amplitude: widget.amplitude,
            ),
            size: Size.infinite,
          ),
        );
      },
    );
  }
}

class _TidePainter extends CustomPainter {
  const _TidePainter({
    required this.level,
    required this.phase,
    required this.color,
    required this.amplitude,
  });

  final double level;
  final double phase;
  final Color color;
  final double amplitude;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    // Keep the crest inside the band at both extremes, so a full day does
    // not clip its own wave off against the top edge.
    final inset = amplitude + 1;
    final baseline =
        size.height - inset - (size.height - inset * 2) * level.clamp(0.0, 1.0);

    final surface = Path()..moveTo(0, baseline);
    const steps = 64;
    for (var i = 0; i <= steps; i++) {
      final x = size.width * i / steps;
      final u = i / steps;
      // Two waves, incommensurate periods, drifting at different speeds and
      // in opposite directions. Their sum never lines up inside a glance.
      final y =
          math.sin(u * 2 * math.pi * 1.6 + phase) * amplitude +
          math.sin(u * 2 * math.pi * 2.7 - phase * 0.63) * amplitude * 0.42;
      surface.lineTo(x, baseline + y);
    }

    // Nothing is painted above the waterline. A tinted band showing "how
    // much is left" gave the widget two visible horizontal edges, and since
    // this sits full-bleed on the page with no card around it, those edges
    // read as a rectangle someone forgot to remove. Empty is empty.

    final water = Path.from(surface)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      water,
      Paint()
        ..shader = TideGradients.tideFill.createShader(
          Rect.fromLTWH(0, baseline, size.width, size.height - baseline),
        ),
    );

    // The lit waterline. This is the one bright edge on the screen, and the
    // reason the fill beneath it can stay as quiet as it does.
    canvas.drawPath(
      surface,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round
        ..color = color.withValues(alpha: level <= 0 ? 0.28 : 0.92),
    );
  }

  @override
  bool shouldRepaint(_TidePainter old) =>
      old.level != level ||
      old.phase != phase ||
      old.color != color ||
      old.amplitude != amplitude;
}
