import 'package:flutter/material.dart';

import '../../../config/app_constants.dart';
import '../../../config/plan_catalog.dart';
import '../../../services/billing/entitlement.dart';
import '../../../theme/tide_colors.dart';
import '../../../theme/tide_elevation.dart';
import '../../../theme/tide_motion.dart';
import '../../../theme/tide_typography.dart';
import '../../../widgets/account_avatar.dart';
import '../../../widgets/press_scale.dart';
import '../../../widgets/tide_surface.dart';

/// Who is signed in, which plan they are on, and the way to Pro.
///
/// It was a bare row: a grey disc, a name, a line of muted text and an
/// outlined button, sitting on the page above three ungrouped lists. The
/// plan line was the only place the free ceiling appeared anywhere in the
/// app outside the paywall itself, and it appeared as the words "4 of 5" in
/// the same grey as everything else — which is not how you tell somebody
/// they are one habit from the end of their plan.
///
/// It is a panel now, with the allowance drawn as a meter that fills on
/// arrival. Pro loses the meter entirely: there is no ceiling to draw — it
/// gets the plan and the date the period ends instead, because on a prepaid
/// plan with nothing renewing, that date is the single most useful fact about
/// the account and nowhere else in the app says it.
///
/// The disc is the account's own: a Google photo when a Google identity is
/// linked — including on an email account that later added Google — and
/// initials otherwise.
class AccountCard extends StatelessWidget {
  const AccountCard({
    super.key,
    required this.name,
    required this.email,
    required this.entitlement,
    required this.habitCount,
    required this.onUpgrade,
    this.avatarUrl,
  });

  final String name;
  final String email;
  final String? avatarUrl;

  /// Which plan, and until when. The whole card reads off this rather than
  /// off a bool, so "Pro" and "Pro for three more days" are the same state
  /// told at two levels of detail instead of two states that can disagree.
  final Entitlement entitlement;

  final int habitCount;
  final VoidCallback onUpgrade;

  bool get isPro => entitlement.isPro;

  double get _used => habitCount / AppConstants.freeHabitLimit;

  /// One habit left, or none. Worth saying differently.
  bool get _nearLimit => !isPro && habitCount >= AppConstants.freeHabitLimit - 1;

  @override
  Widget build(BuildContext context) {
    return TideSurface(
      color: TideColors.shelf,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AccountAvatar(name: name, avatarUrl: avatarUrl),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      style: TideType.hero.copyWith(fontSize: 19),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      email,
                      style: TideType.labelMuted,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _PlanBadge(isPro: isPro),
            ],
          ),

          if (isPro) ...[
            const SizedBox(height: 16),
            _Period(entitlement: entitlement, onExtend: onUpgrade),
          ] else ...[
            const SizedBox(height: 20),
            _Allowance(used: _used, count: habitCount, urgent: _nearLimit),
            const SizedBox(height: 16),
            PressScale(
              onTap: onUpgrade,
              child: Container(
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  // Outlined rather than filled: it is an invitation, not
                  // the primary action on the screen.
                  border: Border.all(
                    color: TideColors.lantern.withValues(alpha: 0.45),
                  ),
                  borderRadius: TideElevation.radius12,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.workspace_premium_rounded,
                      size: 17,
                      color: TideColors.lantern,
                    ),
                    const SizedBox(width: 9),
                    Text(
                      entitlement.lapsed
                          ? 'Renew Pro'
                          : 'Go Pro for unlimited habits',
                      style: TideType.button.copyWith(
                        color: TideColors.lantern,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// What a Pro account is actually holding: the plan, and the day it ends.
///
/// It says the date rather than only the countdown, and the countdown only
/// once it is close. "Until 14 March" is what somebody needs nine months out;
/// "6 days left" is what they need in the last week, and putting the number up
/// all year would make an ordinary state look like a warning.
class _Period extends StatelessWidget {
  const _Period({required this.entitlement, required this.onExtend});

  final Entitlement entitlement;
  final VoidCallback onExtend;

  static String _date(DateTime when) =>
      '${when.day} ${AppConstants.monthNames[when.month - 1]} ${when.year}';

  @override
  Widget build(BuildContext context) {
    final end = entitlement.periodEnd;
    final plan = PlanCatalog.byId(entitlement.planId);
    final soon = entitlement.lapsesSoon;
    final days = entitlement.daysRemaining;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                end == null
                    ? '${AppConstants.appName} Pro'
                    : '${plan?.title ?? 'Pro'} · until ${_date(end)}',
                style: TideType.labelMuted,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (soon)
              Text(
                '$days ${days == 1 ? 'day' : 'days'} left',
                style: TideType.gauge(12, color: TideColors.lantern),
              ),
          ],
        ),
        // Only when it is nearly over. An "extend" button on a plan with
        // eleven months to run is asking for money for no reason.
        if (soon) ...[
          const SizedBox(height: 14),
          PressScale(
            onTap: onExtend,
            child: Container(
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border.all(
                  color: TideColors.lantern.withValues(alpha: 0.45),
                ),
                borderRadius: TideElevation.radius12,
              ),
              child: Text(
                'Extend Pro',
                style: TideType.button.copyWith(color: TideColors.lantern),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// The free ceiling, as a meter rather than as a clause.
class _Allowance extends StatelessWidget {
  const _Allowance({
    required this.used,
    required this.count,
    required this.urgent,
  });

  final double used;
  final int count;
  final bool urgent;

  @override
  Widget build(BuildContext context) {
    final limit = AppConstants.freeHabitLimit;
    final left = (limit - count).clamp(0, limit);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '$count of $limit habits on the free plan',
                style: TideType.labelMuted,
              ),
            ),
            Text(
              left == 0 ? 'Full' : '$left left',
              style: TideType.gauge(
                12,
                color: urgent ? TideColors.lantern : TideColors.silt,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: SizedBox(
            height: 5,
            child: Stack(
              children: [
                Positioned.fill(
                  child: ColoredBox(color: TideColors.trench),
                ),
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: used.clamp(0.0, 1.0)),
                  duration: TideMotion.chartDraw,
                  curve: TideMotion.tabCurve,
                  builder: (context, value, _) => FractionallySizedBox(
                    widthFactor: value,
                    child: ColoredBox(
                      color: urgent
                          ? TideColors.lantern
                          : TideColors.lantern.withValues(alpha: 0.55),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Free or Pro, said once, in the corner.
class _PlanBadge extends StatelessWidget {
  const _PlanBadge({required this.isPro});

  final bool isPro;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isPro
            ? TideColors.lantern.withValues(alpha: 0.16)
            : TideColors.bone.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        isPro ? 'Pro' : 'Free',
        style: TideType.gauge(
          11,
          color: isPro ? TideColors.lantern : TideColors.silt,
        ),
      ),
    );
  }
}
