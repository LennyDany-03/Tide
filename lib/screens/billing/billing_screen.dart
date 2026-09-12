import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../config/app_constants.dart';
import '../../config/app_routes.dart';
import '../../services/billing/billing_service.dart';
import '../../services/billing/entitlement.dart';
import '../../services/billing/payment_record.dart';
import '../../services/tide_scope.dart';
import '../../services/tide_store.dart';
import '../../theme/tide_colors.dart';
import '../../theme/tide_elevation.dart';
import '../../theme/tide_motion.dart';
import '../../theme/tide_typography.dart';
import '../../widgets/press_scale.dart';
import '../../widgets/tide_backdrop.dart';
import '../../widgets/tide_button.dart';
import '../../widgets/tide_surface.dart';
import 'widgets/cancel_plan_dialog.dart';
import 'widgets/receipt_row.dart';

/// Plan and receipts.
///
/// **No FutureBuilder, on purpose.** Nothing else in this app loads data in a
/// widget — every screen reads the store synchronously and draws whatever is
/// true this frame. So the receipts are fetched into the store and this reads
/// [TideStore.payments] and [TideStore.receiptsStatus] the same way Today
/// reads habits and sync status. The asynchrony is in the action.
///
/// The list is never emptied by a reload, which is what keeps the four states
/// down to something a person can follow: a refresh never flashes the rows
/// away, and a refresh that fails still shows the receipts that were already
/// there, with a line saying it could not update them.
class BillingScreen extends StatefulWidget {
  const BillingScreen({super.key});

  @override
  State<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen> {
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // After the frame, not during it: refreshReceipts notifies synchronously,
    // and notifying through TideScope while the tree is building throws.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) TideScope.read(context).refreshReceipts();
    });
  }

  Future<void> _resume() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await TideScope.read(context).resumePlan();
      if (mounted) setState(() => _busy = false);
    } on BillingFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = failure.detail ?? 'That did not go through. Try again.';
      });
    }
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
          RefreshIndicator(
            onRefresh: () => store.refreshReceipts(),
            color: TideColors.lantern,
            backgroundColor: TideColors.shelf,
            child: ListView(
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
                      child: Text('Billing', style: TideType.screenTitle),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.only(left: 48),
                  child: Text(
                    'Your plan, and every payment.',
                    style: TideType.labelMuted,
                  ),
                ),
                const SizedBox(height: 24),

                _PlanCard(
                  plan: plan,
                  busy: _busy,
                  error: _error,
                  onUpgrade: () => context.push(Routes.upgrade),
                  onViewPass: () => context.push(Routes.proPass),
                  onCancel: () =>
                      confirmCancelPlan(context, until: plan.periodEnd),
                  onResume: _resume,
                ),
                const SizedBox(height: 30),

                Row(
                  children: [
                    Expanded(
                      child: Text('Payments', style: TideType.sectionHeader),
                    ),
                    if (store.receiptsStatus == ReceiptsStatus.loading &&
                        store.payments.isNotEmpty)
                      TideSpinner(
                        size: 13,
                        strokeWidth: 1.6,
                        color: TideColors.silt,
                      ),
                  ],
                ),
                const SizedBox(height: 10),

                _Receipts(store: store),
              ],
            ),
          ),
          const Positioned(top: 0, left: 0, right: 0, child: TideTopScrim()),
        ],
      ),
    );
  }
}

/// The receipt list, in whichever of its four states is true.
class _Receipts extends StatelessWidget {
  const _Receipts({required this.store});

  final TideStore store;

