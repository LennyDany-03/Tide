import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../config/app_constants.dart';
import '../../services/tide_scope.dart';
import '../../theme/tide_colors.dart';
import '../../theme/tide_motion.dart';
import '../../theme/tide_typography.dart';
import '../../widgets/press_scale.dart';
import '../../widgets/tide_backdrop.dart';
import '../pro_welcome/widgets/pro_ticket.dart';

/// The pass, kept.
///
/// The welcome sequence hands the ticket over in about four seconds and then
/// it is gone — which would make the most deliberately-drawn object in the app
/// something almost nobody sees twice. A pass you can only ever glimpse is not
/// really a pass, so it lives here as well, reachable from Billing.
///
/// Tapping it runs the sheen again. That is the whole interaction, and it is
/// the reason the sheen was built as a parameter rather than as a loop: the
/// light moves when somebody asks it to.
class ProPassScreen extends StatefulWidget {
  const ProPassScreen({super.key});

  @override
  State<ProPassScreen> createState() => _ProPassScreenState();
}

class _ProPassScreenState extends State<ProPassScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sheen = AnimationController(
    vsync: this,
    duration: TideMotion.proSheen,
  )..forward();

  @override
  void dispose() {
    _sheen.dispose();
    super.dispose();
  }

  void _replay() {
    if (_sheen.isAnimating) return;
    _sheen.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final store = TideScope.of(context);
    final plan = store.entitlement;

    return Scaffold(
      backgroundColor: TideColors.deepWater,
      body: Stack(
        children: [
          const Positioned.fill(child: TideBackdrop()),
          ListView(
            padding: EdgeInsets.fromLTRB(
              20,
              MediaQuery.paddingOf(context).top + 16,
              20,
              40 + MediaQuery.paddingOf(context).bottom,
            ),
            children: [
              Row(
                children: [
                  PressScale(
                    onTap: () => context.pop(),
                    child: SizedBox(
                      width: 38,
                      height: 38,
                      child: Icon(
                        Icons.arrow_back_rounded,
                        size: 21,
                        color: TideColors.bone,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('Your pass', style: TideType.screenTitle),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(left: 48),
                child: Text(
                  plan.isPro
                      ? '${AppConstants.appName} Pro, in your name.'
                      : 'This pass has expired.',
                  style: TideType.labelMuted,
                ),
              ),
              const SizedBox(height: 28),

              PressScale(
                onTap: _replay,
                scale: 0.99,
                child: AnimatedBuilder(
                  animation: _sheen,
                  builder: (context, _) => ProTicket(
                    entitlement: plan,
                    holderName: store.accountName,
                    // Whole from the first frame. This is not an arrival — the
                    // arrival happened once, on the welcome, and replaying it
                    // every time the screen opens would cheapen that.
                    sheen: TideMotion.proSheenCurve.transform(_sheen.value),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              Text(
                'Tap the pass to catch the light.',
                style: TideType.labelMuted.copyWith(fontSize: 11.5),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          const Positioned(top: 0, left: 0, right: 0, child: TideTopScrim()),
        ],
      ),
    );
  }
}
