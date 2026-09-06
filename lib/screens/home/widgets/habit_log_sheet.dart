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
import '../../../widgets/press_scale.dart';
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
/// the day stands, and one hold banks one unit. You stop when the number is
/// right, which is the thing the sweep never let you do.
///
/// The hold used to run as a metronome — a unit on touch-down and another
/// every quarter second after — which traded one unaddressable gesture for
/// a faster one: a resting thumb filled the target before you could react
/// to any single unit of it. A hold now costs one unit and then goes dead
/// until the finger lifts. The nudge buttons flanking it are the answer to
/// what that costs a thirty-minute target, and they are also the only way
/// to walk a count back down after overshooting it.
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

  /// Moves the day's count by [delta], clamped to the target.
  ///
  /// Reads the habit back out of the store rather than closing over the one
  /// this build drew: a unit can land before the sheet rebuilds, and a
  /// stale amount would have every unit after the first overwrite the last.
  void _nudge(int delta) {
    final habit = TideScope.read(context).habitById(widget.habitId);
    if (habit == null) return;

    final logged = habit.amountOn(DateTime.now());
    final next = (logged + delta).clamp(0, habit.target);
    if (next == logged) return;

    widget.onLog(next);

    // Only reaching the target celebrates. Stepping back down to it after
    // an overshoot is a correction, not an arrival.
    if (delta > 0 && next >= habit.target) {
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
        complete: complete,
        canDecrease: logged > 0,
        onStep: () => _nudge(1),
        onNudge: _nudge,
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
                  : 'One hold logs one. Lift and hold again for the next, '
                        'or nudge it with − and +.',
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

/// The hold, the two nudges either side of it, and the way out once the day
/// is done.
///
/// The nudges are deliberately smaller and quieter than the hold: holding is
/// the gesture the screen is about, and tapping is the correction. Sizing
/// them the same would make the hold look optional.
class _HoldRow extends StatelessWidget {
  const _HoldRow({
    required this.complete,
    required this.canDecrease,
    required this.onStep,
    required this.onNudge,
    required this.onDone,
  });

  final bool complete;

  /// False at zero, where there is nothing to walk back.
  final bool canDecrease;

  final VoidCallback onStep;
  final ValueChanged<int> onNudge;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    // Stretched to the hold button's height rather than given one of their
    // own: the hold is sized by its label, and a nudge four pixels short of
    // it reads as a misalignment rather than as a smaller control.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Nudge(
            icon: Icons.remove_rounded,
            semanticLabel: 'Log one less',
            enabled: canDecrease,
            onTap: () => onNudge(-1),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _HoldButton(
              complete: complete,
              onStep: onStep,
              onDone: onDone,
            ),
          ),
          const SizedBox(width: 10),
          _Nudge(
            icon: Icons.add_rounded,
            semanticLabel: 'Log one more',
            enabled: !complete,
            onTap: () => onNudge(1),
          ),
        ],
      ),
    );
  }
}

/// A single unit, tapped rather than held.
///
/// Square-ish and recessed, so it reads as a control *beside* the hold
/// rather than a second primary action competing with it.
class _Nudge extends StatelessWidget {
  const _Nudge({
    required this.icon,
    required this.semanticLabel,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String semanticLabel;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tint = TideColors.lantern.withValues(alpha: enabled ? 0.9 : 0.22);

    return PressScale(
      enabled: enabled,
      onTap: onTap,
      child: Semantics(
        button: true,
        enabled: enabled,
        label: semanticLabel,
        child: Container(
          width: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: TideColors.trench,
            borderRadius: TideElevation.radius12,
            border: Border.all(
              color: TideColors.bone.withValues(alpha: enabled ? 0.10 : 0.05),
            ),
          ),
          child: Icon(icon, size: 20, color: tint),
        ),
      ),
    );
  }
}

/// The hold itself.
///
/// The lap fills once and stops at full, where it sits until the finger
/// lifts — a spent hold, which is why the label changes rather than the
/// fill draining back under a finger that has not moved.
class _HoldButton extends StatelessWidget {
  const _HoldButton({
    required this.complete,
    required this.onStep,
    required this.onDone,
  });

  final bool complete;
  final VoidCallback onStep;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return HoldToStep(
      // Nothing left to count. The control stops rather than idling at a
      // full target, and the last unit disarms it under a finger that is
      // still down.
      enabled: !complete,
      onStep: onStep,
      builder: (context, progress, holding) {
        // A full lap with the finger still down is a hold that has already
        // banked. Saying so is what stops the button reading as stuck.
        final banked = holding && progress >= 1;

        final label = complete
            ? 'All logged'
            : banked
            ? 'Lift to log another'
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
            // The lap. One fill per unit, and it stops there — the button
            // is a thing you complete, not a metronome you let run.
            Positioned.fill(
              child: IgnorePointer(
                child: ClipRRect(
                  borderRadius: TideElevation.radius12,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: complete ? 0 : progress,
                      child: ColoredBox(
                        color: TideColors.lantern.withValues(
                          alpha: banked ? 0.30 : 0.20,
                        ),
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
