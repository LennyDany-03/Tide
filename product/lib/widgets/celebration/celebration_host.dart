import 'package:flutter/material.dart';

import '../../screens/achievements/widgets/unlock_celebration.dart';
import '../../services/tide_scope.dart';
import '../../theme/tide_typography.dart';
import 'habit_completion_celebration.dart';

/// Keeps rewards above routes, sheets and tabs, so completion always feels
/// consistent regardless of where it happened.
class CelebrationHost extends StatelessWidget {
  const CelebrationHost({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final store = TideScope.of(context);
    final cue = store.pendingHabitCue;
    final milestone = store.pendingCelebration;
    return Stack(
      children: [
        child,
        // Above the router there is no Material and therefore no
        // DefaultTextStyle, so every Text here falls back to WidgetsApp's
        // error style — which carries a yellow underline that merges into
        // whatever TideType asked for. That is where the rule under the
        // milestone name came from. One inherited style covers both
        // panels, and covers whatever is added beside them next.
        if (cue != null)
          Positioned.fill(
            child: DefaultTextStyle(
              style: TideType.body,
              child: HabitCompletionCelebration(
                key: ValueKey(cue.nonce),
                cue: cue,
                onDismiss: store.clearHabitCue,
              ),
            ),
          )
        else if (milestone != null)
          Positioned.fill(
            child: DefaultTextStyle(
              style: TideType.body,
              child: UnlockCelebration(
                key: ValueKey(milestone.id),
                milestone: milestone,
                onDismiss: () => store.acknowledgeCelebration(milestone),
              ),
            ),
          ),
      ],
    );
  }
}
