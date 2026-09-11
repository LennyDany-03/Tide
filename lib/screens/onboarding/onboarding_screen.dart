import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../config/app_routes.dart';
import '../../services/tide_scope.dart';
import '../../theme/tide_colors.dart';
import '../../theme/tide_motion.dart';
import '../../theme/tide_typography.dart';
import '../../widgets/demo/loop_demos.dart';
import '../../widgets/press_scale.dart';
import '../../widgets/tide_backdrop.dart';
import '../../widgets/tide_button.dart';
import '../../widgets/tide_line_gauge.dart';
import 'widgets/explainer_step.dart';
import 'widgets/ready_step.dart';
import 'widgets/welcome_step.dart';

/// First run.
///
/// This flow used to be a setup wizard: pick templates, confirm a schedule,
/// approve notifications, done. It asked four questions before it had said
/// what the app was, which is the wrong order — every one of those answers
/// is available inside the product in a screen the user has not yet been
/// given a reason to want. Configuration is not onboarding, it is homework.
///
/// So it explains instead. Five pages: what Tide is, then the three things
/// it does — log, hold, read — each *performed* on a loop rather than
/// described, then the hand-off. Nothing here writes any state; the only
/// output of the whole flow is a user who knows what the swipe does.
///
/// Two affordances the wizard did not need and this does. **Back**, because
/// an explanation you can only move forward through is a slideshow you are
/// trapped in; and **swipe**, because with nothing on the page to fill in,
/// the pages are the content and paging them by hand is the natural
/// gesture. Skip stays exactly where it was and just as legible — a skip
/// that hides is a dark pattern, and it would also be a lie about how much
/// this flow matters.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  final PageController _pages = PageController();

  /// Drives the closing morph into the auth screen.
  late final AnimationController _morph = AnimationController(
    vsync: this,
    duration: TideMotion.morph,
  );

  int _step = 0;

  static const int _stepCount = 5;

  /// The label on the primary button.
  ///
  /// The last page used to say "Create your account", which named a form
  /// rather than an outcome and was also a promise the app no longer keeps:
  /// the screen it opens leads with log in, because most people reaching it
  /// twice are not new. "Get started" is what the button actually does, and
  /// it is the first page that gives up the phrase — page one is offering a
  /// walk-through, so it says so.
  String get _primaryLabel {
    if (_step == 0) return 'Show me how';
    if (_step == _stepCount - 1) return 'Get started';
    return 'Next';
  }

  @override
  void dispose() {
    _pages.dispose();
    _morph.dispose();
    super.dispose();
  }

  void _goTo(int step) {
    if (step < 0 || step >= _stepCount) return;
    _pages.animateToPage(
      step,
      duration: TideMotion.sheetIn,
      curve: TideMotion.sheetCurve,
    );
  }

  void _next() {
    if (_step == _stepCount - 1) {
      _finish();
      return;
    }
    _goTo(_step + 1);
  }

  /// True when the back press was ours to handle.
  bool _back() {
    if (_step == 0) return false;
    _goTo(_step - 1);
    return true;
  }

  Future<void> _finish() async {
    final store = TideScope.read(context);
    final router = GoRouter.of(context);

    // The morph starts first so the ring is already travelling when the
    // route changes, but the route change does *not* wait for it to land.
    // Awaiting the whole sweep left a real gap: onboarding finished fading
    // to nothing and then held an empty page until the navigation ran, and
    // that dead frame is what read as the animation breaking. Handing over
    // partway through means the auth screen is arriving while the ring is
    // still on its way out, which is the overlap the morph was for.
    _morph.forward();
    await Future<void>.delayed(_handOff);
    if (!mounted) return;

    store.completeOnboarding();
    router.go(Routes.auth);
  }

  /// How far into the morph the next screen takes over.
  ///
  /// It was 300ms, which was past the point the page had finished leaving:
  /// the copy, the chrome and the ring all clear by about 210ms, so there
  /// was a blank beat with nothing on it before the account screen even
  /// started arriving. Handing over at 160 puts the incoming page's fade
  /// underneath the tail of the outgoing one, which is the overlap the
  /// morph exists for.
  static const Duration _handOff = Duration(milliseconds: 120);

  void _skip() {
    TideScope.read(context).completeOnboarding();
    context.go(Routes.auth);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // The system back gesture walks the flow rather than leaving it. On
      // the first page there is nothing behind onboarding to go back to, so
      // it falls through to the platform's own handling.
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        backgroundColor: TideColors.deepWater,
        body: Stack(
          children: [
            // The one screen allowed a looping background: first run has no
            // history to show yet, so a still page would read as unloaded.
            const Positioned.fill(child: TideBackdrop(drift: true)),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
                child: Column(
                  children: [
                    // The chrome leaves with everything else. It used to sit
                    // outside the exit fade, so the last thing onboarding did
                    // was dissolve the ring, the copy and the button and then
                    // hold a blank screen carrying a full progress bar and a
                    // Skip link — the two least important things on the page
                    // were the only two that survived it.
                    _ExitFade(morph: _morph, child: _chrome()),
                    const SizedBox(height: 22),
                    Expanded(
                      child: PageView(
                        controller: _pages,
                        onPageChanged: (page) => setState(() => _step = page),
                        children: [
                          for (var i = 0; i < _stepCount; i++)
                            _Depth(
                              controller: _pages,
                              index: i,
                              child: _stepAt(i),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _ExitFade(
                      morph: _morph,
                      child: Column(
                        children: [
                          TideButton(label: _primaryLabel, onPressed: _next),
                          const SizedBox(height: 12),
                          SwipeHint(visible: _step == 0),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chrome() {
    return Row(
      children: [
        // Slides in from nothing rather than appearing, and takes its width
        // with it — a back control that is present-but-disabled on page one
        // is a dead target sitting where the eye lands first.
        _BackButton(visible: _step > 0, onTap: _back),
        Expanded(child: TideLineGauge(progress: (_step + 1) / _stepCount)),
        const SizedBox(width: 18),
        // Always visible while the flow is running, never de-emphasised.
        PressScale(
          onTap: _skip,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            child: Text('Skip', style: TideType.labelMuted),
          ),
        ),
      ],
    );
  }

  Widget _stepAt(int index) => switch (index) {
    0 => const WelcomeStep(),
    1 => const ExplainerStep(
      eyebrow: 'Mark',
      title: 'One swipe, and the day is done',
      body:
          'No forms, no timers, no check-in screen. Carry the card to the '
          'right and Tide records it.',
      demo: SwipeLoopDemo(),
    ),
    2 => const ExplainerStep(
      eyebrow: 'Hold',
      title: 'A missed day does not undo you',
      body:
          'Every habit carries freeze tokens. Spend one and the run holds '
          'through the gap instead of resetting to zero.',
      demo: StreakLoopDemo(),
    ),
    3 => const ExplainerStep(
      eyebrow: 'Read',
      title: 'The shape shows up over weeks',
      body:
          'Every day you mark lands in the grid. What you are actually '
          'building is the pattern, not the number.',
      demo: HistoryLoopDemo(),
    ),
    _ => AnimatedBuilder(
      animation: _morph,
      builder: (context, _) => ReadyStep(morph: _morph.value),
    ),
  };
}

/// The back chevron, and the space it occupies.
class _BackButton extends StatelessWidget {
  const _BackButton({required this.visible, required this.onTap});

  final bool visible;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: TideMotion.tabSwitch,
      curve: TideMotion.tabCurve,
      alignment: Alignment.centerLeft,
      child: !visible
          ? const SizedBox(height: 34)
          : AnimatedOpacity(
              opacity: 1,
              duration: TideMotion.tabSwitch,
              child: Padding(
                padding: const EdgeInsets.only(right: 14),
                child: PressScale(
                  onTap: onTap,
                  child: SizedBox(
                    width: 34,
                    height: 34,
                    child: Icon(
                      Icons.arrow_back_rounded,
                      size: 19,
                      color: TideColors.silt,
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

/// Parallax and depth on the paged content.
///
/// The `PageView` already translates each page by a full screen width. This
/// pulls the *content* back against that travel, tips it a few degrees on
/// the vertical axis and lets it shrink as it leaves, so a page departs into
/// the water rather than sliding off a table. One light source, one
/// vanishing point: the rotation always runs the same way relative to the
/// direction of travel, so paging forward and paging back are the same
/// move in reverse rather than two different effects.
///
/// The perspective entry is small on purpose. Enough that a departing page
/// reads as turning away; past about 0.0015 the near edge fans out and the
/// text on it goes soft.
///
/// **The wrapper shape never changes, and that is load-bearing.** This used
/// to return the bare child at rest and wrap it only once the page had
/// moved, on the reasoning that a motionless page should not pay for a
/// transform. What that actually did was change the widget type sitting at
/// that position in the tree the instant a finger touched the page, so
/// Flutter unmounted the whole step and inflated a fresh one — the ring
/// started drawing again, the copy re-staggered — and then did it a second
/// time when the drag sprang back and the wrapper disappeared again. A
/// nudge too small to turn the page restarted the entrance twice. An
/// identity transform costs one layer; the shape has to stay constant.
class _Depth extends StatefulWidget {
  const _Depth({
    required this.controller,
    required this.index,
    required this.child,
  });

  final PageController controller;
  final int index;
  final Widget child;

  @override
  State<_Depth> createState() => _DepthState();
}

class _DepthState extends State<_Depth> with AutomaticKeepAliveClientMixin {
  /// Pages hold their state once built.
  ///
  /// Without this a page is disposed as soon as it leaves the viewport, so
  /// walking back through the flow replays every entrance from zero — the
  /// welcome ring redrawing on the way back is the same wrong note as it
  /// redrawing after a nudge, just further apart. Keeping them alive is
  /// only affordable because [_ticking] mutes the ones off screen.
  @override
  bool get wantKeepAlive => true;

  /// How far this page sits from the one under the finger, signed. Negative
  /// means the page is to the left of where the view has scrolled to.
  double get _delta {
    final controller = widget.controller;
    // `page` throws before the view has been laid out, and reads null on
    // the frame the controller is attached — both mean "sitting on the
    // initial page", which is what the fallback says.
    final page = controller.hasClients && controller.position.haveDimensions
        ? controller.page ?? controller.initialPage.toDouble()
        : controller.initialPage.toDouble();
    return (page - widget.index).clamp(-1.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final width = MediaQuery.sizeOf(context).width;

    return AnimatedBuilder(
      animation: widget.controller,
      child: widget.child,
      builder: (context, child) {
        final delta = _delta;
        final away = delta.abs();

        // A page that is kept alive but wholly off screen must not keep
        // running its demo loop — three of these ticking behind the one you
        // are reading is three screens' worth of animation nobody can see.
        return TickerMode(
          enabled: away < 1,
          child: Opacity(
            // Faster than the slide, so two pages are never both legible.
            // Identity at rest, where `RenderOpacity` skips the layer.
            opacity: (1 - away * 1.4).clamp(0.0, 1.0),
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.0011)
                ..translateByDouble(-delta * width * 0.34, 0, away * 90, 1)
                ..rotateY(delta * 0.34),
              child: child,
            ),
          ),
        );
      },
    );
  }
}

/// Everything that is not the ring, leaving as the screen hands off.
///
/// Faster than the morph it rides on, so the page has cleared before the
/// ring finishes travelling and the ring is unambiguously the thing being
/// carried across rather than one more element in a crossfade.
class _ExitFade extends StatelessWidget {
  const _ExitFade({required this.morph, required this.child});

  final Animation<double> morph;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: morph,
      builder: (context, child) => IgnorePointer(
        ignoring: morph.value > 0,
        child: Opacity(
          opacity: (1 - morph.value * 2.2).clamp(0.0, 1.0),
          child: child,
        ),
      ),
      child: child,
    );
  }
}
