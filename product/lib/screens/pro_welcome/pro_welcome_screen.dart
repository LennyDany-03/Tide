import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../config/pro_features.dart';
import '../../services/models/milestone.dart';
import '../../services/tide_scope.dart';
import '../../theme/tide_colors.dart';
import '../../theme/tide_motion.dart';
import '../../theme/tide_typography.dart';
import '../../widgets/tide_backdrop.dart';
import '../../widgets/tide_button.dart';
import '../../widgets/tide_mark.dart';
import 'widgets/pro_ticket.dart';
import 'widgets/unlocked_row.dart';

/// The moment after paying.
///
/// **Why this exists at all.** The reward for buying Pro used to be a
/// checkmark on a button and a sheet closing — the same acknowledgement the
/// app gives for saving a habit name. Somebody has just handed over money on
/// the strength of a list of promises, and the only honest answer to that is
/// to show the promises being kept, one at a time, and to hand over something
/// to keep.
///
/// **The shape.** One controller, one pass, no loops. Light opens, the mark
/// draws, the words rise, the ticket assembles and catches the light, the
/// features tick off, the button arrives. Every beat is a window on a fraction
/// of [TideMotion.proWelcome] rather than a timer of its own, so the whole
/// thing is one object moving — and can be scrubbed to its end in one call.
///
/// **It is skippable, and that is what makes the length safe.** Four seconds
/// is a long time to hold somebody who has just paid you. A tap anywhere runs
/// the remainder at speed rather than cutting to the end, because a sequence
/// that snaps reads as a glitch and not as a fast-forward.
class ProWelcomeScreen extends StatefulWidget {
  const ProWelcomeScreen({super.key});

  @override
  State<ProWelcomeScreen> createState() => _ProWelcomeScreenState();
}

class _ProWelcomeScreenState extends State<ProWelcomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: TideMotion.proWelcome,
  );

  /// Which knocks have already fired. The controller can be scrubbed, and a
  /// skip must not fire six haptics inside one frame.
  final Set<String> _knocked = {};

  bool _skipped = false;

  // The score. Each beat is a window on the one clock.
  static const _crown = (0.00, 0.16);
  static const _mark = (0.06, 0.32);
  static const _words = (0.22, 0.46);
  static const _ticket = (0.34, 0.70);
  static const _sheen = (0.56, 0.80);
  static const _features = (0.62, 0.94);
  static const _button = (0.88, 1.00);

  @override
  void initState() {
    super.initState();
    _controller.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) => _acknowledge());
  }

  /// The `high-water` badge unlocked the instant the payment landed. This
  /// screen is its celebration, so Milestones must not play a second, smaller
  /// one the next time it is opened.
  void _acknowledge() {
    if (!mounted) return;
    final store = TideScope.read(context);
    for (final status in store.milestones) {
      if (status.milestone.kind == MilestoneKind.pro && status.unlocked) {
        store.acknowledgeCelebration(status.milestone);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _skip() {
    if (_skipped || !_controller.isAnimating) return;
    _skipped = true;
    _controller.animateTo(
      1,
      duration: TideMotion.proSkip,
      curve: TideMotion.tabCurve,
    );
  }

  void _knock(String beat, bool haptics, {bool heavy = false}) {
    if (!haptics || !_knocked.add(beat)) return;
    if (heavy) {
      HapticFeedback.heavyImpact();
    } else {
      HapticFeedback.selectionClick();
    }
  }

  /// 0..1 within a window, clamped outside it.
  double _phase((double, double) window) {
    final (start, end) = window;
    return ((_controller.value - start) / (end - start)).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final store = TideScope.of(context);
    final haptics = store.haptics;
    final name = store.account?.firstName;

    return Scaffold(
      backgroundColor: TideColors.deepWater,
      body: GestureDetector(
        onTap: _skip,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          children: [
            const Positioned.fill(child: TideBackdrop()),
            AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final mark = _phase(_mark);
                final words = _phase(_words);
                final ticket = _phase(_ticket);
                final features = _phase(_features);
                final button = _phase(_button);

                if (mark > 0.9) _knock('mark', haptics, heavy: true);

                return SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                    child: Column(
                      children: [
                        const Spacer(),

                        // The mark, inside the crown of light it throws.
                        SizedBox(
                          height: 92,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Positioned.fill(
                                child: LightCrown(progress: _phase(_crown)),
                              ),
                              Opacity(
                                opacity: Curves.easeOut.transform(
                                  (mark / 0.3).clamp(0.0, 1.0),
                                ),
                                // Drawn in, unlike the seal on the ticket
                                // below: this one is the arrival.
                                child: TideMark(size: 62, strokeWidth: 3),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 22),

                        _Rise(
                          progress: words,
                          child: Column(
                            children: [
                              Text(
                                name == null
                                    ? 'Welcome to Pro'
                                    : 'Welcome to Pro, $name',
                                style: TideType.screenTitle,
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Everything below is open from now on.',
                                style: TideType.bodyMuted,
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),

                        const Spacer(),

                        _Rise(
                          progress: (ticket / 0.5).clamp(0.0, 1.0),
                          lift: 22,
                          child: ProTicket(
                            entitlement: store.entitlement,
                            holderName: store.accountName,
                            reveal: ticket,
                            sheen: _phase(_sheen),
                          ),
                        ),

                        const Spacer(),

                        // Staggered across the window, so the list ticks off
                        // one row at a time rather than arriving as a block.
                        for (var i = 0; i < ProFeatures.headline.length; i++)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 13),
                            child: Builder(
                              builder: (context) {
                                final count = ProFeatures.headline.length;
                                final step = 1 / (count + 2);
                                final local =
                                    ((features - i * step) / (step * 3)).clamp(
                                      0.0,
                                      1.0,
                                    );
                                if (local > 0.8) _knock('feature$i', haptics);
                                return UnlockedRow(
                                  feature: ProFeatures.headline[i],
                                  progress: local,
                                );
                              },
                            ),
                          ),

                        const Spacer(),

                        Opacity(
                          opacity: Curves.easeOut.transform(button),
                          child: IgnorePointer(
                            ignoring: button < 1,
                            child: TideButton(
                              label: 'Start using it',
                              onPressed: () => context.pop(),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        // Only offered while there is something left to skip.
                        SizedBox(
                          height: 18,
                          child: Opacity(
                            opacity: (1 - button).clamp(0.0, 1.0) * 0.7,
                            child: Text(
                              'Tap anywhere to skip',
                              style: TideType.labelMuted.copyWith(
                                fontSize: 11.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Fades in while rising the last few pixels — the app's entrance, driven by a
/// progress the parent owns so every beat runs on the one clock.
class _Rise extends StatelessWidget {
  const _Rise({required this.progress, required this.child, this.lift = 12});

  final double progress;
  final double lift;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final eased = Curves.easeOutCubic.transform(progress.clamp(0.0, 1.0));
    return Opacity(
      opacity: eased,
      child: Transform.translate(
        offset: Offset(0, lift * (1 - eased)),
        child: child,
      ),
    );
  }
}
