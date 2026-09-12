import 'package:flutter/material.dart';

import '../theme/tide_colors.dart';
import '../theme/tide_motion.dart';
import 'tide_logo.dart';

/// The brand mark, drawing itself in.
///
/// The ring closes, the tide comes in under it, the moon rises above the
/// water, and a lit point sets off round the ring from exactly where the
/// ring finished drawing — so the hand that drew the loop is the thing that
/// keeps going round it. A mark that finishes drawing and then stops is a
/// logo; one that keeps moving is the product's claim, that the loop does
/// not end, stated by the identity object rather than by the tagline.
///
/// It carries across screens: the splash plays the long version of this
/// entrance, the welcome step draws it, the closing step hands it off, and
/// the auth screen wears it small at the top. Same object each time, which
/// is what stops those from reading as different products.
class TideMark extends StatefulWidget {
  const TideMark({
    super.key,
    this.size = 164,
    this.strokeWidth = 4,
    this.coreSize,
    this.orbit = true,
    this.drawIn = true,
    this.delay = const Duration(milliseconds: 180),
  });

  final double size;
  final double strokeWidth;

  /// The moon's diameter. Defaults to a proportion of the ring.
  final double? coreSize;

  /// Whether the lit point runs the circumference once the ring is drawn.
  final bool orbit;

  /// Whether the mark draws itself in, or is simply already whole.
  ///
  /// Off wherever the mark is being *handed* from one screen to the next —
  /// including onto the welcome step straight after the splash has just
  /// drawn it. An object that redraws itself from an empty arc the moment
  /// it lands is plainly a second object.
  final bool drawIn;

  final Duration delay;

  @override
  State<TideMark> createState() => _TideMarkState();
}

class _TideMarkState extends State<TideMark> with TickerProviderStateMixin {
  late final AnimationController _draw = AnimationController(
    vsync: this,
    duration: TideMotion.markDraw,
  );

  late final AnimationController _orbit = AnimationController(
    vsync: this,
    duration: TideMotion.orbit,
  );

  late final AnimationController _swell = AnimationController(
    vsync: this,
    duration: TideMotion.swell,
  );

  /// The fraction of the draw at which the ring closes.
  static const double _ringCloses = 0.55;

  @override
  void initState() {
    super.initState();
    _draw.addListener(_startOrbit);
    if (!widget.drawIn) {
      _draw.value = 1;
      _swell.repeat();
      return;
    }
    Future<void>.delayed(widget.delay, () {
      if (!mounted) return;
      _draw.forward();
      _swell.repeat();
    });
  }

  /// The orbit starts the instant the ring closes, from twelve o'clock where
  /// the drawing head stopped, so the head becomes the point.
  void _startOrbit() {
    if (widget.orbit && _draw.value >= _ringCloses && !_orbit.isAnimating) {
      _orbit.repeat();
    }
  }

  @override
  void dispose() {
    _draw
      ..removeListener(_startOrbit)
      ..dispose();
    _orbit.dispose();
    _swell.dispose();
    super.dispose();
  }

  TideLogoFrame _frame() {
    final t = _draw.value;
    double span(double from, double to, Curve curve) =>
        curve.transform(((t - from) / (to - from)).clamp(0.0, 1.0));

    return TideLogoFrame(
      ring: span(0, _ringCloses, Curves.easeInOutCubic),
      tide: span(0.4, 0.85, TideMotion.overshoot),
      moon: span(0.62, 1, Curves.easeOutBack),
      orbit: widget.orbit ? span(_ringCloses, 0.7, Curves.easeOut) : 0,
      orbitPhase: _orbit.value,
      swell: _swell.value,
    );
  }

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context);

    return RepaintBoundary(
      child: SizedBox.square(
        dimension: widget.size,
        child: AnimatedBuilder(
          animation: Listenable.merge([_draw, _orbit, _swell]),
          builder: (context, _) => CustomPaint(
            painter: TideLogoPainter(
              palette: TideColors.palette,
              strokeWidth: widget.strokeWidth,
              moonRadius: widget.coreSize == null
                  ? null
                  : widget.coreSize! / 2,
              frame: still
                  ? TideLogoFrame(orbit: widget.orbit ? 1 : 0)
                  : _frame(),
            ),
          ),
        ),
      ),
    );
  }
}
