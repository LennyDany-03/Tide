import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/plan_catalog.dart';
import 'billing_service.dart';
import 'entitlement.dart';
import 'payment_gateway.dart';

/// Entitlement held by Supabase, money taken by Razorpay.
///
/// Three ways an account's plan reaches this device, and the order they are
/// listed in is the order they are trusted in:
///
///   1. **The realtime broadcast** on `billing:<user id>`. A trigger on
///      `subscriptions` announces every change, so a period granted by a
///      webhook — on a server this app is not talking to, possibly minutes
///      after the payment sheet was closed — turns the app Pro without
///      anybody reloading anything.
///   2. **`entitlement()`**, asked on sign-in, on pull to refresh, and after a
///      payment. The authority, and what the broadcast is only a shortcut for.
///   3. **The device's copy**, read synchronously at launch so a Pro account
///      draws Pro on its first frame. Never the authority: it is replaced the
///      moment the server answers, and it is dropped on log out.
///
/// **Where the money is checked.** Nowhere in this file. `startCheckout` asks
/// an Edge Function to open an order, the gateway collects the payment, and
/// `confirm` hands the three fields Razorpay returned to another Edge
/// Function, which verifies the signature against its own order row. This
/// class never decides that anybody is Pro; it only ever relays an answer.
class SupabaseBillingService extends BillingService {
  SupabaseBillingService(this._client, this._gateway, this._prefs);

