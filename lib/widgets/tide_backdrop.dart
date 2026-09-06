import 'package:flutter/material.dart';

import '../theme/tide_colors.dart';
import '../theme/tide_gradients.dart';
import '../theme/tide_motion.dart';
import 'grain_overlay.dart';

/// The page ground for every screen: flat deep water, plus grain.
///
/// Flat is deliberate and it is load-bearing. Habit rows paint themselves in
/// the page colour so they vanish at rest and still travel opaquely over the
/// swipe backdrop when dragged — the moment the ground has a ramp or a bloom
/// in it, those rows stop matching and read as a lighter slab down the
/// middle of the screen.
///
/// [drift] turns on the one bloom of warm light, for onboarding only: the
/// screen with no rows to mismatch and no history to show, where a still
/// ground reads as a page that has not finished loading.
class TideBackdrop extends StatefulWidget {
  const TideBackdrop({super.key, this.drift = false, this.grain = true});

  /// Whether the ground carries drifting light. Onboarding only.
  ///
  /// Off everywhere else: the app's rule is that motion has to be caused by
  /// something the user did.
  final bool drift;

  final bool grain;

  @override
  State<TideBackdrop> createState() => _TideBackdropState();
}

class _TideBackdropState extends State<TideBackdrop>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;

  @override
  void initState() {
    super.initState();
    if (widget.drift) _start();
  }

  @override
  void didUpdateWidget(TideBackdrop old) {
    super.didUpdateWidget(old);
    if (widget.drift == old.drift) return;
    if (widget.drift) {
      _start();
    } else {
      _controller?.dispose();
      _controller = null;
    }
  }

  void _start() {
    _controller = AnimationController(
      vsync: this,
      duration: TideMotion.ambientDrift,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    // A still backdrop is one flat rect and is cached; only the drifting
    // one rebuilds per frame, and even then it is a single gradient.
    final ground = controller == null
        ? const ColoredBox(color: TideColors.deepWater, child: SizedBox.expand())
        : AnimatedBuilder(
            animation: controller,
            builder: (context, _) => _Ground(phase: controller.value),
          );

    return IgnorePointer(
      child: RepaintBoundary(
        child: Stack(
          fit: StackFit.expand,
          children: [ground, if (widget.grain) const GrainOverlay()],
        ),
      ),
    );
  }
}

class _Ground extends StatelessWidget {
  const _Ground({required this.phase});

  final double phase;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _GroundPainter(phase), size: Size.infinite);
  }
}

class _GroundPainter extends CustomPainter {
  const _GroundPainter(this.phase);

  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final rect = Offset.zero & size;

    void wash(Gradient gradient) {
      canvas.drawRect(rect, Paint()..shader = gradient.createShader(rect));
    }

    canvas.drawRect(rect, Paint()..color = TideColors.deepWater);
    // The bloom is laid in the same rect rather than its own bounds, so an
    // alignment past ±1 genuinely parks the core off-screen.
    TideGradients.pageBlooms(phase).forEach(wash);
  }

  @override
  bool shouldRepaint(_GroundPainter old) => old.phase != phase;
}

/// The dissolve under the status bar.
///
/// Every screen in Tide is edge-to-edge and scrolls its own header, so
/// without this a title travels straight up into the system clock and the
/// two render on top of each other. The fix is not a solid bar — that would
/// cut the page in half and undo the ground — but a short fade in the page
/// ground's own top colour, so content thins out as it leaves rather than
/// colliding with the OS.
class TideTopScrim extends StatelessWidget {
  const TideTopScrim({super.key});

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.viewPaddingOf(context).top;
    const ground = TideColors.deepWater;

    return IgnorePointer(
      child: SizedBox(
        height: inset + 14,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [ground, ground, ground.withValues(alpha: 0)],
              // Solid across the inset itself, then a short tail — long
              // enough to read as a fade, short enough that it never eats
              // into a header sitting at its resting position.
              stops: const [0, 0.62, 1],
            ),
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}