  @override
  Widget build(BuildContext context) {
    final rows = store.payments;
    final status = store.receiptsStatus;

    // Nothing loaded yet and still working: placeholders rather than a
    // spinner on empty ground, so the shape of the screen does not jump when
    // the rows land.
    if (rows.isEmpty &&
        (status == ReceiptsStatus.unread || status == ReceiptsStatus.loading)) {
      return const _Placeholders();
    }

    if (rows.isEmpty && status == ReceiptsStatus.failed) {
      return _Notice(
        message: 'Your payments could not be loaded.',
        onRetry: store.refreshReceipts,
      );
    }

    if (rows.isEmpty) {
      return TideSurface(
        color: TideColors.shelf,
        padding: const EdgeInsets.fromLTRB(16, 22, 16, 22),
        child: Column(
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 22,
              color: TideColors.silt.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 10),
            Text(
              'No payments yet',
              style: TideType.body,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              'Anything you buy shows up here.',
              style: TideType.labelMuted,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Rows we have, plus a line saying they may be stale. The receipts
        // stay on screen — taking them away because a refresh failed would
        // punish somebody for a dropped connection.
        if (status == ReceiptsStatus.failed) ...[
          _Notice(
            message: 'Could not refresh.',
            onRetry: store.refreshReceipts,
            compact: true,
          ),
          const SizedBox(height: 10),
        ],
        TideSurface(
          color: TideColors.shelf,
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0)
                  Padding(
                    padding: const EdgeInsets.only(left: 60),
                    child: Container(height: 1, color: TideColors.hairline),
                  ),
                ReceiptRow(key: ValueKey(rows[i].id), record: rows[i]),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Rows in outline, while the real ones are on their way.
class _Placeholders extends StatelessWidget {
  const _Placeholders();

  @override
  Widget build(BuildContext context) {
    return TideSurface(
      color: TideColors.shelf,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < 3; i++) ...[
            if (i > 0)
              Padding(
                padding: const EdgeInsets.only(left: 60),
                child: Container(height: 1, color: TideColors.hairline),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: TideColors.bone.withValues(alpha: 0.05),
                      borderRadius: TideElevation.radius12,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      height: 10,
                      decoration: BoxDecoration(
                        color: TideColors.bone.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Something could not be loaded, and the way to try again.
class _Notice extends StatelessWidget {
  const _Notice({
    required this.message,
    required this.onRetry,
    this.compact = false,
  });

  final String message;
  final VoidCallback onRetry;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(14, compact ? 10 : 16, 14, compact ? 10 : 16),
      decoration: BoxDecoration(
        color: TideColors.bone.withValues(alpha: 0.04),
        borderRadius: TideElevation.radius12,
      ),
      child: Row(
        children: [
          Expanded(child: Text(message, style: TideType.labelMuted)),
          const SizedBox(width: 12),
          PressScale(
            onTap: onRetry,
            child: Text(
              'Retry',
              style: TideType.button.copyWith(
                color: TideColors.lantern,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The plan itself: what is held, until when, and the ways to change it.
class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.busy,
    required this.error,
    required this.onUpgrade,
    required this.onViewPass,
    required this.onCancel,
    required this.onResume,
  });

  final Entitlement plan;
  final bool busy;
  final String? error;
  final VoidCallback onUpgrade;
  final VoidCallback onViewPass;
  final VoidCallback onCancel;
  final VoidCallback onResume;

  /// Keyed off the status, never off `cancelledAt` — a refund sets that too,
  /// so it does not mean "the person cancelled".
  bool get _cancelled => plan.status == EntitlementStatus.cancelled;

  static String _date(DateTime when) =>
      '${when.day} ${AppConstants.monthNames[when.month - 1]} ${when.year}';

  @override
  Widget build(BuildContext context) {
    final end = plan.periodEnd;

    return TideSurface(
      color: TideColors.shelf,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      plan.isPro
                          ? '${AppConstants.appName} Pro'
                          : plan.lapsed
                          ? 'Your plan has ended'
                          : 'Free plan',
                      style: TideType.hero.copyWith(fontSize: 19),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      plan.isPro && end != null
                          ? '${plan.plan?.title ?? 'Pro'} · until ${_date(end)}'
                          : plan.lapsed && end != null
                          ? 'Ended ${_date(end)}'
                          : 'Up to ${AppConstants.freeHabitLimit} habits',
                      style: TideType.labelMuted,
                    ),
                  ],
                ),
              ),
              if (plan.isPro)
                Text(
                  '${plan.daysRemaining}d',
                  style: TideType.gauge(15, color: TideColors.lantern),
                ),
            ],
          ),

          if (_cancelled) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
              decoration: BoxDecoration(
                color: TideColors.lantern.withValues(alpha: 0.08),
                borderRadius: TideElevation.radius12,
              ),
              child: Text(
                'Cancelled. You keep Pro until '
                '${end == null ? 'the end of your period' : _date(end)}, '
                'and nothing will be charged.',
                style: TideType.label.copyWith(
                  color: TideColors.lantern,
                  height: 1.35,
                ),
              ),
            ),
          ],

          if (error != null) ...[
            const SizedBox(height: 12),
            Text(
              error!,
              style: TideType.label.copyWith(color: TideColors.coral),
            ),
          ],

          const SizedBox(height: 16),

          if (plan.isPro) ...[
            _Outlined(
              label: 'View my pass',
              icon: Icons.confirmation_number_outlined,
              onTap: onViewPass,
            ),
            const SizedBox(height: 10),
            if (_cancelled)
              _Outlined(
                label: busy ? 'Resuming…' : 'Resume Pro',
                icon: Icons.refresh_rounded,
                onTap: busy ? null : onResume,
              )
            else
              PressScale(
                onTap: onCancel,
                child: SizedBox(
                  height: 44,
                  child: Center(
                    child: Text(
                      'Cancel Pro',
                      style: TideType.button.copyWith(
                        color: TideColors.silt,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ),
          ] else
            TideButton(
              label: plan.lapsed ? 'Renew Pro' : 'Go Pro',
              onPressed: onUpgrade,
            ),
        ],
      ),
    );
  }
}

/// An outlined action — an invitation rather than the primary thing on screen,
/// the same shape `AccountCard` uses.
class _Outlined extends StatelessWidget {
  const _Outlined({required this.label, required this.icon, this.onTap});

  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onTap,
      enabled: onTap != null,
      child: AnimatedOpacity(
        opacity: onTap == null ? 0.5 : 1,
        duration: TideMotion.tabSwitch,
        child: Container(
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border.all(
              color: TideColors.lantern.withValues(alpha: 0.45),
            ),
            borderRadius: TideElevation.radius12,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 17, color: TideColors.lantern),
              const SizedBox(width: 9),
              Text(
                label,
                style: TideType.button.copyWith(color: TideColors.lantern),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
