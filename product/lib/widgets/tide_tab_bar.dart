import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../config/app_constants.dart';
import '../theme/tide_colors.dart';
import '../theme/tide_elevation.dart';
import '../theme/tide_gradients.dart';
import '../theme/tide_motion.dart';
import '../theme/tide_typography.dart';
import 'press_scale.dart';

/// The bottom bar: a frosted panel floating clear of the screen edge.
///
/// It is glass rather than a solid bar because the page keeps scrolling
/// underneath it — habit rows blur as they pass behind, which is what tells
/// you the list continues rather than ending at the bar. That only works if
/// the body extends behind it, so [TideShell] sets `extendBody: true` and
/// every scrolling tab pads its content by [reservedHeight].
///
/// The selected tab holds a small pool of water behind its icon — the
/// app's own material, in the one place every screen shares. It sits
/// behind the icon rather than around the whole tab: an earlier travelling
/// pill that held icon and label together needed a fill, a border and a
/// glow to hold itself together against the glass, and put more decoration
/// on the bar than on the content it navigates.
///
/// What the pool adds is that it behaves like water. On a switch its edges
/// run on different clocks, so it stretches toward the new tab and gathers
/// itself there, and its surface tilts back against the direction of travel
/// and settles as it lands. A switch you can see travel is a switch you
/// understand you caused. At rest nothing moves: the bar sits over every
/// screen, and a surface that kept rippling there would be motion nobody
/// asked for, and a repaint of the blur behind it on every frame.
class TideTabBar extends StatelessWidget {
  const TideTabBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.tabs = TideTab.all,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<TideTab> tabs;

  static const double barHeight = 62;
  static const double sideMargin = 20;

  /// The tab's own layout, named once so the pool can be placed against the
  /// same numbers rather than against a guess.
  static const double _iconSize = 22;
  static const double _iconGap = 5;

  /// Fixed rather than measured. The app clamps text scaling to 1.2, and a
  /// label box that grows moves the icon — which moves it off the pool that
  /// is supposed to be sitting behind it.
  static const double _labelHeight = 18;

  static const double _poolHeight = 30;
  static const double _poolWidth = 54;

  static const double _contentHeight = _iconSize + _iconGap + _labelHeight;
  static const double _contentTop = (barHeight - _contentHeight) / 2;
  static const double _poolTop = _contentTop + _iconSize / 2 - _poolHeight / 2;

  /// Between the panel and the safe area below it.
  static const double bottomGap = 10;

  static const BorderRadius _radius = TideElevation.radius20;

