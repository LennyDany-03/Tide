import 'package:flutter/foundation.dart';

/// How long one payment buys.
enum PlanInterval { month, year }

/// How the money arrives, matching `billing_plans.billing_mode`.
///
/// The two rails are genuinely different products, not a setting: [auto]
/// registers a mandate and debits on its own, [oneTime] buys a period outright
/// and then stops. They differ in how they are bought (a subscription versus an
/// order), how they are cancelled (a call to Razorpay versus a local write),
/// and what the screen is allowed to promise.
enum BillingMode {
  oneTime,
  auto;

  /// The server's spelling, which is snake_case. `test/plan_catalog_test.dart`
  /// holds the two sides to each other through this.
  String get wire => this == BillingMode.oneTime ? 'one_time' : 'auto';
}

/// One thing that can be bought.
///
/// The app quotes these; the server charges from `billing_plans` in
/// `supabase/billing_setup.sql`. Two copies of a price is one copy too many,
/// and the mismatch would be invisible — the sheet would say ₹100 and the
/// bank would take ₹199 — so `test/plan_catalog_test.dart` reads the SQL and
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
    this.mode = BillingMode.auto,
    this.currency = 'INR',
  });

  /// Matches `billing_plans.id` on the server. The only thing the app sends
  /// when it asks for a checkout — never the amount, and never the Razorpay
  /// plan id, which lives in the Edge Function's secrets because it differs
  /// between test mode and live.
  final String id;

  /// What the tier card says: "Monthly", "Yearly".
  final String title;

  final PlanInterval interval;

  /// Paise. ₹100 is 10000.
  final int amountMinor;

  /// What one payment buys, in days, and what the prepaid rail extends a
  /// period by. On [BillingMode.auto] the authority is Razorpay's own cycle
  /// end — their calendar month is 28 to 31 days, and a period worked out from
  /// this number would drift off the date the money actually moves.
  final int periodDays;

  /// The line under the price.
  final String note;

  final BillingMode mode;

  final String currency;

  bool get autoRenews => mode == BillingMode.auto;

  /// "₹100". Whole rupees, because both plans are priced in them; a plan with
  /// paise would need the two decimal places and does not exist.
  String get price => '${symbolFor(currency)}${amountMinor ~/ 100}';

  /// What the CTA says money-wise: "₹100 / month".
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
/// Two plans and no lifetime tier. A lifetime price is a promise the billing
/// table has no column for: every period here has an end, and the only thing
/// that carries one past it is a mandate charging again.
abstract final class PlanCatalog {
  static const BillingPlan monthly = BillingPlan(
    id: 'pro_monthly',
    title: 'Monthly',
    interval: PlanInterval.month,
    amountMinor: 10000,
    periodDays: 30,
    note: 'renews every month',
  );

  static const BillingPlan yearly = BillingPlan(
    id: 'pro_yearly',
    title: 'Yearly',
    interval: PlanInterval.year,
    amountMinor: 49900,
    periodDays: 365,
    note: 'renews once a year',
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
