import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/tide_colors.dart';
import '../theme/tide_motion.dart';

/// The identity object of the app.
///
/// One ring serves the onboarding hero, every habit card, the save spinner
/// and the breathing empty state — which is what lets the onboarding ring
/// morph into Home's ring and still read as the same object.
class TideRing extends StatelessWidget {
  const TideRing({
    super.key,
    required this.progress,
    this.size = 34,
    this.strokeWidth = 2.5,
    this.color,
    this.trackColor,
    this.child,
    this.animate = true,
    this.duration = TideMotion.ringFill,
    this.showTrack = true,
  });

  /// 0..1. Values are animated with the signature overshoot curve, so a
  /// ring filling to 60% swings slightly past and settles back.
  final double progress;

  final double size;
  final double strokeWidth;
  final Color? color;
  final Color? trackColor;

  /// Sits inside the ring — a glyph on habit cards, a dot on onboarding.
  final Widget? child;

  final bool animate;
  final Duration duration;
  final bool showTrack;

  @override
  Widget build(BuildContext context) {
    final target = progress.clamp(0.0, 1.0);

    if (!animate) {
      return _paint(target);
    }

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: target),
      duration: duration,
      curve: TideMotion.overshoot,
      builder: (context, value, _) => _paint(value),
    );
  }

  Widget _paint(double value) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _TideRingPainter(
          progress: value,
          strokeWidth: strokeWidth,
          color: color ?? TideColors.lantern,
          trackColor:
              trackColor ??
              (showTrack
                  ? TideColors.silt.withValues(alpha: 0.18)
                  : Colors.transparent),
        ),
        child: child == null ? null : Center(child: child),
      ),
    );
  }
}

class _TideRingPainter extends CustomPainter {
  const _TideRingPainter({
    required this.progress,
    required this.strokeWidth,
    required this.color,
    required this.trackColor,
  });

  final double progress;
  final double strokeWidth;
  final Color color;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = trackColor;

    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = color;

    if (trackColor.a > 0) {
      canvas.drawCircle(center, radius, track);
    }

    if (progress <= 0) return;

    // The overshoot curve can push past 1.0 mid-flight; drawing more than a
    // full turn just retraces the circle, so cap the sweep.
    final sweep = math.min(progress, 1.0) * 2 * math.pi;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweep,
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(_TideRingPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.trackColor != trackColor ||
      old.strokeWidth != strokeWidth;
}

/// The ring drawing itself in from empty on load — the first thing the user
/// sees in onboarding, before any tap has happened.
class TideRingDrawIn extends StatefulWidget {
  const TideRingDrawIn({
    super.key,
    this.size = 160,
    this.strokeWidth = 4,
    this.child,
    this.delay = const Duration(milliseconds: 180),
  });

  final double size;
  final double strokeWidth;
  final Widget? child;
  final Duration delay;

  @override
  State<TideRingDrawIn> createState() => _TideRingDrawInState();
}

class _TideRingDrawInState extends State<TideRingDrawIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: TideMotion.ringDraw,
  );

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curve = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubic,
    );

    return AnimatedBuilder(
      animation: curve,
      builder: (context, _) {
        return TideRing(
          progress: curve.value,
          size: widget.size,
          strokeWidth: widget.strokeWidth,
          animate: false,
          showTrack: false,
          child: Opacity(
            opacity: Curves.easeIn.transform(curve.value.clamp(0.0, 1.0)),
            child: widget.child,
          ),
        );
      },
    );
  }
}

/// A slow breathing ring — the genuine empty state on Home, and the "still
/// waiting" texture rather than a blank page.
class TideRingBreathing extends StatefulWidget {
  const TideRingBreathing({
    super.key,
    this.size = 120,
    this.strokeWidth = 3,
    this.child,
  });

  final double size;
  final double strokeWidth;
  final Widget? child;

  @override
  State<TideRingBreathing> createState() => _TideRingBreathingState();
}

class _TideRingBreathingState extends State<TideRingBreathing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: TideMotion.breathe,
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = Curves.easeInOut.transform(_controller.value);
        return Transform.scale(
          scale: 0.94 + 0.06 * t,
          child: TideRing(
            progress: 1,
            size: widget.size,
            strokeWidth: widget.strokeWidth,
            animate: false,
            showTrack: false,
            color: TideColors.lantern.withValues(alpha: 0.25 + 0.35 * t),
            child: widget.child,
          ),
        );
      },
    );
  }
}
