import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../config/app_constants.dart';
import '../../config/plan_catalog.dart';
import 'entitlement.dart';
import 'payment_record.dart';

/// Why a purchase did not finish, as something a sheet can say.
///
/// The split that matters is between [cancelled] — which is not a failure and
/// gets no error text at all — and [pending], which is not a failure either:
/// the money has moved and the server has not caught up yet. Everything that
/// treats a slow UPI payment as a decline teaches people that paying twice is
/// how you fix it.
enum BillingProblem {
  /// The person closed the payment sheet. Say nothing.
  cancelled,

  /// The bank or the network refused. Retryable.
  declined,

  /// Paid, and not yet confirmed here. The webhook will finish it and the
  /// realtime broadcast will turn the app Pro on its own.
  pending,

  /// The signature did not check out, the amount did not match, or the order
  /// belongs to somebody else. Never retried automatically.
  rejected,

  offline,

  /// No project, no key, or the functions are not deployed.
  unavailable,

  /// This build cannot take a payment: no Razorpay plugin on this platform.
  unsupportedPlatform,

  /// The mandate behind this plan is gone, so there is nothing to resume and
  /// the only way back to Pro is a fresh checkout. Not an error either — it is
  /// an answer, and the screen turns it into a button.
  resubscribeNeeded,

  /// A live mandate already exists for this account. Raised rather than
  /// silently opening a second one, because two standing instructions on one
  /// account is two debits a month.
  alreadySubscribed,

  unknown,
}

class BillingFailure implements Exception {
  const BillingFailure(this.problem, [this.detail]);

  final BillingProblem problem;

  /// Razorpay's own description when there is one. Its wording for a declined
  /// card is better than anything invented here, so it is passed through
  /// rather than replaced.
  final String? detail;

  bool get silent => problem == BillingProblem.cancelled;

  @override
  String toString() =>
      'BillingFailure(${problem.name}${detail == null ? '' : ': $detail'})';
}

/// Which rail a checkout is running on.
enum CheckoutKind {
  /// A Razorpay order: one payment, one period, and then nothing.
  order,

  /// A Razorpay Subscription: the checkout registers a mandate and takes the
  /// first charge, and every charge after it arrives without the app being
  /// involved — or, usually, installed and open.
  subscription,
}

/// A checkout opened on the server, with everything needed to collect money
/// against it.
///
/// One type with two named constructors rather than two types: everything
/// between here and the payment sheet — the gateway, the sheet's phases, the
/// failure paths — is identical on both rails, and the only fork is the single
/// id handed to Razorpay. The constructors are what make an intent with both
/// ids, or neither, unconstructable.
///
/// The amount comes back from the server rather than being taken from
/// [PlanCatalog]: the sheet shows what will actually be charged, so a price
/// changed in the dashboard is right on the confirm button of a build that
/// shipped before it changed.
@immutable
class CheckoutIntent {
  /// A period bought outright.
  const CheckoutIntent.order({
    required String this.orderId,
    required this.keyId,
    required this.planId,
    required this.amountMinor,
    required this.currency,
    this.email,
    this.contact,
  }) : subscriptionId = null,
       kind = CheckoutKind.order;

  /// A mandate registered, and a plan that renews on its own afterwards.
  const CheckoutIntent.subscription({
    required String this.subscriptionId,
    required this.keyId,
    required this.planId,
    required this.amountMinor,
    required this.currency,
    this.email,
    this.contact,
  }) : orderId = null,
       kind = CheckoutKind.subscription;

  final CheckoutKind kind;

  /// Set on [CheckoutKind.order] and null otherwise.
  final String? orderId;

  /// Set on [CheckoutKind.subscription] and null otherwise.
  final String? subscriptionId;

  /// The public Razorpay key id. Handed down from the server so rotating keys
  /// is a dashboard change, not an app release.
  final String keyId;

  final String planId;
  final int amountMinor;
  final String currency;

  /// Prefilled into the checkout so nobody retypes what the account already
  /// knows.
  final String? email;
  final String? contact;

  BillingPlan? get plan => PlanCatalog.byId(planId);

