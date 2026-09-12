import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tide/config/plan_catalog.dart';

/// The prices the app quotes and the prices the server charges.
///
/// Two copies of a price is one copy too many, and the mismatch would be
/// invisible in the worst possible way: the sheet would say ₹199, the bank
/// would take ₹299, and nothing in the app would ever notice. Razorpay
/// enforces the *order* amount, so a stale build does not overcharge anybody —
/// it just quotes a figure it will not be charged, which is its own kind of
/// wrong.
///
/// So this reads `supabase/billing_setup.sql` and holds the two to each other.
/// If it fails, one of the pair was changed without the other; change both.
void main() {
  late String sql;

  setUpAll(() {
    final file = File('supabase/billing_setup.sql');
    expect(
      file.existsSync(),
      isTrue,
      reason: 'run from the repo root: flutter test',
    );
    sql = file.readAsStringSync();
  });

  /// The `values (...)` row for one plan out of the seed insert.
  ///
  /// Deliberately a narrow match rather than a SQL parser: it has one job,
  /// and a regular expression that stops matching when the statement is
  /// reformatted is a better failure than a parser that quietly matches the
  /// wrong thing.
  List<String> rowFor(String planId) {
    final match = RegExp(
      "\\('$planId',([^)]*)\\)",
    ).firstMatch(sql);
    expect(match, isNotNull, reason: '$planId is not seeded in the SQL');
    return match!
        .group(1)!
        .split(',')
        .map((piece) => piece.trim().replaceAll("'", ''))
        .toList();
  }

  for (final plan in PlanCatalog.all) {
    group(plan.id, () {
      test('is on sale at the same price on both sides', () {
        final row = rowFor(plan.id);
        // (id, name, interval, period_days, amount_minor, currency, sort)
        // minus the id the pattern already consumed.
        expect(row[1], plan.interval.name, reason: 'interval');
        expect(int.parse(row[2]), plan.periodDays, reason: 'period_days');
        expect(int.parse(row[3]), plan.amountMinor, reason: 'amount_minor');
        expect(row[4], plan.currency, reason: 'currency');
      });
    });
  }

  test('the saving on the yearly plan is real and worth naming', () {
    final twelveMonths = PlanCatalog.monthly.amountMinor * 12;
    expect(
      PlanCatalog.yearly.amountMinor,
      lessThan(twelveMonths),
      reason: 'a yearly plan that costs more than paying monthly is a trap',
    );
    expect(
      PlanCatalog.yearlySavingPercent,
      greaterThanOrEqualTo(10),
      reason: 'under that, the badge is noise rather than a reason',
    );
  });

  test('prices are whole rupees, because that is how they are drawn', () {
    // `BillingPlan.price` renders `amountMinor ~/ 100` with no decimals, so a
    // plan priced at ₹199.50 would be shown as ₹199 and charged as ₹199.50.
    for (final plan in PlanCatalog.all) {
      expect(plan.amountMinor % 100, 0, reason: plan.id);
    }
  });

  test('every plan the app sells exists on the server', () {
    for (final plan in PlanCatalog.all) {
      expect(sql, contains("'${plan.id}'"));
    }
  });

  test('the plan the sheet opens on is one of the plans', () {
    expect(PlanCatalog.all, contains(PlanCatalog.preferred));
  });
}
