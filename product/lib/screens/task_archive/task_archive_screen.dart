import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../config/app_constants.dart';
import '../../services/tasks/task.dart';
import '../../services/tasks/task_scope.dart';
import '../../theme/tide_colors.dart';
import '../../theme/tide_motion.dart';
import '../../theme/tide_typography.dart';
import '../../widgets/press_scale.dart';
import '../../widgets/tide_tab_bar.dart';
import '../tasks/widgets/task_card.dart';

/// Finished tasks that were put away, by the month they were finished. Pro.
///
/// Reached from the list header. A free account that arrives here anyway —
/// a plan that lapsed with the screen open — is shown what the archive is
/// and the way to it, never a broken page.
class TaskArchiveScreen extends StatelessWidget {
  const TaskArchiveScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = TaskScope.of(context);
    final archived = store.archived;

    return ListView(
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.paddingOf(context).top + 16,
        20,
        TideTabBar.reservedHeight(context) + 40,
      ),
      children: [
        Row(
          children: [
            PressScale(
              onTap: () => context.pop(),
              child: SizedBox(
                width: 40,
                height: 40,
                child: Icon(
                  Icons.arrow_back_rounded,
                  size: 21,
                  color: TideColors.bone,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text('Archive', style: TideType.hero),
          ],
        ),
        const SizedBox(height: 18),
        if (archived.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 44),
            child: Text(
              'Nothing archived yet. Finished tasks land here when you archive '
              'them from the list.',
              style: TideType.bodyMuted,
              textAlign: TextAlign.center,
            ),
          )
        else
          ..._grouped(context, archived),
      ],
    );
  }

  List<Widget> _grouped(BuildContext context, List<Task> tasks) {
    final store = TaskScope.read(context);
    final widgets = <Widget>[];
    String? heading;
    for (final task in tasks) {
      final at = task.completedAt ?? task.updatedAt;
      final month = '${AppConstants.monthNames[at.month - 1]} ${at.year}';
      if (month != heading) {
        heading = month;
        widgets.add(
          Padding(
            padding: EdgeInsets.only(top: widgets.isEmpty ? 4 : 22, bottom: 2),
            child: Text(month, style: TideType.sectionHeader),
          ),
        );
      }
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: TaskCard(
            key: ValueKey('archived-${task.id}'),
            task: task,
            completeLabel: 'Restore',
            onComplete: () => store.unarchive(task.id),
            onDelete: () {
              final removed = store.delete(task.id);
              if (removed == null) return;
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  SnackBar(
                    persist: false,
                    duration: TideMotion.snackHold,
                    content: Text('Task deleted.', style: TideType.label),
                    action: SnackBarAction(
                      label: 'Undo',
                      onPressed: () => store.restore(removed),
                    ),
                  ),
                );
            },
            onOpen: () => store.unarchive(task.id),
          ),
        ),
      );
    }
    widgets.add(
      Padding(
        padding: const EdgeInsets.only(top: 14),
        child: Text(
          'Swipe right or tap a task to put it back on the completed list.',
          style: TideType.labelMuted,
          textAlign: TextAlign.center,
        ),
      ),
    );
    return widgets;
  }
}
