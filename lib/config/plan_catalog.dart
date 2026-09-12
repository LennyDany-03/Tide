import 'package:flutter/foundation.dart';

/// How long one payment buys.
enum PlanInterval { month, year }

/// One thing that can be bought.
///
/// The app quotes these; the server charges from `billing_plans` in
/// `supabase/billing_setup.sql`. Two copies of a price is one copy too many,
/// and the mismatch would be invisible — the sheet would say ₹199 and the
/// bank would take ₹299 — so `test/plan_catalog_test.dart` reads the SQL and
/// fails when the two drift apart.
///
/// Amounts are in paise, the same unit Razorpay takes, because a price that
/// is ever a `double` is a price that is eventually wrong by a rupee.
@immutable
class BillingPlan {
  const BillingPlan({
    required this.id,
    required this.title,
    required this.interval,
    required this.amountMinor,
    required this.periodDays,
    required this.note,
    this.currency = 'INR',
  });

  /// Matches `billing_plans.id` on the server. The only thing the app sends
  /// when it asks for an order — never the amount.
  final String id;

  /// What the tier card says: "Monthly", "Yearly".
  final String title;

  final PlanInterval interval;

  /// Paise. ₹199 is 19900.
  final int amountMinor;

  final int periodDays;

  /// The line under the price.
  final String note;

  final String currency;

  /// "₹199". Whole rupees, because both plans are priced in them; a plan with
  /// paise would need the two decimal places and does not exist.
  String get price => '${symbolFor(currency)}${amountMinor ~/ 100}';

  /// What the CTA says money-wise: "₹199 / month".
  String get perPeriod =>
      '$price / ${interval == PlanInterval.month ? 'month' : 'year'}';

  /// The yearly plan expressed the way it is actually compared — against
  /// twelve monthly payments.
  String get equivalentMonthly =>
      '${symbolFor(currency)}${(amountMinor / 12 / 100).round()}';

  static String symbolFor(String currency) => switch (currency) {
    'INR' => '₹',
    'USD' => r'$',
    'EUR' => '€',
    'GBP' => '£',
    _ => '$currency ',
  };
}

/// The price list, as data.
///
/// Two plans and no lifetime tier. The sheet used to offer "$39 once", which
/// a prepaid-period model cannot honour: there is no mandate behind these
/// payments and no way to charge again, so a lifetime price is a promise the
/// billing table has no column for.
abstract final class PlanCatalog {
  static const BillingPlan monthly = BillingPlan(
    id: 'pro_monthly',
    title: 'Monthly',
    interval: PlanInterval.month,
    amountMinor: 19900,
    periodDays: 30,
    note: 'billed every 30 days',
  );

  static const BillingPlan yearly = BillingPlan(
    id: 'pro_yearly',
    title: 'Yearly',
    interval: PlanInterval.year,
    amountMinor: 149900,
    periodDays: 365,
    note: 'billed once a year',
  );

  static const List<BillingPlan> all = [monthly, yearly];

  /// Which one the sheet opens on. Yearly: it is the better deal and the one
  /// the savings badge is attached to, and a picker that opens on the option
  /// nobody recommends makes the recommendation look like an upsell.
  static const BillingPlan preferred = yearly;

  static BillingPlan? byId(String? id) {
    for (final plan in all) {
      if (plan.id == id) return plan;
    }
    return null;
  }

  /// How much less a year costs than twelve months of the monthly plan, as a
  /// whole percentage. Drawn on the yearly card.
  static int get yearlySavingPercent {
    final twelveMonths = monthly.amountMinor * 12;
    if (twelveMonths <= 0) return 0;
    return (100 * (twelveMonths - yearly.amountMinor) / twelveMonths).round();
  }
}