  /// Reads the device's copy before the first frame, the way
  /// `SupabaseHabitRepository.load` and `DeviceFlags.load` do.
  static Future<SupabaseBillingService> load(
    SupabaseClient client, {
    PaymentGateway? gateway,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    return SupabaseBillingService(
      client,
      gateway ?? DemoPaymentGateway(),
      prefs,
    );
  }

  final SupabaseClient _client;
  final PaymentGateway _gateway;
  final SharedPreferences _prefs;

  static const String _cachePrefix = 'tide.entitlement.';

  /// How long the app waits on the server before falling back to what it
  /// already knows. Short: every one of these calls has a good answer to give
  /// when it times out.
  static const Duration _timeout = Duration(seconds: 12);

  final StreamController<Entitlement> _changes =
      StreamController<Entitlement>.broadcast();

  String? _accountId;
  RealtimeChannel? _channel;
  Entitlement _current = Entitlement.free;

  @override
  Entitlement cached(String? accountId) {
    if (accountId == null) return Entitlement.free;
    final raw = _prefs.getString('$_cachePrefix$accountId');
    if (raw == null) return Entitlement.free;
    try {
      return Entitlement.fromJson(jsonDecode(raw));
    } catch (error) {
      debugPrint('Entitlement cache unreadable: $error');
      return Entitlement.free;
    }
  }

  @override
  Stream<Entitlement> get changes => _changes.stream;

  @override
  bool get isLocalOnly => false;

  @override
  bool get canPay => _gateway.available;

  @override
  void open(String accountId) {
    if (_accountId == accountId) return;
    unawaited(close());
    _accountId = accountId;
    _current = cached(accountId);
    unawaited(_listen(accountId));
    unawaited(refresh());
  }

  @override
  Future<PaymentReceipt> collectPayment(
    CheckoutIntent intent, {
    required String title,
    required String description,
    int? themeColor,
  }) => _gateway.collect(
    intent,
    title: title,
    description: description,
    themeColor: themeColor,
  );

  @override
  Future<Entitlement> refresh() async {
    final accountId = _accountId;
    if (accountId == null) return Entitlement.free;
    try {
      final answer = await _client
          .rpc<dynamic>('entitlement')
          .timeout(_timeout);
      if (_accountId != accountId) return _current;
      return _adopt(Entitlement.fromJson(answer), accountId);
    } catch (error) {
      // The last known answer stands. Dropping somebody to free because their
      // train went into a tunnel is worse than being briefly out of date, and
      // the period they paid for is on the device with an end date on it.
      debugPrint('Entitlement not refreshed: $error');
      return _current;
    }
  }

  @override
  Future<CheckoutIntent> startCheckout(BillingPlan plan) async {
    if (_accountId == null) {
      throw const BillingFailure(
        BillingProblem.unavailable,
        'Sign in before starting a payment.',
      );
    }
    if (!_gateway.available) {
      throw const BillingFailure(
        BillingProblem.unsupportedPlatform,
        'Tide Pro can be bought in the phone app.',
      );
    }

    // Only the plan id is sent. The amount is read from `billing_plans` inside
    // the function, so a request that made up its own price would be charged
    // the real one.
    final body = await _invoke('razorpay-create-order', {'plan': plan.id});

    final orderId = body['order_id'];
    final keyId = body['key_id'];
    if (orderId is! String || keyId is! String || keyId.isEmpty) {
      throw const BillingFailure(
        BillingProblem.unavailable,
        'The order did not come back complete.',
      );
    }

    final user = _client.auth.currentUser;
    return CheckoutIntent(
      orderId: orderId,
      keyId: keyId,
      planId: body['plan'] as String? ?? plan.id,
      // The server's figure, not the catalogue's: the sheet shows what will
      // actually be charged even on a build that shipped before a price
      // changed.
      amountMinor: (body['amount_minor'] as num?)?.toInt() ?? plan.amountMinor,
      currency: body['currency'] as String? ?? plan.currency,
      email: user?.email,
      contact: user?.phone?.isEmpty ?? true ? null : user?.phone,
    );
  }

  @override
  Future<Entitlement> confirm(PaymentReceipt receipt) async {
    final accountId = _accountId;
    if (accountId == null) {
      throw const BillingFailure(BillingProblem.unavailable, 'Signed out.');
    }

    final body = await _invoke('razorpay-verify-payment', {
      'razorpay_order_id': receipt.orderId,
      'razorpay_payment_id': receipt.paymentId,
      'razorpay_signature': receipt.signature,
    });

    // The bank had not come back when the device did. The webhook finishes it,
    // and the broadcast turns the app Pro — so this is a wait, not a failure,
    // and the sheet says so.
    if (body['pending'] == true) {
      throw const BillingFailure(
        BillingProblem.pending,
        'Payment received. Confirming it now.',
      );
    }

    final entitlement = Entitlement.fromJson(body['entitlement']);
    return _adopt(entitlement, accountId);
  }

  @override
  Future<void> abandon(String orderId, {Object? error}) async {
    if (_accountId == null) return;
    final failure = error is BillingFailure ? error : null;
    try {
      await _invoke('razorpay-verify-payment', {
        'razorpay_order_id': orderId,
        'error': {
          'code': failure?.problem.name ?? 'unknown',
          'description': failure?.detail ?? error?.toString(),
          'source': 'customer',
          'step': 'payment_authentication',
          'reason': failure?.problem.name ?? 'unknown',
        },
      });
    } catch (report) {
      // A failed payment that also fails to be written down is still just a
      // failed payment. Nothing above this is waiting on it.
      debugPrint('Failed payment not recorded: $report');
    }
  }

  @override
  Future<void> close({bool forget = false}) async {
    final accountId = _accountId;
    _accountId = null;

    final channel = _channel;
    _channel = null;
    if (channel != null) {
      try {
        await _client.removeChannel(channel);
      } catch (error) {
        debugPrint('Billing channel not removed: $error');
      }
    }

    if (forget && accountId != null) {
      await _prefs.remove('$_cachePrefix$accountId');
      _current = Entitlement.free;
      _announce(Entitlement.free);
    }
  }

  // --- Realtime -----------------------------------------------------------

  Future<void> _listen(String accountId) async {
    // A private channel is authorised by the token the socket holds when it
    // joins, and that token can still be on its way just after a sign-in — so
    // it is set here rather than joining on the publishable key and being
    // refused. The same reasoning as the habits channel.
    final token = _client.auth.currentSession?.accessToken;
    if (token != null) {
      try {
        await _client.realtime.setAuth(token);
      } catch (error) {
        debugPrint('Realtime token not set: $error');
      }
    }
    if (_accountId != accountId) return;

    final channel = _client.channel(
      'billing:$accountId',
      opts: const RealtimeChannelConfig(private: true),
    );
    _channel = channel;

    var joinedBefore = false;
    channel
      ..onBroadcast(
        event: '*',
        callback: (message) => _onBroadcast(accountId, message),
      )
      ..subscribe((state, error) {
        if (!identical(_channel, channel)) return;
        if (state == RealtimeSubscribeStatus.subscribed) {
          // A rejoin follows a dropped socket, and a period granted while it
          // was down was announced to nobody. The first join is already
          // covered by the refresh [open] started.
          if (joinedBefore) unawaited(refresh());
          joinedBefore = true;
        } else if (state != RealtimeSubscribeStatus.closed) {
          debugPrint('Billing channel ${state.name}: ${error ?? ''}');
        }
      });
  }

  /// A `subscriptions` row changed.
  ///
  /// The row is not parsed into an entitlement here. It carries the raw
  /// columns, and `pro` is a comparison against the *server's* clock that only
  /// `entitlement()` can make — so the broadcast is treated as a nudge and the
  /// answer is asked for properly. It arrives a few hundred milliseconds
  /// later, which is not a cost anybody can see.
  void _onBroadcast(String accountId, Map<String, dynamic> message) {
    if (_accountId != accountId) return;
    final body = message['payload'];
    if (body is! Map || body['table'] != 'subscriptions') return;
    unawaited(refresh());
  }

  // --- Plumbing -----------------------------------------------------------

  /// Calls an Edge Function and turns whatever went wrong into a
  /// [BillingFailure] the sheet can draw.
  Future<Map<String, dynamic>> _invoke(
    String name,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await _client.functions
          .invoke(name, body: body)
          .timeout(_timeout);
      final data = response.data;
      if (data is Map) return Map<String, dynamic>.from(data);
      throw const BillingFailure(
        BillingProblem.unavailable,
        'The server sent something unreadable.',
      );
    } on BillingFailure {
      rethrow;
    } on FunctionException catch (error) {
      throw _translate(error);
    } on TimeoutException {
      throw const BillingFailure(
        BillingProblem.offline,
        'The server did not answer in time.',
      );
    } catch (error) {
      if (_looksOffline(error)) {
        throw const BillingFailure(BillingProblem.offline);
      }
      throw BillingFailure(BillingProblem.unknown, error.toString());
    }
  }

