import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../config/app_constants.dart';
import '../../config/app_routes.dart';
import '../../config/task_copy.dart';
import '../../services/habits/habit_repository.dart' show SyncStatus;
import '../../services/tasks/task.dart';
import '../../services/tasks/task_scope.dart';
import '../../services/tasks/task_store.dart';
import '../../theme/tide_colors.dart';
import '../../theme/tide_elevation.dart';
import '../../theme/tide_motion.dart';
import '../../theme/tide_typography.dart';
import '../../widgets/gauge_number.dart';
import '../../widgets/hold_to_fill.dart';
import '../../widgets/press_scale.dart';
import '../../widgets/tide_ring.dart';
import '../../widgets/tide_tab_bar.dart';
import 'widgets/list_options_sheet.dart';
import 'widgets/quick_add_bar.dart';
import 'widgets/task_card.dart';

/// The to-do list: a side module next to the habit tracker.
///
/// Read top to bottom: what day it is and how today is going, the one field
/// that adds a task, then the list grouped by when things are due, and the
/// finished ones folded away at the foot.
///
/// Everything is finished the way a habit is marked on Today — carried right.
/// A tip says so once, until it is dismissed or the gesture has been used.
class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  bool _showCompleted = false;

  void _snack(String message, {VoidCallback? undo}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          persist: false,
          duration: TideMotion.snackHold,
          content: Text(message, style: TideType.label),
          action: undo == null
              ? null
              : SnackBarAction(label: 'Undo', onPressed: undo),
        ),
      );
  }

  void _complete(Task task) {
    final store = TaskScope.read(context);
    store.dismissSwipeHint();
    final wasDone = task.isCompleted;
    final completion = store.toggleComplete(task.id);
    if (wasDone) {
      _snack('Moved back to your list.');
      return;
    }
    if (completion == null) return;
    _snack(
      completion.spawnedId != null
          ? 'Completed. The next one is on your list.'
          : 'Completed.',
      undo: () => store.undoCompletion(completion),
    );
  }

  /// A right swipe on a task whose steps are not all ticked. It finishes
  /// with its last step, so say how many are left rather than nothing.
  void _blocked(Task task) {
    final left = task.subtasksLeft;
    _snack(
      '${TaskCopy.steps(left)} still open. The task completes with its last '
      'step.',
    );
  }

  void _delete(Task task) {
    final store = TaskScope.read(context);
    store.dismissSwipeHint();
    final removed = store.delete(task.id);
    if (removed == null) return;
    _snack('Task deleted.', undo: () => store.restore(removed));
  }

  void _open(Task task) => context.push(Routes.task(task.id));

  void _openArchive() => context.push(Routes.taskArchive);

  @override
  Widget build(BuildContext context) {
    final store = TaskScope.of(context);
    final open = store.open;
    final completed = store.completed;
    final filter = store.activeTagFilter;
    final today = store.today;

    return ListView(
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.paddingOf(context).top + 24,
        20,
        TideTabBar.reservedHeight(context) + 40,
      ),
      children: [
        _Header(
          status: store.status,
          pending: store.hasPendingChanges,
          onOptions: () => showListOptionsSheet(context),
          onArchive: _openArchive,
        ),
        const SizedBox(height: 20),
        if (today.total > 0 || open.isNotEmpty) ...[
          _TodayCard(
            done: today.done,
            total: today.total,
            overdue: today.overdue,
            open: open.length,
          ),
          const SizedBox(height: 14),
        ],
        QuickAddBar(
          focusRequests: store.quickAddRequests,
          onAdd: (title, due) => store.add(title: title, dueDate: due),
        ),
        if (filter != null) ...[
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: TagChip(
              label: '#$filter',
              selected: true,
              onTap: () => showListOptionsSheet(context),
              onRemove: () => store.setTagFilter(null),
            ),
          ),
        ],
        if (open.isNotEmpty && !store.swipeHintSeen) ...[
          const SizedBox(height: 14),
          _SwipeHint(onDismiss: store.dismissSwipeHint),
        ],
        if (open.isEmpty)
          _EmptyList(filter: filter, anyDone: completed.isNotEmpty)
        else
          ..._sections(store, open),
        if (completed.isNotEmpty) ...[
          const SizedBox(height: 22),
          _CompletedHead(
            count: completed.length,
            expanded: _showCompleted,
            onTap: () => setState(() => _showCompleted = !_showCompleted),
          ),
          AnimatedSize(
            duration: TideMotion.tabSwitch,
            curve: TideMotion.tabCurve,
            alignment: Alignment.topCenter,
            child: !_showCompleted
                ? const SizedBox(width: double.infinity)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final task in completed)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: TaskCard(
                            key: ValueKey('done-${task.id}'),
                            task: task,
                            showTags: true,
                            onComplete: () => _complete(task),
                            onDelete: () => _delete(task),
                            onOpen: () => _open(task),
                          ),
                        ),
                      const SizedBox(height: 6),
                      _CompletedActions(
                        onArchive: () {
                          store.archiveCompleted();
                          _snack('Moved to the archive.');
                        },
                        onClear: () {
                          store.clearCompleted();
                          _snack('Completed tasks cleared.');
                        },
                      ),
                    ],
                  ),
          ),
        ],
      ],
    );
  }

  /// Due-date order gets Overdue / Today / Upcoming / No date; tag order gets
  /// one heading per first tag. Each heading carries its count.
  List<Widget> _sections(TaskStore store, List<Task> open) {
    final today = DateUtils.dateOnly(DateTime.now());
    String headingOf(Task task) {
      if (store.sort == TaskSort.tag) {
        return task.tags.isEmpty ? 'No tag' : '#${task.tags.first}';
      }
      final due = task.dueDate;
      if (due == null) return 'Someday';
      if (due.isBefore(today)) return 'Overdue';
      if (due == today) return 'Today';
      if (due == DateTime(today.year, today.month, today.day + 1)) {
        return 'Tomorrow';
      }
      return 'Upcoming';
    }

    final groups = <String, List<Task>>{};
    for (final task in open) {
      groups.putIfAbsent(headingOf(task), () => []).add(task);
    }

    return [
      for (final entry in groups.entries) ...[
        _SectionHead(title: entry.key, count: entry.value.length),
        for (final task in entry.value)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: TaskCard(
              key: ValueKey('open-${task.id}'),
              task: task,
              showTags: true,
              onComplete: () => _complete(task),
              onBlocked: () => _blocked(task),
              onDelete: () => _delete(task),
              onOpen: () => _open(task),
            ),
          ),
      ],
    ];
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.status,
    required this.pending,
    required this.onOptions,
    required this.onArchive,
  });

  final SyncStatus status;
  final bool pending;
  final VoidCallback onOptions;
  final VoidCallback onArchive;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final date =
        '${AppConstants.weekdayNames[now.weekday - 1]}, '
        '${now.day} ${AppConstants.monthNames[now.month - 1]}';
    // Said only when it matters: changes are waiting and the server cannot
    // be reached. A synced list says nothing about syncing.
    final offline = status == SyncStatus.offline && pending;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  if (offline) ...[
                    Icon(
                      Icons.cloud_off_rounded,
                      size: 14,
                      color: TideColors.silt,
                    ),
                    const SizedBox(width: 6),
                  ],
                  Flexible(
                    child: Text(
                      offline ? 'Offline · saved on this phone' : date,
                      style: TideType.labelMuted,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text('To-do', style: TideType.screenTitle),
            ],
          ),
        ),
        _IconButton(
          icon: Icons.tune_rounded,
          label: 'Sort and filter',
          onTap: onOptions,
        ),
        const SizedBox(width: 8),
        Stack(
          clipBehavior: Clip.none,
          children: [
            _IconButton(
              icon: Icons.inventory_2_outlined,
              label: 'Archive',
              onTap: onArchive,
            ),
          ],
        ),
      ],
    );
  }
}

