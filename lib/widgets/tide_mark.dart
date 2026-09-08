import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/tide_colors.dart';
import '../theme/tide_motion.dart';
import 'tide_ring.dart';

/// The brand mark: the tide ring, drawing itself in, with one lit point
/// going round it.
///
/// [TideRingDrawIn] already draws the ring; what this adds is the orbit. A
/// ring that finishes drawing and then stops is a logo, and a logo on the
/// first screen of an app is the one thing the user is asked to look at
/// while nothing happens. A point travelling the circumference forever is
/// the product's actual claim — the loop does not end — stated by the
/// identity object rather than by the tagline underneath it.
///
/// It carries across three screens: the welcome step draws it, the closing
/// step hands it off, and the auth screen wears it small at the top. Same
/// object each time, which is what stops those three from reading as three
/// different products.
class TideMark extends StatefulWidget {
  const TideMark({
    super.key,
    this.size = 164,
    this.strokeWidth = 4,
    this.coreSize = 14,
    this.orbit = true,
    this.drawIn = true,
    this.delay = const Duration(milliseconds: 180),
  });

  final double size;
  final double strokeWidth;

  /// The still point at the centre.
  final double coreSize;

  /// Whether the lit point runs the circumference once the ring is drawn.
  final bool orbit;

  /// Whether the ring draws itself in, or is simply already closed.
  ///
  /// Off wherever the mark is being *handed* one screen to the next. The
  /// point of that hand-off is that it is one object arriving, and an
  /// object that redraws itself from an empty arc the moment it lands is
  /// plainly a second object — it also takes a full second to do it, so
  /// there is a long beat where the thing that was supposed to have
  /// travelled is not there at all.
  final bool drawIn;

  final Duration delay;

  @override
  State<TideMark> createState() => _TideMarkState();
}

class _TideMarkState extends State<TideMark> with TickerProviderStateMixin {
  late final AnimationController _draw = AnimationController(
    vsync: this,
    duration: TideMotion.ringDraw,
  );

  late final AnimationController _orbit = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 5200),
  );

  @override
  void initState() {
    super.initState();
    if (!widget.drawIn) {
      _draw.value = 1;
      if (widget.orbit) _orbit.repeat();
      return;
    }
    Future<void>.delayed(widget.delay, () {
      if (!mounted) return;
      _draw.forward();
      if (widget.orbit) _orbit.repeat();
    });
  }

  @override
  void dispose() {
    _draw.dispose();
    _orbit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_draw, _orbit]),
      builder: (context, _) {
        final drawn = Curves.easeInOutCubic.transform(_draw.value);

        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              TideRing(
                progress: drawn,
                size: widget.size,
                strokeWidth: widget.strokeWidth,
                animate: false,
                showTrack: false,
              ),

              // The core arrives last, once there is a ring for it to sit
              // inside. Scaling it in alongside the sweep put a dot in the
              // middle of an arc that had not closed yet, which reads as
              // two unrelated marks.
              Transform.scale(
                scale: Curves.easeOutBack.transform(
                  ((drawn - 0.55) / 0.45).clamp(0.0, 1.0),
                ),
                child: Container(
                  width: widget.coreSize,
                  height: widget.coreSize,
                  decoration: const BoxDecoration(
                    color: TideColors.lantern,
                    shape: BoxShape.circle,
                  ),
                ),
              ),

              if (widget.orbit && drawn > 0.98)
                CustomPaint(
                  size: Size.square(widget.size),
                  painter: _OrbitPainter(
                    phase: _orbit.value,
                    strokeWidth: widget.strokeWidth,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// The travelling point, plus the short wake behind it.
class _OrbitPainter extends CustomPainter {
  const _OrbitPainter({required this.phase, required this.strokeWidth});

  /// 0..1 around the ring.
  final double phase;

  final double strokeWidth;

  /// How much of the circumference the wake covers. Short: a long tail
  /// turns the mark into a loading spinner, which is the one thing a splash
  /// screen must not look like.
  static const double _wake = 0.13;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = (size.shortestSide - strokeWidth) / 2;
    final center = size.center(Offset.zero);
    final start = -math.pi / 2 + phase * 2 * math.pi;

    // The wake is drawn as a few short arcs of rising alpha rather than one
    // gradient sweep: a SweepGradient has a seam where it wraps, and the
    // seam parks somewhere different every frame as the point travels.
    const segments = 7;
    for (var i = 0; i < segments; i++) {
      final from = start - _wake * 2 * math.pi * (i + 1) / segments;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        from,
        _wake * 2 * math.pi / segments + 0.01,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round
          ..color = TideColors.bone.withValues(
            alpha: 0.32 * (1 - i / segments),
          ),
      );
    }

    final point = Offset(
      center.dx + radius * math.cos(start),
      center.dy + radius * math.sin(start),
    );
    canvas.drawCircle(
      point,
      strokeWidth * 1.05,
      Paint()..color = TideColors.bone,
    );
  }

  @override
  bool shouldRepaint(_OrbitPainter old) => old.phase != phase;
}
