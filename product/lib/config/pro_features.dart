import 'package:flutter/foundation.dart';

import 'app_constants.dart';

/// Everything Pro unlocks, named once.
///
/// The paywall used to hold this list as four hardcoded rows of copy, and the
/// gates that enforced it lived in four unrelated screens — which is how a
/// paywall ends up promising "full history" that nothing restricts, and how a
/// restriction ends up in the app that the paywall never mentions. Both of
/// those are worse than having no paywall: one is a false promise and the
/// other is a wall with no door drawn on it.
///
/// So this is the single list. [ProFeatures.all] is what the upgrade sheet
/// draws, and `store.locked(...)` is what every gate asks. Adding a Pro
/// feature means adding a case here; it cannot be done in a widget.
enum ProFeature {
  /// More than [AppConstants.freeHabitLimit] active habits.
  unlimitedHabits,

  /// History and heatmaps further back than [AppConstants.freeHistoryDays].
  fullHistory,

  /// A freeze allowance above the free two per habit.
  carryOverFreezes,

  /// Saving and sharing a milestone card.
  shareCards,

  /// Every palette but Midnight.
  palettes,

  /// The Sunday evening recap.
  weeklyRecap,
}

/// One line of the paywall, and one gate in the app. The same object, because
/// they must never say different things.
@immutable
class ProFeatureSpec {
  const ProFeatureSpec({
    required this.label,
    required this.freeAllowance,
    required this.blurb,
  });

  /// What the paywall row says.
  final String label;

  /// What the free plan gets instead, drawn beside it. An em dash means
  /// nothing at all.
  final String freeAllowance;

  /// What a locked control says when it is tapped.
  final String blurb;
}

abstract final class ProFeatures {
  static const Map<ProFeature, ProFeatureSpec> all = {
    ProFeature.unlimitedHabits: ProFeatureSpec(
      label: 'Unlimited habits',
      freeAllowance: '${AppConstants.freeHabitLimit} free',
      blurb: 'Pro keeps room for every loop.',
    ),
    ProFeature.fullHistory: ProFeatureSpec(
      label: 'Full history and heatmaps',
      freeAllowance: '${AppConstants.freeHistoryDays} days',
      blurb: 'Pro opens every month you have logged.',
    ),
    ProFeature.carryOverFreezes: ProFeatureSpec(
      label: 'Freezes that carry over',
      freeAllowance: '${AppConstants.freeFreezeAllowance} / habit',
      blurb:
          'Pro raises the allowance to '
          '${AppConstants.maxFreezeAllowance} a habit.',
    ),
    ProFeature.shareCards: ProFeatureSpec(
      label: 'Shareable milestone cards',
      freeAllowance: '—',
      blurb: 'Pro turns a milestone into a card you can send.',
    ),
    ProFeature.palettes: ProFeatureSpec(
      label: 'Every palette',
      freeAllowance: 'Midnight',
      blurb: 'Pro opens the other four.',
    ),
    ProFeature.weeklyRecap: ProFeatureSpec(
      label: 'Sunday recap',
      freeAllowance: '—',
      blurb: 'Pro sends the week in one line.',
    ),
  };

  static ProFeatureSpec of(ProFeature feature) => all[feature]!;

  /// The order the paywall lists them in. Habits first because it is what
  /// brought most people to the sheet — the paywall is contextual and the free
  /// ceiling is what triggers it.
  static const List<ProFeature> headline = [
    ProFeature.unlimitedHabits,
    ProFeature.fullHistory,
    ProFeature.carryOverFreezes,
    ProFeature.palettes,
    ProFeature.shareCards,
  ];
}