  /// Everything the bar occupies at the bottom of the screen, including the
  /// system gesture inset — for a screen inside the shell's body, which is
  /// where every caller is.
  ///
  /// Read from the body's `padding`, which `extendBody` sets to the height
  /// the bar's slot was actually laid out at. It used to be rebuilt from
  /// `viewPadding`, but the Scaffold strips the bottom view padding out of a
  /// body that has a bottom bar: the sum came up one gesture bar short —
  /// the New task button sat on the bar, and last rows never quite cleared
  /// it — and it changed as the keyboard opened, rebuilding every tab.
  static double reservedHeight(BuildContext context) =>
      MediaQuery.paddingOf(context).bottom;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        sideMargin,
        0,
        sideMargin,
        bottomGap + MediaQuery.viewPaddingOf(context).bottom,
      ),
      child: SizedBox(
        height: barHeight,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: _radius,
            boxShadow: TideElevation.floating,
          ),
          child: ClipRRect(
            borderRadius: _radius,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: TideGradients.glass,
                  // A floor under the blur. Without it the glass goes muddy
                  // over a card and unreadable over deep water.
                  color: TideColors.deepWater.withValues(alpha: 0.62),
                  borderRadius: _radius,
                  border: Border.all(color: TideColors.hairline),
                ),
                child: Stack(
                  children: [
                    // The lit top edge every raised surface in the app has,
                    // so the glass reads as a pane with thickness rather
                    // than as a tinted hole in the page.
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: TideElevation.innerHighlightWidth,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: TideElevation.innerHighlightGradient,
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: _TidePool(index: currentIndex, count: tabs.length),
                    ),
                    Row(
                      children: [
                        for (var i = 0; i < tabs.length; i++)
                          Expanded(
                            child: _Tab(
                              tab: tabs[i],
                              active: i == currentIndex,
                              onTap: () => onTap(i),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The water behind the selected tab, and its journey between tabs.
///
/// Positions are kept in tab units — 2.0 is "centred on the third tab" —
/// not pixels, so a pool caught mid-flight by a second tap sets off again
/// from exactly where it is, and a change of width (a rotation, a fold)
/// never strands it between two tabs.
class _TidePool extends StatefulWidget {
  const _TidePool({required this.index, required this.count});

  final int index;
  final int count;

  @override
  State<_TidePool> createState() => _TidePoolState();
}

class _TidePoolState extends State<_TidePool>
    with SingleTickerProviderStateMixin {
  // Starts at rest: the bar's first frame shows the pool already in place.
  late final AnimationController _travel = AnimationController(
    vsync: this,
    duration: TideMotion.tabTide,
    value: 1,
  );

  late double _fromLeft = widget.index.toDouble();
  late double _fromRight = widget.index.toDouble();
  late int _to = widget.index;

  /// +1 travelling right, -1 left. Decides which edge leads and which way
  /// the surface leans.
  double _direction = 1;

  double get _t => _travel.value;

  /// Both edges, the trailing one held within [TideMotion.tabStretch] of
  /// the one leading.
  (double, double) get _edges {
    final to = _to.toDouble();
    final lead = TideMotion.tabLead.transform(_t);
    final trail = TideMotion.tabTrail.transform(_t);
    if (_direction > 0) {
      final right = _lerp(_fromRight, to, lead);
      final left = _lerp(_fromLeft, to, trail);
      return (math.max(left, right - TideMotion.tabStretch), right);
    }
    final left = _lerp(_fromLeft, to, lead);
    final right = _lerp(_fromRight, to, trail);
    return (left, math.min(right, left + TideMotion.tabStretch));
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;

  @override
  void didUpdateWidget(_TidePool old) {
    super.didUpdateWidget(old);
    if (widget.index == _to) return;
    // From wherever the edges are now, mid-flight or not.
    final (left, right) = _edges;
    _fromLeft = left;
    _fromRight = right;
    _direction = widget.index > (left + right) / 2 ? 1 : -1;
    _to = widget.index;
    if (MediaQuery.disableAnimationsOf(context)) {
      _travel.value = 1;
    } else {
      _travel.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _travel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Read here, not in the painter: tokens are runtime values that change
    // with the palette.
    final lantern = TideColors.lantern;
    final light = TideColors.palette.isLight;
    final water = TideGradients.tabWater;
    final glow = TideElevation.tabGlow;

    return IgnorePointer(
      child: RepaintBoundary(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final tabWidth = constraints.maxWidth / widget.count;
            // A tab's centre, in pixels, for a position in tab units.
            double centre(double units) => tabWidth * (units + 0.5);

            return AnimatedBuilder(
              animation: _travel,
              builder: (context, _) {
                // Rises and falls once over the journey: the water is
                // stirred most in mid-flight and still again on arrival.
                final slosh = math.sin(math.pi * _t);
                final (left, right) = _edges;
                return CustomPaint(
                  size: Size.infinite,
                  painter: _PoolPainter(
                    left: centre(left) - TideTabBar._poolWidth / 2,
                    right: centre(right) + TideTabBar._poolWidth / 2,
                    slosh: slosh,
                    lean: _direction * slosh,
                    phase: _t * math.pi * 1.4,
                    tint: lantern.withValues(alpha: light ? 0.05 : 0.1),
                    surface: lantern.withValues(alpha: light ? 0.5 : 0.9),
                    water: water,
                    glow: glow,
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _PoolPainter extends CustomPainter {
  const _PoolPainter({
    required this.left,
    required this.right,
    required this.slosh,
    required this.lean,
    required this.phase,
    required this.tint,
    required this.surface,
    required this.water,
    required this.glow,
  });

  final double left;
  final double right;

  /// 0 at rest, 1 at the height of the journey.
  final double slosh;

  /// Signed [slosh]: which way the surface leans, and how far.
  final double lean;

  final double phase;

  /// The empty part of the pool: glass with a little of the light in it.
  final Color tint;

  /// The lit waterline.
  final Color surface;

  final Gradient water;
  final List<BoxShadow> glow;

  /// How far down the pool the surface rests — a little below halfway, so
  /// the icon stands in the water rather than sinking under it.
  static const double _waterline = 0.56;

  @override
  void paint(Canvas canvas, Size size) {
    const height = TideTabBar._poolHeight;
    final rect = Rect.fromLTRB(
      left,
      TideTabBar._poolTop,
      right,
      TideTabBar._poolTop + height,
    );
    final pool = RRect.fromRectAndRadius(
      rect,
      const Radius.circular(height / 2),
    );

    for (final shadow in glow) {
      canvas.drawRRect(
        pool.shift(shadow.offset).inflate(shadow.spreadRadius),
        shadow.toPaint(),
      );
    }

    canvas
      ..save()
      ..clipRRect(pool)
      ..drawRect(rect, Paint()..color = tint);

    // A ripple you can just see at rest, stirred up in flight. Two sines at
    // unrelated periods, as on Today's level, so the crest never reads as a
    // drawn curve.
    final amplitude = 0.7 + 1.4 * slosh;
    // Water piles up behind a moving pool: the trailing side stands higher.
    final tilt = lean * 4;
    final base = rect.top + height * _waterline;

    final crest = Path();
    const steps = 32;
    for (var i = 0; i <= steps; i++) {
      final u = i / steps;
      final y =
          base +
          math.sin(u * 2 * math.pi * 1.3 + phase) * amplitude +
          math.sin(u * 2 * math.pi * 2.4 - phase * 0.7) * amplitude * 0.45 +
          tilt * (u - 0.5);
      final x = rect.left + rect.width * u;
      if (i == 0) {
        crest.moveTo(x, y);
      } else {
        crest.lineTo(x, y);
      }
    }

    final body = Path.from(crest)
      ..lineTo(rect.right, rect.bottom)
      ..lineTo(rect.left, rect.bottom)
      ..close();
    final depth = Rect.fromLTRB(
      rect.left,
      base - amplitude * 1.45 - tilt.abs() / 2,
      rect.right,
      rect.bottom,
    );

    canvas
      ..drawPath(body, Paint()..shader = water.createShader(depth))
      // The lit surface — the part of water you actually see.
      ..drawPath(
        crest,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.3
          ..strokeJoin = StrokeJoin.round
          ..color = surface,
      )
      ..restore();
  }

  @override
  bool shouldRepaint(_PoolPainter old) =>
      old.left != left ||
      old.right != right ||
      old.slosh != slosh ||
      old.lean != lean ||
      old.phase != phase ||
      old.surface != surface;
}

class _Tab extends StatelessWidget {
  const _Tab({required this.tab, required this.active, required this.onTap});

  final TideTab tab;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: active,
      button: true,
      child: PressScale(
        onTap: onTap,
        child: SizedBox.expand(
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(end: active ? 1 : 0),
            duration: TideMotion.tabSwitch,
            curve: TideMotion.tabCurve,
            builder: (context, t, _) {
              final tint = Color.lerp(TideColors.silt, TideColors.lantern, t)!;

              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _Lift(
                    active: active,
                    // Crossfaded rather than swapped: at 21px the outline
                    // and the filled shape share most of their geometry, so
                    // a hard swap reads as the icon flickering while a
                    // crossfade reads as it thickening.
                    child: SizedBox(
                      width: TideTabBar._iconSize,
                      height: TideTabBar._iconSize,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Opacity(
                            opacity: 1 - t,
                            child: Icon(tab.icon, size: 21, color: tint),
                          ),
                          Opacity(
                            opacity: t,
                            child: Icon(tab.activeIcon, size: 21, color: tint),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: TideTabBar._iconGap),
                  SizedBox(
                    height: TideTabBar._labelHeight,
                    child: Center(
                      child: Text(
                        tab.label,
                        style: TideType.labelMuted.copyWith(
                          fontSize: 11,
                          color: tint,
                          fontWeight: t > 0.5
                              ? FontWeight.w700
                              : FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// The selected icon bobbing once as the water arrives under it.
///
/// A scale, not a rise: the icon has to stay centred in the pool, and one
/// that climbed would lift itself out of the water that has just come for
/// it.
class _Lift extends StatelessWidget {
  const _Lift({required this.active, required this.child});

  final bool active;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      // Starts at its end value, so the first frame of the app does not bob.
      tween: Tween<double>(end: active ? 1 : 0),
      duration: TideMotion.tabTide,
      builder: (context, p, child) {
        final bob = active
            ? math.sin(math.pi * TideMotion.tabPop.transform(p))
            : 0.0;
        return Transform.scale(scale: 1 + 0.14 * bob, child: child);
      },
      child: child,
    );
  }
}
