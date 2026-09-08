import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../services/models/milestone.dart';
import '../../../theme/tide_colors.dart';
import '../../../theme/tide_typography.dart';
import '../../../widgets/habit_glyph.dart';

/// The rarest moment in the app, and it has to look like it.
///
/// It used to be the ripple burst with its intensity turned up — literally
/// the same animation the app plays when you tick off a glass of water,
/// only bigger. That was the wrong instinct dressed as consistency. A daily
/// reward and a sixty-day one that differ only in scale do not read as one
/// language at two volumes; they read as the app having only one idea, and
/// the rare thing loses by being compared to the common one every day.
///
/// So a milestone gets its own motion, and it is the metaphor the whole
/// product is named after: something *surfacing*. A waterline sweeps up
/// through the badge, motes rise past it, and a crown of light opens
/// outward — spokes, not rings, because rings are what a logged habit does.
class UnlockCelebration extends StatefulWidget {
  const UnlockCelebration({
    super.key,
    required this.milestone,
    required this.onDismiss,
  });

  final Milestone milestone;
  final VoidCallback onDismiss;

  @override
  State<UnlockCelebration> createState() => _UnlockCelebrationState();
}

class _UnlockCelebrationState extends State<UnlockCelebration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _total,
  )..forward();

  /// Longer than the daily panel. A milestone happens a handful of times a
  /// year and is allowed to take a breath; the daily one is on screen most
  /// days and is not.
  static const Duration _total = Duration(milliseconds: 2300);

  /// Where the badge is fully arrived and the copy has settled.
  static const double _settled = 0.42;

  /// Where the whole thing starts leaving.
  static const double _exit = 0.84;

  @override
  void initState() {
    super.initState();
    HapticFeedback.heavyImpact();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) widget.onDismiss();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final t = _controller.value;

            final presence = t < 0.12
                ? Curves.easeOut.transform(t / 0.12)
                : t < _exit
                ? 1.0
                : 1 - Curves.easeIn.transform((t - _exit) / (1 - _exit));

            // The badge rises into place and stops. Everything after that
            // is the light around it, which is what keeps the eye on the
            // mark rather than on the effect.
            final arrival = Curves.easeOutCubic.transform(
              (t / _settled).clamp(0.0, 1.0),
            );

            final copy = Curves.easeOut.transform(
              ((t - 0.26) / 0.24).clamp(0.0, 1.0),
            );

            return Stack(
              children: [
                Positioned.fill(
                  child: ColoredBox(
                    color: TideColors.deepWater.withValues(
                      alpha: 0.94 * presence,
                    ),
                  ),
                ),
                Center(
                  child: Opacity(
                    opacity: presence,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 260,
                          height: 260,
                          child: CustomPaint(
                            painter: _SurfacingPainter(t: t),
                            child: Center(
                              child: Transform.translate(
                                offset: Offset(0, (1 - arrival) * 34),
                                child: Transform.scale(
                                  scale: 0.72 + 0.28 * arrival,
                                  child: _Badge(
                                    milestone: widget.milestone,
                                    shimmer: t,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Opacity(
                          opacity: copy,
                          child: Transform.translate(
                            offset: Offset(0, (1 - copy) * 10),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  widget.milestone.name,
                                  style: TideType.screenTitle.copyWith(
                                    color: TideColors.lantern,
                                    fontSize: 30,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Surfaced at ${widget.milestone.caption}',
                                  style: TideType.labelMuted,
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// The badge itself: the milestone's mark inside a lit disc.
class _Badge extends StatelessWidget {
  const _Badge({required this.milestone, required this.shimmer});

  final Milestone milestone;

  /// 0..1 across the whole animation, used to sweep a highlight across the
  /// disc once as it settles.
  final double shimmer;

  @override
  Widget build(BuildContext context) {
    final sweep = Curves.easeInOut.transform(
      ((shimmer - 0.30) / 0.34).clamp(0.0, 1.0),
    );

    return Container(
      width: 124,
      height: 124,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: TideColors.lantern.withValues(alpha: 0.85),
          width: 2,
        ),
        // A gradient rather than a flat fill plus a gradient: BoxDecoration
        // silently drops the colour when both are set, so the base tint is
        // baked into the stops instead.
        gradient: LinearGradient(
          begin: Alignment(-1 + sweep * 2, -1),
          end: Alignment(sweep * 2, 1),
          colors: [
            TideColors.lantern.withValues(alpha: 0.10),
            TideColors.lantern.withValues(alpha: 0.10 + 0.20 * (1 - sweep)),
            TideColors.lantern.withValues(alpha: 0.10),
          ],
        ),
      ),
      child: HabitGlyph(
        glyph: milestone.glyph,
        size: 58,
        color: TideColors.lantern,
        strokeWidth: 2.4,
      ),
    );
  }
}

/// The light around the badge: a waterline crossing it, motes rising past
/// it, and a crown of spokes opening outward.
///
/// Deliberately not concentric rings. Rings are the daily reward's whole
/// vocabulary, and if a milestone draws rings then a milestone is a large
/// habit log, which is the one thing it must not feel like.
class _SurfacingPainter extends CustomPainter {
  const _SurfacingPainter({required this.t});

  /// 0..1 across the whole celebration.
  final double t;

  static const int _spokes = 20;
  static const int _motes = 16;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final reach = size.width / 2;

    _paintWaterline(canvas, size, centre, reach);
    _paintCrown(canvas, centre, reach);
    _paintMotes(canvas, size, centre);
  }

  /// A bright horizontal line sweeping up through the badge — the surface
  /// of the water, passing the mark as it comes up through it.
  void _paintWaterline(Canvas canvas, Size size, Offset centre, double reach) {
    final progress = Curves.easeOutCubic.transform(
      (t / 0.40).clamp(0.0, 1.0),
    );
    if (progress <= 0 || progress >= 1) return;

    final y = size.height * (1 - progress);
    final fade = math.sin(progress * math.pi);
    final half = reach * (0.35 + 0.65 * fade);

    canvas.drawLine(
      Offset(centre.dx - half, y),
      Offset(centre.dx + half, y),
      Paint()
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round
        ..shader = LinearGradient(
          colors: [
            TideColors.lantern.withValues(alpha: 0),
            TideColors.lantern.withValues(alpha: 0.75 * fade),
            TideColors.lantern.withValues(alpha: 0),
          ],
        ).createShader(
          Rect.fromLTWH(centre.dx - half, y - 1, half * 2, 2),
        ),
    );
  }

  /// Spokes opening outward from the badge and fading — light leaving the
  /// mark, rather than a wave arriving at it.
  void _paintCrown(Canvas canvas, Offset centre, double reach) {
    final open = Curves.easeOutCubic.transform(
      ((t - 0.16) / 0.46).clamp(0.0, 1.0),
    );
    if (open <= 0) return;

    final fade = 1 - Curves.easeIn.transform(open);
    if (fade <= 0.01) return;

    // A slow quarter-turn while they open, so the crown reads as light
    // moving rather than as a fixed asterisk being scaled up.
    final spin = open * 0.22;

    for (var i = 0; i < _spokes; i++) {
      final long = i.isEven;
      final angle = (math.pi * 2 / _spokes) * i + spin;
      final inner = 68 + 22 * open;
      final outer = inner + (long ? 34 : 18) * open;
      if (outer > reach) continue;

      final direction = Offset(math.cos(angle), math.sin(angle));
      canvas.drawLine(
        centre + direction * inner,
        centre + direction * outer,
        Paint()
          ..strokeWidth = long ? 2 : 1.2
          ..strokeCap = StrokeCap.round
          ..color = TideColors.lantern.withValues(
            alpha: (long ? 0.5 : 0.28) * fade,
          ),
      );
    }
  }

  /// Motes rising past the badge, the way anything does when it breaks the
  /// surface. Seeded off the index so they are stable frame to frame
  /// without carrying any state.
  void _paintMotes(Canvas canvas, Size size, Offset centre) {
    final run = ((t - 0.10) / 0.72).clamp(0.0, 1.0);
    if (run <= 0 || run >= 1) return;

    for (var i = 0; i < _motes; i++) {
      final seed = (i * 37) % 100 / 100;
      final phase = (run * (0.7 + seed * 0.5)).clamp(0.0, 1.0);
      if (phase <= 0) continue;

      final spread = (seed - 0.5) * size.width * 0.9;
      final drift = math.sin(phase * math.pi * 2 + i) * 6;
      final y = size.height * (1 - phase) + size.height * 0.1;
      final radius = 1.2 + seed * 1.8;
      final fade = math.sin(phase * math.pi);

      canvas.drawCircle(
        Offset(centre.dx + spread + drift, y),
        radius,
        Paint()
          ..color = TideColors.lantern.withValues(alpha: 0.5 * fade),
      );
    }
  }

  @override
  bool shouldRepaint(_SurfacingPainter old) => old.t != t;
}
