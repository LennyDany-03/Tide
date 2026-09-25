import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../../config/task_copy.dart';
import '../../../services/haptics.dart';
import '../../../services/tasks/task.dart';
import '../../../theme/tide_colors.dart';
import '../../../theme/tide_elevation.dart';
import '../../../theme/tide_motion.dart';
import '../../../theme/tide_typography.dart';
import '../../../widgets/press_scale.dart';
import '../../../widgets/swipe_reveal.dart';

/// One task, and the gesture surface for finishing it.
///
/// **Swipe right to complete, left to delete — the same hand the habit cards
/// use.** The first version put a tick box at the start of every row, which
/// made completing a task a 24-pixel aim, and it did not match Today, where a
/// habit is carried right to mark it. The circle is still drawn, because it
/// says at a glance which tasks are done, but it is a status mark now, not a
/// button: the whole card is the target.
///
/// The drag is the habit card's: a backdrop is uncovered under the card —
/// lantern and a tick on the left, coral and a bin on the right — the icon
/// grows as the threshold nears and there is one haptic tick when it is
/// crossed. A flick fast enough to be a page swipe is refused rather than
/// guessed at, so throwing the page at the next tab never completes a task.
/// Past the threshold the card leaves the way it was pushed and the gap
/// closes behind it; short of it, it springs back.
///
/// **A task with steps still open cannot be swiped complete.** The right
/// side shows a checklist and how many steps are left instead of a tick, and
/// past the threshold the card springs back rather than leaving; [onBlocked]
/// says why. The task finishes when its last step is ticked.
///
/// **Its steps are on the card**, given [onStep], and tick where they are:
/// the list is where a task is worked through, and opening each one to tick
/// a line off would put the steps a screen away from the rule they enforce.
/// Ticking the last open step sends the card off the way a right swipe does
/// before [onStep] finishes the task, so a task completed by its steps
/// leaves the list the same way as one completed by hand.
///
/// Tapping opens the task. Screen readers get "Complete" and "Delete" as
/// custom actions, because a gesture is not an accessible control.
class TaskCard extends StatefulWidget {
  const TaskCard({
    super.key,
    required this.task,
    required this.onComplete,
    required this.onDelete,
    required this.onOpen,
    this.onBlocked,
    this.onStep,
    this.onMenu,
    this.showTags = true,
    this.overdueInHeading = false,
    this.completeLabel,
  });

  final Task task;

  /// Called once the card has left. Toggles: a finished task is reopened.
  final VoidCallback onComplete;
  final VoidCallback onDelete;
  final VoidCallback onOpen;

  /// A right swipe on a task whose steps are not all done.
  final VoidCallback? onBlocked;

  /// A step ticked or unticked on the card. Null leaves the steps off the
  /// card — the archive, where a task is only restored or deleted.
  final void Function(Subtask step)? onStep;

  /// A long press anywhere on the card: the menu of what it can do. Long
  /// press and the horizontal drag settle in the gesture arena on their own
  /// — movement picks the drag, stillness picks the press.
  final VoidCallback? onMenu;

  /// Off on the free plan unless the task already carries tags from a plan
  /// that has since ended — then they are still shown, never hidden.
  final bool showTags;

  /// The card sits under an "Overdue" heading, so its due chip gives the
  /// date alone rather than saying "Overdue" again on every card.
  final bool overdueInHeading;

  /// What the right swipe says. Defaults to "Complete", or "Reopen" on a
  /// finished task.
  final String? completeLabel;

  @override
  State<TaskCard> createState() => _TaskCardState();
}

class _TaskCardState extends State<TaskCard> with TickerProviderStateMixin {
  late final AnimationController _settle = AnimationController(vsync: this);
  late final AnimationController _collapse = AnimationController(
    vsync: this,
    duration: TideMotion.tabSwitch,
    value: 1,
  );

  double _drag = 0;
  double _width = 0;
  bool _armed = false;
  bool _leaving = false;

  /// The last step, ticked on the card and drawn ticked while the card
  /// leaves, before the store has been told.
  String? _finishing;

