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

  /// Opens the add-habit screen. Handed down rather than looked up: the
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
            // Above the router means above the Navigator, and above the
            // Navigator there is no Material and therefore no
            // DefaultTextStyle — every Text falls back to WidgetsApp's error
            // style and merges its underline into whatever TideType asked
            // for. That is why the first build of this had a rule under
            // every line of the caption. One inherited style at the root of
            // the overlay fixes all of them, including the shared demo's.
            child: DefaultTextStyle(
              style: TideType.body,
              child: TourOverlay(
                onFinish: store.finishTour,
                onAddHabit: () {
                  store.finishTour();
                  onAddHabit();
                },
              ),
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
/// Three things were wrong with the first version of this, and all three
/// were the same mistake — everything animating at once, in one tree.
///
/// The step's text swapped through an `AnimatedSwitcher` *while* the light
/// was still travelling and the panel was still resizing, so three
/// animations of three different lengths overlapped and the caption
/// visibly rubber-banded. The panel was also laid out against the *moving*
/// hole, which relaid the whole caption — text, gauge, and on one step a
/// running demo — every single frame of the travel. And the ambient rim
/// pulse was merged into the same `AnimatedBuilder` as the caption, so that
/// entire subtree rebuilt sixty times a second for the whole tour, whether
/// anything was moving or not.
///
/// Now: the caption fades out, the light travels alone, the caption fades
/// back in at its new home. Nothing crossfades against anything, the
/// caption is laid out once per step against the light's *destination*, and
/// the pulse drives one small painter behind its own repaint boundary and
/// nothing else.
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
    duration: _travelTime,
  );

  /// The caption's presence. Driven to 0 before a step change and back to 1
  /// once the light is on its way, so the panel is never legible while it
  /// is somewhere it should not be.
  late final AnimationController _presence = AnimationController(
    vsync: this,
    duration: _captionIn,
    reverseDuration: _captionOut,
  );

  /// The ring breathing around the hole. Ambient, and earned: the tour is a
  /// held moment where the app is talking, and the pulse is what keeps the
  /// eye on the target while the caption is being read.
  late final AnimationController _rim = AnimationController(
    vsync: this,
    duration: TideMotion.breathe,
  )..repeat(reverse: true);

  late final Animation<double> _fade = CurvedAnimation(
    parent: _presence,
    curve: Curves.easeOut,
    reverseCurve: Curves.easeIn,
  );

  late final Animation<Offset> _rise =
      Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero).animate(
        CurvedAnimation(parent: _presence, curve: TideMotion.sheetCurve),
      );

  int _step = 0;

  Rect? _from;
  Rect? _to;
  double _fromRadius = 0;
  double _toRadius = 0;

  /// A step change is in flight. Blocks the scrim's tap-to-advance, so a
  /// second tap cannot start a second hand-off over the top of the first —
  /// which is what made the light stutter when the panel was tapped
  /// through impatiently.
  bool _moving = false;

  /// The opening step has found its target and the caption has been let in.
  bool _opened = false;

  /// Frames spent waiting for an anchor to turn up.
  int _waited = 0;

  /// Long enough to cover Home's own entrance, short enough that a genuinely
  /// missing anchor does not hold the tour hostage.
  static const int _maxWait = 40;

  /// Let Today paint and settle before the light contracts onto it. The
  /// first thing a new account sees should be their empty Today, not a
  /// scrim over a screen they never got to look at.
  static const Duration _settle = Duration(milliseconds: 520);

  /// The light's flight, and the caption's two halves. The caption leaves
  /// faster than it arrives — an exit that lingers reads as hesitation,
  /// where an arrival that lingers reads as arrival.
  static const Duration _travelTime = Duration(milliseconds: 480);
  static const Duration _captionOut = Duration(milliseconds: 150);
  static const Duration _captionIn = Duration(milliseconds: 260);

  /// How far into the light's flight the caption starts coming back. Enough
  /// that the eye has followed the light off the old target first.
  static const Duration _captionDelay = Duration(milliseconds: 130);

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
    _presence.dispose();
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
      _open();
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
    _open();
  }

  /// Lets the caption in, once, on the opening step. Later steps are driven
  /// by [_advance], which sequences the fade against the travel itself.
  void _open() {
    if (_opened) return;
    _opened = true;
    _presence.forward();
  }

  /// Where the light starts on the very first step: bigger than the screen,
  /// so the tour opens by *closing in* on the header rather than by
  /// dropping a black sheet over everything.
  Rect _opening() =>
      (Offset.zero & MediaQuery.sizeOf(context)).inflate(_openingSpread);

  static const double _openingSpread = 140;

  /// One step to the next, as a sequence rather than a pile.
  Future<void> _advance() async {
    if (_moving) return;
    if (_isLast) {
      widget.onFinish();
      return;
    }

    _moving = true;
    await _presence.reverse();
    if (!mounted) return;

    setState(() => _step++);
    _resolve();

    await Future<void>.delayed(_captionDelay);
    if (!mounted) return;
    await _presence.forward();
    _moving = false;
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);

    return Stack(
      children: [
        // The scrim takes every tap: the screen underneath is being
        // explained, not operated, and a stray tap landing on a real
        // control mid-tour is how a guided flow loses its place.
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _advance,
            child: _Spotlight(
              travel: _travel,
              rim: _rim,
              from: _from,
              to: _to,
              fromRadius: _fromRadius,
              toRadius: _toRadius,
            ),
          ),
        ),

        // Laid out against the light's *destination*, not against where it
        // happens to be this frame. The panel therefore lays out once per
        // step instead of once per frame, and it is invisible for the whole
        // of the move anyway.
        Positioned.fill(
          child: CustomSingleChildLayout(
            delegate: _CaptionLayout(hole: _to, padding: padding),
            child: FadeTransition(
              opacity: _fade,
              child: SlideTransition(
                position: _rise,
                // A faded-out panel still hit-tests, and "Skip tour" is
                // under the caller's thumb during the hand-off. Nothing in
                // here takes a tap until it is legible again.
                child: AnimatedBuilder(
                  animation: _presence,
                  child: _caption(),
                  builder: (context, child) => IgnorePointer(
                    ignoring: _presence.value < 0.5,
                    child: child,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _caption() {
    return TideSurface(
      key: ValueKey(_step),
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
          Text(_current.title, style: TideType.hero),
          const SizedBox(height: 8),
          Text(_current.body, style: TideType.bodyMuted),
          if (_current.demo == TourDemo.swipe) ...[
            const SizedBox(height: 20),
            const SwipeLoopDemo(name: 'Evening walk', streak: 4),
          ],
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

/// The scrim with the hole in it, and the ring breathing around the hole.
///
/// Two painters, not one, and each behind its own repaint boundary. The
/// scrim costs a full-screen path difference and only changes while the
/// light is travelling; the ring is a single stroked rectangle and changes
/// every frame forever. Painting them together meant paying the first
/// price at the second rate for the entire length of the tour.
class _Spotlight extends StatelessWidget {
  const _Spotlight({
    required this.travel,
    required this.rim,
    required this.from,
    required this.to,
    required this.fromRadius,
    required this.toRadius,
  });

  final Animation<double> travel;
  final Animation<double> rim;
  final Rect? from;
  final Rect? to;
  final double fromRadius;
  final double toRadius;

  /// The hole at [t] of the current flight.
  (Rect, double) _holeAt(double t) {
    final target = to;
    if (target == null) return (Rect.zero, 0);
    final start = from;
    if (start == null) return (target, toRadius);

    final eased = TideMotion.morphCurve.transform(t);
    return (
      Rect.lerp(start, target, eased)!,
      fromRadius + (toRadius - fromRadius) * eased,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: AnimatedBuilder(
              animation: travel,
              builder: (context, _) {
                final (hole, radius) = _holeAt(travel.value);
                return CustomPaint(
                  painter: _ScrimPainter(
                    hole: hole,
                    radius: radius,
                    scrim: TideColors.scrim,
                  ),
                  size: Size.infinite,
                );
              },
            ),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: Listenable.merge([travel, rim]),
                builder: (context, _) {
                  final (hole, radius) = _holeAt(travel.value);
                  return CustomPaint(
                    painter: _RimPainter(
                      hole: hole,
                      radius: radius,
                      pulse: Curves.easeInOut.transform(rim.value),
                    ),
                    size: Size.infinite,
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Places the caption beside the light without ever covering it.
///
/// A delegate rather than a stack of aligned boxes, because the decision
/// needs the caption's own measured height: whether there is room below the
/// hole is not answerable until the panel — which changes height between
/// steps — has been laid out.
class _CaptionLayout extends SingleChildLayoutDelegate {
  const _CaptionLayout({required this.hole, required this.padding});

  /// The light's destination. Null on a step whose target could not be
  /// found; the caption then takes the middle of the screen.
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

    if (target == null || target.isEmpty) {
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

/// The dark, and the hole cut in it.
class _ScrimPainter extends CustomPainter {
  const _ScrimPainter({
    required this.hole,
    required this.radius,
    required this.scrim,
  });

  final Rect hole;
  final double radius;
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
  }

  @override
  bool shouldRepaint(_ScrimPainter old) =>
      old.hole != hole || old.radius != radius;
}

/// The lit edge of the hole, and the ring pushing out from it.
class _RimPainter extends CustomPainter {
  const _RimPainter({
    required this.hole,
    required this.radius,
    required this.pulse,
  });

  final Rect hole;
  final double radius;

  /// 0..1, breathing.
  final double pulse;

  @override
  void paint(Canvas canvas, Size size) {
    if (hole.isEmpty) return;

    final cut = RRect.fromRectAndRadius(hole, Radius.circular(radius));

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
  bool shouldRepaint(_RimPainter old) =>
      old.hole != hole || old.radius != radius || old.pulse != pulse;
}
