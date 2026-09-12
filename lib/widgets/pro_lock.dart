import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../config/app_routes.dart';
import '../config/pro_features.dart';
import '../theme/tide_colors.dart';
import '../theme/tide_typography.dart';

/// The mark on something Pro holds, and the way through to the paywall.
///
/// Two rules this exists to keep, both learned from paywalls that get them
/// wrong:
///
///   **A locked control is visible, not absent.** Hiding what Pro unlocks
///   makes the free app look like the whole app, and then the paywall arrives
///   as a surprise. Every gate in Tide draws the thing, marks it, and lets it
///   be tapped — the tap is what opens the sheet.
///
///   **The tap goes to the paywall, never to a dead end.** There is no
///   "upgrade to use this" toast anywhere in the app. Tapping a locked
///   control is a request, and the answer to it is the sheet that takes the
///   payment.
class ProBadge extends StatelessWidget {
  const ProBadge({super.key, this.compact = false});

  /// Tighter, for a badge sitting inside a row rather than beside a title.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: compact
          ? const EdgeInsets.symmetric(horizontal: 6, vertical: 2)
          : const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: TideColors.lantern.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.lock_outline_rounded,
            size: compact ? 10 : 11,
            color: TideColors.lantern,
          ),
          const SizedBox(width: 4),
          Text(
            'Pro',
            style: TideType.gauge(compact ? 9.5 : 10.5, color: TideColors.lantern),
          ),
        ],
      ),
    );
  }
}

/// Opens the paywall because [feature] was reached for.
///
/// One function rather than a `context.push(Routes.upgrade)` in nine places,
/// so every gate arrives at the same sheet by the same route — and so there
/// is exactly one thing to change the day the paywall learns to open on the
/// feature that sent somebody to it.
void askForPro(BuildContext context, ProFeature feature) {
  context.push(Routes.upgrade);
}

/// What a locked control says underneath itself.
///
/// Drawn from the same catalogue the paywall's rows come from, so the
/// sentence beside a locked palette and the line on the sheet cannot come to
/// disagree about what Pro includes.
class ProHint extends StatelessWidget {
  const ProHint({super.key, required this.feature, this.align});

  final ProFeature feature;
  final TextAlign? align;

  @override
  Widget build(BuildContext context) {
    return Text(
      ProFeatures.of(feature).blurb,
      style: TideType.labelMuted.copyWith(
        fontSize: 11.5,
        color: TideColors.lantern.withValues(alpha: 0.8),
      ),
      textAlign: align,
    );
  }
}