  bool get isSubscription => kind == CheckoutKind.subscription;

  /// Whichever id Razorpay is being asked to collect against. Exactly one of
  /// the two is set, by construction.
  String get reference => orderId ?? subscriptionId!;

  String get amountLabel =>
      '${BillingPlan.symbolFor(currency)}${amountMinor ~/ 100}';
}

/// What the checkout hands back on success — the fields Razorpay returns, and
/// nothing else. None of them is trusted here; they are relayed to the server,
/// which checks the signature against its own row.
///
/// Which id comes back depends on the rail, and so does the signature itself:
/// an order is signed over `order_id|payment_id` and a subscription over
/// `payment_id|subscription_id` — the same two fields the other way round. The
/// server is where that distinction is handled; here they are just strings.
@immutable
class PaymentReceipt {
  const PaymentReceipt({
    required this.paymentId,
    required this.signature,
    this.orderId,
    this.subscriptionId,
  });

  final String paymentId;
  final String signature;
  final String? orderId;
  final String? subscriptionId;

  bool get isSubscription => subscriptionId != null;

  /// Whichever id this payment was collected against.
  String get reference => orderId ?? subscriptionId ?? '';
}

/// Entitlement and the account's payment history, from one request — the
/// shape `billing_snapshot()` returns.
///
/// One call rather than two, deliberately: the snapshot's entitlement half
/// carries a fresh `server_time`, so asking for receipts also re-anchors the
/// clock skew. Throwing that away and asking `entitlement()` separately would
/// be two round trips for one answer.
@immutable
class BillingSnapshot {
  const BillingSnapshot({required this.entitlement, required this.payments});

  static const BillingSnapshot none = BillingSnapshot(
    entitlement: Entitlement.free,
    payments: [],
  );

  final Entitlement entitlement;

  /// Newest first — the order the server sorted them in. Both implementations
  /// guarantee it, so no screen ever sorts a list of money.
  final List<PaymentRecord> payments;
}

/// The seam between Tide and whoever takes the money.
///
/// Two implementations: `SupabaseBillingService` for a real build, and
/// `DemoBillingService` for tests and for a build with no project configured.
///
/// The shape mirrors `HabitRepository` on purpose. The store is the source of
/// truth for what is on screen, the device keeps a copy so a Pro account opens
/// Pro on the first frame rather than after a round trip, and anything that
/// changes elsewhere — a webhook granting a period, a refund taking one back —
/// arrives as a push rather than being polled for.
///
/// What is *not* here is as deliberate as what is. There is no `setPro`, no
/// `grant`, and no way for any screen to make the app Pro. Entitlement only
/// ever comes back from the server.
abstract class BillingService {
  /// What this device already knows about [accountId], synchronously, so the
  /// first frame after launch is drawn with the right plan. [Entitlement.free]
  /// before anyone has signed in.
  Entitlement cached(String? accountId);

  /// Entitlement as it changes: the server's answer landing, a webhook
  /// granting a period, a refund taking one back.
  Stream<Entitlement> get changes;

  /// True when nothing leaves the device — no project, or the demo service.
  bool get isLocalOnly;

  /// Whether this build can actually open a payment sheet. False on web and
  /// desktop, where the Razorpay plugin has no implementation: the paywall
  /// says so rather than offering a button that does nothing.
  bool get canPay;

  /// Starts following [accountId]: reads its entitlement and listens for
  /// changes. Closes whichever account was open.
  void open(String accountId);

  /// Buy [plan]: open an order, take the money, have the server verify it.
  ///
  /// The one call a screen makes. The three steps below are separate because
  /// each fails differently and each has to be recoverable on its own — but
  /// nothing outside this class sequences them, because getting that sequence
  /// wrong is how an order is left open or a payment is taken twice.
  ///
  /// Throws [BillingFailure]. [BillingProblem.pending] is not a failure: the
  /// money moved, the webhook will finish it, and the entitlement arrives on
  /// its own through [changes].
  Future<Entitlement> purchase(
    BillingPlan plan, {
    required String title,
    required String description,
    int? themeColor,
  }) async {
    final intent = await startCheckout(plan);

    final PaymentReceipt receipt;
    try {
      receipt = await collectPayment(
        intent,
        title: title,
        description: description,
        themeColor: themeColor,
      );
    } catch (error) {
      // Closing the order is bookkeeping, not part of the outcome: whatever
      // happened to the payment has already happened, and the person is owed
      // an answer now rather than after a second round trip.
      unawaited(abandon(intent, error: error));
      rethrow;
    }

    // Deliberately outside the catch above. A confirm that fails has not
    // failed to *pay* — the signature checked out or it did not, and either
    // way the order must not be marked abandoned underneath a payment the
    // webhook is about to apply.
    return confirm(receipt);
  }

