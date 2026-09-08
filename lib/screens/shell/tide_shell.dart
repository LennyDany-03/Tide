import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../config/app_constants.dart';
import '../../config/tour_catalog.dart';
import '../../theme/tide_colors.dart';
import '../../theme/tide_motion.dart';
import '../../widgets/tide_backdrop.dart';
import '../../widgets/tide_tab_bar.dart';
import '../../widgets/tour/tour_anchor.dart';

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
  void _onTap(int index) {
    navigationShell.goBranch(
      index,
      // Tapping the tab you are already on pops back to its root — the
      // standard escape hatch out of a pushed detail screen.
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final onFirstTab = navigationShell.currentIndex == 0;

    // Android's back button on History, Insights or Settings used to close
    // the app. Nothing was wrong with the router — there was simply nothing
    // on the stack to pop, because switching tabs replaces the branch
    // rather than pushing onto it, so back fell through to the system and
    // the system quit.
    //
    // Back on a secondary tab now means what it means everywhere else on
    // Android: go back to where you came from, which for a tab bar is the
    // first tab. Only Today may exit the app, and only from its own root —
    // a screen pushed inside a branch pops normally, because the branch
    // navigator handles the gesture before this ever sees it.
    return PopScope(
      canPop: onFirstTab,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) navigationShell.goBranch(0);
      },
      child: _scaffold(context),
    );
  }

  Widget _scaffold(BuildContext context) {
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
        ],
      ),
      // Anchored so the guided tour can point at the four destinations.
      // This is the reason the tour overlay is mounted above the router
      // rather than inside the shell: the bar is in the Scaffold's own
      // bottom slot, outside every tab body.
      bottomNavigationBar: TourAnchor(
        stop: TourStop.tabs,
        child: TideTabBar(
          currentIndex: navigationShell.currentIndex,
          onTap: _onTap,
          tabs: TideTab.all,
        ),
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

  /// What the settle is driving the offset along, while it is running.
  ///
  /// Held in a field and read by one permanent listener. Attaching a fresh
  /// listener per gesture leaked them: a settle that is stopped part-way
  /// never completes, so the callback that would have detached it never
  /// ran.
  Animation<double>? _travel;

  /// How far the page has been carried, in pixels. Negative is a swipe
  /// left, which brings the *next* tab in from the right.
  double _drag = 0;

  double _width = 0;

  /// The branch this stack paints as selected.
  ///
  /// Owned here rather than read straight off the widget. A committed swipe
  /// re-bases the offset onto the arriving branch in the same frame the
  /// finger lifts, while the shell's own index arrives a beat later —
  /// painting from the shell's index leaves a frame where the offset says
  /// the page is arriving from one side while the index still says the
  /// branch on the other side is selected, which flashes a third screen
  /// through the gap.
  late int _index;

  /// The branch a commit has handed over to, until the shell catches up.
  /// An index change matching this one is our own swipe landing rather than
  /// a tab tap.
  int? _handedOver;

  /// Whether the page is being moved, or has just been moved, by hand.
  ///
  /// A swipe carries both branches bodily across the screen, so nothing may
  /// fade during one — and nothing may fade at the *end* of one either. The
  /// branch left behind is already off the page by then; fading it out from
  /// there means first snapping it back to the middle, which paints the tab
  /// you just left directly on top of the one you arrived at for the length
  /// of a crossfade. That ghost is what this flag exists to prevent, and it
  /// is why the flag stays set after the page comes to rest: the landing
  /// frame is the one that has to snap.
  ///
  /// A tab tap is the opposite case — it moves nothing, so the crossfade is
  /// the whole transition. Tapping clears the flag again.
  bool _byHand = false;

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

  /// The branch alongside the current one: the one being pulled in during a
  /// drag, and the one being carried away once a swipe has committed.
  int? get _incoming {
    if (_drag == 0) return null;
    final next = _drag < 0 ? _index + 1 : _index - 1;
    if (next < 0 || next >= widget.branches.length) return null;
    return next;
  }

  @override
  void initState() {
    super.initState();
    _index = widget.currentIndex;
    _settle = AnimationController(vsync: this)..addListener(_onSettleTick);
  }

  @override
  void didUpdateWidget(_BranchStack old) {
    super.didUpdateWidget(old);
    if (old.currentIndex == widget.currentIndex) return;

    if (widget.currentIndex == _handedOver) {
      // Our own swipe landing. The offset was re-based onto this branch the
      // moment the finger lifted and the shell is only now catching up;
      // re-basing again here would jump the page a whole screen.
      _handedOver = null;
      return;
    }

    // A tab tap. It moves nothing by itself, so the crossfade is the whole
    // transition — unless it arrives mid-swipe, where snapping the
    // half-carried page away beats fading it back over the top of the tab
    // being tapped to.
    _handedOver = null;
    _byHand = _moving;
    _index = widget.currentIndex;
    _stopSettle();
    _drag = 0;
  }

  @override
  void dispose() {
    _settle
      ..removeListener(_onSettleTick)
      ..dispose();
    super.dispose();
  }

  void _onSettleTick() {
    final travel = _travel;
    if (travel == null) return;
    setState(() => _drag = travel.value);
  }

  void _stopSettle() {
    _gesture++;
    _settle.stop();
    _travel = null;
  }

  void _onStart(DragStartDetails details) {
    _stopSettle();
    _byHand = true;
  }

  void _onUpdate(DragUpdateDetails details) {
    final heading = _drag + details.delta.dx;
    final atStart = _index == 0 && heading > 0;
    final atEnd = _index == widget.branches.length - 1 && heading < 0;
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
    final forward = target > _index;
    setState(() {
      _drag += forward ? _width : -_width;
      _index = target;
      _handedOver = target;
    });
    widget.onSwipeTo(target);
    _slideTo(0);
  }

  void _slideTo(double to) {
    if (_drag == to) return;

    final token = ++_gesture;
    _travel = _settle.drive(
      Tween<double>(
        begin: _drag,
        end: to,
      ).chain(CurveTween(curve: TideMotion.tabCurve)),
    );

    _settle
      ..stop()
      ..duration = TideMotion.tabSwitch
      ..forward(from: 0).whenComplete(() {
        // A settle stopped part-way never completes, so arriving here means
        // the page really did come to rest — though a tab tap can still
        // have moved the goalposts, which the token catches.
        if (!mounted || token != _gesture) return;
        _travel = null;
        setState(() => _drag = to);
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
              active: i == _index,
              shown: i == _index || i == incoming,
              moving: _moving,
              snap: _byHand,
              dx: _offsetOf(i, incoming),
              child: widget.branches[i],
            ),
        ],
      ),
    );
  }

  double _offsetOf(int index, int? incoming) {
    if (index == _index) return _drag;
    if (incoming == null || index != incoming) return 0;
    // The branch alongside is parked one screen away on the side it comes
    // from, and rides along with the drag.
    return _drag + (incoming > _index ? _width : -_width);
  }
}

