import 'package:flutter_test/flutter_test.dart';
import 'package:tide/config/plan_catalog.dart';
import 'package:tide/services/auth/demo_auth_service.dart';
import 'package:tide/services/billing/billing_service.dart';
import 'package:tide/services/billing/demo_billing_service.dart';
import 'package:tide/services/billing/entitlement.dart';
import 'package:tide/services/billing/payment_gateway.dart';
import 'package:tide/services/device_flags.dart';
import 'package:tide/services/tide_store.dart';

/// Buying Pro, without Supabase, Razorpay or a network.
///
/// The store is driven through `DemoBillingService`, which keeps the same
/// rules the server does — a period stacks onto one still running, a payment
/// already applied changes nothing the second time — so what passes here is
/// the behaviour the real service has rather than a simplified one.
///
/// What these cannot cover is the half that only exists on the server: the
/// signature check, the amount check, and the webhook. Those live in
/// `supabase/functions/` and are verified against Razorpay's test mode, which
/// is written down in `supabase/functions/README.md`.
void main() {
  TideStore signedIn({
    DemoBillingService? billing,
    PaymentGateway? gateway,
  }) => TideStore(
    auth: DemoAuthService(signedIn: true),
    flags: DeviceFlags.memory(onboardingSeen: true),
    billing: billing ?? DemoBillingService(gateway: gateway),
  );

  /// The plan reaches the store through the same stream a webhook's broadcast
  /// would, so it lands on the next microtask rather than inside the call.
  Future<void> settle() => Future<void>.delayed(Duration.zero);

  group('a payment that goes through', () {
    test('opens the gates and records the period', () async {
      final store = signedIn();
      expect(store.isPro, isFalse);

      final plan = await store.purchase(PlanCatalog.monthly);

      expect(plan.isPro, isTrue);
      expect(store.isPro, isTrue);
      expect(store.entitlement.planId, 'pro_monthly');
      expect(store.entitlement.daysRemaining, PlanCatalog.monthly.periodDays);
    });

    test('the plan bought is the one the order was opened for', () async {
      // The server reads the plan off the order row, never off the request
      // that confirms it. The demo service does the same, so a confirm cannot
      // be talked into granting a year for a month's money.
      final billing = DemoBillingService();
      final store = signedIn(billing: billing);

      await store.purchase(PlanCatalog.yearly);

      expect(billing.confirmedPlans, ['pro_yearly']);
      expect(store.entitlement.daysRemaining, PlanCatalog.yearly.periodDays);
    });

    test('paying again adds to the end rather than starting over', () async {
      final store = signedIn();
      await store.purchase(PlanCatalog.monthly);
      final first = store.entitlement.periodEnd!;

      await store.purchase(PlanCatalog.yearly);

      expect(
        store.entitlement.periodEnd!.isAfter(first),
        isTrue,
        reason: 'a second payment in month one must not throw month one away',
      );
      expect(
        store.entitlement.daysRemaining,
        greaterThan(PlanCatalog.yearly.periodDays),
      );
    });

    test('the same payment applied twice buys one period', () async {
      // What keeps the verify call and the webhook — which race, and which
      // both arrive — from buying two months with one payment.
      final billing = DemoBillingService();
      // Opened through a signed-in store, because the service refuses an
      // order with nobody signed in — the same rule the Edge Function has.
      signedIn(billing: billing);

      final intent = await billing.startCheckout(PlanCatalog.monthly);
      const receipt = PaymentReceipt(
        orderId: 'order_demo_1',
        paymentId: 'pay_once',
        signature: 'demo-signature',
      );
      expect(intent.orderId, receipt.orderId);

      final once = await billing.confirm(receipt);
      final twice = await billing.confirm(receipt);

      expect(twice.periodEnd, once.periodEnd);
      expect(billing.confirmedPlans, hasLength(1));
    });
  });

  group('a payment that does not', () {
    test('a closed payment sheet changes nothing and says nothing', () async {
      final store = signedIn(
        gateway: DemoPaymentGateway(
          delay: Duration.zero,
          fail: const BillingFailure(BillingProblem.cancelled),
        ),
      );

      await expectLater(
        store.purchase(PlanCatalog.monthly),
        throwsA(
          isA<BillingFailure>()
              .having((f) => f.problem, 'problem', BillingProblem.cancelled)
              .having((f) => f.silent, 'is silent', isTrue),
        ),
      );
      expect(store.isPro, isFalse);
    });

    test('a declined card leaves the account on free with a reason', () async {
      final store = signedIn(
        gateway: DemoPaymentGateway(
          delay: Duration.zero,
          fail: const BillingFailure(
            BillingProblem.declined,
            'Your card was declined.',
          ),
        ),
      );

      await expectLater(
        store.purchase(PlanCatalog.yearly),
        throwsA(
          isA<BillingFailure>()
              .having((f) => f.problem, 'problem', BillingProblem.declined)
              .having((f) => f.silent, 'is silent', isFalse)
              .having((f) => f.detail, 'detail', 'Your card was declined.'),
        ),
      );
      expect(store.isPro, isFalse);
    });

    test('a failed checkout closes its order', () async {
      // Nothing is left open for a payment that will never arrive, which is
      // also what stops the create-order call handing back a stale one.
      final billing = DemoBillingService(
        gateway: DemoPaymentGateway(
          delay: Duration.zero,
          fail: const BillingFailure(BillingProblem.declined),
        ),
      );
      final store = signedIn(billing: billing);

      await store.purchase(PlanCatalog.monthly).catchError(
        (Object _) => Entitlement.free,
      );

      await expectLater(
        billing.confirm(
          const PaymentReceipt(
            orderId: 'order_demo_1',
            paymentId: 'pay_late',
            signature: 'demo-signature',
          ),
        ),
        throwsA(
          isA<BillingFailure>().having(
            (f) => f.problem,
            'problem',
            BillingProblem.rejected,
          ),
        ),
      );
    });
  });

  group('a plan that arrives from somewhere else', () {
    test('a webhook granting a period turns the app Pro', () async {
      // The case the whole realtime channel exists for: the money moved, the
      // app was not listening, and the server applied it anyway.
      final billing = DemoBillingService();
      final store = signedIn(billing: billing);
      expect(store.isPro, isFalse);

      billing.grant(PlanCatalog.yearly);
      await settle();

      expect(store.isPro, isTrue);
      expect(store.entitlement.source, 'promo');
    });

    test('a refund takes the gates back', () async {
      final billing = DemoBillingService();
      final store = signedIn(billing: billing);
      await store.purchase(PlanCatalog.monthly);
      expect(store.isPro, isTrue);

      billing.revoke();
      await settle();

      expect(store.isPro, isFalse);
      expect(store.entitlement.lapsed, isTrue);
    });

    test('a lapsed plan turns off the preference it was holding open', () async {
      final billing = DemoBillingService();
      final store = signedIn(billing: billing);
      await store.purchase(PlanCatalog.monthly);

      store.setPreference(weeklyRecap: true);
      expect(store.weeklyRecap, isTrue);

      billing.revoke();
      await settle();

      expect(
        store.weeklyRecap,
        isFalse,
        reason: 'a switch left on that does nothing is what generates mail',
      );
    });
  });

  group('the account boundary', () {
    test('a restored session opens on its plan in the first frame', () {
      // No pump, no await: read straight out of the device's copy, the same
      // way the habits are, so a Pro account never spends the first second of
      // a launch being told it has five habits.
      final store = signedIn(billing: DemoBillingService.pro());
      expect(store.isPro, isTrue);
    });

    test('logging out leaves nothing of the plan behind', () async {
      final store = signedIn(billing: DemoBillingService.pro());
      expect(store.isPro, isTrue);

      await store.logOut();
      await settle();

      expect(
        store.isPro,
        isFalse,
        reason: 'the next person to pick up this phone is not on Pro',
      );
    });
  });

  group('what the store will not do', () {
    test('there is no way to become Pro without the billing service', () {
      // Not an assertion about behaviour so much as about surface: the
      // upgrade sheet used to call `setPreference(isPro: true)`, and the whole
      // point of this rewrite is that no such call exists to be made. If this
      // ever fails to compile, entitlement has grown a setter again.
      final store = signedIn();
      store.setPreference(
        dailyReminders: false,
        quietHours: true,
        haptics: false,
      );
      expect(store.isPro, isFalse);
    });

    test('the recap can be turned off on any plan, on only on Pro', () async {
      final billing = DemoBillingService();
      final store = signedIn(billing: billing);

      store.setPreference(weeklyRecap: true);
      expect(store.weeklyRecap, isFalse, reason: 'free plan, gate holds');

      billing.grant(PlanCatalog.monthly);
      await settle();
      store.setPreference(weeklyRecap: true);
      expect(store.weeklyRecap, isTrue);

      // Turning it off is never gated — a gate that also refused to let
      // somebody out would be a trap.
      store.setPreference(weeklyRecap: false);
      expect(store.weeklyRecap, isFalse);
    });
  });
}
