import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../config/app_routes.dart';
import '../../services/tide_scope.dart';
import '../../theme/tide_colors.dart';
import '../../theme/tide_motion.dart';
import '../../theme/tide_typography.dart';
import '../../widgets/account_avatar.dart';
import '../../widgets/tide_backdrop.dart';

/// The moment between signing in and the app.
///
/// The account form used to end on a checkmark and a hard cut to Today.
/// That is right for a sheet that saves a habit and wrong for the screen
/// that opens an account: the first thing the product says to a person it
/// now knows should be their name.
///
/// One sequence, then out of the way — the portrait settles, the greeting
/// and the name rise under it, a hold long enough to read them, and a `go`
/// to Today. A tap skips the hold, as it does on the splash.
///
/// It plays after a sign-in and never after a restored session. Somebody
/// opening the app for the fortieth time does not need greeting at the door.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _arrive = AnimationController(
    vsync: this,
    duration: TideMotion.welcomeIn,
  );

  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _play());
  }

  Future<void> _play() async {
    if (!mounted) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _arrive.value = 1;
    } else {
      await _arrive.forward();
    }
    await Future<void>.delayed(TideMotion.welcomeHold);
    _leave();
  }

  void _leave() {
    if (_leaving || !mounted) return;
    _leaving = true;
    context.go(Routes.today);
  }

  @override
  void dispose() {
    _arrive.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = TideScope.of(context);
    final account = store.account;
    final firstName = account?.firstName;
    final isNew = store.welcomingNewAccount;
    final greeting = isNew ? 'Welcome' : 'Welcome back';

    return Scaffold(
      backgroundColor: TideColors.deepWater,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _leave,
        child: Stack(
          children: [
            const Positioned.fill(child: TideBackdrop(drift: true)),
            SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: AnimatedBuilder(
                    animation: _arrive,
                    builder: (context, _) {
                      final t = _arrive.value;
                      double span(double from, double to) =>
                          TideMotion.sheetCurve.transform(
                            ((t - from) / (to - from)).clamp(0.0, 1.0),
                          );
                      final portrait = span(0, 0.6);

                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Opacity(
                            opacity: portrait,
                            child: Transform.scale(
                              scale: 0.86 + 0.14 * portrait,
                              child: AccountAvatar(
                                name: account?.displayName ?? '',
                                avatarUrl: account?.avatarUrl,
                                size: 96,
                              ),
                            ),
                          ),
                          const SizedBox(height: 34),
                          // The greeting is the small line and the name is
                          // the headline: the name is the part that is new
                          // information. Without one, the greeting takes the
                          // headline itself rather than leaving a gap.
                          if (firstName != null) ...[
                            _Rise(
                              progress: span(0.2, 0.7),
                              lift: 8,
                              child: Text(
                                '$greeting,',
                                style: TideType.bodyMuted,
                              ),
                            ),
                            const SizedBox(height: 6),
                          ],
                          _Rise(
                            progress: span(0.3, 0.85),
                            lift: 14,
                            child: Text(
                              firstName ?? greeting,
                              style: TideType.screenTitle.copyWith(
                                fontSize: 40,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(height: 14),
                          _Rise(
                            progress: span(0.45, 1),
                            lift: 8,
                            child: Text(
                              isNew
                                  ? 'Your first loop starts today.'
                                  : 'Picking up where the loop left off.',
                              style: TideType.labelMuted,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fades in while rising the last few pixels into place.
class _Rise extends StatelessWidget {
  const _Rise({
    required this.progress,
    required this.lift,
    required this.child,
  });

  final double progress;
  final double lift;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: progress,
      child: Transform.translate(
        offset: Offset(0, lift * (1 - progress)),
        child: child,
      ),
    );
  }
}
