import 'package:flutter/material.dart';

import '../../../config/app_constants.dart';
import '../../../services/billing/billing_service.dart';
import '../../../services/tide_scope.dart';
import '../../../theme/tide_colors.dart';
import '../../../theme/tide_motion.dart';
import '../../../theme/tide_typography.dart';
import '../../../widgets/hold_to_fill.dart';
import '../../../widgets/tide_dialog.dart';
import '../../../widgets/tide_button.dart';

/// Cancelling Pro, and being honest about what that means.
///
/// **The copy is the hard part, not the code.** Nothing about a Tide plan
/// auto-renews — there is no mandate and no card on file — so cancelling
/// cannot stop a charge, because no charge is coming. The two things it
/// genuinely does are worth saying before the hold rather than after it:
///
///   1. Every day already paid for is kept. The date is named, so nobody has
///      to take that on trust.
///   2. The app stops offering to renew.
///
/// Anything vaguer than that produces the support mail this dialog exists to
/// prevent — "I cancelled, am I still being charged?" — and the honest answer
/// is easier to write than the evasive one.
///
/// Held rather than tapped, like every other control in Tide that takes
/// something away.
Future<void> confirmCancelPlan(BuildContext context, {required DateTime? until}) {
  return showTideDialog<void>(
    context: context,
    builder: (context) => _CancelPanel(until: until),
  );
}

class _CancelPanel extends StatefulWidget {
  const _CancelPanel({required this.until});

  final DateTime? until;

  @override
  State<_CancelPanel> createState() => _CancelPanelState();
}

class _CancelPanelState extends State<_CancelPanel> {
  bool _cancelling = false;
  String? _error;

  String get _date {
    final when = widget.until;
    if (when == null) return 'the end of your period';
    return '${when.day} ${AppConstants.monthNames[when.month - 1]} ${when.year}';
  }

  Future<void> _cancel() async {
    // Captured before the await: the panel can be popped out from under this.
    final store = TideScope.read(context);
    final navigator = Navigator.of(context);
    setState(() {
      _cancelling = true;
      _error = null;
    });
    try {
      await store.cancelPlan();
      if (mounted) navigator.pop();
    } on BillingFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _cancelling = false;
        _error = switch (failure.problem) {
          BillingProblem.offline =>
            'No connection. Nothing has changed — try again when you are back.',
          _ => failure.detail ?? 'That did not go through. Try again.',
        };
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_cancelling,
      child: TideDialogPanel(
        title: 'Cancel Tide Pro?',
        body:
            'Pro stays on until $_date — you keep every day you have paid '
            'for. Nothing is charged either way; Tide never renews on its '
            'own. Cancelling just stops us offering.',
        actions: [
          if (_error != null) ...[
            Text(
              _error!,
              style: TideType.label.copyWith(color: TideColors.coral),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
          ],
          AnimatedOpacity(
            opacity: _cancelling ? 0.4 : 1,
            duration: TideMotion.tabSwitch,
            child: TideDialogAction(
              label: 'Keep Pro',
              tone: TideDialogTone.primary,
              onTap: () {
                if (!_cancelling) Navigator.of(context).pop();
              },
            ),
          ),
          AnimatedSwitcher(
            duration: TideMotion.tabSwitch,
            child: _cancelling
                ? SizedBox(
                    key: const ValueKey('cancelling'),
                    height: 52,
                    child: Center(
                      child: TideSpinner(
                        size: 18,
                        strokeWidth: 2,
                        color: TideColors.coral,
                      ),
                    ),
                  )
                : HoldToConfirmButton(
                    key: const ValueKey('hold'),
                    label: 'Hold to cancel',
                    holdingLabel: 'Keep holding to cancel',
                    onConfirm: _cancel,
                  ),
          ),
        ],
      ),
    );
  }
}
