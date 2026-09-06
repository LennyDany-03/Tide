import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../config/app_constants.dart';
import '../../config/app_routes.dart';
import '../../services/tide_scope.dart';
import '../../theme/tide_colors.dart';
import '../../theme/tide_motion.dart';
import '../../widgets/tide_backdrop.dart';
import '../../widgets/tide_fab.dart';
import '../../widgets/tide_tab_bar.dart';

/// The frame around the four tabs.
///
/// Holds the page ground, the tab bar and the floating add action. The tab
/// bodies stay alive in a stack rather than being rebuilt, so switching
/// away from a half-scrolled Insights and back does not lose the position —
/// and the crossfade has something real to fade between.
///
/// The backdrop is mounted once here rather than per screen, so all four
/// tabs share a single continuous ground: switching tabs moves the content
/// across a background that never moves, which is what makes the four feel
/// like rooms in one app instead of four separate pages.
class TideShell extends StatelessWidget {
  const TideShell({
    super.key,
    required this.navigationShell,
    required this.branches,
  });

  final StatefulNavigationShell navigationShell;
  final List<Widget> branches;

  /// Whether the current branch is showing its own root screen rather than
  /// something pushed on top of it.
  ///
  /// Matching against the tab paths rather than tracking a stack depth keeps
  /// this true for any screen pushed inside a branch later.
  bool _atTabRoot(BuildContext context) {
    final location = GoRouter.of(context).state.matchedLocation;
    return TideTab.all.any((tab) => tab.path == location);
  }

  /// Where the add action belongs: Today, and only at its root.
  ///
  /// It used to ride along on History and Insights too. Those two screens
  /// are for reading back what already happened — putting the app's one
  /// primary action on them means the brightest object on a review screen
  /// is a button that has nothing to do with reviewing. A pushed screen —
  /// habit detail — carries its own controls at the bottom of the page,
  /// which the FAB would otherwise sit directly on top of.
  bool _showFab(BuildContext context) =>
      navigationShell.currentIndex == 0 && _atTabRoot(context);

  void _onTap(int index) {
    navigationShell.goBranch(
      index,
      // Tapping the tab you are already on pops back to its root — the
      // standard escape hatch out of a pushed detail screen.
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  void _onAdd(BuildContext context) {
    final store = TideScope.read(context);
    // The paywall is contextual: it appears at the moment the free ceiling
    // actually blocks something, never as a nag.
    context.push(store.canAddHabit ? Routes.newHabit : Routes.upgrade);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TideColors.deepWater,
      // The tab bar is frosted glass, so the page has to keep going behind
      // it — there is nothing for a blur to sample otherwise. Scrolling
      // screens buy that space back with `TideTabBar.reservedHeight`.
      extendBody: true,
      body: Stack(
        children: [
          const Positioned.fill(child: TideBackdrop()),
          Positioned.fill(
            child: _BranchStack(
              currentIndex: navigationShell.currentIndex,
              branches: branches,
              // Only at a tab root. On a pushed screen the horizontal axis
              // belongs to that screen and to the system back gesture, and
              // swapping the tab out from under it would strand the pushed
              // route in a branch you can no longer see.
              swipeEnabled: _atTabRoot(context),
              onSwipeTo: navigationShell.goBranch,
            ),
          ),
          const Positioned(top: 0, left: 0, right: 0, child: TideTopScrim()),
          Positioned(
            right: 20,
            bottom: TideTabBar.reservedHeight(context) + 14,
            child: TideFabSlot(
              visible: _showFab(context),
              child: TideFab(onPressed: () => _onAdd(context)),
            ),
          ),
        ],
      ),
      bottomNavigationBar: TideTabBar(
        currentIndex: navigationShell.currentIndex,
        onTap: _onTap,
        tabs: TideTab.all,
      ),
    );
  }
}

/// The four tab bodies, and the swipe between them.
///
/// Every branch stays mounted — a branch navigator that leaves the tree
/// loses the routes pushed onto it — so the swipe slides the branches over
/// each other rather than paging a `PageView`, which would build and drop
/// them as it scrolled. Only two are painted at once: the current one, and
/// whichever one the drag is pulling in beside it.
class _BranchStack extends StatefulWidget {
  const _BranchStack({
    required this.currentIndex,
    required this.branches,
    required this.swipeEnabled,
    required this.onSwipeTo,
  });

  final int currentIndex;
  final List<Widget> branches;
  final bool swipeEnabled;
  final ValueChanged<int> onSwipeTo;

