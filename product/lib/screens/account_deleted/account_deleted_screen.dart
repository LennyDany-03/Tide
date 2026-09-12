import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../config/app_routes.dart';
import '../../services/tide_scope.dart';
import '../../theme/tide_colors.dart';
import '../../theme/tide_motion.dart';
import '../../theme/tide_typography.dart';
import '../../widgets/rise.dart';
import '../../widgets/tide_backdrop.dart';
import '../../widgets/tide_button.dart';
import '../../widgets/tide_tick.dart';

/// The last thing Tide says to an account: that it is gone.
///
/// Deleting used to end on the pop-up vanishing and the account form
/// appearing, which left the most consequential action in the app
/// confirmed by nothing more than a screen changing. Somebody who has just
/// held a button down to destroy something should be told, plainly, that it
/// worked.
///
/// It is the welcome's other end. The same ground and the same rise, with
/// the code screen's tick in place of the portrait — the app's one way of
/// saying "that is done". Unlike the welcome it does not move on by itself:
/// there is nothing after it to hurry towards, and a confirmation that
/// leaves before it is read has not confirmed anything. "Done" goes to the
/// account form.
///
/// Reached only through the router's guard, and only while the store still
/// holds the address that was deleted.
class AccountDeletedScreen extends StatefulWidget {
  const AccountDeletedScreen({super.key});

  @override
  State<AccountDeletedScreen> createState() => _AccountDeletedScreenState();
}

class _AccountDeletedScreenState extends State<AccountDeletedScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _arrive = AnimationController(
    vsync: this,
    duration: TideMotion.farewell,
  );

  /// The tick takes the first stretch of the sequence, on its own clock from
  /// [TideTick.start]; the words rise in as it closes.
  late final Animation<double> _tick = _arrive.drive(
    Tween<double>(
      begin: TideTick.start,
      end: 1,
    ).chain(CurveTween(curve: const Interval(0, 0.7))),
  );

  /// Read once: leaving clears it from the store, and the sentence must not
  /// go blank on the way out.
  String _email = '';

  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    _email = TideScope.read(context).deletedAccountEmail ?? '';
    WidgetsBinding.instance.addPostFrameCallback((_) => _play());
  }

  void _play() {
    if (!mounted) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _arrive.value = 1;
    } else {
      _arrive.forward();
    }
  }

  void _leave() {
    if (_leaving || !mounted) return;
    _leaving = true;
    TideScope.read(context).acknowledgeDeletion();
    context.go(Routes.auth);
  }

  @override
  void dispose() {
    _arrive.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Back has nowhere to return to — the account it came from is gone —
      // so it means the same as Done.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        backgroundColor: TideColors.deepWater,
        body: Stack(
          children: [
            const Positioned.fill(child: TideBackdrop(drift: true)),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(28, 0, 28, 24),
                child: AnimatedBuilder(
                  animation: _arrive,
                  builder: (context, _) {
                    final t = _arrive.value;
                    double span(double from, double to) =>
                        TideMotion.sheetCurve.transform(
                          ((t - from) / (to - from)).clamp(0.0, 1.0),
                        );
                    final done = span(0.7, 1);

                    return Column(
                      children: [
                        Expanded(
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TideTickMark(progress: _tick, size: 104),
                                const SizedBox(height: 36),
                                Rise(
                                  progress: span(0.45, 0.8),
                                  lift: 14,
                                  child: Text(
                                    'Account deleted',
                                    style: TideType.screenTitle,
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Rise(
                                  progress: span(0.55, 0.9),
                                  lift: 8,
                                  child: _sentence(),
                                ),
                                const SizedBox(height: 10),
                                Rise(
                                  progress: span(0.62, 0.95),
                                  lift: 6,
                                  child: Text(
                                    'That address is free to sign up with '
                                    'again, whenever you like.',
                                    style: TideType.labelMuted,
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Rise(
                          progress: done,
                          lift: 10,
                          child: IgnorePointer(
                            ignoring: done == 0,
                            child: TideButton(label: 'Done', onPressed: _leave),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sentence() {
    if (_email.isEmpty) {
      return Text(
        'Your account has been deleted successfully.',
        style: TideType.bodyMuted,
        textAlign: TextAlign.center,
      );
    }
    return Text.rich(
      TextSpan(
        style: TideType.bodyMuted,
        children: [
          const TextSpan(text: 'The Tide account for '),
          TextSpan(
            text: _email,
            style: TideType.body.copyWith(color: TideColors.bone),
          ),
          const TextSpan(text: ' has been deleted successfully.'),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}
