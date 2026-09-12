import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../config/app_routes.dart';
import '../../config/plan_catalog.dart';
import '../../config/pro_features.dart';
import '../../services/billing/billing_service.dart';
import '../../services/tide_scope.dart';
import '../../services/tide_store.dart';
import '../../theme/tide_colors.dart';
import '../../theme/tide_typography.dart';
import '../../widgets/stagger_list.dart';
import '../../widgets/tide_button.dart';
import '../../widgets/tide_sheet.dart';
import 'widgets/checkout_notice.dart';
import 'widgets/feature_row.dart';
import 'widgets/pricing_tier_card.dart';

/// The paywall.
///
/// Contextual by construction: it is pushed at the moment the free ceiling
/// actually blocks something, so the headline can name what just happened
/// rather than making a general pitch. It is a dismissible sheet, the ×
/// carries plain press feedback and nothing else, and the copy under the CTA
/// says the data stays yours — the way out is as easy as the way in.
///
/// **What changed when the payment became real.** It used to wait 700ms and
/// set a bool. Three things follow from money actually moving:
///
///   - The feature list is generated from [ProFeatures], which is the same
///     list the gates read. A paywall that promises something nothing
///     enforces is a lie in one direction; a gate the paywall never mentions
///     is a lie in the other.
///   - The tiers are the two plans on sale, and the price on the button is
///     the one the *server* quoted for the order, not the one this build
///     shipped with.
///   - Not every outcome is success or failure. A cancelled sheet says
///     nothing at all, and a payment that has gone through but not been
///     confirmed says so and leaves the sheet open — the plan arrives on its
///     own through the billing stream, and the sheet turns Pro under the
///     person's thumb rather than telling them to try paying again.
class UpgradeSheet extends StatefulWidget {
  const UpgradeSheet({super.key});

  @override
  State<UpgradeSheet> createState() => _UpgradeSheetState();
}

class _UpgradeSheetState extends State<UpgradeSheet> {
  BillingPlan _plan = PlanCatalog.preferred;
  TideButtonPhase _phase = TideButtonPhase.idle;
  BillingFailure? _failure;

  bool get _busy => _phase != TideButtonPhase.idle;

