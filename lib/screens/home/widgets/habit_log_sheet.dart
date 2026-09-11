import 'dart:math' as math;

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
import '../../../widgets/tide_sheet.dart';
import 'duration_log_sheet.dart';

/// Logging a habit that has a count, raised as a bottom sheet.
///
/// Held habits used to be logged from the Home row itself: press and hold,
/// and a single fill swept the whole target. That gesture only had two
/// outcomes — release early and log nothing, or hold on and log all ten —
/// which is the wrong shape for a habit whose whole point is that it has
/// parts. It also put a slow gesture on a row you scroll past, so brushing
/// the list logged things.
///
/// Here the count is the subject of its own surface, and one hold banks one
/// unit. You stop when the number is right, which is the thing the sweep
/// never let you do.
///
/// **The redesign.** This was a progress ring with the count inside it and
/// a caption underneath explaining the controls. Three things were wrong
/// with that. The ring is the app's most reused object — it is on every
/// habit card, in the save button, behind the empty state — so the one
/// screen that exists to be *about* a quantity looked like everything else.
/// A ring is also a poor instrument for a count: an arc at 62% does not
/// answer "how many more", it answers "roughly how far", and this screen is
/// only ever open because somebody wants the first answer. And the whole
/// middle of the sheet was spent restating the controls in a sentence.
///
/// What replaces it is a vessel filling up — the level rises, the units are
/// ruled across it, and the figure sits beside it at the size the screen
/// deserves. It is the product's own metaphor stated literally, on the one
/// screen where a literal reading is the useful one, and it leaves the
/// space the caption was using to say the thing that actually matters:
/// how many are left.
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

