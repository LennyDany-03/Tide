import 'package:flutter/material.dart';

import '../../../config/reminder_copy.dart';
import '../../../theme/tide_colors.dart';
import '../../../theme/tide_elevation.dart';
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

/// The to-do on a Lighthouse call: a slip of paper the beam finds.
///
/// Its steps can be ticked here, on the lock screen, because a to-do with
/// steps open cannot be docked — the same rule the list keeps — and a call
/// that told you so without letting you do anything about it would be a
/// dead end. [glint] brightens the lit top edge as the beam passes over.
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
  });

  final String title;
  final String note;

  /// "Today", "Tomorrow", "12 Sep" — or '' for no date.
  final String due;
  final bool repeats;
  final List<SlipStep> steps;
  final void Function(SlipStep step) onStep;
  final double glint;

  static const int _shown = 4;

  @override
  Widget build(BuildContext context) {
    final done = steps.where((s) => s.done).length;
    return Stack(
      children: [
        TideSurface(
          color: TideColors.shoal,
          floating: true,
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  if (due.isNotEmpty) _Chip(label: due),
                  if (repeats) ...[
                    const SizedBox(width: 8),
                    Icon(
                      Icons.repeat_rounded,
                      size: 15,
                      color: TideColors.silt,
                    ),
                  ],
                  const Spacer(),
                  if (steps.isNotEmpty)
                    Text(
                      ReminderCopy.steps(done, steps.length),
                      style: TideType.labelMuted.copyWith(fontSize: 12),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                title,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TideType.hero.copyWith(fontSize: 25),
              ),
              if (note.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  note,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TideType.bodyMuted,
                ),
              ],
              if (steps.isNotEmpty) ...[
                const SizedBox(height: 14),
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
        // The beam catching the paper's top edge as it passes.
        Positioned(
          left: 18,
          right: 18,
          top: 0,
          child: IgnorePointer(
            child: Container(
              height: 2,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(1),
                gradient: LinearGradient(
                  colors: [
                    TideColors.lantern.withValues(alpha: 0),
                    TideColors.lantern.withValues(alpha: 0.9 * glint),
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

class _Chip extends StatelessWidget {
  const _Chip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: TideColors.lantern.withValues(alpha: 0.14),
        borderRadius: TideElevation.radius12,
      ),
      child: Text(
        label,
        style: TideType.labelMuted.copyWith(
          color: TideColors.lantern,
          fontSize: 12,
        ),
      ),
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
                        : Border.all(color: TideColors.silt, width: 1.5),
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
