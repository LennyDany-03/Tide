import 'package:flutter/material.dart';

import '../../../services/billing/billing_service.dart';
import '../../../theme/tide_colors.dart';
import '../../../theme/tide_elevation.dart';
import '../../../theme/tide_motion.dart';
import '../../../theme/tide_typography.dart';

/// What went wrong with a payment, said in one line above the button.
///
/// Three tones rather than one, because a payment sheet that draws every
/// outcome in the same alarming red teaches people that the alarming red
/// means nothing:
///
///   - **Waiting** (lantern). The money moved and the confirmation has not
///     landed. Nothing is wrong, nothing needs doing, and above all nobody
///     should pay again — so this one never offers a retry.
///   - **Refused** (coral). The bank said no, or the network did. Try again.
///   - **Stuck** (coral, no retry). The signature did not check out or the
///     amount was wrong. Paying again would fail the same way; this is for
///     support, not for a second attempt.
///
/// There is no case for [BillingProblem.cancelled] here at all. The sheet
/// never builds this widget for it: closing a payment sheet is a decision,
/// and answering it with a notice would be telling somebody off for changing
/// their mind.
class CheckoutNotice extends StatelessWidget {
  const CheckoutNotice({super.key, required this.failure});

  final BillingFailure failure;

  bool get _waiting => failure.problem == BillingProblem.pending;

  Color get _tint => _waiting ? TideColors.lantern : TideColors.coral;

  IconData get _mark => switch (failure.problem) {
    BillingProblem.pending => Icons.hourglass_top_rounded,
    BillingProblem.offline => Icons.cloud_off_rounded,
    BillingProblem.unsupportedPlatform => Icons.phone_iphone_rounded,
    _ => Icons.error_outline_rounded,
  };

  String get _message {
    // Razorpay's own wording for a declined card is better than anything
    // written here, so it is used where there is one. Everything else gets a
    // sentence that says what to do rather than what happened.
    final detail = failure.detail;
    return switch (failure.problem) {
      BillingProblem.pending =>
        'Payment received. Pro opens as soon as it is confirmed — '
            'you do not need to pay again.',
      BillingProblem.offline =>
        'No connection. Nothing was charged; try again when you are back.',
      BillingProblem.unsupportedPlatform =>
        'Tide Pro can be bought in the phone app.',
      BillingProblem.unavailable =>
        'Payments are not set up on this build yet.',
      BillingProblem.rejected =>
        'That payment could not be verified. Nothing has been charged — '
            'get in touch if money has left your account.',
      _ =>
        detail == null || detail.isEmpty
            ? 'The payment did not go through. Nothing was charged.'
            : detail,
    };
  }

  @override
  Widget build(BuildContext context) {
    // Arrives on the same short rise the rest of the app uses rather than
    // appearing between two frames: a line of text that materialises under a
    // button reads as a rendering fault. Keyed on the problem so a second,
    // different outcome plays the move again instead of swapping the words
    // silently.
    return TweenAnimationBuilder<double>(
      key: ValueKey(failure.problem),
      tween: Tween<double>(begin: 0, end: 1),
      duration: TideMotion.sheetIn,
      curve: TideMotion.sheetCurve,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, 8 * (1 - t)), child: child),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: _tint.withValues(alpha: 0.10),
          borderRadius: TideElevation.radius12,
          border: Border.all(color: _tint.withValues(alpha: 0.28)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(_mark, size: 16, color: _tint),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _message,
                style: TideType.label.copyWith(color: _tint, height: 1.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
