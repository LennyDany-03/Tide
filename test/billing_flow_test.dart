import 'package:flutter_test/flutter_test.dart';
import 'package:tide/config/plan_catalog.dart';
import 'package:tide/config/pro_features.dart';
import 'package:tide/services/auth/demo_auth_service.dart';
import 'package:tide/services/billing/billing_service.dart';
import 'package:tide/services/billing/demo_billing_service.dart';
import 'package:tide/services/billing/entitlement.dart';
import 'package:tide/services/billing/payment_gateway.dart';
import 'package:tide/services/billing/payment_record.dart';
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
/// A prepaid plan, for the rail that no longer sells itself.
///
/// Everything in [PlanCatalog] renews now, but the order path is still live
/// code and every account from before auto-pay is on one: `apply_payment`, the
/// `cancel_subscription` RPC and `resume_subscription` all still have to work.
/// The id matches a real plan so `Entitlement.plan` still resolves.
const prepaid = BillingPlan(
  id: 'pro_monthly',
  title: 'Monthly',
  interval: PlanInterval.month,
  amountMinor: 10000,
  periodDays: 30,
  note: 'bought outright',
  mode: BillingMode.oneTime,
);

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

      // The order rail, deliberately: this is about `apply_payment`'s
      // idempotency, and its key is an order reaching 'captured'. The renewal
      // rail has its own key and its own test further down.
      final intent = await billing.startCheckout(prepaid);
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

  group('cancelling', () {
    test('keeps every day that was paid for', () async {
      final store = signedIn();
      await store.purchase(PlanCatalog.monthly);
      final until = store.entitlement.periodEnd;
      final days = store.entitlement.daysRemaining;

      await store.cancelPlan();

      expect(store.isPro, isTrue, reason: 'cancelling is not surrendering');
      expect(store.entitlement.status, EntitlementStatus.cancelled);
      expect(store.entitlement.periodEnd, until);
      expect(store.entitlement.daysRemaining, days);
    });

    test('the gates stay open until the period ends', () async {
      final store = signedIn();
      await store.purchase(PlanCatalog.yearly);
      await store.cancelPlan();

      for (final feature in ProFeature.values) {
        expect(store.allows(feature), isTrue, reason: feature.name);
      }
    });

    test('cancelling twice is the same as cancelling once', () async {
      final store = signedIn();
      await store.purchase(PlanCatalog.monthly);
      await store.cancelPlan();
      final after = store.entitlement;

      await store.cancelPlan();

      expect(store.entitlement.periodEnd, after.periodEnd);
      expect(store.entitlement.status, EntitlementStatus.cancelled);
    });

    test('resume goes back to active without moving the date', () async {
      // The prepaid rail. Resume exists there because nothing was ever
      // stopped: the row said 'cancelled' and now it does not.
      final store = signedIn();
      await store.purchase(prepaid);
      final until = store.entitlement.periodEnd;

      await store.cancelPlan();
      await store.resumePlan();

      expect(store.entitlement.status, EntitlementStatus.active);
      expect(store.entitlement.cancelledAt, isNull);
      expect(
        store.entitlement.periodEnd,
        until,
        reason: 'resume must not be a way to extend a period',
      );
    });

    test('neither does anything on an account with no plan', () async {
      final store = signedIn();
      await store.cancelPlan();
      expect(store.isPro, isFalse);
      expect(store.entitlement.status, EntitlementStatus.none);

      await store.resumePlan();
      expect(
        store.isPro,
        isFalse,
        reason: 'resume is not a way to become Pro for free',
      );
    });

    test('resume cannot revive a plan that has run out', () async {
      final billing = DemoBillingService();
      final store = signedIn(billing: billing);
      await store.purchase(PlanCatalog.monthly);
      billing.revoke();
      await settle();
      expect(store.isPro, isFalse);

      await store.resumePlan();

      expect(store.isPro, isFalse);
      expect(store.entitlement.status, isNot(EntitlementStatus.active));
    });
  });

  group('auto-pay', () {
    test('buying a plan that renews registers a mandate', () async {
      final billing = DemoBillingService();
      final store = signedIn(billing: billing);

      final intent = await billing.startCheckout(PlanCatalog.monthly);
      expect(
        intent.isSubscription,
        isTrue,
        reason: 'an auto plan is bought as a subscription, not an order',
      );
      expect(intent.orderId, isNull);
      expect(intent.subscriptionId, isNotNull);

      await store.purchase(PlanCatalog.monthly);

      expect(store.isPro, isTrue);
      expect(store.entitlement.autoRenews, isTrue);
      expect(store.entitlement.nextChargeAt, store.entitlement.periodEnd);
      expect(store.entitlement.cancelsThroughProvider, isTrue);
      expect(
        store.entitlement.lapsesSoon,
        isFalse,
        reason: 'a plan that renews itself never needs renewing by hand',
      );
    });

    test('a renewal that lands while nobody is looking stacks a period', () async {
      final billing = DemoBillingService();
      final store = signedIn(billing: billing);
      await store.purchase(PlanCatalog.monthly);
      final first = store.entitlement.periodEnd!;

      // No device callback for this: the mandate came due, Razorpay debited
      // the card, and `subscription.charged` arrived at the webhook.
      billing.charge(paymentId: 'pay_renewal_1');
      await settle();

      expect(store.entitlement.periodEnd!.isAfter(first), isTrue);
      expect(store.isPro, isTrue);
      expect(store.entitlement.autoRenews, isTrue);
    });

    test('the same renewal delivered twice buys one period', () async {
      final billing = DemoBillingService();
      final store = signedIn(billing: billing);
      await store.purchase(PlanCatalog.monthly);

      billing.charge(paymentId: 'pay_renewal_1');
      await settle();
      final once = store.entitlement.periodEnd;

      billing.charge(paymentId: 'pay_renewal_1');
      await settle();

      expect(
        store.entitlement.periodEnd,
        once,
        reason: 'Razorpay replays webhooks; a replay is not a payment',
      );
    });

    test('a failed debit does not take away days already paid for', () async {
      final billing = DemoBillingService();
      final store = signedIn(billing: billing);
      await store.purchase(PlanCatalog.yearly);
      final until = store.entitlement.periodEnd;

      billing.renewalFailed();
      await settle();

      expect(
        store.isPro,
        isTrue,
        reason: 'the period was paid for; the renewal is what failed',
      );
      expect(store.entitlement.status, EntitlementStatus.pastDue);
      expect(store.entitlement.renewalFailing, isTrue);
      expect(store.entitlement.periodEnd, until);
      for (final feature in ProFeature.values) {
        expect(store.allows(feature), isTrue, reason: feature.name);
      }
    });

    test('a halted mandate keeps the period and stops renewing', () async {
      final billing = DemoBillingService();
      final store = signedIn(billing: billing);
      await store.purchase(PlanCatalog.monthly);
      final until = store.entitlement.periodEnd;

      billing.renewalFailed(halted: true);
      await settle();

      expect(store.isPro, isTrue);
      expect(store.entitlement.status, EntitlementStatus.halted);
      expect(store.entitlement.periodEnd, until);
      expect(
        store.entitlement.autoRenews,
        isFalse,
        reason: 'Razorpay has given up, so nothing is coming',
      );
    });

    test('cancelling stops the renewal and keeps the period', () async {
      final store = signedIn();
      await store.purchase(PlanCatalog.monthly);
      final until = store.entitlement.periodEnd;

      await store.cancelPlan();

      expect(store.isPro, isTrue, reason: 'cancelling is not surrendering');
      expect(store.entitlement.status, EntitlementStatus.cancelled);
      expect(store.entitlement.periodEnd, until);
      expect(
        store.entitlement.autoRenews,
        isFalse,
        reason: 'the whole point: no further debit',
      );
      expect(store.entitlement.nextChargeAt, isNull);
    });

    test('a cancelled mandate cannot be resumed', () async {
      // Razorpay has no un-cancel, so there is nothing to put back and the
      // only honest answer is a fresh checkout. Failing loudly here is what
      // keeps the app from flipping a row to 'active' and promising a renewal
      // that nothing is going to perform.
      final store = signedIn();
      await store.purchase(PlanCatalog.monthly);
      await store.cancelPlan();

      await expectLater(
        store.resumePlan(),
        throwsA(
          isA<BillingFailure>().having(
            (failure) => failure.problem,
            'problem',
            BillingProblem.resubscribeNeeded,
          ),
        ),
      );
      expect(store.entitlement.status, EntitlementStatus.cancelled);
      expect(store.isPro, isTrue);
    });

    test('a mandate that failed can still be cancelled', () async {
      // The most likely moment somebody wants to: the card is being retried
      // and they would rather it stopped.
      final billing = DemoBillingService();
      final store = signedIn(billing: billing);
      await store.purchase(PlanCatalog.monthly);
      billing.renewalFailed();
      await settle();

      await store.cancelPlan();

      expect(store.entitlement.status, EntitlementStatus.cancelled);
      expect(store.entitlement.autoRenews, isFalse);
      expect(store.isPro, isTrue);
    });

    test('the receipt list shows a renewal', () async {
      final billing = DemoBillingService();
      final store = signedIn(billing: billing);
      await store.purchase(PlanCatalog.monthly);
      billing.charge(paymentId: 'pay_renewal_1');
      await settle();

      await store.refreshReceipts();

      expect(store.payments, hasLength(2));
      expect(store.payments.first.paymentId, 'pay_renewal_1');
    });
  });

  group('receipts', () {
    test('nothing is fetched until something asks', () async {
      final store = signedIn();
      expect(store.receiptsStatus, ReceiptsStatus.unread);
      expect(store.payments, isEmpty);
    });

    test('a payment shows up in the history', () async {
      final store = signedIn();
      await store.purchase(PlanCatalog.yearly);
      await store.refreshReceipts();

      expect(store.receiptsStatus, ReceiptsStatus.loaded);
      expect(store.payments, hasLength(1));
      expect(store.payments.first.planId, 'pro_yearly');
      expect(store.payments.first.paid, isTrue);
    });

    test('a dismissed payment sheet leaves no receipt behind', () async {
      // The server filters these out of billing_snapshot, so the demo must
      // not invent one — otherwise every test would carry a bug the real
      // service does not have.
      final store = signedIn(
        gateway: DemoPaymentGateway(
          delay: Duration.zero,
          fail: const BillingFailure(BillingProblem.cancelled),
        ),
      );
      await store.purchase(PlanCatalog.monthly).catchError(
        (Object _) => Entitlement.free,
      );
      await store.refreshReceipts();

      expect(store.payments, isEmpty);
    });

    test('a refund is struck through rather than removed', () async {
      final billing = DemoBillingService();
      final store = signedIn(billing: billing);
      await store.purchase(PlanCatalog.monthly);
      billing.revoke();
      await store.refreshReceipts();

      expect(store.payments, hasLength(1), reason: 'history is not edited');
      expect(store.payments.first.status, PaymentStatus.refunded);
    });

    test('logging out leaves none of them behind', () async {
      final store = signedIn();
      await store.purchase(PlanCatalog.monthly);
      await store.refreshReceipts();
      expect(store.payments, isNotEmpty);

      await store.logOut();
      await settle();

      expect(store.payments, isEmpty);
      expect(
        store.receiptsStatus,
        ReceiptsStatus.unread,
        reason: 'the next person to open this screen has asked for nothing',
      );
    });

    test('a failed read keeps the rows it already had', () async {
      // The rule the whole four-state design rests on: a refresh never
      // empties the list, so a dropped connection does not take away the
      // receipts somebody is reading.
      final billing = _BrokenSnapshot();
      final store = signedIn(billing: billing);
      await store.purchase(PlanCatalog.monthly);
      await store.refreshReceipts();
      expect(store.payments, hasLength(1));

      billing.broken = true;
      await store.refreshReceipts();

      expect(store.receiptsStatus, ReceiptsStatus.failed);
      expect(store.payments, hasLength(1), reason: 'the rows stay on screen');
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

/// A billing service whose snapshot can be made to fail on demand, so the
/// "keep the rows you already had" rule can be tested without a network.
class _BrokenSnapshot extends DemoBillingService {
  bool broken = false;

  @override
  Future<BillingSnapshot> snapshot({int limit = 20}) {
    if (broken) {
      return Future<BillingSnapshot>.error(
        const BillingFailure(BillingProblem.offline),
      );
    }
    return super.snapshot(limit: limit);
  }
}