  Future<void> _purchase() async {
    if (_busy) return;
    setState(() {
      _phase = TideButtonPhase.busy;
      _failure = null;
    });

    final store = TideScope.read(context);
    try {
      await store.purchase(_plan);
      if (!mounted) return;
      setState(() => _phase = TideButtonPhase.done);

      // Long enough for the checkmark to land before the sheet gives way.
      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;

      // Replaced rather than popped-then-pushed. The sheet is already on the
      // root navigator, so swapping it for the welcome avoids a frame of
      // whatever was underneath showing through — and backing out of the
      // welcome still returns wherever the paywall was opened from.
      context.pushReplacement(Routes.proWelcome);
    } on BillingFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _phase = TideButtonPhase.idle;
        // Closing the payment sheet is a decision, not an error. Putting a
        // red line on screen for it would tell somebody off for changing
        // their mind.
        _failure = failure.silent ? null : failure;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _phase = TideButtonPhase.idle;
        _failure = BillingFailure(BillingProblem.unknown, error.toString());
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = TideScope.of(context);
    final atLimit = !store.canAddHabit;
    final pro = store.isPro;

    return TideSheet(
      eyebrow: 'Tide Pro',
      title: pro
          ? 'You are on Pro'
          : atLimit
          ? 'You have filled your five free habits'
          : 'Room for every loop',
      onDismiss: () => context.pop(),
      maxHeightFactor: 0.9,
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_failure != null) ...[
            CheckoutNotice(failure: _failure!),
            const SizedBox(height: 12),
          ],

          // A plain primary button. The CTA used to breathe on a slow
          // repeating glow; a button that pulses at you is applying
          // pressure, which is not the relationship this screen wants, and
          // it was the only looping animation on the sheet.
          TideButton(
            label: _label(store.isPro, store.entitlement.lapsed),
            phase: _phase,
            enabled: store.billing.canPay,
            onPressed: store.billing.canPay ? _purchase : null,
          ),
          const SizedBox(height: 12),
          Text(
            _footnote(store.billing.canPay, pro),
            style: TideType.labelMuted.copyWith(fontSize: 11.5),
            textAlign: TextAlign.center,
          ),
        ],
      ),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
        children: [
          Text(
            pro
                ? 'Everything below is open. Paying again adds to the end of '
                      'what you already have.'
                : 'Unlimited habits, full history, and freezes that carry over.',
            style: TideType.bodyMuted,
          ),
          const SizedBox(height: 24),

          // Staggered in, exactly like Home's habit list. Generated from the
          // same catalogue the gates read, so the two cannot drift.
          StaggerColumn(
            spacing: 16,
            children: [
              for (final feature in ProFeatures.headline)
                FeatureRow(
                  label: ProFeatures.of(feature).label,
                  freeLimit: ProFeatures.of(feature).freeAllowance,
                ),
            ],
          ),
          const SizedBox(height: 26),

          // Both tiers stay the same height whichever is selected.
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final plan in PlanCatalog.all) ...[
                  if (plan != PlanCatalog.all.first) const SizedBox(width: 10),
                  Expanded(
                    child: PricingTierCard(
                      title: plan.title,
                      price: plan.price,
                      note: plan.note,
                      // Only on the yearly card, and only as a figure: a
                      // badge on both would be decoration rather than
                      // information.
                      badge: plan.interval == PlanInterval.year
                          ? 'Save ${PlanCatalog.yearlySavingPercent}%'
                          : null,
                      selected: plan.id == _plan.id,
                      onTap: _busy ? null : () => setState(() => _plan = plan),
                    ),
                  ),
                ],
              ],
            ),
          ),

          if (_plan.interval == PlanInterval.year) ...[
            const SizedBox(height: 10),
            Text(
              'Works out at ${_plan.equivalentMonthly} a month.',
              style: TideType.labelMuted.copyWith(fontSize: 11.5),
              textAlign: TextAlign.center,
            ),
          ],

          if (pro) ...[
            const SizedBox(height: 16),
            Text(
              _renewalLine(store),
              style: TideType.label.copyWith(color: TideColors.lantern),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  String _label(bool pro, bool lapsed) {
    final price = _plan.perPeriod;
    if (pro) return 'Extend Pro — $price';
    if (lapsed) return 'Renew Pro — $price';
    return 'Start Pro — $price';
  }

  /// The line under the button, and the only place the *shape* of the charge
  /// is stated before somebody agrees to it.
  ///
  /// It has to name three things for an auto-debit, because a mandate nobody
  /// was told about is a chargeback: what is taken, how often, and how to
  /// stop it. A plan that renews cannot be sold with the old prepaid line —
  /// "ends on its own, nothing renews" was true of every payment Tide had
  /// taken until auto-pay, and is now the opposite of what happens.
  String _footnote(bool canPay, bool pro) {
    if (!canPay) return 'Tide Pro can be bought in the phone app.';
    if (!_plan.autoRenews) {
      return pro
          ? 'Payments add to the end of your period. No auto-renewal.'
          : 'Ends on its own — nothing renews. Your data stays yours.';
    }
    final every = _plan.interval == PlanInterval.month ? 'month' : 'year';
    return pro
        ? '${_plan.price} every $every from the end of your period. '
              'Cancel any time.'
        : '${_plan.price} every $every, automatically. '
              'Cancel any time in Settings.';
  }

  static String _renewalLine(TideStore store) {
    final plan = store.entitlement;
    final days = plan.daysRemaining;
    if (days <= 0) return 'You are already on Pro.';
    if (plan.autoRenews) {
      return 'Pro, renewing in $days ${days == 1 ? 'day' : 'days'}.';
    }
    return 'Pro for $days more ${days == 1 ? 'day' : 'days'}.';
  }
}