/// One tab body.
///
/// Crossfades with a 4px lift when the tab bar is tapped, and travels
/// horizontally when the page is swiped. The widget structure is identical
/// either way — swapping between two shapes here would remount the branch
/// navigator underneath and throw its routes away — so the difference is
/// carried entirely by the durations, which drop to zero for anything the
/// hand is driving.
class _Branch extends StatelessWidget {
  const _Branch({
    required this.active,
    required this.shown,
    required this.moving,
    required this.snap,
    required this.dx,
    required this.child,
  });

  /// The branch the shell currently considers selected.
  final bool active;

  /// Painted this frame: the selected branch, plus the one alongside it
  /// during a swipe.
  final bool shown;

  /// The page is physically in motion — mid-drag or mid-settle.
  final bool moving;

  /// Fade and lift instantly rather than over the tab-switch duration.
  ///
  /// Set for the whole life of a swipe, including the frame it lands on:
  /// the branch being left behind has to go the instant it stops being
  /// painted, because by then it is off-screen and any fade would first
  /// snap it back over the top of the branch that replaced it.
  final bool snap;

  final double dx;
  final Widget child;

  Duration get _duration => snap ? Duration.zero : TideMotion.tabSwitch;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: Offset(dx, 0),
      child: AnimatedOpacity(
        opacity: shown ? 1 : 0,
        duration: _duration,
        curve: TideMotion.tabCurve,
        child: AnimatedSlide(
          offset: (active || moving) ? Offset.zero : const Offset(0, 0.012),
          duration: _duration,
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
