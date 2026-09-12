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
/// **The copy is the hard part, not the code, and it is now two pieces of
/// copy.** What cancelling does depends on what is paying:
///
///   * On a **mandate**, there is a real charge to stop, and stopping it is
///     the point. The dialog says when the last debit would have been, so the
///     answer to "did it work" is on screen rather than in an inbox.
///   * On a **prepaid period**, nothing is coming either way, and saying
///     "you won't be charged again" would imply a charge had been stopped. All
///     it does is make the app stop offering to renew.
///
/// Both versions name the date Pro runs to, because that is the fact somebody
/// is actually worried about, and both are worth saying *before* the hold
/// rather than after it. Anything vaguer produces the support mail this dialog
/// exists to prevent — "I cancelled, am I still being charged?"
///
/// Held rather than tapped, like every other control in Tide that takes
/// something away.
Future<void> confirmCancelPlan(
  BuildContext context, {
  required DateTime? until,
  bool autoRenews = false,
}) {
  return showTideDialog<void>(
    context: context,
    builder: (context) => _CancelPanel(until: until, autoRenews: autoRenews),
  );
}

class _CancelPanel extends StatefulWidget {
  const _CancelPanel({required this.until, required this.autoRenews});

  final DateTime? until;

  /// Whether a standing instruction is behind this plan. Decides the copy, and
  /// nothing else: the call is the same either way, and which of the two
  /// things it does is settled on the server.
  final bool autoRenews;

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
        body: widget.autoRenews
            ? 'Nothing more will be taken. Pro stays on until $_date — the '
                  'time you have already paid for is yours — and the '
                  'renewal that would have been charged then is cancelled.'
            : 'Pro stays on until $_date — you keep every day you have paid '
                  'for. Nothing is charged either way; this plan never '
                  'renewed on its own. Cancelling just stops us offering.',
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
