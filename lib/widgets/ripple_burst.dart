import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/tide_colors.dart';
import '../theme/tide_motion.dart';

/// The reward animation, in one place.
///
/// The same ripple fires when a habit is logged, when an onboarding
/// template is picked, when a day toggle is switched on, and when an icon is
/// chosen — because in every one of those cases the user just *claimed*
/// something. Unlocking a milestone uses the same ripple scaled up with a
/// particle flourish, so the rare reward reads as more of the familiar
/// thing rather than as a different language.
///
/// Fires when [trigger] changes; keep an int in the parent and increment it.
class RippleBurst extends StatefulWidget {
  const RippleBurst({
    super.key,
    required this.child,
    required this.trigger,
    this.color,
    this.accent,
    this.particles = false,
    this.intensity = 1,
    this.origin = Alignment.center,
    this.duration,
    this.clip = true,
    this.borderRadius,
  });

  final Widget child;

  /// Increment to fire. A change of value is the event.
  final int trigger;

  /// The rings and the wash. Defaults to the accent.
  final Color? color;

  /// The trailing ring and half the particles. Defaults to the accent.
  final Color? accent;

  /// The milestone celebration adds a brief particle flourish on top.
  final bool particles;

  /// 1 is a daily habit ripple; the unlock burst runs around 2.
  final double intensity;

  final Alignment origin;
  final Duration? duration;

  /// Keeps the rings inside the widget they belong to.
  ///
  /// On by default, and it has to be: the rings run to 0.72 of the *longer*
  /// side, so on a wide, short surface like a habit row they reach far
  /// above and below it. Unclipped, logging one habit throws a circle
  /// across the whole list. Turn it off only where the spill is the effect
  /// — the milestone burst, which is centred on a full-screen scrim.
  final bool clip;

  /// Rounds the clip to match the surface underneath, so the wash stops at
  /// the card's corners rather than squaring them off.
  final BorderRadius? borderRadius;

  @override
  State<RippleBurst> createState() => _RippleBurstState();
}

class _RippleBurstState extends State<RippleBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration:
        widget.duration ??
        (widget.particles ? TideMotion.celebration : TideMotion.ripple),
  );

  late final List<_Particle> _particles = _seedParticles();

  @override
  void didUpdateWidget(RippleBurst old) {
    super.didUpdateWidget(old);
    if (old.trigger != widget.trigger) {
      _controller
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<_Particle> _seedParticles() {
    // Fixed angles rather than random ones, so the burst looks composed
    // rather than scattered, and identical every time it fires.
    final random = math.Random(7);
    return List<_Particle>.generate(14, (i) {
      final angle = (math.pi * 2 / 14) * i + random.nextDouble() * 0.3;
      return _Particle(
        angle: angle,
        distance: 0.55 + random.nextDouble() * 0.45,
        size: 1.6 + random.nextDouble() * 2.4,
        delay: random.nextDouble() * 0.18,
        foam: i.isEven,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      // passthrough, not the default loose fit: a Stack would otherwise let
      // the wrapped content shrink-wrap, which silently narrows every card
      // that has a ripple on it.
      fit: StackFit.passthrough,
      children: [
        widget.child,
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                if (_controller.isDismissed) {
                  return const SizedBox.shrink();
                }
                return CustomPaint(
                  painter: _RipplePainter(
                    t: _controller.value,
                    color: widget.color ?? TideColors.lantern,
                    accent: widget.accent ?? TideColors.lantern,
                    intensity: widget.intensity,
                    origin: widget.origin,
                    particles: widget.particles ? _particles : const [],
                    clip: widget.clip,
                    borderRadius: widget.borderRadius,
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _Particle {
  const _Particle({
    required this.angle,
    required this.distance,
    required this.size,
    required this.delay,
    required this.foam,
  });

  final double angle;
  final double distance;
  final double size;
  final double delay;

  /// Alternating kelp green and foam cyan, per the celebration spec.
  final bool foam;
}

class _RipplePainter extends CustomPainter {
  const _RipplePainter({
    required this.t,
    required this.color,
    required this.accent,
    required this.intensity,
    required this.origin,
    required this.particles,
    required this.clip,
    required this.borderRadius,
  });

  final double t;
  final Color color;
  final Color accent;
  final double intensity;
  final Alignment origin;
  final List<_Particle> particles;
  final bool clip;
  final BorderRadius? borderRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = origin.withinRect(rect);

    // Clipped here rather than by a ClipRRect around the child: wrapping
    // the child would crop the surface's drop shadow along with the rings.
    if (clip) {
      canvas.save();
      final radius = borderRadius;
      if (radius == null) {
        canvas.clipRect(rect);
      } else {
        canvas.clipRRect(radius.toRRect(rect));
      }
    }

    final maxRadius = math.max(size.width, size.height) * 0.72 * intensity;

    // Two rings, the second trailing the first — the water reading of a
    // single event, not two events.
    for (var ring = 0; ring < 2; ring++) {
      final offset = ring * 0.16;
      final local = ((t - offset) / (1 - offset)).clamp(0.0, 1.0);
      if (local <= 0) continue;

      final eased = Curves.easeOutCubic.transform(local);
      final radius = maxRadius * eased;
      final opacity = (1 - eased) * (ring == 0 ? 0.55 : 0.3);

      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = (2.5 - ring) * intensity
          ..color = (ring == 0 ? color : accent).withValues(alpha: opacity),
      );
    }

    // A soft wash inside the leading ring.
    final wash = Curves.easeOut.transform(t.clamp(0.0, 1.0));
    canvas.drawCircle(
      center,
      maxRadius * wash * 0.9,
      Paint()..color = color.withValues(alpha: 0.18 * (1 - wash)),
    );

    for (final particle in particles) {
      final local = ((t - particle.delay) / (1 - particle.delay)).clamp(
        0.0,
        1.0,
      );
      if (local <= 0) continue;

      final eased = Curves.easeOutCubic.transform(local);
      final travel = maxRadius * particle.distance * eased;
      final position =
          center +
          Offset(
            math.cos(particle.angle) * travel,
            math.sin(particle.angle) * travel,
          );

      canvas.drawCircle(
        position,
        particle.size * (1 - eased * 0.5),
        Paint()
          ..color = (particle.foam ? accent : color).withValues(
            alpha: (1 - eased).clamp(0.0, 1.0),
          ),
      );
    }

    if (clip) canvas.restore();
  }

  @override
  bool shouldRepaint(_RipplePainter old) =>
      old.t != t ||
      old.color != color ||
      old.accent != accent ||
      old.clip != clip ||
      old.borderRadius != borderRadius;
}
