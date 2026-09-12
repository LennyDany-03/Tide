import 'package:flutter/foundation.dart';

import '../../config/plan_catalog.dart';

/// What the `subscriptions` row says, in the app's words.
///
/// [cancelled] is not [expired]: a cancelled plan has been paid for and its
/// period is still running, so Pro stays on until it ends. [pastDue] and
/// [halted] say the same thing about a mandate — a debit failed and is being
/// retried, or has been given up on — and they mean exactly the same for
/// access: the days already paid for are still yours. The distinction is why
/// nothing in this file decides access from the status alone.
enum EntitlementStatus {
  none,
  active,
  cancelled,
  pastDue,
  halted,
  expired;

  /// The server's spelling, which is snake_case and so cannot be [name] for
  /// the two-word one.
  String get wire => switch (this) {
    EntitlementStatus.pastDue => 'past_due',
    _ => name,
  };

  static EntitlementStatus parse(Object? value) {
    for (final status in EntitlementStatus.values) {
      if (status.wire == value) return status;
    }
    return EntitlementStatus.none;
  }
}

/// Whether this account is Pro, on what, until when, and whether anything is
/// going to renew it.
///
/// Immutable, and always read against a clock. `isPro` is not a stored flag —
/// it is [status] and [periodEnd] compared to now, exactly the way
/// `entitlement()` computes it on the server. Two places compute it because
/// the app has to answer offline; they agree because they are the same
/// expression.
///
/// **Whose clock.** The server sends its own time with every answer, and the
/// gap between that and this device's clock is kept as [skew]. Somebody who
/// sets their phone forward a year does not get a free year, and — the case
/// that actually happens — somebody whose phone is a few minutes slow does
/// not see Pro flicker off on the last day of their period.
@immutable
class Entitlement {
  const Entitlement({
    required this.status,
    this.planId,
    this.periodStart,
    this.periodEnd,
    this.cancelledAt,
    this.source,
    this.lastPaymentId,
    this.autoRenews = false,
    this.nextChargeAt,
    this.mandateStatus,
    this.skew = Duration.zero,
  });

  /// Nobody has paid. What every account starts on, what a signed-out app
  /// falls back to, and what a device with no project behind it stays on.
  static const Entitlement free = Entitlement(status: EntitlementStatus.none);

  final EntitlementStatus status;

  /// `pro_monthly` / `pro_yearly`, matching `billing_plans.id`.
  final String? planId;

  final DateTime? periodStart;
  final DateTime? periodEnd;
  final DateTime? cancelledAt;

  /// `razorpay`, `promo` or `manual`.
  final String? source;

  final String? lastPaymentId;

  /// Whether a mandate is standing behind this plan and will charge again.
  ///
  /// Not derivable from [status]: an active plan may be a prepaid period
  /// bought outright, which ends, or a subscription, which does not. It is the
  /// difference between "ends on 12 October" and "renews on 12 October", and
  /// only the server knows which.
  final bool autoRenews;

  /// When the next debit is due, when one is.
  final DateTime? nextChargeAt;

  /// Razorpay's own word for the mandate — `active`, `pending`, `halted`,
  /// `cancelled` — kept verbatim for support, and for the one screen that has
  /// to explain a failed renewal.
  final String? mandateStatus;

  /// Server time minus device time, as of the last answer. Public because
  /// [copyWith] and the cache both carry it forward, and because a test that
  /// wants to stand on a particular day sets it here.
  final Duration skew;

  BillingPlan? get plan => PlanCatalog.byId(planId);

  /// Now, as the server would see it.
  DateTime get _now => DateTime.now().add(skew);

  /// The whole question, in one place.
  bool get isPro => isProAt(_now);

  /// Mirrors `entitlement_of` in `supabase/billing_setup.sql` exactly. Every
  /// status but a refund ([none]) and a period already run out ([expired]) is
  /// Pro while the period runs, because the period is what was paid for: a
  /// failed renewal stops the next month, it does not undo this one.
  ///
  /// Written as a switch rather than a set so that adding a status to the enum
  /// fails to compile until somebody has decided whether it is Pro.
  bool isProAt(DateTime when) {
    final end = periodEnd;
    if (end == null) return false;
    switch (status) {
      case EntitlementStatus.active:
      case EntitlementStatus.cancelled:
      case EntitlementStatus.pastDue:
      case EntitlementStatus.halted:
        return end.isAfter(when);
      case EntitlementStatus.none:
      case EntitlementStatus.expired:
        return false;
    }
  }

  /// Days left in the paid period, rounded up, so the last partial day counts
  /// as a day. Zero when there is no period or it has run out.
  int get daysRemaining {
    final end = periodEnd;
    if (end == null || !isPro) return 0;
    final left = end.difference(_now);
    if (left.isNegative) return 0;
    return (left.inMinutes / (60 * 24)).ceil();
  }

