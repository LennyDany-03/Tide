import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/app_constants.dart';
import '../../config/plan_catalog.dart';
import 'billing_service.dart';
import 'entitlement.dart';
import 'payment_gateway.dart';
import 'payment_record.dart';

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
  Future<BillingSnapshot> snapshot({
    int limit = AppConstants.receiptLimit,
  }) async {
    final accountId = _accountId;
    if (accountId == null) return BillingSnapshot.none;
    try {
      final answer = await _client
          .rpc<dynamic>('billing_snapshot', params: {'p_limit': limit})
          .timeout(_timeout);
      if (_accountId != accountId) return BillingSnapshot.none;
      final body = answer is Map ? answer : const {};
      return BillingSnapshot(
        // Adopted rather than merely returned: this is the same authority
        // [refresh] reads, so it caches and it announces. A plan that changed
        // while the billing screen was closed is learned here without a second
        // request, and there is still exactly one path by which a plan reaches
        // the app.
        entitlement: _adopt(
          Entitlement.fromJson(body['entitlement']),
          accountId,
        ),
        payments: PaymentRecord.listFrom(body['orders']),
      );
    } on PostgrestException catch (error) {
      throw _translateRpc(error);
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

  /// **Which of the two this is depends on whether a mandate is standing.**
  ///
  /// On a prepaid period it is the RPC, which writes one row and stops — there
  /// is no charge to stop. On a plan with a mandate it is an Edge Function,
  /// because stopping a debit means telling Razorpay, and the SQL refuses a
  /// local write for exactly that reason: a row marked cancelled while the
  /// instruction is still registered is the app saying nothing more will be
  /// taken while the money keeps going out.
  ///
  /// The mandate is read off entitlement rather than asked for: the answer is
  /// already on the device, and a round trip to find out how to make a round
  /// trip is a round trip nobody needs.
  @override
  Future<Entitlement> cancelSubscription() =>
      _current.cancelsThroughProvider
      ? _mandate('razorpay-cancel-subscription')
      : _renewal('cancel_subscription');

  /// There is no resuming a mandate — Razorpay has no un-cancel — so this
  /// refuses before it reaches the network and the screen offers a new
  /// checkout instead. See [BillingProblem.resubscribeNeeded].
  @override
  Future<Entitlement> resumeSubscription() {
    if (_current.cancelsThroughProvider) {
      return Future<Entitlement>.error(
        const BillingFailure(
          BillingProblem.resubscribeNeeded,
          'This plan was cancelled at the payment provider and cannot be '
              'restarted. Subscribing again sets up a new payment method.',
        ),
      );
    }
    return _renewal('resume_subscription');
  }

  /// Cancelling through Razorpay: the function cancels the subscription there
  /// first and marks the row second, so a failure at their end leaves nothing
  /// claimed here.
  Future<Entitlement> _mandate(String function) async {
    final accountId = _accountId;
    if (accountId == null) {
      throw const BillingFailure(BillingProblem.unavailable, 'Signed out.');
    }
    final body = await _invoke(function, const <String, dynamic>{});
    if (_accountId != accountId) return _current;
    return _adopt(Entitlement.fromJson(body['entitlement']), accountId);
  }

  /// Deliberately unlike [refresh], which swallows: there the last known answer
  /// is a good answer, and here there is a person waiting on a button. Leaving
  /// the old entitlement in place silently would read as the tap having worked.
  Future<Entitlement> _renewal(String function) async {
    final accountId = _accountId;
    if (accountId == null) {
      throw const BillingFailure(BillingProblem.unavailable, 'Signed out.');
    }
    try {
      final answer = await _client.rpc<dynamic>(function).timeout(_timeout);
      if (_accountId != accountId) return _current;
      return _adopt(Entitlement.fromJson(answer), accountId);
    } on PostgrestException catch (error) {
      throw _translateRpc(error);
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

  /// The RPC counterpart of [_translate].
  ///
  /// `PGRST202` is the one that actually happens: a build that knows about
  /// these functions running against a project where `billing_setup.sql` has
  /// not been re-run. Saying which file to run beats a generic failure, and it
  /// is the same courtesy `SupabaseAuthService` extends for `delete_account`.
  static BillingFailure _translateRpc(PostgrestException error) =>
      switch (error.code) {
        'PGRST202' || 'PGRST205' => const BillingFailure(
          BillingProblem.unavailable,
          'Billing is not set up on the server yet. Run '
              'supabase/billing_setup.sql in the SQL editor.',
        ),
        '42501' || '28000' => const BillingFailure(
          BillingProblem.unavailable,
          'Sign in again.',
        ),
        _ => BillingFailure(BillingProblem.unknown, error.message),
      };

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

    // Only the plan id is sent, on either rail. The amount — and, for a
    // subscription, the Razorpay plan id, which differs between test mode and
    // live and so lives in the function's secrets — is read on the server. A
    // request that made up its own price would be charged the real one.
    final subscription = plan.autoRenews;
    final body = await _invoke(
      subscription ? 'razorpay-create-subscription' : 'razorpay-create-order',
      {'plan': plan.id},
    );

    final keyId = body['key_id'];
    final reference = body[subscription ? 'subscription_id' : 'order_id'];
    if (reference is! String || keyId is! String || keyId.isEmpty) {
      throw BillingFailure(
        BillingProblem.unavailable,
        'The ${subscription ? 'subscription' : 'order'} did not come back '
            'complete.',
      );
    }

    final user = _client.auth.currentUser;
    final planId = body['plan'] as String? ?? plan.id;
    // The server's figure, not the catalogue's: the sheet shows what will
    // actually be charged even on a build that shipped before a price changed.
    final amountMinor =
        (body['amount_minor'] as num?)?.toInt() ?? plan.amountMinor;
    final currency = body['currency'] as String? ?? plan.currency;
    final email = user?.email;
    final contact = user?.phone?.isEmpty ?? true ? null : user?.phone;

    return subscription
        ? CheckoutIntent.subscription(
            subscriptionId: reference,
            keyId: keyId,
            planId: planId,
            amountMinor: amountMinor,
            currency: currency,
            email: email,
            contact: contact,
          )
        : CheckoutIntent.order(
            orderId: reference,
            keyId: keyId,
            planId: planId,
            amountMinor: amountMinor,
            currency: currency,
            email: email,
            contact: contact,
          );
  }

  @override
  Future<Entitlement> confirm(PaymentReceipt receipt) async {
    final accountId = _accountId;
    if (accountId == null) {
      throw const BillingFailure(BillingProblem.unavailable, 'Signed out.');
    }

    // Both ids are sent as they came back and neither is trusted: the
    // function reads the authoritative one off its own row and checks the
    // signature against that. Which pair is hashed differs by rail — an order
    // signs `order_id|payment_id`, a subscription signs
    // `payment_id|subscription_id` — and that is handled there, not here.
    final body = await _invoke('razorpay-verify-payment', {
      if (receipt.orderId != null) 'razorpay_order_id': receipt.orderId,
      if (receipt.subscriptionId != null)
        'razorpay_subscription_id': receipt.subscriptionId,
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
  Future<void> abandon(CheckoutIntent intent, {Object? error}) async {
    if (_accountId == null) return;
    final failure = error is BillingFailure ? error : null;
    try {
      await _invoke('razorpay-verify-payment', {
        if (intent.orderId != null) 'razorpay_order_id': intent.orderId,
        if (intent.subscriptionId != null)
          'razorpay_subscription_id': intent.subscriptionId,
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

    // No receipts are dropped here because none are held: this service keeps
    // entitlement on the device and the payment history only in the store's
    // memory. If a cache is ever added for receipts, it has to be forgotten
    // here too.
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