class _LogSheetState extends State<_LogSheet>
    with SingleTickerProviderStateMixin {
  /// The water moving when something lands in it.
  ///
  /// The app's rule is that motion has to be caused by something the user
  /// did, and this obeys it exactly: the surface is flat until a unit is
  /// banked, then it rocks once and settles. An idling wave would be
  /// decoration; a wave that only moves when the level does is the level
  /// reporting itself.
  ///
  /// Made in [initState], not lazily. A duration habit hands this sheet over
  /// to its dial and never touches the slosh, so a lazy controller would be
  /// created for the first time inside [dispose] — on an element already
  /// torn out of the tree.
  late final AnimationController _slosh;

  @override
  void initState() {
    super.initState();
    _slosh = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
  }

  @override
  void dispose() {
    _slosh.dispose();
    super.dispose();
  }

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
    _slosh
      ..reset()
      ..forward();

    // Only reaching the target celebrates. Stepping back down to it after
    // an overshoot is a correction, not an arrival.
    if (delta > 0 && next >= habit.target) {
      HapticFeedback.heavyImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    final habit = TideScope.of(context).habitById(widget.habitId);
    if (habit == null) return const SizedBox.shrink();

    // A duration's unit is a minute, and one hold per minute is ninety holds
    // for a ninety-minute session. Time gets its own instrument.
    if (habit.type == HabitType.duration) {
      return DurationLogSheet(
        habit: habit,
        leading: _Glyph(habit: habit),
        onLog: widget.onLog,
        onDismiss: () => Navigator.of(context).pop(),
      );
    }

    final today = DateTime.now();
    final logged = habit.amountOn(today);
    final complete = habit.isCompleteOn(today);
    final remaining = (habit.target - logged).clamp(0, habit.target);

    return TideSheet(
      eyebrow: '${habit.targetLabel} a day',
      title: habit.name,
      leading: _Glyph(habit: habit),
      onDismiss: () => Navigator.of(context).pop(),
      maxHeightFactor: 0.72,
      footer: _HoldRow(
        complete: complete,
        canDecrease: logged > 0,
        onStep: () => _nudge(1),
        onNudge: _nudge,
        onDone: () => Navigator.of(context).pop(),
      ),
      // Scrollable so the vessel is never the thing that gets clipped. The
      // body is sized by what is left after the header and the hold control,
      // and at the top of the text-scale band that is less than the column
      // and its figure want.
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
        // Centred as a group, not stretched across the sheet. Left-aligned
        // with the readout expanded, the pair sat hard against the left
        // edge with a hand's width of empty sheet beside it — on the one
        // surface in the app whose entire content is two objects, which
        // made it read as a layout that had failed rather than one that had
        // been decided.
        //
        // The row also sits inside a scroll view, so there is no bounded
        // height for a cross-axis stretch to resolve against: the vessel
        // carries the height and the readout centres against it.
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 92,
              height: 200,
              child: AnimatedBuilder(
                animation: _slosh,
                builder: (context, _) => TweenAnimationBuilder<double>(
                  tween: Tween<double>(end: habit.progressOn(today)),
                  duration: TideMotion.holdStep,
                  curve: TideMotion.tabCurve,
                  builder: (context, level, _) => CustomPaint(
                    painter: _VesselPainter(
                      level: level,
                      slosh: _slosh.value,
                      // Ruled per unit while the units are countable. Past a
                      // dozen the lines stop being a scale and start being
                      // hatching, so a duration habit gets quarters instead.
                      divisions: habit.target <= 12
                          ? habit.target.round()
                          : 4,
                      complete: complete,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 26),
            // Capped rather than free: a custom unit long enough to wrap
            // would otherwise push the vessel off its own centre.
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 190),
              child: _Readout(
                logged: logged,
                habit: habit,
                remaining: remaining,
                complete: complete,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The figure, what it is counted in, and how much is left.
///
/// Beside the vessel rather than inside a ring, and centred on its own
/// axis. Left-aligned it was technically centred and looked anything but:
/// the vessel is a solid block and the readout is three lines of very
/// different widths, so the pair's visual weight sat well left of the
/// middle even with its geometry dead centre. Centring the three lines
/// puts the optical centre where the geometric one already was.
class _Readout extends StatelessWidget {
  const _Readout({
    required this.logged,
    required this.habit,
    required this.remaining,
    required this.complete,
  });

  final num logged;
  final Habit habit;
  final num remaining;
  final bool complete;

  /// "3 glasses to go", "15 min to go" — the answer to the only question
  /// anybody opens this sheet with.
  String get _left {
    final amount = remaining.round();
    final unit = habit.unit.isEmpty ? '' : ' ${habit.unit}';
    return '$amount$unit to go';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          '${logged.round()}',
          style: TideType.gauge(
            64,
            letterSpacing: -3.4,
            color: complete ? TideColors.lantern : TideColors.bone,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          'of ${habit.targetLabel}',
          style: TideType.labelMuted,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: complete
                ? TideColors.lantern.withValues(alpha: 0.12)
                : TideColors.trench,
            borderRadius: TideElevation.radius12,
          ),
          child: Text(
            complete ? 'Target reached for today.' : _left,
            style: TideType.label.copyWith(
              color: complete ? TideColors.lantern : TideColors.silt,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

/// The vessel: a recessed column, the level in it, and the units ruled
/// across it.
class _VesselPainter extends CustomPainter {
  const _VesselPainter({
    required this.level,
    required this.slosh,
    required this.divisions,
    required this.complete,
  });

  /// 0..1 of the target.
  final double level;

  /// 0..1 of one rock-and-settle, fired when a unit lands.
  final double slosh;

  /// How many units the column is ruled into.
  final int divisions;

  final bool complete;

  static const double _radius = 26;

  @override
  void paint(Canvas canvas, Size size) {
    final body = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(_radius),
    );

    // The well. Darker than the page, because a recess shows the water
    // below it — the same reading every input in the app gets.
    canvas.drawRRect(body, Paint()..color = TideColors.trench);

    canvas.save();
    canvas.clipRRect(body);

    if (level > 0) {
      _paintWater(canvas, size);
    }
    _paintRules(canvas, size);

    canvas.restore();

    canvas.drawRRect(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = complete
            ? TideColors.lantern.withValues(alpha: 0.5)
            : TideColors.hairline,
    );
  }

  void _paintWater(Canvas canvas, Size size) {
    // A rocking surface that decays to flat. Amplitude is small on purpose:
    // this is water settling after something was added to it, not a sea.
    final decay = slosh == 0 ? 0.0 : (1 - slosh) * (1 - slosh);
    final amplitude = 7 * decay;
    final phase = slosh * math.pi * 4;

    final surface = size.height * (1 - level.clamp(0.0, 1.0));
    final path = Path()..moveTo(0, surface);

    // Sampled rather than drawn as two arcs: the crest has to stay put at
    // the edges of the column while the middle moves, and a quadratic
    // through three points drifts at the walls.
    const steps = 24;
    for (var i = 0; i <= steps; i++) {
      final x = size.width * i / steps;
      final wave =
          math.sin((i / steps) * math.pi * 2 + phase) *
          amplitude *
          math.sin((i / steps) * math.pi);
      path.lineTo(x, surface + wave);
    }
    path
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            TideColors.lantern.withValues(alpha: 0.85),
            TideColors.lantern.withValues(alpha: 0.42),
          ],
        ).createShader(Rect.fromLTWH(0, surface, size.width, size.height)),
    );

    // A bright line along the surface itself, so the level has an edge
    // rather than fading into the fill under it.
    final crest = Path()..moveTo(0, surface);
    for (var i = 0; i <= steps; i++) {
      final x = size.width * i / steps;
      final wave =
          math.sin((i / steps) * math.pi * 2 + phase) *
          amplitude *
          math.sin((i / steps) * math.pi);
      crest.lineTo(x, surface + wave);
    }
    canvas.drawPath(
      crest,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = TideColors.bone.withValues(alpha: 0.55),
    );
  }

  /// The unit marks. Short ticks off the left wall rather than full rules:
  /// a line all the way across cuts the water in half at every unit, and at
  /// eight of them the column stops reading as one body of anything.
  void _paintRules(Canvas canvas, Size size) {
    if (divisions < 2) return;

    final paint = Paint()
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round
      ..color = TideColors.bone.withValues(alpha: 0.14);

    for (var i = 1; i < divisions; i++) {
      final y = size.height * (1 - i / divisions);
      canvas.drawLine(
        Offset(size.width * 0.30, y),
        Offset(size.width * 0.70, y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_VesselPainter old) =>
      old.level != level ||
      old.slosh != slosh ||
      old.divisions != divisions ||
      old.complete != complete;
}

/// The habit's mark, in the sheet header where the add screen puts its own —
/// so a sheet always opens with the thing it is about in the same corner.
class _Glyph extends StatelessWidget {
  const _Glyph({required this.habit});

  final Habit habit;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: TideColors.trench,
        borderRadius: TideElevation.radius12,
      ),
      child: Center(
        child: HabitGlyph(
          glyph: habit.glyph,
          size: 17,
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
            semanticLabel: 'Mark one less',
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
            semanticLabel: 'Mark one more',
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
          width: 54,
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
            ? 'All marked'
            : banked
            ? 'Lift to mark another'
            : holding
            ? 'Keep holding…'
            : 'Hold to mark';

        return Stack(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 17,
              ),
              decoration: BoxDecoration(
                color: complete
                    ? TideColors.lantern.withValues(alpha: 0.10)
                    : TideColors.lantern,
                borderRadius: TideElevation.radius12,
                border: complete
                    ? Border.all(
                        color: TideColors.lantern.withValues(alpha: 0.3),
                      )
                    : null,
              ),
              child: Center(
                child: Text(
                  label,
                  style: TideType.button.copyWith(
                    // Solid accent while there is something to log: this is
                    // the primary action on the sheet and it used to be a
                    // 14%-alpha wash, quieter than the two corrections
                    // flanking it.
                    color: complete
                        ? TideColors.lantern
                        : TideColors.onLantern,
                  ),
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
                        color: TideColors.onLantern.withValues(
                          alpha: banked ? 0.24 : 0.16,
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