  /// True while the period is running and **nothing will renew it** — either
  /// cancelled, or a prepaid period nearing its end.
  ///
  /// [autoRenews] is what keeps this honest since auto-pay: nagging somebody
  /// to renew a plan that is about to charge their card on its own is how an
  /// account ends up paying for the same month twice.
  bool get lapsesSoon => isPro && !autoRenews && daysRemaining <= 7;

  /// The other side of it: money is about to move, and it is worth saying so
  /// before it does rather than after.
  bool get renewsSoon => isPro && autoRenews && daysRemaining <= 7;

  /// A debit did not go through. Pro is still on — see [isProAt] — but the
  /// renewal is in trouble and the person is the only one who can fix it.
  bool get renewalFailing =>
      status == EntitlementStatus.pastDue || status == EntitlementStatus.halted;

  /// Was Pro, is not any more. Worth saying differently from never having
  /// paid: the offer to renew reads differently from the offer to start.
  bool get lapsed => !isPro && periodEnd != null;

  /// Whether stopping this plan has to go through Razorpay rather than a local
  /// write, and — the part that shows on screen — whether "Resume" is even a
  /// thing that exists for it. A cancelled mandate cannot be un-cancelled at
  /// Razorpay, so starting again is a checkout.
  bool get cancelsThroughProvider => mandateStatus != null;

  Entitlement copyWith({Duration? skew}) => Entitlement(
    status: status,
    planId: planId,
    periodStart: periodStart,
    periodEnd: periodEnd,
    cancelledAt: cancelledAt,
    source: source,
    lastPaymentId: lastPaymentId,
    autoRenews: autoRenews,
    nextChargeAt: nextChargeAt,
    mandateStatus: mandateStatus,
    skew: skew ?? this.skew,
  );

  // --- The wire ----------------------------------------------------------
  //
  // The shape `entitlement()` returns, and the shape the device's copy is
  // kept in. Parsing is forgiving on purpose: a field added to the function
  // later must not stop an older build reading the rest, and a row written by
  // a newer build must not lock somebody out of a plan they paid for.

  static Entitlement fromJson(Object? json) {
    if (json is! Map) return free;

    final serverTime = _time(json['server_time']);
    return Entitlement(
      status: EntitlementStatus.parse(json['status']),
      planId: json['plan'] as String?,
      periodStart: _time(json['current_period_start']),
      periodEnd: _time(json['current_period_end']),
      cancelledAt: _time(json['cancelled_at']),
      source: json['source'] as String?,
      lastPaymentId: json['last_payment_id'] as String?,
      autoRenews: json['auto_renews'] == true,
      nextChargeAt: _time(json['next_charge_at']),
      mandateStatus: json['mandate_status'] as String?,
      skew: serverTime == null
          ? Duration.zero
          : serverTime.difference(DateTime.now()),
    );
  }

  /// What is kept on the device. The skew is written out as the server time it
  /// came from, so a copy read back next week is still measured against the
  /// server's clock rather than silently re-anchored to this one.
  Map<String, dynamic> toJson() => {
    'status': status.wire,
    'plan': planId,
    'current_period_start': periodStart?.toIso8601String(),
    'current_period_end': periodEnd?.toIso8601String(),
    'cancelled_at': cancelledAt?.toIso8601String(),
    'source': source,
    'last_payment_id': lastPaymentId,
    'auto_renews': autoRenews,
    'next_charge_at': nextChargeAt?.toIso8601String(),
    'mandate_status': mandateStatus,
    'server_time': DateTime.now().add(skew).toIso8601String(),
  };

  static DateTime? _time(Object? value) {
    if (value is! String || value.isEmpty) return null;
    return DateTime.tryParse(value)?.toLocal();
  }

  @override
  bool operator ==(Object other) =>
      other is Entitlement &&
      other.status == status &&
      other.planId == planId &&
      other.periodStart == periodStart &&
      other.periodEnd == periodEnd &&
      other.cancelledAt == cancelledAt &&
      other.source == source &&
      other.lastPaymentId == lastPaymentId &&
      other.autoRenews == autoRenews &&
      other.nextChargeAt == nextChargeAt &&
      other.mandateStatus == mandateStatus;

  @override
  int get hashCode => Object.hash(
    status,
    planId,
    periodStart,
    periodEnd,
    cancelledAt,
    source,
    lastPaymentId,
    autoRenews,
    nextChargeAt,
    mandateStatus,
  );

  @override
  String toString() =>
      'Entitlement(${status.wire}${planId == null ? '' : ' $planId'}'
      '${periodEnd == null ? '' : ' until $periodEnd'}, pro: $isPro'
      '${autoRenews ? ', renews' : ''})';
}