  /// The function's own `error.code` decides the problem, because it is the
  /// half of the reply that was written to be switched on. The HTTP status is
  /// only consulted when there is no body to read — a function that is not
  /// deployed, or a gateway in the way.
  BillingFailure _translate(FunctionException error) {
    final details = error.details;
    final body = details is Map ? details['error'] : null;
    final code = body is Map ? body['code'] : null;
    final message = body is Map ? body['message'] as String? : null;

    return BillingFailure(switch (code) {
      'signature_mismatch' ||
      'amount_mismatch' ||
      'payment_mismatch' ||
      'unknown_order' ||
      'unknown_plan' => BillingProblem.rejected,
      'payment_failed' => BillingProblem.declined,
      // Verified and paid; only the grant did not land. The webhook applies
      // the same payment, so this waits rather than failing.
      'grant_failed' => BillingProblem.pending,
      'gateway_error' => BillingProblem.declined,
      'unauthorised' => BillingProblem.unavailable,
      _ => switch (error.status) {
        401 || 403 => BillingProblem.unavailable,
        404 => BillingProblem.unavailable,
        502 || 503 || 504 => BillingProblem.offline,
        _ => BillingProblem.unknown,
      },
    }, message ?? error.reasonPhrase);
  }

  /// Matched on the description rather than on a type, the same way
  /// `SupabaseAuthService._unexpected` does it: `SocketException` lives in
  /// `dart:io`, and importing that would stop the app building for web.
  static bool _looksOffline(Object error) {
    final described = error.toString();
    return described.contains('SocketException') ||
        described.contains('ClientException') ||
        described.contains('TimeoutException') ||
        described.contains('Failed host lookup');
  }

  Entitlement _adopt(Entitlement next, String accountId) {
    _current = next;
    unawaited(
      _prefs.setString('$_cachePrefix$accountId', jsonEncode(next.toJson())),
    );
    _announce(next);
    return next;
  }

  void _announce(Entitlement next) {
    if (_changes.isClosed) return;
    _changes.add(next);
  }

  void dispose() {
    unawaited(close());
    _gateway.dispose();
    unawaited(_changes.close());
  }
}
