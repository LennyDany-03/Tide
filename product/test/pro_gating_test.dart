import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tide/config/app_constants.dart';
import 'package:tide/config/plan_catalog.dart';
import 'package:tide/config/pro_features.dart';
import 'package:tide/services/auth/demo_auth_service.dart';
import 'package:tide/services/billing/demo_billing_service.dart';
import 'package:tide/services/device_flags.dart';
import 'package:tide/services/models/habit.dart';
import 'package:tide/services/models/tide_glyph.dart';
import 'package:tide/services/tide_store.dart';

/// What the free plan can reach, and what Pro opens.
///
/// Every gate in the app asks `store.locked(...)`, so this file is the whole
/// of the enforcement side. The promise side — the rows the paywall draws —
/// comes out of the same [ProFeatures] catalogue, and the last group here is
/// what keeps a feature from being promised and never enforced, or enforced
/// and never mentioned.
void main() {
  TideStore free() => TideStore(
    auth: DemoAuthService(signedIn: true),
    flags: DeviceFlags.memory(onboardingSeen: true),
    billing: DemoBillingService(),
  );

  TideStore pro() => TideStore(
    auth: DemoAuthService(signedIn: true),
    flags: DeviceFlags.memory(onboardingSeen: true),
    billing: DemoBillingService.pro(),
  );

  group('habits', () {
    test('the free ceiling holds, and Pro lifts it', () {
      final store = free();
      while (store.activeHabitCount < AppConstants.freeHabitLimit) {
        store.addHabit(
          Habit(
            id: store.newHabitId(),
            name: 'Another',
            glyph: TideGlyph.dot,
            type: HabitType.binary,
            createdAt: DateTime.now(),
          ),
        );
      }
      expect(store.canAddHabit, isFalse);
      expect(pro().canAddHabit, isTrue);
    });
  });

  group('history', () {
    test('the free window ends where the paywall says it does', () {
      final store = free();
      final horizon = store.historyHorizon;

      expect(horizon, isNotNull);
      final span = DateUtils.dateOnly(DateTime.now()).difference(horizon!).inDays;
      expect(
        span,
        AppConstants.freeHistoryDays - 1,
        reason: 'the window is $span + today = ${AppConstants.freeHistoryDays}',
      );
    });

    test('today and the edge of the window are visible, the day before is not', () {
      final store = free();
      final today = DateUtils.dateOnly(DateTime.now());

      expect(store.canSee(today), isTrue);
      expect(store.canSee(store.historyHorizon!), isTrue);
      expect(
        store.canSee(store.historyHorizon!.subtract(const Duration(days: 1))),
        isFalse,
      );
    });

    test('Pro has no horizon at all', () {
      final store = pro();
      expect(store.historyHorizon, isNull);
      expect(
        store.canSee(DateTime.now().subtract(const Duration(days: 900))),
        isTrue,
      );
    });

    test('tomorrow is nobody\'s to see, on either plan', () {
      final ahead = DateTime.now().add(const Duration(days: 1));
      expect(free().canSee(ahead), isFalse);
      expect(pro().canSee(ahead), isFalse);
    });
  });

  group('freezes', () {
    test('the free ceiling is what a new habit already starts with', () {
      // Deliberate: the gate must not take away anything a free account had
      // before it existed. It only stops the number going up.
      expect(free().freezeCeiling, AppConstants.defaultFreezeAllowance);
      expect(pro().freezeCeiling, AppConstants.maxFreezeAllowance);
      expect(
        pro().freezeCeiling,
        greaterThan(free().freezeCeiling),
        reason: 'otherwise the paywall row is promising nothing',
      );
    });
  });

  group('the rest of the gates', () {
    test('free reaches none of them, Pro reaches all of them', () {
      final open = free();
      final paid = pro();
      for (final feature in ProFeature.values) {
        expect(open.locked(feature), isTrue, reason: feature.name);
        expect(paid.allows(feature), isTrue, reason: feature.name);
      }
    });

    test('a plan bought mid-session opens the gates without a restart', () async {
      final billing = DemoBillingService();
      final store = TideStore(
        auth: DemoAuthService(signedIn: true),
        flags: DeviceFlags.memory(onboardingSeen: true),
        billing: billing,
      );
      expect(store.locked(ProFeature.palettes), isTrue);

      await store.purchase(PlanCatalog.yearly);

      expect(store.locked(ProFeature.palettes), isFalse);
      expect(store.historyHorizon, isNull);
      expect(store.freezeCeiling, AppConstants.maxFreezeAllowance);
    });
  });

  group('the paywall and the gates describe the same app', () {
    test('every gated feature has a row to be sold on', () {
      // The failure this catches: a gate added in a screen with nothing on
      // the sheet naming it, so somebody hits a wall the paywall never
      // mentioned.
      for (final feature in ProFeature.values) {
        final spec = ProFeatures.all[feature];
        expect(spec, isNotNull, reason: '${feature.name} has no copy');
        expect(spec!.label, isNotEmpty);
        expect(spec.freeAllowance, isNotEmpty);
        expect(spec.blurb, isNotEmpty);
      }
    });

    test('the headline rows are real features, listed once each', () {
      expect(ProFeatures.headline.toSet(), hasLength(ProFeatures.headline.length));
      for (final feature in ProFeatures.headline) {
        expect(ProFeature.values, contains(feature));
      }
    });

    test('the quoted allowances are the ones actually enforced', () {
      // The numbers on the sheet are built from AppConstants rather than
      // typed, so this is really a guard on that staying true.
      expect(
        ProFeatures.of(ProFeature.unlimitedHabits).freeAllowance,
        contains('${AppConstants.freeHabitLimit}'),
      );
      expect(
        ProFeatures.of(ProFeature.fullHistory).freeAllowance,
        contains('${AppConstants.freeHistoryDays}'),
      );
      expect(
        ProFeatures.of(ProFeature.carryOverFreezes).freeAllowance,
        contains('${AppConstants.freeFreezeAllowance}'),
      );
    });
  });
}
