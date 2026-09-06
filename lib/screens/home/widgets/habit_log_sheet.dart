import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../services/models/habit.dart';
import '../../../services/tide_scope.dart';
import '../../../theme/tide_colors.dart';
import '../../../theme/tide_elevation.dart';
import '../../../theme/tide_motion.dart';
import '../../../theme/tide_typography.dart';
import '../../../widgets/habit_glyph.dart';
import '../../../widgets/hold_to_fill.dart';
import '../../../widgets/ripple_burst.dart';
import '../../../widgets/tide_ring.dart';
import '../../../widgets/tide_sheet.dart';

/// Logging a habit that has a count, raised as a bottom sheet.
///
/// Held habits used to be logged from the Home row itself: press and hold,
/// and a single fill swept the whole target. That gesture only had two
/// outcomes — release early and log nothing, or hold on and log all ten —
/// which is the wrong shape for a habit whose whole point is that it has
/// parts. It also put a slow gesture on a row you scroll past, so brushing
/// the list logged things.
///
/// Here the count is the subject of its own surface: the ring shows where
/// the day stands, and one hold meters the units out one at a time, with a
/// tick you can feel for each. You stop when the number is right, which is
/// the thing the sweep never let you do.
///
/// A sheet rather than a pushed screen, for the same reason as the day
/// breakdown: you are still looking at Today, and Today should stay behind
/// it.
Future<void> showHabitLogSheet(
  BuildContext context, {
  required String habitId,
  required ValueChanged<num> onLog,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss',
    barrierColor: Colors.transparent,
    transitionDuration: TideMotion.sheetIn,
    pageBuilder: (context, animation, secondary) => const SizedBox.shrink(),
    transitionBuilder: (context, animation, secondary, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: TideMotion.sheetCurve,
        reverseCurve: Curves.easeInCubic,
      );

      return Stack(
        children: [
          TideBackdrop(
            animation: curved,
            onTap: () => Navigator.of(context).pop(),
          ),
          SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).animate(curved),
            child: _LogSheet(habitId: habitId, onLog: onLog),
          ),
        ],
      );
    },
  );
}

class _LogSheet extends StatefulWidget {
  const _LogSheet({required this.habitId, required this.onLog});

  final String habitId;

  /// The amount the day should now stand at. Routed back out to Home rather
  /// than written straight to the store, so logging the last habit from in
  /// here still fires the day-complete moment out there.
  final ValueChanged<num> onLog;

  @override
  State<_LogSheet> createState() => _LogSheetState();
}

class _LogSheetState extends State<_LogSheet> {
  int _burst = 0;

  /// Counts one unit onto the day.
  ///
  /// Reads the habit back out of the store rather than closing over the one
  /// this build drew: steps land faster than the sheet rebuilds, and a
  /// stale amount would have every unit after the first overwrite the last.
  void _step() {
    final habit = TideScope.read(context).habitById(widget.habitId);
    if (habit == null) return;

    final logged = habit.amountOn(DateTime.now());
    final next = (logged + 1).clamp(0, habit.target);
    if (next <= logged) return;

    widget.onLog(next);

    if (next >= habit.target) {
      HapticFeedback.heavyImpact();
      setState(() => _burst++);
    }
  }

  @override
  Widget build(BuildContext context) {
    final habit = TideScope.of(context).habitById(widget.habitId);
    if (habit == null) return const SizedBox.shrink();

    final logged = habit.amountOn(DateTime.now());
    final complete = habit.isCompleteOn(DateTime.now());

    return TideSheet(
      title: habit.name,
      leading: _Glyph(habit: habit),
      onDismiss: () => Navigator.of(context).pop(),
      maxHeightFactor: 0.7,
      footer: _HoldRow(
        habit: habit,
        complete: complete,
        onStep: _step,
        onDone: () => Navigator.of(context).pop(),
      ),
      // Scrollable so the ring is never the thing that gets clipped. The
      // body is sized by what is left after the header and the hold control,
      // and on a short screen — or at the top of the text-scale band — that
      // is less than the ring and its line of copy want.
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RippleBurst(
              trigger: _burst,
              // The one place the spill is wanted: the ring is centred in
              // open sheet, and the wash reading past it is the reward for
              // reaching the target.
              clip: false,
              child: TideRing(
                progress: habit.progressOn(DateTime.now()),
                size: 132,
                strokeWidth: 4,
                // Keeps pace with the count. The default fill is longer
                // than a step, so a held run would leave the ring trailing
                // several units behind the number inside it.
                duration: TideMotion.holdStep,
                child: _Readout(logged: logged, habit: habit),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              complete
                  ? 'Target reached for today.'
                  : 'Hold below — one at a time. Lift when the count is '
                        'right.',
              textAlign: TextAlign.center,
              style: TideType.bodyMuted,
            ),
          ],
        ),
      ),
    );
  }
}

/// The count, inside the ring.
class _Readout extends StatelessWidget {
  const _Readout({required this.logged, required this.habit});

  final num logged;
  final Habit habit;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${logged.round()}',
          style: TideType.gauge(
            46,
            letterSpacing: -2.4,
            color: habit.isCompleteOn(DateTime.now())
                ? TideColors.lantern
                : TideColors.bone,
          ),
        ),
        const SizedBox(height: 6),
        Text('of ${habit.targetLabel}', style: TideType.labelMuted),
      ],
    );
  }
}

/// The habit's mark, in the sheet header where the FAB's disc sits on the
/// add/edit sheet — so a sheet always opens with the thing it is about in
/// the same corner.
class _Glyph extends StatelessWidget {
  const _Glyph({required this.habit});

  final Habit habit;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: const BoxDecoration(
        color: TideColors.trench,
        borderRadius: TideElevation.radius12,
      ),
      child: Center(
        child: HabitGlyph(
          glyph: habit.glyph,
          size: 16,
          color: TideColors.lantern,
        ),
      ),
    );
  }
}

/// The metered hold, and the way out once the day is done.
class _HoldRow extends StatelessWidget {
  const _HoldRow({
    required this.habit,
    required this.complete,
    required this.onStep,
    required this.onDone,
  });

  final Habit habit;
  final bool complete;
  final VoidCallback onStep;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return HoldToStep(
      // Nothing left to count. The control stops rather than idling at a
      // full target, and the last step disarms it under a finger that is
      // still down.
      enabled: !complete,
      onStep: onStep,
      builder: (context, progress, holding) {
        final label = complete
            ? 'All logged'
            : holding
            ? 'Keep holding…'
            : 'Hold to log';

        return Stack(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 16,
              ),
              decoration: BoxDecoration(
                color: TideColors.lantern.withValues(
                  alpha: complete ? 0.10 : 0.14,
                ),
                borderRadius: TideElevation.radius12,
                border: Border.all(
                  color: TideColors.lantern.withValues(
                    alpha: complete ? 0.22 : 0.34,
                  ),
                ),
              ),
              child: Center(
                child: Text(
                  label,
                  style: TideType.button.copyWith(color: TideColors.lantern),
                ),
              ),
            ),
            // The lap. It fills one unit's worth and resets, so the button
            // is a metronome you can watch as well as feel.
            Positioned.fill(
              child: IgnorePointer(
                child: ClipRRect(
                  borderRadius: TideElevation.radius12,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: complete ? 0 : progress,
                      child: ColoredBox(
                        color: TideColors.lantern.withValues(alpha: 0.20),
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (complete)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onDone,
                ),
              ),
          ],
        );
      },
    );
  }
}