  @override
  State<_BranchStack> createState() => _BranchStackState();
}

class _BranchStackState extends State<_BranchStack>
    with SingleTickerProviderStateMixin {
  // Built eagerly in initState rather than lazily, for the same reason the
  // habit card does it: a shell torn down without anyone ever swiping would
  // otherwise construct the controller inside dispose(), which is too late
  // to look up a TickerMode.
  late final AnimationController _settle;

  /// How far the page has been carried, in pixels. Negative is a swipe
  /// left, which brings the *next* tab in from the right.
  double _drag = 0;

  double _width = 0;

  /// Invalidates a settle that is still running when a new gesture starts,
  /// so its completion cannot commit a swipe the user has since grabbed
  /// back.
  int _gesture = 0;

  /// Fraction of the screen a drag has to cross to commit.
  static const double _commitAt = 0.22;

  /// Or the speed it has to be thrown at, in pixels per second.
  static const double _flingAt = 380;

  /// Past the first and last tab there is nothing to reveal, so the page
  /// gives a little and springs back rather than sliding off nothing.
  static const double _resistance = 0.28;

  bool get _moving => _drag != 0;

  /// The branch being pulled in beside the current one, if any.
  int? get _incoming {
    if (_drag == 0) return null;
    final next = _drag < 0 ? widget.currentIndex + 1 : widget.currentIndex - 1;
    if (next < 0 || next >= widget.branches.length) return null;
    return next;
  }

  @override
  void initState() {
    super.initState();
    _settle = AnimationController(vsync: this);
  }

  @override
  void dispose() {
    _settle.dispose();
    super.dispose();
  }

  void _onStart(DragStartDetails details) {
    _gesture++;
    _settle.stop();
  }

  void _onUpdate(DragUpdateDetails details) {
    final heading = _drag + details.delta.dx;
    final atStart = widget.currentIndex == 0 && heading > 0;
    final atEnd =
        widget.currentIndex == widget.branches.length - 1 && heading < 0;
    final scale = (atStart || atEnd) ? _resistance : 1.0;

    setState(() {
      _drag = (_drag + details.delta.dx * scale).clamp(-_width, _width);
    });
  }

  void _onEnd(DragEndDetails details) {
    final target = _incoming;
    if (target == null) {
      _slideTo(0);
      return;
    }

    final velocity = details.velocity.pixelsPerSecond.dx;
    final crossed = _width > 0 && _drag.abs() / _width > _commitAt;
    // A fling only counts if it is still heading the way the drag was
    // going; a flick back the other way is a cancel, however fast.
    final flung = velocity.abs() > _flingAt && velocity.sign == _drag.sign;

    if (crossed || flung) {
      _commit(target);
    } else {
      _slideTo(0);
    }
  }

  /// Hands the index over *now* and re-bases the offset onto the branch
  /// that is arriving, so the page carries on from exactly where it is.
  ///
  /// Switching at the end of the animation instead would leave the tab bar
  /// snapping to the new tab once everything had already come to rest.
  /// Re-basing lets the pill travel while the page is still moving.
  void _commit(int target) {
    setState(() => _drag += target > widget.currentIndex ? _width : -_width);
    widget.onSwipeTo(target);
    _slideTo(0);
  }

  void _slideTo(double to) {
    final from = _drag;
    if (from == to) return;

    final token = ++_gesture;
    _settle
      ..stop()
      ..reset()
      ..duration = TideMotion.tabSwitch;

    final travel = _settle.drive(
      Tween<double>(
        begin: from,
        end: to,
      ).chain(CurveTween(curve: TideMotion.tabCurve)),
    );

    void tick() {
      if (token != _gesture) return;
      setState(() => _drag = travel.value);
    }

    travel.addListener(tick);
    _settle.forward().whenComplete(() {
      travel.removeListener(tick);
      if (mounted && token == _gesture) setState(() => _drag = to);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Measured from the window rather than a LayoutBuilder. The stack fills
    // the body, so the two are the same number — but a LayoutBuilder builds
    // its child during layout, and putting the branch navigators through a
    // layout-phase build corrupts the element lifecycle of the global keys
    // they are mounted under.
    _width = MediaQuery.sizeOf(context).width;
    final incoming = _incoming;

    return GestureDetector(
      // Deferring to the child leaves taps and vertical scrolls reaching the
      // page exactly as before; only the horizontal drag is claimed, and a
      // habit row's own swipe-to-log still wins it because that recogniser
      // sits deeper in the tree.
      onHorizontalDragStart: widget.swipeEnabled ? _onStart : null,
      onHorizontalDragUpdate: widget.swipeEnabled ? _onUpdate : null,
      onHorizontalDragEnd: widget.swipeEnabled ? _onEnd : null,
      child: Stack(
        children: [
          for (var i = 0; i < widget.branches.length; i++)
            _Branch(
              active: i == widget.currentIndex,
              shown: i == widget.currentIndex || i == incoming,
              moving: _moving,
              dx: _offsetOf(i, incoming),
              child: widget.branches[i],
            ),
        ],
      ),
    );
  }

  double _offsetOf(int index, int? incoming) {
    if (index == widget.currentIndex) return _drag;
    if (incoming == null || index != incoming) return 0;
    // The arriving branch is parked one screen away on the side it comes
    // from, and rides in with the drag.
    return _drag + (incoming > widget.currentIndex ? _width : -_width);
  }
}

/// One tab body.
///
/// Crossfades with a 4px lift when the tab bar is tapped, and travels
/// horizontally when the page is swiped. The widget structure is identical
/// either way — swapping between two shapes here would remount the branch
/// navigator underneath and throw its routes away — so the difference is
/// carried entirely by the durations, which drop to zero while a finger is
/// driving the movement.
class _Branch extends StatelessWidget {
  const _Branch({
    required this.active,
    required this.shown,
    required this.moving,
    required this.dx,
    required this.child,
  });

  /// The branch the shell currently considers selected.
  final bool active;

  /// Painted this frame: the selected branch, plus the one arriving beside
  /// it during a swipe.
  final bool shown;

  final bool moving;
  final double dx;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: Offset(dx, 0),
      child: AnimatedOpacity(
        opacity: shown ? 1 : 0,
        duration: moving ? Duration.zero : TideMotion.tabSwitch,
        curve: TideMotion.tabCurve,
        child: AnimatedSlide(
          offset: (active || moving) ? Offset.zero : const Offset(0, 0.012),
          duration: moving ? Duration.zero : TideMotion.tabSwitch,
          curve: TideMotion.tabCurve,
          child: IgnorePointer(
            // Nothing takes input mid-swipe: a tap landing on the page you
            // are sliding away from would act on the wrong screen.
            ignoring: !active || moving,
            // Pausing tickers on hidden branches keeps four screens' worth
            // of ambient animation from running at once.
            child: TickerMode(enabled: shown, child: child),
          ),
        ),
      ),
    );
  }
}
