import 'package:flutter_test/flutter_test.dart';
import 'package:tide/services/billing/entitlement.dart';

/// The one calculation the whole paywall rests on: is this account Pro.
///
/// It is worth its own file because it is decided twice — here, and by
/// `entitlement()` in `supabase/billing_setup.sql` — and the two have to agree.
/// Every case below is written the way the SQL reads it: status *and* period
/// end against a clock, never status alone.
void main() {
  Entitlement plan({
    required EntitlementStatus status,
    Duration? endsIn,
    Duration skew = Duration.zero,
  }) {
    final now = DateTime.now();
    return Entitlement(
      status: status,
      planId: 'pro_yearly',
      periodStart: endsIn == null ? null : now.subtract(const Duration(days: 1)),
      periodEnd: endsIn == null ? null : now.add(endsIn),
      skew: skew,
    );
  }

  group('is this account Pro', () {
    test('nobody has paid', () {
      expect(Entitlement.free.isPro, isFalse);
      expect(Entitlement.free.lapsed, isFalse, reason: 'never had a plan');
    });

    test('active and inside its period', () {
      expect(
        plan(
          status: EntitlementStatus.active,
          endsIn: const Duration(days: 30),
        ).isPro,
        isTrue,
      );
    });

    test('cancelled keeps what was paid for until the period ends', () {
      // The distinction the whole model turns on. Cancelling stops a renewal
      // that does not exist on a prepaid plan anyway; it must not take back
      // the days somebody already bought.
      expect(
        plan(
          status: EntitlementStatus.cancelled,
          endsIn: const Duration(days: 5),
        ).isPro,
        isTrue,
      );
    });

    test('a period that has run out is not Pro, whatever the status says', () {
      // The case that matters when nothing has run: a row still marked
      // 'active' with a period that ended last Tuesday. Reading the status
      // alone would hand out a free year here.
      expect(
        plan(
          status: EntitlementStatus.active,
          endsIn: const Duration(days: -1),
        ).isPro,
        isFalse,
      );
    });

    test('a status with no period at all is not Pro', () {
      expect(plan(status: EntitlementStatus.active).isPro, isFalse);
    });

    test('a plan that has ended reads as lapsed, not as never-paid', () {
      final ended = plan(
        status: EntitlementStatus.expired,
        endsIn: const Duration(days: -3),
      );
      expect(ended.isPro, isFalse);
      expect(ended.lapsed, isTrue, reason: 'the offer says "renew", not "start"');
    });
  });

  group('whose clock', () {
    test('a device set a year forward does not expire a paid plan', () {
      // The device believes it is a year from now. The skew says the server
      // does not, and the server is the one holding the money.
      final wrong = Entitlement(
        status: EntitlementStatus.active,
        planId: 'pro_monthly',
        periodStart: DateTime.now(),
        periodEnd: DateTime.now().add(const Duration(days: 30)),
        skew: const Duration(days: -365),
      );
      expect(wrong.isPro, isTrue);
    });

    test('a device set a year back does not extend one', () {
      final over = Entitlement(
        status: EntitlementStatus.active,
        planId: 'pro_monthly',
        periodStart: DateTime.now().subtract(const Duration(days: 60)),
        periodEnd: DateTime.now().subtract(const Duration(days: 30)),
        skew: const Duration(days: 365),
      );
      expect(over.isPro, isFalse);
    });
  });

  group('how long is left', () {
    test('a part day still counts as a day', () {
      // Rounded up, so somebody with nine hours left is told "1 day" rather
      // than "0 days" on a plan that still works.
      final nearly = plan(
        status: EntitlementStatus.active,
        endsIn: const Duration(hours: 9),
      );
      expect(nearly.daysRemaining, 1);
      expect(nearly.isPro, isTrue);
    });

    test('nothing left on a plan that has ended', () {
      expect(
        plan(
          status: EntitlementStatus.active,
          endsIn: const Duration(days: -1),
        ).daysRemaining,
        0,
      );
    });

    test('the last week is worth saying differently', () {
      expect(
        plan(
          status: EntitlementStatus.active,
          endsIn: const Duration(days: 3),
        ).lapsesSoon,
        isTrue,
      );
      expect(
        plan(
          status: EntitlementStatus.active,
          endsIn: const Duration(days: 40),
        ).lapsesSoon,
        isFalse,
      );
    });
  });

  group('the wire', () {
    test('the shape entitlement() returns is read whole', () {
      final end = DateTime.now().add(const Duration(days: 200));
      final parsed = Entitlement.fromJson({
        'pro': true,
        'plan': 'pro_yearly',
        'interval': 'year',
        'status': 'active',
        'source': 'razorpay',
        'current_period_start': DateTime.now().toIso8601String(),
        'current_period_end': end.toIso8601String(),
        'cancelled_at': null,
        'last_payment_id': 'pay_abc123',
        'server_time': DateTime.now().toIso8601String(),
      });

      expect(parsed.isPro, isTrue);
      expect(parsed.planId, 'pro_yearly');
      expect(parsed.source, 'razorpay');
      expect(parsed.lastPaymentId, 'pay_abc123');
      expect(parsed.plan?.title, 'Yearly');
    });

    test('an answer the app does not recognise falls back to free', () {
      // Forgiving on purpose: a field added to the function later must not
      // stop an older build reading the rest.
      expect(Entitlement.fromJson(null).isPro, isFalse);
      expect(Entitlement.fromJson('nonsense').isPro, isFalse);
      expect(
        Entitlement.fromJson({'status': 'something_new'}).status,
        EntitlementStatus.none,
      );
    });

    test('the device copy survives a round trip', () {
      final original = plan(
        status: EntitlementStatus.active,
        endsIn: const Duration(days: 120),
      );
      final restored = Entitlement.fromJson(original.toJson());

      expect(restored, original);
      expect(restored.isPro, isTrue);
      expect(restored.daysRemaining, original.daysRemaining);
    });
  });
}
