import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../config/app_constants.dart';
import '../../services/tide_scope.dart';
import '../../theme/tide_colors.dart';
import '../../theme/tide_gradients.dart';
import '../../theme/tide_motion.dart';
import '../../theme/tide_palette.dart';
import '../../theme/tide_typography.dart';
import '../../widgets/tide_logo.dart';

/// The first thing Tide shows: the logo assembling itself, then the name.
///
/// One continuous sequence on a single timeline, each part arriving because
/// the one before it made room:
///
/// 1. **Light.** A soft glow comes up where the mark will be, so the ring
///    draws into lit water rather than onto a black void.
/// 2. **The loop.** The ring draws clockwise from twelve.
/// 3. **The tide.** Water rises inside it — past its level, and back — the
///    same overshoot every filling thing in the app settles on.
/// 4. **The moon.** It pops above the water and a ripple runs outward from
///    the ring, the one moment of emphasis in the sequence.
/// 5. **The orbit.** A lit point leaves twelve o'clock exactly where the
///    ring's drawing head stopped, and keeps going.
/// 6. **The name.** "Tide" rises in with its letters closing up from wide
///    tracking, then the tagline under it.
///
/// It holds the finished mark for a beat and leaves by fading while the
/// mark pushes slightly toward you. The ground never changes colour between
/// the native launch window, this screen and the screen after it, so there
/// is no flash at either end. A tap anywhere skips straight to the exit: a
/// splash is a moment, not a gate.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.next});

  /// Where the app goes when the splash is done.
  final String next;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: TideMotion.splashIntro,
  );

  late final AnimationController _orbit = AnimationController(
    vsync: this,
    duration: TideMotion.orbit,
  );

  late final AnimationController _swell = AnimationController(
    vsync: this,
    duration: TideMotion.swell,
  )..repeat();

  late final AnimationController _exit = AnimationController(
    vsync: this,
    duration: TideMotion.splashExit,
  );

  static const double _markSize = 148;

  /// The fraction of the intro at which the ring closes and the orbit sets
  /// off from where it finished.
  static const double _ringCloses = 0.44;

  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    _intro.addListener(_startOrbit);
    WidgetsBinding.instance.addPostFrameCallback((_) => _play());
  }

  void _startOrbit() {
    if (_intro.value >= _ringCloses && !_orbit.isAnimating) _orbit.repeat();
  }

  Future<void> _play() async {
    if (!mounted) return;
    // With reduced motion the mark simply appears whole and the name with
    // it; the hold still lets it be seen before the app takes over.
    if (MediaQuery.disableAnimationsOf(context)) {
      _intro.value = 1;
    } else {
      await _intro.forward();
    }
    await Future<void>.delayed(TideMotion.splashHold);
    _leave();
  }

  void _leave() {
    if (_leaving || !mounted) return;
    _leaving = true;
    // The welcome step shows the same mark next. It arrives already whole,
    // because it was just drawn here.
    TideScope.read(context).splashPlayed = true;
    _exit.forward().whenComplete(() {
      if (mounted) context.go(widget.next);
    });
  }

  @override
  void dispose() {
    _intro
      ..removeListener(_startOrbit)
      ..dispose();
    _orbit.dispose();
    _swell.dispose();
    _exit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = TideColors.palette;

    return Scaffold(
      backgroundColor: TideColors.deepWater,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _leave,
        child: AnimatedBuilder(
          animation: Listenable.merge([_intro, _orbit, _swell, _exit]),
          builder: (context, _) {
            final t = _intro.value;
            double span(double from, double to, [Curve curve = Curves.linear]) =>
                curve.transform(((t - from) / (to - from)).clamp(0.0, 1.0));

            final leaving = Curves.easeInCubic.transform(_exit.value);
            final glow = span(0, 0.5, Curves.easeOut);
            final ripple = span(0.56, 1, Curves.easeOutCubic);
            final name = span(0.62, 0.9, Curves.easeOutCubic);
            final tagline = span(0.74, 1, Curves.easeOutCubic);

            final frame = TideLogoFrame(
              ring: span(0.04, _ringCloses, Curves.easeInOutCubic),
              tide: span(0.32, 0.72, TideMotion.overshoot),
              moon: span(0.54, 0.76, Curves.easeOutBack),
              orbit: span(_ringCloses, 0.58, Curves.easeOut),
              orbitPhase: _orbit.value,
              swell: _swell.value,
            );

            return Center(
              child: Opacity(
                opacity: 1 - leaving,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Transform.scale(
                      // Settles in from a touch small, and on the way out
                      // keeps going the same direction — one push toward
                      // you rather than an arrival and a separate departure.
                      scale: 0.92 + 0.08 * glow + 0.06 * leaving,
                      child: SizedBox.square(
                        dimension: _markSize,
                        child: CustomPaint(
                          painter: _Halo(
                            palette: palette,
                            glow: glow,
                            ripple: ripple,
                          ),
                          foregroundPainter: TideLogoPainter(
                            palette: palette,
                            frame: frame,
                            strokeWidth: 4.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 44),
                    Opacity(
                      opacity: name,
                      child: Transform.translate(
                        offset: Offset(0, 14 * (1 - name)),
                        child: Text(
                          AppConstants.appName,
                          style: TideType.screenTitle.copyWith(
                            fontSize: 44,
                            // The letters close up as the name arrives: wide
                            // and loose, then set.
                            letterSpacing: lerpDouble(10, -1.4, name),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Opacity(
                      opacity: tagline,
                      child: Transform.translate(
                        offset: Offset(0, 8 * (1 - tagline)),
                        child: Text(
                          AppConstants.tagline,
                          style: TideType.bodyMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// The light behind the mark and the ripple it sends out when the moon
/// lands. Painted past its own bounds on purpose — the glow is wider than
/// the mark, and a clipped glow is a disc.
class _Halo extends CustomPainter {
  const _Halo({
    required this.palette,
    required this.glow,
    required this.ripple,
  });

  final TidePalette palette;
  final double glow;
  final double ripple;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final radius = size.shortestSide / 2;

    if (glow > 0) {
      final reach = radius * 2.4;
      canvas.drawCircle(
        centre,
        reach,
        Paint()
          ..shader = TideGradients.bloom(
            color: palette.lantern,
            alpha: 0.2 * glow,
            center: Alignment.center,
            radius: 0.5,
          ).createShader(Rect.fromCircle(center: centre, radius: reach)),
      );
    }

    // Two rings leaving the mark, the second trailing the first — the same
    // reading of one event that a logged habit's ripple uses.
    for (final (delay, strength) in [(0.0, 0.38), (0.22, 0.22)]) {
      final p = ((ripple - delay) / (1 - delay)).clamp(0.0, 1.0);
      if (p <= 0 || p >= 1) continue;
      canvas.drawCircle(
        centre,
        radius * (1 + 0.95 * p),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = palette.lantern.withValues(alpha: strength * (1 - p)),
      );
    }
  }

  @override
  bool shouldRepaint(_Halo old) =>
      old.glow != glow ||
      old.ripple != ripple ||
      !identical(old.palette, palette);
}
