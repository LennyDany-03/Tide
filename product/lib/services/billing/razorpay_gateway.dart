import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import '../../config/app_constants.dart';
import 'billing_service.dart';
import 'payment_gateway.dart';

/// Razorpay's checkout, on Android and iOS.
///
/// **Why the SDK and not a web view.** Razorpay's own guidance is explicit
/// about it: a checkout in a web view has to be given third-party cookies and
/// DOM storage before bank redirects and OTP pages work, and UPI intent — the
/// method most people in India actually use — cannot hand off to a payment app
/// and come back from inside one. The plugin is the supported path on a phone.
///
/// **What this class is careful about.** The plugin is event-based and global:
/// handlers are registered on an instance, `open` returns immediately, and the
/// result arrives on a listener some time later — possibly after the process
/// was killed on the bank's page and restarted, in which case the plugin
/// replays it through `resync`. Every one of those paths is funnelled into a
/// single [Future] here, so the layer above only ever sees a call that
/// resolves or throws.
///
/// One checkout at a time. A second [collect] while one is open is refused
/// rather than queued: two open orders with one visible sheet is how a person
/// ends up paying twice.
class RazorpayGateway implements PaymentGateway {
  RazorpayGateway() {
    if (!available) return;
    _razorpay = Razorpay()
      ..on(Razorpay.EVENT_PAYMENT_SUCCESS, _onSuccess)
      ..on(Razorpay.EVENT_PAYMENT_ERROR, _onError)
      ..on(Razorpay.EVENT_EXTERNAL_WALLET, _onExternalWallet);
  }

  Razorpay? _razorpay;
  Completer<PaymentReceipt>? _pending;

  /// The intent the open sheet belongs to.
  ///
  /// Kept because the success callback cannot be relied on to say. The plugin
  /// lifts `razorpay_order_id` into a field of its own but has no field for
  /// `razorpay_subscription_id` — it only survives in the raw `data` map — and
  /// on some rails it does not come back at all. This is what the subscription
  /// id falls back to, and it is the id the server will check against anyway.
  CheckoutIntent? _open;

  @override
  bool get available => razorpaySupportsThisPlatform;

  @override
  Future<PaymentReceipt> collect(
    CheckoutIntent intent, {
    required String title,
    required String description,
    int? themeColor,
  }) {
    final razorpay = _razorpay;
    if (razorpay == null) {
      return Future<PaymentReceipt>.error(
        const BillingFailure(
          BillingProblem.unsupportedPlatform,
          'Payments are only available in the phone app.',
        ),
      );
    }
    if (_pending != null && !_pending!.isCompleted) {
      return Future<PaymentReceipt>.error(
        const BillingFailure(
          BillingProblem.unknown,
          'A payment is already open.',
        ),
      );
    }

    final completer = Completer<PaymentReceipt>();
    _pending = completer;
    _open = intent;

    razorpay.open({
      'key': intent.keyId,
      if (intent.isSubscription)
        // A subscription checkout is told the subscription and nothing about
        // money: Razorpay reads the amount and the cycle off the plan the
        // subscription was created against, and the sheet it draws is the
        // mandate authorisation rather than a one-off payment. Sending an
        // `amount` alongside it is how you get a sheet that charges once and
        // registers nothing.
        'subscription_id': intent.subscriptionId
      else ...{
        'order_id': intent.orderId,
        // Sent for display only. The order is what is charged, and Razorpay
        // refuses a mismatch — which is the behaviour wanted: a build quoting
        // a stale price fails loudly rather than charging one figure and
        // showing another.
        'amount': intent.amountMinor,
        'currency': intent.currency,
      },
      'name': title,
      'description': description,
      if (themeColor != null)
        'theme': {'color': _hex(themeColor)},
      'prefill': {
        if (intent.email != null) 'email': intent.email,
        if (intent.contact != null) 'contact': intent.contact,
      },
      'notes': {'plan': intent.planId},
      // Both rails: the sheet says what it is registering, and on the
      // subscription rail that sentence is the thing the person is consenting
      // to. An auto-debit that was never described is a chargeback.
      if (intent.isSubscription) 'recurring': true,
      // Long enough for a UPI approval on another app, short enough that an
      // abandoned sheet does not sit open on the order all afternoon.
      'timeout': AppConstants.checkoutTimeoutSeconds,
      'retry': {'enabled': true, 'max_count': 2},
      'send_sms_hash': true,
    });

    return completer.future;
  }

