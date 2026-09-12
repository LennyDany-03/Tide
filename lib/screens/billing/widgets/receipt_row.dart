import 'package:flutter/material.dart';

import '../../../config/app_constants.dart';
import '../../../services/billing/payment_record.dart';
import '../../../theme/tide_colors.dart';
import '../../../theme/tide_elevation.dart';
import '../../../theme/tide_typography.dart';

/// One payment, as a line.
///
/// The amount is the thing somebody is looking for, so it is the only figure
/// at full weight and it sits where the eye lands last on a left-to-right
/// scan. Everything else — plan, date, method — is muted supporting detail.
///
/// A refunded row is struck through rather than removed. Money that came back
/// is still part of the history, and a list that quietly dropped it would be
/// the one place in the app that edits the past.
class ReceiptRow extends StatelessWidget {
  const ReceiptRow({super.key, required this.record});

  final PaymentRecord record;

  static String _date(DateTime when) =>
      '${when.day} ${AppConstants.monthNames[when.month - 1]} ${when.year}';

  bool get _refunded => record.status == PaymentStatus.refunded;
  bool get _failed => record.status == PaymentStatus.failed;

  @override
  Widget build(BuildContext context) {
    // Coral only for a payment that did not go through — the app's one
    // colour for something having gone wrong. A refund is not a failure, so it
    // stays in the ordinary ink and says so in words.
    final tint = _failed ? TideColors.coral : TideColors.bone;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: (_failed ? TideColors.coral : TideColors.lantern)
                  .withValues(alpha: 0.12),
              borderRadius: TideElevation.radius12,
            ),
            child: Icon(
              _failed
                  ? Icons.close_rounded
                  : _refunded
                  ? Icons.undo_rounded
                  : Icons.check_rounded,
              size: 17,
              color: _failed ? TideColors.coral : TideColors.lantern,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  record.planLabel,
                  style: TideType.body.copyWith(color: tint),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  [
                    _date(record.createdAt),
                    if (record.methodLabel != null) record.methodLabel!,
                    if (_refunded) 'Refunded',
                    if (_failed) 'Failed',
                  ].join(' · '),
                  style: TideType.labelMuted,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            record.amountLabel,
            style: TideType.gauge(
              14,
              color: _failed ? TideColors.silt : TideColors.bone,
            ).copyWith(
              decoration: _refunded || _failed
                  ? TextDecoration.lineThrough
                  : null,
              decorationColor: TideColors.silt,
            ),
          ),
        ],
      ),
    );
  }
}

/// A payment the server has taken but not yet confirmed.
///
/// UPI can take a minute and the app is often closed before the answer lands,
/// so `billing_snapshot` has nothing to show — an `authorized` order is not a
/// receipt yet, and widening the query to include one would make it a lie.
/// This row exists so the gap does not read as the money having vanished.
class PendingReceiptRow extends StatelessWidget {
  const PendingReceiptRow({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: TideColors.lantern.withValues(alpha: 0.12),
              borderRadius: TideElevation.radius12,
            ),
            child: Icon(
              Icons.hourglass_top_rounded,
              size: 16,
              color: TideColors.lantern,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Confirming your payment',
                  style: TideType.body.copyWith(color: TideColors.lantern),
                ),
                const SizedBox(height: 3),
                Text(
                  'It appears here once the bank confirms it. '
                  'Do not pay again.',
                  style: TideType.labelMuted,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
