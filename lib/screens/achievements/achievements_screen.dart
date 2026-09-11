import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../services/models/milestone.dart';
import '../../services/tide_scope.dart';
import '../../theme/tide_colors.dart';
import '../../theme/tide_elevation.dart';
import '../../theme/tide_typography.dart';
import '../../widgets/habit_glyph.dart';
import '../../widgets/press_scale.dart';
import '../../widgets/tide_backdrop.dart';
import '../../widgets/tide_surface.dart';
import 'widgets/milestone_route.dart';
import 'widgets/share_card_view.dart';

/// Milestones.
///
/// A full-screen destination rather than a tab: you come here when
/// something has happened, not to browse. Unlocks play above the app's
/// router so completing a milestone on Today is rewarded immediately; this
/// screen is where the route is read back.
///
/// The route replaces a 3×3 grid of badges. A grid could only ever say
/// "here are nine things, one of them is yours" — no order, no distance,
/// no you. The line says how far along you are, which is the only question
/// anybody opens this screen to ask.
class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  void _simulate() {
    TideScope.read(context).simulateNextUnlock();
  }

  @override
  Widget build(BuildContext context) {
    final store = TideScope.of(context);
    final statuses = store.milestones;
    final unlocked = statuses.where((s) => s.unlocked).length;
    final streak = store.allTimeBestStreak;

    // The route runs on streak milestones, which are the ones with an order
    // between them. The clean-days badge is earned a different way and is
    // shown as what it is — something off to the side, not a station you
    // pass through on the way to 365 days.
    final route = [
      for (final status in statuses)
        if (status.milestone.kind == MilestoneKind.streak) status,
    ];
    final aside = [
      for (final status in statuses)
        if (status.milestone.kind != MilestoneKind.streak) status,
    ];

    final next = route.where((status) => !status.unlocked).firstOrNull;

    return Scaffold(
      backgroundColor: TideColors.deepWater,
      body: Stack(
        children: [
          const Positioned.fill(child: TideBackdrop()),
          ListView(
            padding: EdgeInsets.fromLTRB(
              20,
              MediaQuery.paddingOf(context).top + 16,
              20,
              40 + MediaQuery.paddingOf(context).bottom,
            ),
            children: [
              Row(
                children: [
                  // A bare glyph, matching habit detail. Back is the least
                  // interesting control on any screen and should not be the
                  // only filled shape in its row.
                  PressScale(
                    onTap: () => context.pop(),
                    child: SizedBox(
                      width: 38,
                      height: 38,
                      child: Icon(
                        Icons.arrow_back_rounded,
                        size: 21,
                        color: TideColors.bone,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('Milestones', style: TideType.screenTitle),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(left: 48),
                child: Text(
                  '$unlocked of ${statuses.length} surfaced',
                  style: TideType.labelMuted,
                ),
              ),
              const SizedBox(height: 20),

              _Standing(streak: streak, next: next),
              const SizedBox(height: 26),

              MilestoneRoute(
                statuses: route,
                streak: streak,
                onTap: (status) => showShareCard(
                  context,
                  milestone: status.milestone,
                  streak: store.allTimeBestStreak,
                  accountName: store.accountName,
                ),
              ),
              const SizedBox(height: 22),

              if (aside.isNotEmpty) ...[
                Text('Off the route', style: TideType.sectionHeader),
                const SizedBox(height: 10),
                for (final status in aside)
                  _AsideBadge(
                    status: status,
                    clean: store.cleanStreak,
                    onTap: () => showShareCard(
                      context,
                      milestone: status.milestone,
                      streak: store.allTimeBestStreak,
                      accountName: store.accountName,
                    ),
                  ),
                const SizedBox(height: 20),
              ],

              // A demo affordance, kept deliberately: the unlock moment is
              // the best animation in the app and would otherwise be
              // unreachable without waiting sixty days for it.
              PressScale(
                onTap: _simulate,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  // Outlined and quiet. It is a demo control sitting under
                  // the route, and a filled accent block would make the
                  // least important thing on the screen the loudest.
                  decoration: BoxDecoration(
                    borderRadius: TideElevation.radius12,
                    border: Border.all(color: TideColors.hairline),
                  ),
                  child: Center(
                    child: Text(
                      'Simulate next unlock',
                      style: TideType.button.copyWith(color: TideColors.silt),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const Positioned(top: 0, left: 0, right: 0, child: TideTopScrim()),
        ],
      ),
    );
  }
}

/// Where you actually stand, said in numbers before the route says it in
/// pictures.
class _Standing extends StatelessWidget {
  const _Standing({required this.streak, required this.next});

  final int streak;
  final MilestoneStatus? next;

  @override
  Widget build(BuildContext context) {
    final target = next;

    return TideSurface(
      color: TideColors.shelf,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$streak',
                  style: TideType.gaugeStat(color: TideColors.lantern),
                ),
                const SizedBox(height: 6),
                Text('days, best run', style: TideType.labelMuted),
              ],
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  target == null
                      ? 'All of it'
                      : '${(target.milestone.threshold - streak).clamp(0, 9999)}',
                  style: TideType.gaugeStat(),
                ),
                const SizedBox(height: 6),
                Text(
                  target == null
                      ? 'the whole route'
                      : 'to ${target.milestone.name.toLowerCase()}',
                  style: TideType.labelMuted,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The badge that is not on the line — earned by not spending freezes,
/// which has nothing to do with how long the streak is.
class _AsideBadge extends StatelessWidget {
  const _AsideBadge({
    required this.status,
    required this.clean,
    required this.onTap,
  });

  final MilestoneStatus status;

  /// Clean days logged so far.
  final int clean;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final unlocked = status.unlocked;
    final accent = unlocked
        ? TideColors.lantern
        : TideColors.drained(TideColors.lantern, 0.8);

    return PressScale(
      onTap: onTap,
      enabled: unlocked,
      child: TideSurface(
        color: unlocked ? TideColors.shelf : TideColors.trench,
        highlight: unlocked,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: unlocked
                    ? TideColors.lantern.withValues(alpha: 0.14)
                    : Colors.transparent,
                border: Border.all(
                  color: unlocked
                      ? TideColors.lantern.withValues(alpha: 0.8)
                      : TideColors.hairline,
                ),
              ),
              child: HabitGlyph(
                glyph: status.milestone.glyph,
                size: 19,
                color: accent,
                strokeWidth: 1.8,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    status.milestone.name,
                    style: TideType.heading.copyWith(
                      color: unlocked ? TideColors.bone : TideColors.silt,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    unlocked
                        ? '${status.milestone.caption}, surfaced'
                        : '$clean of ${status.milestone.threshold} days '
                              'without a freeze',
                    style: TideType.labelMuted,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