  /// Steps still open, so the right swipe is a refusal. Not on the archive,
  /// where the right swipe restores rather than completes.
  bool get _blocked =>
      widget.completeLabel == null &&
      !widget.task.isCompleted &&
      widget.task.subtasksLeft > 0;

  String get _rightLabel {
    if (_blocked) return '${TaskCopy.steps(widget.task.subtasksLeft)} left';
    return widget.completeLabel ??
        (widget.task.isCompleted ? 'Reopen' : 'Complete');
  }

  @override
  void dispose() {
    _settle.dispose();
    _collapse.dispose();
    super.dispose();
  }

  void _onUpdate(DragUpdateDetails details) {
    if (_leaving) return;
    _settle.stop();
    setState(() {
      // A refused right swipe gives, but stiffly, and not far: it should
      // feel like a card that will not go rather than one that is going.
      final dx = _blocked && _drag + details.delta.dx > 0
          ? details.delta.dx * 0.5
          : details.delta.dx;
      final reach = _blocked ? _width * 0.45 : _width;
      _drag = (_drag + dx).clamp(-_width, reach);
    });
    final armed =
        _width > 0 && _drag.abs() / _width >= TideMotion.swipeThreshold;
    if (armed != _armed) {
      _armed = armed;
      if (armed) TideHaptics.selectionClick();
    }
  }

  void _onEnd(DragEndDetails details) {
    if (_leaving) return;
    final velocity = details.velocity.pixelsPerSecond.dx;
    // A page thrown at the tab bar, not a considered swipe — see
    // TideMotion.swipeFlingVelocity.
    final flung = velocity.abs() >= TideMotion.swipeFlingVelocity;
    if (_armed && !flung && _drag > 0 && _blocked) {
      TideHaptics.heavyImpact();
      _slide(0, TideMotion.swipeCancel, TideMotion.swipeCancelCurve);
      widget.onBlocked?.call();
    } else if (_armed && !flung) {
      _commit(_drag > 0);
    } else {
      _slide(0, TideMotion.swipeCancel, TideMotion.swipeCancelCurve);
    }
    _armed = false;
  }

  Future<void> _commit(bool right) async {
    if (!await _leave(right)) return;
    right ? widget.onComplete() : widget.onDelete();
  }

  /// Sends the card off the way it was pushed and closes the gap behind it.
  /// False if the card went away meanwhile.
  Future<bool> _leave(bool right) async {
    _leaving = true;
    TideHaptics.mediumImpact();
    await _slide(
      right ? _width : -_width,
      TideMotion.swipeSettle,
      Curves.easeOutCubic,
    );
    if (!mounted) return false;
    await _collapse.reverse();
    return mounted;
  }

  /// A step ticked on the card. Any but the last is simply ticked; the last
  /// finishes the task, so the card leaves first, as it would for a swipe.
  Future<void> _tickStep(Subtask step) async {
    if (_leaving) return;
    final task = widget.task;
    final last =
        !step.isCompleted && !task.isCompleted && task.subtasksLeft == 1;
    if (!last) {
      widget.onStep?.call(step);
      return;
    }
    setState(() => _finishing = step.id);
    if (!await _leave(true)) return;
    widget.onStep?.call(step);
    // Normally the list drops the card on its next build and this is never
    // seen. If the task did not finish after all, the card comes back.
    setState(() {
      _leaving = false;
      _finishing = null;
      _drag = 0;
    });
    _collapse.value = 1;
  }

