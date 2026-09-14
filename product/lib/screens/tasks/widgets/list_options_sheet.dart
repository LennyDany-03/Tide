import 'package:flutter/material.dart';

import '../../../config/pro_features.dart';
import '../../../services/tasks/task_scope.dart';
import '../../../services/tasks/task_store.dart';
import '../../../theme/tide_colors.dart';
import '../../../theme/tide_elevation.dart';
import '../../../theme/tide_motion.dart';
import '../../../theme/tide_typography.dart';
import '../../../widgets/pro_lock.dart';
import '../../../widgets/press_scale.dart';
import '../../../widgets/segmented_pill.dart';

/// Sort and filter, kept off the list itself.
///
/// A row of filter chips across the top of the list would be permanent
/// furniture on a screen whose whole job is to be light, and most people
/// never change the order. One sheet behind one icon holds both.
Future<void> showListOptionsSheet(BuildContext context) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss',
    barrierColor: TideColors.scrim,
    transitionDuration: TideMotion.sheetIn,
    pageBuilder: (context, _, _) => const Align(
      alignment: Alignment.bottomCenter,
      child: Material(type: MaterialType.transparency, child: _OptionsSheet()),
    ),
    transitionBuilder: (context, animation, _, child) => SlideTransition(
      position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
          .animate(
            CurvedAnimation(
              parent: animation,
              curve: TideMotion.sheetCurve,
              reverseCurve: Curves.easeInCubic,
            ),
          ),
      child: child,
    ),
  );
}

class _OptionsSheet extends StatelessWidget {
  const _OptionsSheet();

  @override
  Widget build(BuildContext context) {
    final store = TaskScope.of(context);
    final tagsLocked = store.locked(ProFeature.taskTags);
    final tags = store.tags;

    return Container(
      constraints: const BoxConstraints(maxWidth: 520),
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        20 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: BoxDecoration(
        color: TideColors.shoal,
        borderRadius: TideElevation.sheetRadius,
        boxShadow: TideElevation.floating,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Sort by', style: TideType.sectionHeader),
          const SizedBox(height: 10),
          SegmentedPill(
            labels: const ['Due date', 'Tag'],
            selectedIndex: store.sort.index,
            onChanged: (i) => store.setSort(TaskSort.values[i]),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Text('Filter by tag', style: TideType.sectionHeader),
              if (tagsLocked) ...[
                const SizedBox(width: 8),
                const ProBadge(compact: true),
              ],
            ],
          ),
          const SizedBox(height: 10),
          if (tagsLocked)
            PressScale(
              onTap: () {
                Navigator.of(context).pop();
                askForPro(context, ProFeature.taskTags);
              },
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: TideColors.shelf,
                  borderRadius: TideElevation.radius12,
                  border: Border.all(color: TideColors.hairline),
                ),
                child: const ProHint(feature: ProFeature.taskTags),
              ),
            )
          else if (tags.isEmpty)
            Text(
              'Add tags to a task from its details, then filter by them here.',
              style: TideType.labelMuted,
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                TagChip(
                  label: 'All',
                  selected: store.activeTagFilter == null,
                  onTap: () => store.setTagFilter(null),
                ),
                for (final tag in tags)
                  TagChip(
                    label: '#$tag',
                    selected: store.activeTagFilter == tag,
                    onTap: () => store.setTagFilter(tag),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class TagChip extends StatelessWidget {
  const TagChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.onRemove,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onTap,
      child: AnimatedContainer(
        duration: TideMotion.tabSwitch,
        padding: EdgeInsets.fromLTRB(12, 7, onRemove == null ? 12 : 6, 7),
        decoration: BoxDecoration(
          color: selected
              ? TideColors.lantern.withValues(alpha: 0.14)
              : TideColors.shelf,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? TideColors.lantern.withValues(alpha: 0.4)
                : TideColors.hairline,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TideType.label.copyWith(
                fontSize: 13,
                color: selected ? TideColors.lantern : TideColors.bone,
              ),
            ),
            if (onRemove != null) ...[
              const SizedBox(width: 2),
              PressScale(
                onTap: onRemove,
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Icon(
                    Icons.close_rounded,
                    size: 15,
                    color: TideColors.silt,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
