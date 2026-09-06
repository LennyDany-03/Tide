import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../services/tide_scope.dart';
import '../../theme/tide_colors.dart';
import '../../theme/tide_elevation.dart';
import '../../theme/tide_typography.dart';
import '../../widgets/tide_backdrop.dart';
import '../../widgets/press_scale.dart';
import 'widgets/badge_grid.dart';
import 'widgets/share_card_view.dart';

/// Milestones.
///
/// A full-screen destination rather than a tab: you come here when
/// something has happened, not to browse. Unlocks now play above the app's
/// router so completing a milestone on Today is rewarded immediately; this
/// screen remains the place to inspect and share the route.
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
                    child: const SizedBox(
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
                  const Expanded(
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
              const SizedBox(height: 22),

              BadgeGrid(
                statuses: statuses,
                onTapBadge: (status) => showShareCard(
                  context,
                  milestone: status.milestone,
                  streak: store.allTimeBestStreak,
                  accountName: store.accountName,
                ),
              ),
              const SizedBox(height: 16),

              // A demo affordance, kept deliberately: the unlock burst is
              // the best animation in the app and would otherwise be
              // unreachable without waiting sixty days for it.
              PressScale(
                onTap: _simulate,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  // Outlined and quiet. It is a demo control sitting under a
                  // wall of badges, and a filled accent block would make the
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
