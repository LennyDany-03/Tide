import 'dart:async';

import '../../config/plan_catalog.dart';
import 'billing_service.dart';
import 'entitlement.dart';
import 'payment_gateway.dart';

/// Entitlement kept in memory, for tests and for a build with no project.
///
/// It enforces the same rules the server does — a period is extended from
/// whichever is later, now or the end of a period still running; a second
/// confirm of the same payment changes nothing — so a test that passes against
/// this is testing the behaviour the real service has, not a simplified one.
///
/// What it cannot do is take money or check a signature. [confirm] accepts
/// whatever it is handed, which is exactly why the real service exists and why
/// nothing above these two ever decides entitlement for itself.
class DemoBillingService extends BillingService {
  DemoBillingService({
    Entitlement? entitlement,
    this.accounts = const {},
    PaymentGateway? gateway,
  }) : _initial = entitlement ?? Entitlement.free,
       _current = entitlement ?? Entitlement.free,
       gateway = gateway ?? DemoPaymentGateway(delay: Duration.zero);

  /// Already Pro, on [plan], for its whole period. What a test that is about
  /// something else — a palette, a heatmap — uses to get past the gates
  /// without walking through a payment first.
  factory DemoBillingService.pro({BillingPlan? plan}) {
    final on = plan ?? PlanCatalog.preferred;
    final now = DateTime.now();
    return DemoBillingService(
      entitlement: Entitlement(
        status: EntitlementStatus.active,
        planId: on.id,
        periodStart: now,
        periodEnd: now.add(Duration(days: on.periodDays)),
        source: 'promo',
      ),
    );
  }

  /// What stands in for a card reader. Swappable so a test can make the next
  /// payment fail without a declined card anywhere near it.
  final PaymentGateway gateway;

  /// Entitlement an account already has when it is opened, by account id.
  /// Lets a test start signed in as somebody who is already Pro.
  final Map<String, Entitlement> accounts;

  final StreamController<Entitlement> _changes =
      StreamController<Entitlement>.broadcast();

  /// What every account opened by this service starts on, unless [accounts]
  /// names a different plan for it. Without this an account signing in would
  /// wipe out the plan the service was constructed with, which is exactly
  /// what a test that starts signed in as a Pro account wants not to happen.
  final Entitlement _initial;

  Entitlement _current;
  String? _accountId;
  int _orders = 0;

  /// Which plan each open order is for — the demo's `payment_orders` table.
  /// [confirm] reads the plan off this rather than being told, which is how
  /// the server does it and why a caller cannot buy a year by asking for one.
  final Map<String, BillingPlan> _open = {};

  /// Every payment this service has been asked to confirm, so a test can say
  /// what was bought rather than only that something was.
  final List<String> confirmedPlans = [];

  /// Entitlement as it stands, without going through the store.
  Entitlement get current => _current;

  @override
  Entitlement cached(String? accountId) =>
      accountId == null ? Entitlement.free : accounts[accountId] ?? _current;

  @override
  bool get canPay => gateway.available;

  @override
  Stream<Entitlement> get changes => _changes.stream;

  @override
  bool get isLocalOnly => true;

  @override
  void open(String accountId) {
    _accountId = accountId;
    _current = accounts[accountId] ?? _initial;
    _announce();
  }

  @override
  Future<Entitlement> refresh() async => _current;

  @override
  Future<PaymentReceipt> collectPayment(
    CheckoutIntent intent, {
    required String title,
    required String description,
    int? themeColor,
  }) => gateway.collect(
    intent,
    title: title,
    description: description,
    themeColor: themeColor,
  );

  @override
  Future<CheckoutIntent> startCheckout(BillingPlan plan) async {
    if (_accountId == null) {
      throw const BillingFailure(
        BillingProblem.unavailable,
        'Nobody is signed in.',
      );
    }
    _orders++;
    final orderId = 'order_demo_$_orders';
    _open[orderId] = plan;
    return CheckoutIntent(
      orderId: orderId,
      keyId: 'rzp_test_demo',
      planId: plan.id,
      amountMinor: plan.amountMinor,
      currency: plan.currency,
    );
  }

  @override
  Future<Entitlement> confirm(PaymentReceipt receipt) async {
    // The plan comes back through the order id the same way the server reads
    // it off the row: nothing the caller passes decides what was bought.
    final plan = _open[receipt.orderId];
    if (plan == null) {
      throw const BillingFailure(
        BillingProblem.rejected,
        'No such order on this account.',
      );
    }

    if (_current.lastPaymentId == receipt.paymentId) return _current;
    confirmedPlans.add(plan.id);

    final now = DateTime.now();
    final running = _current.isPro ? _current.periodEnd! : now;
    _current = Entitlement(
      status: EntitlementStatus.active,
      planId: plan.id,
      periodStart: _current.isPro ? _current.periodStart : now,
      periodEnd: running.add(Duration(days: plan.periodDays)),
      source: 'razorpay',
      lastPaymentId: receipt.paymentId,
    );
    _announce();
    return _current;
  }

  @override
  Future<void> abandon(String orderId, {Object? error}) async {
    _open.remove(orderId);
  }

  @override
  Future<void> close({bool forget = false}) async {
    _accountId = null;
    if (forget) {
      _current = Entitlement.free;
      _open.clear();
      _announce();
    }
  }

  /// Grants a period without a payment — how a test arrives at Pro, and what
  /// stands in for a promo code until there is one.
  void grant(BillingPlan plan, {DateTime? until}) {
    final now = DateTime.now();
    _current = Entitlement(
      status: EntitlementStatus.active,
      planId: plan.id,
      periodStart: now,
      periodEnd: until ?? now.add(Duration(days: plan.periodDays)),
      source: 'promo',
    );
    _announce();
  }

  /// The other direction: a refund, or a period that ran out.
  void revoke() {
    _current = Entitlement(
      status: EntitlementStatus.expired,
      planId: _current.planId,
      periodStart: _current.periodStart,
      periodEnd: DateTime.now().subtract(const Duration(days: 1)),
      source: _current.source,
    );
    _announce();
  }

  /// A change that arrived from somewhere else — a webhook granting a period
  /// while the app was closed, say. What drives the realtime path in tests.
  void announce(Entitlement next) {
    _current = next;
    _announce();
  }

  void _announce() {
    if (_changes.isClosed) return;
    _changes.add(_current);
  }

  void dispose() {
    gateway.dispose();
    _changes.close();
  }
}