  /// Takes the money for an order that is already open. Implemented by the
  /// gateway in a real build and faked in the demo one.
  @protected
  Future<PaymentReceipt> collectPayment(
    CheckoutIntent intent, {
    required String title,
    required String description,
    int? themeColor,
  });

  /// Asks the server what this account is entitled to. Never throws; a failure
  /// leaves the last known answer in place, because the alternative — dropping
  /// somebody to free because their train went into a tunnel — is worse than
  /// being briefly out of date.
  Future<Entitlement> refresh();

  /// Entitlement and the last [limit] receipts, in one request.
  ///
  /// Asked for when a screen that shows receipts opens — never on sign-in and
  /// never at launch. A payment history is not something to fetch on the
  /// chance somebody looks at it.
  ///
  /// Throws [BillingFailure].
  Future<BillingSnapshot> snapshot({int limit = AppConstants.receiptLimit});

  /// Stops the plan renewing, keeping every day already paid for.
  ///
  /// **What this does depends on the rail, and the difference is money.** On a
  /// prepaid period there is no charge to stop and this is a local write: all
  /// it changes is that the app stops offering to renew. On a plan with a
  /// mandate behind it there very much is a charge to stop, and stopping it
  /// means telling Razorpay — so the call goes to an Edge Function, and the
  /// row is only marked cancelled once Razorpay has confirmed. Pro stays on
  /// until [Entitlement.periodEnd] in both cases, which is what was paid for.
  ///
  /// Throws [BillingFailure]. Unlike [refresh], a failure here has to be
  /// seen: a button that silently does nothing is worse than one that admits
  /// it could not reach the server — and on this rail, silence would mean
  /// somebody believing a debit had been stopped when it had not.
  Future<Entitlement> cancelSubscription();

  /// Undo of [cancelSubscription], and only on the prepaid rail —
  /// 'cancelled' back to 'active' while the period is still running.
  ///
  /// **A cancelled mandate cannot be resumed.** Razorpay treats a cancelled
  /// subscription as finished and offers no un-cancel, so there is nothing
  /// left to put back: starting again means authorising a new mandate, which
  /// is a checkout rather than a button. Throws
  /// [BillingProblem.resubscribeNeeded] for that case, which is what the
  /// billing screen turns into an offer to subscribe again.
  ///
  /// Throws [BillingFailure].
  Future<Entitlement> resumeSubscription();

  /// Opens an order for [plan] on the server. Throws [BillingFailure].
  Future<CheckoutIntent> startCheckout(BillingPlan plan);

  /// Hands [receipt] to the server, which checks the signature against its own
  /// order and grants the period. Returns the entitlement that results.
  ///
  /// Throws [BillingFailure]; [BillingProblem.pending] means the money moved
  /// and the webhook has not landed yet, which is a wait rather than an error.
  Future<Entitlement> confirm(PaymentReceipt receipt);

  /// Tells the server a checkout attempt failed, so the order stops being open
  /// and the reason is recorded. Never throws: a failed payment that also
  /// fails to be written down is still just a failed payment.
  ///
  /// Takes the whole intent because there is nothing to close on the
  /// subscription rail — no order row was ever opened — and the
  /// implementations need to know which they are looking at.
  Future<void> abandon(CheckoutIntent intent, {Object? error});

  /// Stops following the open account. [forget] also drops this device's copy —
  /// for a log out, where the next person to pick up the phone should not find
  /// somebody else's plan.
  Future<void> close({bool forget = false});
}
