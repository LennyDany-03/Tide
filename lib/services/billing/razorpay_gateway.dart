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
  String? _openOrderId;

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
    _openOrderId = intent.orderId;

    razorpay.open({
      'key': intent.keyId,
      'order_id': intent.orderId,
      // Sent for display only. The order is what is charged, and Razorpay
      // refuses a mismatch — which is the behaviour wanted: a build quoting a
      // stale price fails loudly rather than charging one figure and showing
      // another.
      'amount': intent.amountMinor,
      'currency': intent.currency,
      'name': title,
      'description': description,
      if (themeColor != null)
        'theme': {'color': _hex(themeColor)},
      'prefill': {
        if (intent.email != null) 'email': intent.email,
        if (intent.contact != null) 'contact': intent.contact,
      },
      'notes': {'plan': intent.planId},
      // Long enough for a UPI approval on another app, short enough that an
      // abandoned sheet does not sit open on the order all afternoon.
      'timeout': AppConstants.checkoutTimeoutSeconds,
      'retry': {'enabled': true, 'max_count': 2},
      'send_sms_hash': true,
    });

    return completer.future;
  }

  void _onSuccess(PaymentSuccessResponse response) {
    final orderId = response.orderId ?? _openOrderId;
    final paymentId = response.paymentId;
    final signature = response.signature;

    if (orderId == null || paymentId == null || signature == null) {
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
    _openOrderId = null;
    if (pending != null && !pending.isCompleted) pending.complete(receipt);
  }

  void _settleError(BillingFailure failure) {
    final pending = _pending;
    _pending = null;
    _openOrderId = null;
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
