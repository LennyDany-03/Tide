import 'package:flutter/foundation.dart';

import '../../config/plan_catalog.dart';

/// What became of one payment.
///
/// The three `payment_orders` states `billing_snapshot` returns, plus
/// [unknown] for a status added to the table after this build shipped — one
/// unreadable row must not take the list down with it.
enum PaymentStatus { captured, refunded, failed, unknown }

/// Where the account's receipt list stands.
///
/// Four states rather than a nullable list, because "nobody has asked yet" and
/// "asked, and there are none" are different screens. Collapsing them is how
/// an empty state comes to say "no payments" to somebody whose request is
/// still in flight.
enum ReceiptsStatus { unread, loading, loaded, failed }

/// One line of the account's payment history: a `payment_orders` row as
/// `billing_snapshot()` hands it over.
///
/// Not to be confused with `PaymentReceipt` in `billing_service.dart`, which
/// is the three fields one checkout hands back on its way to being verified.
/// This is the record that outlives it — what Settings shows, and what a
/// support conversation is about.
///
/// Never written, never kept on the device, and never the authority on
/// anything. Entitlement comes from `entitlement()`; nothing here feeds it.
@immutable
class PaymentRecord {
  const PaymentRecord({
    required this.id,
    required this.amountMinor,
    required this.currency,
    required this.status,
    required this.createdAt,
    this.planId,
    this.method,
    this.paymentId,
  });

  /// `payment_orders.id`. Stable, and what the list keys its rows on.
  final String id;

  /// `pro_monthly` / `pro_yearly`. Nullable: a plan can be retired from
  /// `billing_plans` long after somebody bought it, and their receipt has to
  /// keep rendering.
  final String? planId;

  final int amountMinor;
  final String currency;
  final PaymentStatus status;

  /// Razorpay's own word — `upi`, `card`, `netbanking`, `wallet`. Kept
  /// verbatim on the server so a method added next year never fails a
  /// constraint, so kept verbatim here too; only [methodLabel] guesses at a
  /// display name.
  final String? method;

  /// `razorpay_payment_id` — the number support will ask for. Null on an
  /// attempt that never got one.
  final String? paymentId;

  final DateTime createdAt;

  BillingPlan? get plan => PlanCatalog.byId(planId);

  /// The catalogue's name if this build knows the plan, the server's own id if
  /// it does not. Never blank.
  String get planLabel => plan?.title ?? planId ?? 'Tide Pro';

  /// "₹199" — the same expression `CheckoutIntent.amountLabel` uses, for the
  /// same reason: every plan is priced in whole rupees.
  String get amountLabel =>
      '${BillingPlan.symbolFor(currency)}${amountMinor ~/ 100}';

  String? get methodLabel => switch (method) {
    null || '' => null,
    'upi' => 'UPI',
    'card' => 'Card',
    'netbanking' => 'Netbanking',
    'wallet' => 'Wallet',
    'emi' => 'EMI',
    final other => other[0].toUpperCase() + other.substring(1),
  };

  bool get paid => status == PaymentStatus.captured;

  // --- The wire ----------------------------------------------------------
  //
  // The `orders` half of billing_snapshot(). Forgiving the same way
  // Entitlement.fromJson and HabitRows.parseHabit are: a field added to the
  // function later must not stop an older build reading the rest.

  /// Null when the row has no usable identity or date — the caller drops those
  /// with `.nonNulls`, the way habit rows are parsed.
  static PaymentRecord? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final created = _time(json['created_at']);
    if (id is! String || id.isEmpty || created == null) return null;

    return PaymentRecord(
      id: id,
      // `plan` and `payment_id`, not `plan_id` and `razorpay_payment_id`:
      // billing_snapshot renames both on its way out, and these two are the
      // easy thing to get wrong.
      planId: _text(json['plan']),
      amountMinor: (json['amount_minor'] as num?)?.toInt() ?? 0,
      currency: _text(json['currency']) ?? 'INR',
      status:
          PaymentStatus.values.asNameMap()[json['status']] ??
          PaymentStatus.unknown,
      method: _text(json['method']),
      paymentId: _text(json['payment_id']),
      createdAt: created,
    );
  }

  /// Every readable row of an `orders` payload, newest first — the order the
  /// server sorted them in, preserved so no screen ever sorts a list of money.
  static List<PaymentRecord> listFrom(Object? json) {
    if (json is! List) return const [];
    return [for (final row in json) fromJson(row)].nonNulls.toList(
      growable: false,
    );
  }

  static String? _text(Object? value) =>
      value is String && value.isNotEmpty ? value : null;

  static DateTime? _time(Object? value) {
    if (value is! String || value.isEmpty) return null;
    return DateTime.tryParse(value)?.toLocal();
  }

  @override
  bool operator ==(Object other) =>
      other is PaymentRecord &&
      other.id == id &&
      other.status == status &&
      other.paymentId == paymentId;

  @override
  int get hashCode => Object.hash(id, status, paymentId);

  @override
  String toString() => 'PaymentRecord($id, $planId, $amountLabel, ${status.name})';
}
