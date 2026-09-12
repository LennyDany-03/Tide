import 'package:flutter/foundation.dart';

import '../../config/plan_catalog.dart';

/// What the `subscriptions` row says, in the app's words.
///
/// [cancelled] is not [expired]: a cancelled plan has been paid for and its
/// period is still running, so Pro stays on until it ends. The distinction is
/// why nothing in this file decides access from the status alone.
enum EntitlementStatus { none, active, cancelled, expired }

/// Whether this account is Pro, on what, and until when.
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

  /// Server time minus device time, as of the last answer. Public because
  /// [copyWith] and the cache both carry it forward, and because a test that
  /// wants to stand on a particular day sets it here.
  final Duration skew;

  BillingPlan? get plan => PlanCatalog.byId(planId);

  /// Now, as the server would see it.
  DateTime get _now => DateTime.now().add(skew);

  /// The whole question, in one place.
  bool get isPro => isProAt(_now);

  bool isProAt(DateTime when) {
    final end = periodEnd;
    if (end == null) return false;
    if (status != EntitlementStatus.active &&
        status != EntitlementStatus.cancelled) {
      return false;
    }
    return end.isAfter(when);
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

  /// True while the period is running but nothing will renew it — either
  /// cancelled, or simply the normal state of a prepaid plan nearing its end.
  bool get lapsesSoon => isPro && daysRemaining <= 7;

  /// Was Pro, is not any more. Worth saying differently from never having
  /// paid: the offer to renew reads differently from the offer to start.
  bool get lapsed => !isPro && periodEnd != null;

  Entitlement copyWith({Duration? skew}) => Entitlement(
    status: status,
    planId: planId,
    periodStart: periodStart,
    periodEnd: periodEnd,
    cancelledAt: cancelledAt,
    source: source,
    lastPaymentId: lastPaymentId,
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
      status:
          EntitlementStatus.values.asNameMap()[json['status']] ??
          EntitlementStatus.none,
      planId: json['plan'] as String?,
      periodStart: _time(json['current_period_start']),
      periodEnd: _time(json['current_period_end']),
      cancelledAt: _time(json['cancelled_at']),
      source: json['source'] as String?,
      lastPaymentId: json['last_payment_id'] as String?,
      skew: serverTime == null
          ? Duration.zero
          : serverTime.difference(DateTime.now()),
    );
  }

  /// What is kept on the device. The skew is written out as the server time it
  /// came from, so a copy read back next week is still measured against the
  /// server's clock rather than silently re-anchored to this one.
  Map<String, dynamic> toJson() => {
    'status': status.name,
    'plan': planId,
    'current_period_start': periodStart?.toIso8601String(),
    'current_period_end': periodEnd?.toIso8601String(),
    'cancelled_at': cancelledAt?.toIso8601String(),
    'source': source,
    'last_payment_id': lastPaymentId,
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
      other.lastPaymentId == lastPaymentId;

  @override
  int get hashCode => Object.hash(
    status,
    planId,
    periodStart,
    periodEnd,
    cancelledAt,
    source,
    lastPaymentId,
  );

  @override
  String toString() =>
      'Entitlement(${status.name}${planId == null ? '' : ' $planId'}'
      '${periodEnd == null ? '' : ' until $periodEnd'}, pro: $isPro)';
}
