import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import '../../../config/task_copy.dart';
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
/// says why. The task finishes when its last step is ticked in the editor.
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
    this.showTags = true,
    this.completeLabel,
  });

  final Task task;

  /// Called once the card has left. Toggles: a finished task is reopened.
  final VoidCallback onComplete;
  final VoidCallback onDelete;
  final VoidCallback onOpen;

  /// A right swipe on a task whose steps are not all done.
  final VoidCallback? onBlocked;

  /// Off on the free plan unless the task already carries tags from a plan
  /// that has since ended — then they are still shown, never hidden.
  final bool showTags;

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
      if (armed) HapticFeedback.selectionClick();
    }
  }

  void _onEnd(DragEndDetails details) {
    if (_leaving) return;
    final velocity = details.velocity.pixelsPerSecond.dx;
    // A page thrown at the tab bar, not a considered swipe — see
    // TideMotion.swipeFlingVelocity.
    final flung = velocity.abs() >= TideMotion.swipeFlingVelocity;
    if (_armed && !flung && _drag > 0 && _blocked) {
      HapticFeedback.heavyImpact();
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
    _leaving = true;
    HapticFeedback.mediumImpact();
    await _slide(
      right ? _width : -_width,
      TideMotion.swipeSettle,
      Curves.easeOutCubic,
    );
    if (!mounted) return;
    await _collapse.reverse();
    if (!mounted) return;
    right ? widget.onComplete() : widget.onDelete();
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
                        scale: 0.985,
                        haptic: false,
                        child: _Face(
                          task: widget.task,
                          showTags: widget.showTags,
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
  const _Face({required this.task, required this.showTags});

  final Task task;
  final bool showTags;

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
          text: overdue
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
      padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
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
                if (meta.isNotEmpty) ...[
                  const SizedBox(height: 8),
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
