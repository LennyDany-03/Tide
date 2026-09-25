import 'package:flutter/material.dart';

import '../../../config/reminder_copy.dart';
import '../../../theme/tide_colors.dart';
import '../../../theme/tide_elevation.dart';
import '../../../theme/tide_gradients.dart';
import '../../../theme/tide_motion.dart';
import '../../../theme/tide_typography.dart';
import '../../../widgets/press_scale.dart';
import '../../../widgets/tide_surface.dart';

/// One step on the slip, as the call carries it.
@immutable
class SlipStep {
  const SlipStep({required this.id, required this.title, required this.done});

  final String id;
  final String title;
  final bool done;

  static List<SlipStep> parse(Object? raw) {
    if (raw is! List) return const [];
    return [
      for (final item in raw)
        if (item is Map && item['id'] is String && item['title'] is String)
          SlipStep(
            id: item['id'] as String,
            title: item['title'] as String,
            done: item['done'] == true,
          ),
    ];
  }
}

/// The to-do on a Lighthouse call: the card the beam finds.
///
/// Its steps can be ticked here, on the lock screen, because a to-do with
/// steps open cannot be docked — the same rule the list keeps — and a call
/// that told you so without letting you do anything about it would be a
/// dead end.
///
/// The beam is drawn behind it, so the light on its face is drawn here:
/// [glint] 0..1 is how squarely the beam is on it, and [sheen] where across
/// it the light falls (0 the top-left corner, 1 the bottom-right). As the
/// beam sweeps, a band of light crosses the card in step with it, and its
/// top edge and rim catch.
class TaskSlip extends StatelessWidget {
  const TaskSlip({
    super.key,
    required this.title,
    required this.note,
    required this.due,
    required this.repeats,
    required this.steps,
    required this.onStep,
    this.glint = 0,
    this.sheen = 0.5,
  });

  final String title;
  final String note;

  /// "Today", "Tomorrow", "12 Sep" — or '' for no date.
  final String due;
  final bool repeats;
  final List<SlipStep> steps;
  final void Function(SlipStep step) onStep;
  final double glint;
  final double sheen;

  static const int _shown = 4;

  @override
  Widget build(BuildContext context) {
    final done = steps.where((s) => s.done).length;
    final lit = glint.clamp(0.0, 1.0);
    const radius = TideElevation.radius20;
    return Stack(
      children: [
        TideSurface(
          color: TideColors.shoal,
          radius: radius,
          border: Border.all(
            color: Color.lerp(
              TideColors.hairline,
              TideColors.lantern.withValues(alpha: 0.4),
              lit,
            )!,
          ),
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (due.isNotEmpty || repeats) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (due.isNotEmpty)
                      _Tag(
                        icon: Icons.schedule_rounded,
                        label: due,
                        accent: true,
                      ),
                    if (repeats)
                      const _Tag(icon: Icons.repeat_rounded, label: 'Repeats'),
                  ],
                ),
                const SizedBox(height: 14),
              ],
              Text(
                title,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TideType.hero.copyWith(fontSize: 26, height: 1.15),
              ),
              if (note.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  note,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TideType.bodyMuted,
                ),
              ],
              if (steps.isNotEmpty) ...[
                const SizedBox(height: 18),
                _Progress(done: done, total: steps.length),
                const SizedBox(height: 6),
                for (final step in steps.take(_shown))
                  _StepRow(step: step, onTap: () => onStep(step)),
                if (steps.length > _shown)
                  Padding(
                    padding: const EdgeInsets.only(top: 6, left: 34),
                    child: Text(
                      '+${steps.length - _shown} more in the app',
                      style: TideType.labelMuted,
                    ),
                  ),
              ],
            ],
          ),
        ),
        // The beam's light crossing the card's face.
        if (lit > 0.01)
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: radius,
                  gradient: TideGradients.slipSheen(at: sheen, strength: lit),
                ),
              ),
            ),
          ),
        // And catching its top edge.
        Positioned(
          left: 22,
          right: 22,
          top: 0,
          child: IgnorePointer(
            child: Container(
              height: 1.5,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(1),
                gradient: LinearGradient(
                  colors: [
                    TideColors.lantern.withValues(alpha: 0),
                    TideColors.lantern.withValues(alpha: 0.9 * lit),
                    TideColors.lantern.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A small fact about the to-do above its title: when it is due, whether
/// it repeats.
class _Tag extends StatelessWidget {
  const _Tag({required this.icon, required this.label, this.accent = false});

  final IconData icon;
  final String label;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final ink = accent ? TideColors.lantern : TideColors.silt;
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 5, 10, 5),
      decoration: BoxDecoration(
        color: accent
            ? TideColors.lantern.withValues(alpha: 0.12)
            : TideColors.bone.withValues(alpha: 0.05),
        borderRadius: TideElevation.radius12,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: ink),
          const SizedBox(width: 5),
          Text(
            label,
            style: TideType.labelMuted.copyWith(
              color: ink,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// How far through its steps the to-do is: a thin bar filling in the
/// accent, and the count beside it.
class _Progress extends StatelessWidget {
  const _Progress({required this.done, required this.total});

  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: SizedBox(
              height: 3,
              child: Stack(
                children: [
                  Positioned.fill(child: ColoredBox(color: TideColors.trench)),
                  TweenAnimationBuilder<double>(
                    tween: Tween(end: total == 0 ? 0 : done / total),
                    duration: TideMotion.tabSwitch,
                    curve: TideMotion.tabCurve,
                    builder: (context, value, _) => FractionallySizedBox(
                      widthFactor: value,
                      heightFactor: 1,
                      child: ColoredBox(color: TideColors.lantern),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          ReminderCopy.steps(done, total),
          style: TideType.labelMuted.copyWith(fontSize: 12),
        ),
      ],
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.step, required this.onTap});

  final SlipStep step;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      checked: step.done,
      label: step.title,
      onTap: onTap,
      child: ExcludeSemantics(
        child: PressScale(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: TideMotion.tabSwitch,
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: step.done ? TideColors.lantern : null,
                    border: step.done
                        ? null
                        : Border.all(
                            color: TideColors.silt.withValues(alpha: 0.7),
                            width: 1.5,
                          ),
                  ),
                  child: step.done
                      ? Icon(
                          Icons.check_rounded,
                          size: 15,
                          color: TideColors.onLantern,
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    step.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TideType.body.copyWith(
                      color: step.done ? TideColors.silt : TideColors.bone,
                      decoration: step.done ? TextDecoration.lineThrough : null,
                      decorationColor: TideColors.silt,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
