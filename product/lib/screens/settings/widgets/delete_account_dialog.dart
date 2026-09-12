import 'package:flutter/material.dart';

import '../../../services/auth/auth_service.dart';
import '../../../services/tide_scope.dart';
import '../../../theme/tide_colors.dart';
import '../../../theme/tide_elevation.dart';
import '../../../theme/tide_motion.dart';
import '../../../theme/tide_typography.dart';
import '../../../widgets/hold_to_fill.dart';
import '../../../widgets/tide_button.dart';
import '../../../widgets/tide_dialog.dart';

/// Asks, and then asks again with a hold, before the account is deleted.
///
/// Two gates on purpose, because this is the one action in Tide that cannot
/// be walked back. The row only opens this panel, which says in plain words
/// what goes; the hold inside it is the commit. A tap that reached the row
/// by accident meets a sentence, and a thumb resting on the panel meets a
/// fill that has to be held all the way across.
Future<void> confirmDeleteAccount(
  BuildContext context, {
  required String email,
}) {
  return showTideDialog<void>(
    context: context,
    builder: (context) => _DeleteAccountPanel(email: email),
  );
}

class _DeleteAccountPanel extends StatefulWidget {
  const _DeleteAccountPanel({required this.email});

  /// Passed in rather than read, so the sentence keeps its address while the
  /// panel leaves — by then the account it names has already gone.
  final String email;

  @override
  State<_DeleteAccountPanel> createState() => _DeleteAccountPanelState();
}

class _DeleteAccountPanelState extends State<_DeleteAccountPanel> {
  bool _deleting = false;
  String? _error;

  Future<void> _delete() async {
    final store = TideScope.read(context);
    final navigator = Navigator.of(context);
    setState(() {
      _deleting = true;
      _error = null;
    });

    try {
      await store.deleteAccount();
      // The router is already on its way to the farewell. Closing the
      // panel here lets it leave on its own exit; if the new page got there
      // first, the panel went with the old one and there is nothing to pop.
      if (mounted) navigator.pop();
    } on AuthFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _deleting = false;
        _error = _describe(failure);
      });
    }
  }

  static String _describe(AuthFailure failure) => switch (failure.problem) {
    AuthProblem.offline =>
      'Tide could not reach the server, so nothing was deleted. Check the '
          'connection and try again.',
    AuthProblem.rateLimited => 'Too many tries. Wait a minute, then try again.',
    _ => failure.detail ?? 'The account could not be deleted. Try again.',
  };

  @override
  Widget build(BuildContext context) {
    final who = widget.email.isEmpty ? 'this account' : widget.email;

    return PopScope(
      // Mid-request, leaving would only hide the outcome, not stop it.
      canPop: !_deleting,
      child: TideDialogPanel(
        title: 'Delete your account?',
        body:
            'This permanently deletes the Tide account for $who — its '
            'sign-in, its profile and any Google link — and signs this '
            'device out. It cannot be undone.',
        actions: [
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                _error!,
                style: TideType.labelMuted.copyWith(color: TideColors.coral),
              ),
            ),
          AnimatedOpacity(
            opacity: _deleting ? 0.4 : 1,
            duration: TideMotion.tabSwitch,
            child: TideDialogAction(
              label: 'Keep my account',
              tone: TideDialogTone.primary,
              onTap: () {
                if (!_deleting) Navigator.of(context).pop();
              },
            ),
          ),
          AnimatedSwitcher(
            duration: TideMotion.tabSwitch,
            child: _deleting
                ? const _Deleting(key: ValueKey('deleting'))
                : HoldToConfirmButton(
                    key: const ValueKey('hold'),
                    label: 'Hold to delete account',
                    holdingLabel: 'Keep holding to delete',
                    onConfirm: _delete,
                  ),
          ),
        ],
      ),
    );
  }
}

/// The hold button's shape, spinning, while the server does the deleting.
class _Deleting extends StatelessWidget {
  const _Deleting({super.key});

  @override
  Widget build(BuildContext context) {
    final color = TideColors.coral;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: TideElevation.radius12,
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TideSpinner(size: 16, strokeWidth: 2, color: color),
          const SizedBox(width: 10),
          Text(
            'Deleting account',
            style: TideType.button.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}
