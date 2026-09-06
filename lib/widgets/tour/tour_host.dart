import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../config/tour_catalog.dart';
import '../../services/tide_scope.dart';
import '../../theme/tide_colors.dart';
import '../../theme/tide_motion.dart';
import '../../theme/tide_typography.dart';
import '../demo/loop_demos.dart';
import '../press_scale.dart';
import '../tide_button.dart';
import '../tide_line_gauge.dart';
import '../tide_surface.dart';
import 'tour_anchor.dart';

/// Keeps the guided tour above routes, sheets and tabs.
///
/// Mounted beside [CelebrationHost] rather than inside a screen, for the
/// same reason: the tour points at the tab bar, which lives in the
/// `Scaffold`'s bottom slot and is not inside any tab's body. An overlay
/// mounted under the shell could light the header and the hero and then
/// have nothing to say about the four destinations, which are half of what
/// a new user needs told.
class TourHost extends StatelessWidget {
  const TourHost({super.key, required this.child, required this.onAddHabit});

  final Widget child;

  /// Opens the add-habit sheet. Handed down rather than looked up: the
  /// router is not in scope above `MaterialApp.router`'s own builder.
  final VoidCallback onAddHabit;

  @override
  Widget build(BuildContext context) {
    final store = TideScope.of(context);

    return Stack(
      children: [
        child,
        if (store.tourPending)
          Positioned.fill(
            child: TourOverlay(
              onFinish: store.finishTour,
              onAddHabit: () {
                store.finishTour();
                onAddHabit();
              },
            ),
          ),
      ],
    );
  }
}

/// The travelling spotlight.
///
/// One hole in one scrim, moving between targets — not a scrim that fades
/// out and a different scrim that fades in. That distinction is the whole
/// design: a light that travels tells the user the tour is walking them
/// around a single screen, where a sequence of dissolves would read as five
/// modal cards that happen to have holes in them, and they would stop
/// looking at what is underneath.
///
/// The caption rides with the light for the same reason, and re-lays itself
/// above or below the hole depending on which side has room, so the panel
/// never covers the thing it is describing.
class TourOverlay extends StatefulWidget {
  const TourOverlay({
    super.key,
    required this.onFinish,
    required this.onAddHabit,
  });

  final VoidCallback onFinish;
  final VoidCallback onAddHabit;

  @override
  State<TourOverlay> createState() => _TourOverlayState();
}