/// How today is going, as a ring and a sentence.
class _TodayCard extends StatelessWidget {
  const _TodayCard({
    required this.done,
    required this.total,
    required this.overdue,
    required this.open,
  });

  final int done;
  final int total;
  final int overdue;
  final int open;

  String get _line {
    if (total == 0) return 'Nothing due today';
    if (done == total) return 'Everything due today is done';
    final left = total - done;
    return '$left left for today';
  }

  @override
  Widget build(BuildContext context) {
    final progress = total == 0 ? 0.0 : done / total;
    final complete = total > 0 && done == total;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: TideColors.shelf,
        borderRadius: TideElevation.radius20,
        border: Border.all(color: TideColors.hairline),
      ),
      child: Row(
        children: [
          TideRing(
            progress: progress,
            size: 46,
            strokeWidth: 4,
            child: complete
                ? Icon(Icons.check_rounded, size: 20, color: TideColors.lantern)
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      GaugeNumber(
                        value: done,
                        style: TideType.gauge(15, color: TideColors.bone),
                      ),
                      Text(
                        '/$total',
                        style: TideType.gauge(10, color: TideColors.silt),
                      ),
                    ],
                  ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_line, style: TideType.heading),
                const SizedBox(height: 3),
                Text(
                  open == 0 ? 'Your list is clear' : '$open open in total',
                  style: TideType.labelMuted,
                ),
              ],
            ),
          ),
          if (overdue > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: TideColors.lantern.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$overdue overdue',
                style: TideType.label.copyWith(
                  fontSize: 12.5,
                  color: TideColors.lantern,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The one-time tip, until it is dismissed or the gesture has been used.
class _SwipeHint extends StatelessWidget {
  const _SwipeHint({required this.onDismiss});

  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      decoration: BoxDecoration(
        color: TideColors.lantern.withValues(alpha: 0.08),
        borderRadius: TideElevation.radius12,
        border: Border.all(color: TideColors.lantern.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Icon(Icons.swipe_right_rounded, size: 20, color: TideColors.lantern),
          const SizedBox(width: 12),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: 'Swipe right',
                    style: TideType.label.copyWith(color: TideColors.lantern),
                  ),
                  const TextSpan(text: ' to complete, '),
                  TextSpan(text: 'left', style: TideType.label),
                  const TextSpan(text: ' to delete. Tap to edit.'),
                ],
              ),
              style: TideType.labelMuted.copyWith(color: TideColors.bone),
            ),
          ),
          PressScale(
            onTap: onDismiss,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Icon(
                Icons.close_rounded,
                size: 18,
                color: TideColors.silt,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyList extends StatelessWidget {
  const _EmptyList({required this.filter, required this.anyDone});

  final String? filter;
  final bool anyDone;

  @override
  Widget build(BuildContext context) {
    final title = filter != null
        ? 'Nothing tagged #$filter'
        : anyDone
        ? 'All done'
        : 'All clear';
    final body = filter != null
        ? 'Clear the filter to see the rest of your list.'
        : 'Nothing on your list — add something above.';

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 48, 12, 12),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: TideColors.lantern.withValues(alpha: 0.08),
              border: Border.all(
                color: TideColors.lantern.withValues(alpha: 0.2),
              ),
            ),
            child: Icon(
              anyDone ? Icons.done_all_rounded : Icons.checklist_rounded,
              size: 28,
              color: TideColors.lantern,
            ),
          ),
          const SizedBox(height: 16),
          Text(title, style: TideType.hero),
          const SizedBox(height: 6),
          Text(body, style: TideType.bodyMuted, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _SectionHead extends StatelessWidget {
  const _SectionHead({required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    final overdue = title == 'Overdue';
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 22, 2, 10),
      child: Row(
        children: [
          Text(
            title,
            style: TideType.heading.copyWith(
              fontSize: 15,
              color: overdue ? TideColors.lantern : TideColors.bone,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: overdue
                  ? TideColors.lantern.withValues(alpha: 0.12)
                  : TideColors.bone.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$count',
              style: TideType.gauge(
                12,
                color: overdue ? TideColors.lantern : TideColors.silt,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  const _IconButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: PressScale(
        onTap: onTap,
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: TideColors.shelf,
            border: Border.all(color: TideColors.hairline),
          ),
          child: Icon(icon, size: 19, color: TideColors.bone),
        ),
      ),
    );
  }
}

class _CompletedHead extends StatelessWidget {
  const _CompletedHead({
    required this.count,
    required this.expanded,
    required this.onTap,
  });

  final int count;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onTap,
      scale: 0.99,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          borderRadius: TideElevation.radius12,
          border: Border.all(color: TideColors.hairline),
        ),
        child: Row(
          children: [
            Icon(Icons.done_all_rounded, size: 18, color: TideColors.silt),
            const SizedBox(width: 10),
            Text('Completed', style: TideType.label),
            const SizedBox(width: 8),
            Text('$count', style: TideType.gauge(13, color: TideColors.silt)),
            const Spacer(),
            Text(expanded ? 'Hide' : 'Show', style: TideType.labelMuted),
            AnimatedRotation(
              turns: expanded ? 0.5 : 0,
              duration: TideMotion.tabSwitch,
              child: Icon(
                Icons.expand_more_rounded,
                size: 20,
                color: TideColors.silt,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompletedActions extends StatelessWidget {
  const _CompletedActions({required this.onArchive, required this.onClear});

  final VoidCallback onArchive;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: PressScale(
            onTap: onArchive,
            child: Container(
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: TideColors.shelf,
                borderRadius: TideElevation.radius12,
                border: Border.all(color: TideColors.hairline),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.inventory_2_outlined,
                    size: 17,
                    color: TideColors.bone,
                  ),
                  const SizedBox(width: 8),
                  Text('Archive all', style: TideType.label),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: HoldToConfirmButton(
            label: 'Hold to clear',
            holdingLabel: 'Keep holding…',
            quiet: true,
            onConfirm: onClear,
          ),
        ),
      ],
    );
  }
}