  void _onSuccess(PaymentSuccessResponse response) {
    final intent = _open;
    final paymentId = response.paymentId;
    final signature = response.signature;
    final subscription = intent?.isSubscription ?? false;

    // The plugin lifts `razorpay_order_id` into a field of its own and leaves
    // everything else in the raw map, so the subscription id is read from
    // there — and from the open intent when it is absent, which it is on some
    // rails.
    final reported = response.data?['razorpay_subscription_id'];
    final subscriptionId = subscription
        ? (reported is String && reported.isNotEmpty
              ? reported
              : intent?.subscriptionId)
        : null;
    final orderId = subscription ? null : response.orderId ?? intent?.orderId;

    if ((orderId == null && subscriptionId == null) ||
        paymentId == null ||
        signature == null) {
      // The money may well have moved; what did not arrive is the proof. The
      // webhook is what settles it, so this is a wait, not a failure.
      _settleError(
        const BillingFailure(
          BillingProblem.pending,
          'The payment went through but did not come back complete.',
        ),
      );
      return;
    }

    _settle(
      PaymentReceipt(
        orderId: orderId,
        subscriptionId: subscriptionId,
        paymentId: paymentId,
        signature: signature,
      ),
    );
  }

  void _onError(PaymentFailureResponse response) {
    _settleError(
      BillingFailure(
        switch (response.code) {
          Razorpay.PAYMENT_CANCELLED => BillingProblem.cancelled,
          Razorpay.NETWORK_ERROR => BillingProblem.offline,
          // A plugin that is not registered, or options the SDK refused. Both
          // are integration faults rather than anything the person did, and
          // neither is worth offering a retry for.
          Razorpay.INCOMPATIBLE_PLUGIN ||
          Razorpay.INVALID_OPTIONS => BillingProblem.unavailable,
          Razorpay.TLS_ERROR => BillingProblem.offline,
          _ => BillingProblem.declined,
        },
        _describe(response),
      ),
    );
  }

  /// An external wallet — Paytm and the like — takes the person out of the app
  /// and the result arrives as a webhook rather than here. Treated as pending
  /// for the same reason a slow UPI payment is: the money may have moved, and
  /// the server is the one that finds out.
  void _onExternalWallet(ExternalWalletResponse response) {
    _settleError(
      BillingFailure(
        BillingProblem.pending,
        'Finishing in ${response.walletName ?? 'your wallet app'}.',
      ),
    );
  }

  /// Razorpay's own wording where there is any, because "Your card was
  /// declined because of insufficient funds" is a better sentence than
  /// anything this file would write.
  static String? _describe(PaymentFailureResponse response) {
    final error = response.error;
    if (error is Map) {
      final description = error['description'] ?? error['reason'];
      if (description is String && description.isNotEmpty) return description;
    }
    final message = response.message;
    if (message == null || message.isEmpty) return null;
    return message;
  }

  void _settle(PaymentReceipt receipt) {
    final pending = _pending;
    _pending = null;
    _open = null;
    if (pending != null && !pending.isCompleted) pending.complete(receipt);
  }

  void _settleError(BillingFailure failure) {
    final pending = _pending;
    _pending = null;
    _open = null;
    if (pending != null && !pending.isCompleted) {
      pending.completeError(failure);
    } else {
      // A result the plugin replayed after the app was restarted on the bank's
      // page, with nothing waiting on it. Nothing to do here — the webhook
      // grants the period and the realtime broadcast turns the app Pro.
      debugPrint('Razorpay result with nothing waiting: $failure');
    }
  }

  static String _hex(int color) =>
      '#${(color & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

  @override
  void dispose() {
    _settleError(
      const BillingFailure(BillingProblem.cancelled, 'The app closed.'),
    );
    _razorpay?.clear();
    _razorpay = null;
  }
}