class _TourOverlayState extends State<TourOverlay>
    with TickerProviderStateMixin {
  /// The light moving from one target to the next.
  late final AnimationController _travel = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 560),
  );

  /// The caption arriving, once — subsequent steps slide rather than fade.
  late final AnimationController _enter = AnimationController(
    vsync: this,
    duration: TideMotion.sheetIn,
  );

  /// The ring breathing around the hole. Ambient, and earned: the tour is a
  /// held moment where the app is talking, and the pulse is what keeps the
  /// eye on the target while the caption is being read.
  late final AnimationController _rim = AnimationController(
    vsync: this,
    duration: TideMotion.breathe,
  )..repeat(reverse: true);

  int _step = 0;

  Rect? _from;
  Rect? _to;
  double _fromRadius = 0;
  double _toRadius = 0;

  /// Frames spent waiting for an anchor to turn up.
  int _waited = 0;

  /// Long enough to cover Home's own entrance, short enough that a genuinely
  /// missing anchor does not hold the tour hostage.
  static const int _maxWait = 40;

  /// Let Today paint and settle before the light contracts onto it. The
  /// first thing a new account sees should be their empty Today, not a
  /// scrim over a screen they never got to look at.
  static const Duration _settle = Duration(milliseconds: 520);

  List<TourStep> get _steps => TourCatalog.steps;

  TourStep get _current => _steps[_step];

  bool get _isLast => _step == _steps.length - 1;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(_settle, () {
      if (mounted) _resolve();
    });
  }

  @override
  void dispose() {
    _travel.dispose();
    _enter.dispose();
    _rim.dispose();
    super.dispose();
  }

  /// Measures the current step's target and starts the light travelling.
  ///
  /// Retries frame by frame while the anchor is missing. It genuinely can
  /// be: the tour is armed by sign-up and mounts in the same frame Today is
  /// first built, so on the opening step the widget being measured may not
  /// have been laid out yet.
  void _resolve() {
    if (!mounted) return;

    final registry = TourAnchorScope.maybeOf(context);
    final rect = registry?.rectOf(_current.stop);

    if (rect == null) {
      if (_waited++ < _maxWait) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _resolve());
        return;
      }
      // Nothing to point at. Better a caption with no light than a tour
      // that silently never appears — the words are the part that matters.
      setState(() {
        _from = _to;
        _to = null;
      });
      _enter.forward();
      return;
    }

    _waited = 0;
    setState(() {
      _from = _to ?? _opening();
      _fromRadius = _to == null ? 0 : _toRadius;
      _to = rect.inflate(_current.inset);
      _toRadius = _current.radius;
    });
    _travel
      ..reset()
      ..forward();
    _enter.forward();
  }

  /// Where the light starts on the very first step: bigger than the screen,
  /// so the tour opens by *closing in* on the header rather than by
  /// dropping a black sheet over everything.
  Rect _opening() =>
      (Offset.zero & MediaQuery.sizeOf(context)).inflate(_openingSpread);

  static const double _openingSpread = 140;

  void _advance() {
    if (_isLast) {
      widget.onFinish();
      return;
    }
    setState(() => _step++);
    _resolve();
  }

  /// The hole this frame.
  (Rect, double) get _hole {
    final to = _to;
    if (to == null) return (Rect.zero, 0);
    final from = _from;
    if (from == null) return (to, _toRadius);

    final t = TideMotion.morphCurve.transform(_travel.value);
    return (
      Rect.lerp(from, to, t)!,
      _fromRadius + (_toRadius - _fromRadius) * t,
    );
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);

    return AnimatedBuilder(
      animation: Listenable.merge([_travel, _enter, _rim]),
      builder: (context, _) {
        final (hole, radius) = _hole;
        final pulse = Curves.easeInOut.transform(_rim.value);

        return Stack(
          children: [
            // The scrim takes every tap: the screen underneath is being
            // explained, not operated, and a stray tap landing on a real
            // control mid-tour is how a guided flow loses its place.
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _advance,
                child: CustomPaint(
                  painter: _SpotlightPainter(
                    hole: hole,
                    radius: radius,
                    pulse: pulse,
                    scrim: TideColors.scrim,
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                ignoring: _enter.value < 0.5,
                child: Opacity(
                  opacity: Curves.easeOut.transform(_enter.value),
                  child: CustomSingleChildLayout(
                    delegate: _CaptionLayout(
                      hole: hole.isEmpty ? null : hole,
                      padding: padding,
                    ),
                    child: _caption(),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _caption() {
    return TideSurface(
      color: TideColors.shoal,
      floating: true,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(width: 54, child: TideLineGauge(progress: _progress)),
              const SizedBox(width: 12),
              Text(
                '${_step + 1} of ${_steps.length}',
                style: TideType.labelMuted,
              ),
            ],
          ),
          const SizedBox(height: 16),
          // The panel resizes into the next step rather than snapping,
          // which matters because the step carrying the demo is twice the
          // height of the ones that do not.
          AnimatedSize(
            duration: TideMotion.sheetIn,
            curve: TideMotion.sheetCurve,
            alignment: Alignment.topLeft,
            child: AnimatedSwitcher(
              duration: TideMotion.tabSwitch,
              child: Column(
                key: ValueKey(_step),
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_current.title, style: TideType.hero),
                  const SizedBox(height: 8),
                  Text(_current.body, style: TideType.bodyMuted),
                  if (_current.demo == TourDemo.swipe) ...[
                    const SizedBox(height: 20),
                    const SwipeLoopDemo(name: 'Evening walk', streak: 4),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              PressScale(
                onTap: widget.onFinish,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 10,
                  ),
                  child: Text('Skip tour', style: TideType.labelMuted),
                ),
              ),
              const Spacer(),
              TideButton(
                label: _isLast ? 'Add a habit' : 'Next',
                expand: false,
                onPressed: _isLast ? widget.onAddHabit : _advance,
              ),
            ],
          ),
        ],
      ),
    );
  }

  double get _progress => (_step + 1) / _steps.length;
}

/// Places the caption beside the light without ever covering it.
///
/// A delegate rather than a stack of aligned boxes, because the decision
/// needs the caption's own measured height: whether there is room below the
/// hole is not answerable until the panel — which changes height between
/// steps — has been laid out.
class _CaptionLayout extends SingleChildLayoutDelegate {
  const _CaptionLayout({required this.hole, required this.padding});

  /// Null on a step whose target could not be found; the caption then takes
  /// the middle of the screen.
  final Rect? hole;

  final EdgeInsets padding;

  /// Air between the lit target and the panel describing it.
  static const double _gap = 18;

  /// Off the screen edges.
  static const double _margin = 20;

  /// Wider than this and the body text runs past a comfortable measure.
  static const double _maxWidth = 420;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    return BoxConstraints(
      maxWidth: math.min(constraints.maxWidth - _margin * 2, _maxWidth),
      maxHeight: constraints.maxHeight - padding.vertical - _margin * 2,
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final top = padding.top + _margin;
    final bottom = size.height - padding.bottom - _margin - childSize.height;
    final x = (size.width - childSize.width) / 2;
    final target = hole;

    if (target == null) {
      return Offset(x, (size.height - childSize.height) / 2);
    }

    // Below by preference — reading downward from the thing being named is
    // the direction the eye is already going. Above only when the bottom of
    // the screen has run out, which is what happens on the tab-bar stop.
    final below = target.bottom + _gap;
    if (below <= bottom) return Offset(x, below);

    final above = target.top - _gap - childSize.height;
    if (above >= top) return Offset(x, above);

    // Neither side fits: sit in whichever gap is larger and let the caption
    // clamp. Only reachable on a very short window.
    final roomAbove = target.top - top;
    final roomBelow = size.height - padding.bottom - _margin - target.bottom;
    return Offset(x, roomAbove > roomBelow ? top : math.max(top, bottom));
  }

  @override
  bool shouldRelayout(_CaptionLayout old) =>
      old.hole != hole || old.padding != padding;
}

/// The scrim, the hole in it, and the ring breathing around the hole.
class _SpotlightPainter extends CustomPainter {
  const _SpotlightPainter({
    required this.hole,
    required this.radius,
    required this.pulse,
    required this.scrim,
  });

  final Rect hole;
  final double radius;

  /// 0..1, breathing.
  final double pulse;

  final Color scrim;

  @override
  void paint(Canvas canvas, Size size) {
    final full = Offset.zero & size;

    if (hole.isEmpty) {
      canvas.drawRect(full, Paint()..color = scrim);
      return;
    }

    final cut = RRect.fromRectAndRadius(hole, Radius.circular(radius));
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(full),
        Path()..addRRect(cut),
      ),
      Paint()..color = scrim,
    );

    // A hairline on the cut itself, so the target has an edge even where it
    // is the same colour as the page behind the scrim.
    canvas.drawRRect(
      cut,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = TideColors.lantern.withValues(alpha: 0.34),
    );

    // And one ring pushing out from it and fading — the light landing,
    // repeatedly, rather than a static outline.
    final spread = 3 + 10 * pulse;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        hole.inflate(spread),
        Radius.circular(radius + spread),
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = TideColors.lantern.withValues(alpha: 0.24 * (1 - pulse)),
    );
  }

  @override
  bool shouldRepaint(_SpotlightPainter old) =>
      old.hole != hole || old.radius != radius || old.pulse != pulse;
}