  Future<void> _slide(double to, Duration duration, Curve curve) {
    final from = _drag;
    final travel = Tween<double>(
      begin: from,
      end: to,
    ).chain(CurveTween(curve: curve));
    void tick() => setState(() => _drag = travel.transform(_settle.value));
    _settle
      ..stop()
      ..duration = duration
      ..addListener(tick);
    return _settle.forward(from: 0).whenComplete(() {
      _settle.removeListener(tick);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizeTransition(
      sizeFactor: CurvedAnimation(
        parent: _collapse,
        curve: TideMotion.tabCurve,
      ),
      alignment: Alignment.topCenter,
      child: Semantics(
        customSemanticsActions: {
          CustomSemanticsAction(label: _rightLabel): _blocked
              ? () => widget.onBlocked?.call()
              : widget.onComplete,
          const CustomSemanticsAction(label: 'Delete'): widget.onDelete,
        },
        child: LayoutBuilder(
          builder: (context, constraints) {
            _width = constraints.maxWidth;
            final progress = _width == 0
                ? 0.0
                : (_drag.abs() / (_width * TideMotion.swipeThreshold)).clamp(
                    0.0,
                    1.0,
                  );

            return ClipRRect(
              borderRadius: TideElevation.radius12,
              child: Stack(
                children: [
                  if (_drag != 0) Positioned.fill(child: _backdrop(progress)),
                  Transform.translate(
                    offset: Offset(_drag, 0),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onHorizontalDragUpdate: _onUpdate,
                      onHorizontalDragEnd: _onEnd,
                      child: PressScale(
                        onTap: widget.onOpen,
                        onLongPress: widget.onMenu == null
                            ? null
                            : () {
                                TideHaptics.mediumImpact();
                                widget.onMenu!();
                              },
                        scale: 0.985,
                        haptic: false,
                        child: _Face(
                          task: widget.task,
                          showTags: widget.showTags,
                          overdueInHeading: widget.overdueInHeading,
                          finishing: _finishing,
                          onStep: widget.onStep == null ? null : _tickStep,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// Lantern and a tick on the left, coral and a bin on the right — or, for
  /// a task with steps left, plain ink and a checklist: not an action, a
  /// reason.
  Widget _backdrop(double progress) {
    if (_drag < 0) {
      return SwipeReveal(
        right: false,
        progress: progress,
        hue: TideColors.coral,
        icon: Icons.delete_outline_rounded,
        label: 'Delete',
      );
    }
    if (_blocked) {
      return SwipeReveal(
        right: true,
        progress: progress,
        hue: TideColors.bone,
        icon: Icons.checklist_rounded,
        label: _rightLabel,
      );
    }
    return SwipeReveal(
      right: true,
      progress: progress,
      hue: TideColors.lantern,
      onHue: TideColors.onLantern,
      icon: widget.task.isCompleted ? Icons.undo_rounded : Icons.check_rounded,
      label: _rightLabel,
    );
  }
}

/// The card itself.
class _Face extends StatelessWidget {
  const _Face({
    required this.task,
    required this.showTags,
    required this.overdueInHeading,
    this.finishing,
    this.onStep,
  });

  final Task task;
  final bool showTags;
  final bool overdueInHeading;
  final String? finishing;
  final void Function(Subtask step)? onStep;

  /// Steps shown on the card before the rest are left to the task itself. A
  /// long checklist would turn one card into a page.
  static const int _shownSteps = 4;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final done = task.isCompleted;
    final overdue = task.isOverdue(now);
    final dueToday =
        !done && task.dueDate != null && DateUtils.isSameDay(task.dueDate, now);

    final meta = <Widget>[
      if (done && task.completedAt != null)
        _Chip(text: TaskCopy.completed(task.completedAt!))
      else if (task.dueDate != null)
        _Chip(
          icon: overdue ? Icons.error_outline_rounded : Icons.event_rounded,
          text: overdue && !overdueInHeading
              ? 'Overdue · ${TaskCopy.due(task.dueDate!, now: now)}'
              : TaskCopy.due(task.dueDate!, now: now),
          tone: overdue || dueToday ? _Tone.accent : _Tone.plain,
        ),
      if (task.repeats && !done)
        _Chip(icon: Icons.repeat_rounded, text: TaskCopy.repeat(task)),
      if (task.reminders.isNotEmpty && !done)
        _Chip(
          icon: Icons.notifications_none_rounded,
          text: task.reminders.length == 1
              ? TaskCopy.time(task.reminders.first)
              : '${task.reminders.length}',
        ),
      if (task.subtasks.isNotEmpty)
        _Chip(
          icon: Icons.checklist_rounded,
          text: '${task.subtasksDone}/${task.subtasks.length}',
        ),
      if (showTags)
        for (final tag in task.tags.take(2)) _Chip(text: '#$tag'),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 16, 12),
      decoration: BoxDecoration(
        color: done
            ? Color.lerp(TideColors.shelf, TideColors.deepWater, 0.45)
            : TideColors.shelf,
        borderRadius: TideElevation.radius12,
        border: Border.all(
          color: overdue
              ? TideColors.lantern.withValues(alpha: 0.22)
              : TideColors.hairline,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StatusMark(done: done, overdue: overdue),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  task.title,
                  style: TideType.heading.copyWith(
                    fontSize: 15.5,
                    height: 1.3,
                    color: done ? TideColors.silt : TideColors.bone,
                    decoration: done ? TextDecoration.lineThrough : null,
                    decorationColor: TideColors.silt,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (task.description != null && !done) ...[
                  const SizedBox(height: 3),
                  Text(
                    task.description!,
                    style: TideType.labelMuted,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (onStep != null && !done && task.subtasks.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  for (final step in task.subtasks.take(_shownSteps))
                    _StepLine(
                      step: step,
                      ticked: step.isCompleted || step.id == finishing,
                      onTap: () => onStep!(step),
                    ),
                  if (task.subtasks.length > _shownSteps)
                    Padding(
                      padding: const EdgeInsets.only(left: 28, top: 2),
                      child: Text(
                        '+${task.subtasks.length - _shownSteps} more in the '
                        'task',
                        style: TideType.labelMuted.copyWith(fontSize: 12),
                      ),
                    ),
                ],
                if (meta.isNotEmpty) ...[
                  const SizedBox(height: 7),
                  Wrap(spacing: 6, runSpacing: 6, children: meta),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One step on the card, and the target for ticking it — the whole line, not
/// just its circle. Unlike the task's own mark, this one is a button: a step
/// has no swipe of its own.
class _StepLine extends StatelessWidget {
  const _StepLine({
    required this.step,
    required this.ticked,
    required this.onTap,
  });

  final Subtask step;
  final bool ticked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      checked: ticked,
      label: step.title,
      onTap: onTap,
      child: ExcludeSemantics(
        child: PressScale(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: TideMotion.tabSwitch,
                  curve: TideMotion.tabCurve,
                  width: 18,
                  height: 18,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: TideColors.lantern.withValues(alpha: ticked ? 1 : 0),
                    border: Border.all(
                      color: ticked
                          ? TideColors.lantern
                          : TideColors.bone.withValues(alpha: 0.28),
                      width: 1.4,
                    ),
                  ),
                  child: ticked
                      ? Icon(
                          Icons.check_rounded,
                          size: 12,
                          color: TideColors.onLantern,
                        )
                      : null,
                ),
                Expanded(
                  child: Text(
                    step.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TideType.label.copyWith(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w400,
                      color: ticked ? TideColors.silt : TideColors.bone,
                      decoration: ticked ? TextDecoration.lineThrough : null,
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

/// Where the task stands, drawn — not tapped.
class _StatusMark extends StatelessWidget {
  const _StatusMark({required this.done, required this.overdue});

  final bool done;
  final bool overdue;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 1),
      child: AnimatedContainer(
        duration: TideMotion.tabSwitch,
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: done ? TideColors.lantern : Colors.transparent,
          border: Border.all(
            color: done
                ? TideColors.lantern
                : overdue
                ? TideColors.lantern.withValues(alpha: 0.6)
                : TideColors.bone.withValues(alpha: 0.24),
            width: 1.6,
          ),
        ),
        child: done
            ? Icon(Icons.check_rounded, size: 13, color: TideColors.onLantern)
            : null,
      ),
    );
  }
}

enum _Tone { plain, accent }

class _Chip extends StatelessWidget {
  const _Chip({required this.text, this.icon, this.tone = _Tone.plain});

  final String text;
  final IconData? icon;
  final _Tone tone;

  @override
  Widget build(BuildContext context) {
    final accent = tone == _Tone.accent;
    final color = accent ? TideColors.lantern : TideColors.silt;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: accent
            ? TideColors.lantern.withValues(alpha: 0.10)
            : TideColors.bone.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: TideType.labelMuted.copyWith(
              fontSize: 12,
              color: color,
              fontWeight: accent ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
