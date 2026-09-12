import 'package:flutter_test/flutter_test.dart';
import 'package:tide/services/billing/payment_record.dart';

/// Reading the `orders` half of `billing_snapshot()`.
///
/// The rule these all check is the one the codec files share: a row the app
/// cannot make sense of is dropped, and it never takes the rest of the list
/// with it. A payment history that fails to render because the server added a
/// column is worse than one missing a line.
void main() {
  Map<String, Object?> row({
    Object? id = 'ord_1',
    Object? createdAt = '2026-09-12T12:00:00Z',
    Object? plan = 'pro_monthly',
    Object? amount = 19900,
    Object? currency = 'INR',
    Object? status = 'captured',
    Object? method = 'upi',
    Object? paymentId = 'pay_abc',
  }) => {
    'id': id,
    'created_at': createdAt,
    'plan': plan,
    'amount_minor': amount,
    'currency': currency,
    'status': status,
    'method': method,
    'payment_id': paymentId,
  };

  group('one row', () {
    test('a full row is read whole', () {
      final record = PaymentRecord.fromJson(row())!;

      expect(record.id, 'ord_1');
      expect(record.planId, 'pro_monthly');
      expect(record.planLabel, 'Monthly');
      expect(record.amountMinor, 19900);
      expect(record.amountLabel, '₹199');
      expect(record.status, PaymentStatus.captured);
      expect(record.paid, isTrue);
      expect(record.methodLabel, 'UPI');
      expect(record.paymentId, 'pay_abc');
    });

    test('the server renames two fields, and both are read by that name', () {
      // `plan` and `payment_id` — not `plan_id` and `razorpay_payment_id`.
      // billing_snapshot renames them on the way out, and getting either
      // wrong would silently blank a column of the receipt list.
      final wrong = PaymentRecord.fromJson({
        'id': 'ord_1',
        'created_at': '2026-09-12T12:00:00Z',
        'plan_id': 'pro_yearly',
        'razorpay_payment_id': 'pay_xyz',
      })!;
      expect(wrong.planId, isNull);
      expect(wrong.paymentId, isNull);
    });

    test('an optional field absent is null, not an empty string', () {
      final record = PaymentRecord.fromJson(
        row(method: null, paymentId: null, plan: null),
      )!;
      expect(record.method, isNull);
      expect(record.methodLabel, isNull);
      expect(record.paymentId, isNull);
      expect(record.planId, isNull);
      // Still renders: a retired plan must not blank the row.
      expect(record.planLabel, 'Tide Pro');
    });

    test('an empty string is treated as absent', () {
      final record = PaymentRecord.fromJson(row(method: '', paymentId: ''))!;
      expect(record.method, isNull);
      expect(record.paymentId, isNull);
    });

    test('a status this build has never heard of is not a crash', () {
      final record = PaymentRecord.fromJson(row(status: 'disputed_v2'))!;
      expect(record.status, PaymentStatus.unknown);
      expect(record.paid, isFalse);
    });

    test('a missing amount reads as zero rather than throwing', () {
      expect(PaymentRecord.fromJson(row(amount: null))!.amountMinor, 0);
    });

    test('a row with no identity or no date is dropped', () {
      expect(PaymentRecord.fromJson(row(id: null)), isNull);
      expect(PaymentRecord.fromJson(row(id: '')), isNull);
      expect(PaymentRecord.fromJson(row(createdAt: null)), isNull);
      expect(PaymentRecord.fromJson(row(createdAt: 'not a date')), isNull);
      expect(PaymentRecord.fromJson('nonsense'), isNull);
      expect(PaymentRecord.fromJson(null), isNull);
    });

    test('a method nobody wrote a label for is still shown, capitalised', () {
      expect(PaymentRecord.fromJson(row(method: 'paylater'))!.methodLabel,
          'Paylater');
    });
  });

  group('the list', () {
    test('keeps the order the server sorted them in', () {
      // Newest first is a contract, so no screen ever sorts money.
      final list = PaymentRecord.listFrom([
        row(id: 'newest', createdAt: '2026-09-12T12:00:00Z'),
        row(id: 'oldest', createdAt: '2026-01-01T12:00:00Z'),
      ]);
      expect(list.map((r) => r.id), ['newest', 'oldest']);
    });

    test('one unreadable row does not take the others with it', () {
      final list = PaymentRecord.listFrom([
        row(id: 'good'),
        {'nothing': 'usable'},
        row(id: 'also_good'),
      ]);
      expect(list.map((r) => r.id), ['good', 'also_good']);
    });

    test('a payload that is not a list is empty, not an exception', () {
      expect(PaymentRecord.listFrom(null), isEmpty);
      expect(PaymentRecord.listFrom('[]'), isEmpty);
      expect(PaymentRecord.listFrom(const {}), isEmpty);
    });
  });
}
