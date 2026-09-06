import 'package:flutter/material.dart';

import '../../screens/achievements/widgets/unlock_celebration.dart';
import '../../services/tide_scope.dart';
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
        if (cue != null)
          Positioned.fill(
            child: HabitCompletionCelebration(
              key: ValueKey(cue.nonce),
              cue: cue,
              onDismiss: store.clearHabitCue,
            ),
          )
        else if (milestone != null)
          Positioned.fill(
            child: UnlockCelebration(
              key: ValueKey(milestone.id),
              milestone: milestone,
              onDismiss: () => store.acknowledgeCelebration(milestone),
            ),
          ),
      ],
    );
  }
}
