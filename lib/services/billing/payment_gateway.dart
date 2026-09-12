import 'dart:async';

import 'package:flutter/foundation.dart';

import 'billing_service.dart';

/// Where the money is actually collected.
///
/// The narrowest seam in the billing layer, and deliberately so: an order is
/// opened on the server, this hands it to something that takes a card or a
/// UPI approval, and three strings come back. Nothing above it knows which
/// checkout that was.
///
/// It is its own seam rather than part of [BillingService] because the two
/// change for different reasons. `BillingService` is Tide's contract with its
/// own server — orders, entitlement, receipts — and it is the same whatever
/// takes the payment. This is the payment provider's SDK, on the one platform
/// it has an implementation for, and it is the part that would be replaced
/// wholesale by Razorpay's Custom SDK, by App Store billing on iOS, or by a
/// hosted page on the web.
///
/// Every failure leaves through [BillingFailure], so the sheet above has one
/// set of outcomes to draw whichever gateway is behind it.
abstract class PaymentGateway {
  /// Whether this build can open a payment sheet at all. False on web and
  /// desktop: the paywall says the plan can be bought on the phone rather
  /// than showing a button that cannot work.
  bool get available;

  /// Opens the checkout for [intent] and resolves when the payment is made.
  ///
  /// Throws [BillingFailure] — [BillingProblem.cancelled] when the sheet was
  /// dismissed, which is not an error and is not shown as one.
  Future<PaymentReceipt> collect(
    CheckoutIntent intent, {
    required String title,
    required String description,
    int? themeColor,
  });

  void dispose();
}

/// Takes no money and always succeeds.
///
/// What tests and an unconfigured build run on. It exists so the whole flow
/// above it — the sheet's phases, the store's confirm, the gates opening — can
/// be exercised without a network, a plugin, or a merchant account, which is
/// the only way this layer is testable at all.
class DemoPaymentGateway implements PaymentGateway {
  DemoPaymentGateway({this.delay = const Duration(milliseconds: 400), this.fail});

  /// Long enough for the button's busy phase to be visible, short enough that
  /// a widget test is not sitting through a real checkout.
  final Duration delay;

  /// Set to make the next collection throw instead — how the failure paths are
  /// tested without a declined card.
  final BillingFailure? fail;

  int collections = 0;

  @override
  bool get available => true;

  @override
  Future<PaymentReceipt> collect(
    CheckoutIntent intent, {
    required String title,
    required String description,
    int? themeColor,
  }) async {
    collections++;
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    final failure = fail;
    if (failure != null) throw failure;
    return PaymentReceipt(
      orderId: intent.orderId,
      paymentId: 'pay_demo_${intent.orderId.hashCode.abs()}',
      // The demo billing service does not check this; the real server does,
      // and would refuse it.
      signature: 'demo-signature',
    );
  }

  @override
  void dispose() {}
}

/// Which platforms the Razorpay plugin has a native implementation on.
///
/// Checked before a gateway is built rather than after a button is pressed:
/// `razorpay_flutter` registers no plugin on web, desktop or a test binding,
/// so `open` there fails on a missing method channel — a crash where the
/// honest answer is "not on this device".
bool get razorpaySupportsThisPlatform {
  if (kIsWeb) return false;
  return defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;
}
