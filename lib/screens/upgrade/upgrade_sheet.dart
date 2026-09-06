import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../config/app_constants.dart';
import '../../services/tide_scope.dart';
import '../../theme/tide_colors.dart';
import '../../theme/tide_typography.dart';
import '../../widgets/stagger_list.dart';
import '../../widgets/tide_button.dart';
import '../../widgets/tide_sheet.dart';
import 'widgets/feature_row.dart';
import 'widgets/pricing_tier_card.dart';

/// The paywall.
///
/// Contextual by construction: it is pushed at the moment the free ceiling
/// actually blocks a new habit, so the headline can name what just
/// happened rather than making a general pitch. It is a dismissible sheet,
/// the × carries plain press feedback and nothing else, and the copy under
/// the CTA says the data stays yours — the way out is as easy as the way
/// in.
class UpgradeSheet extends StatefulWidget {
  const UpgradeSheet({super.key});

  @override
  State<UpgradeSheet> createState() => _UpgradeSheetState();
}

class _UpgradeSheetState extends State<UpgradeSheet> {
  bool _lifetime = false;
  TideButtonPhase _phase = TideButtonPhase.idle;

  Future<void> _purchase() async {
    setState(() => _phase = TideButtonPhase.busy);
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;

    TideScope.read(context).setPreference(isPro: true);
    setState(() => _phase = TideButtonPhase.done);

    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final store = TideScope.of(context);
    final atLimit = !store.canAddHabit;

    return TideSheet(
      eyebrow: 'Tide Pro',
      title: atLimit
          ? 'You have filled your five free habits'
          : 'Room for every loop',
      onDismiss: () => context.pop(),
      maxHeightFactor: 0.88,
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // A plain primary button. The CTA used to breathe on a slow
          // repeating glow; a button that pulses at you is applying
          // pressure, which is not the relationship this screen wants, and
          // it was the only looping animation on the sheet.
          TideButton(
            label: _lifetime ? 'Start Pro — \$39 once' : 'Start Pro — \$3/mo',
            phase: _phase,
            onPressed: _purchase,
          ),
          const SizedBox(height: 12),
          Text(
            'Cancel any time. Your data stays yours.',
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
            'Unlimited habits, full history, and freezes that carry over.',
            style: TideType.bodyMuted,
          ),
          const SizedBox(height: 24),

          // Staggered in, exactly like Home's habit list.
          StaggerColumn(
            spacing: 16,
            children: const [
              FeatureRow(label: 'Unlimited habits', freeLimit: '5 free'),
              FeatureRow(
                label: 'Full history & heatmaps',
                freeLimit: '${AppConstants.freeHistoryDays} days',
              ),
              FeatureRow(label: 'Freezes that carry over', freeLimit: '2 / mo'),
              FeatureRow(label: 'Shareable milestone cards', freeLimit: '—'),
            ],
          ),
          const SizedBox(height: 26),

          // Both tiers stay the same height whichever is selected.
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: PricingTierCard(
                    title: 'Monthly',
                    price: r'$3',
                    note: 'billed monthly',
                    selected: !_lifetime,
                    onTap: () => setState(() => _lifetime = false),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: PricingTierCard(
                    title: 'Lifetime',
                    price: r'$39',
                    note: 'one payment',
                    selected: _lifetime,
                    onTap: () => setState(() => _lifetime = true),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          if (store.isPro)
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Text(
                'You are already on Pro.',
                style: TideType.label.copyWith(color: TideColors.lantern),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }
}
