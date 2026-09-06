import 'package:flutter/material.dart';

import '../../../config/app_constants.dart';
import '../../../services/models/day_summary.dart';
import '../../../theme/tide_colors.dart';
import '../../../theme/tide_elevation.dart';
import '../../../theme/tide_motion.dart';
import '../../../theme/tide_typography.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/habit_glyph.dart';
import '../../../widgets/stagger_list.dart';
import '../../../widgets/tide_ring.dart';
import '../../../widgets/tide_sheet.dart';
import '../../../widgets/tide_surface.dart';

/// What happened on one day, raised as a bottom sheet.
///
/// A sheet rather than a pushed screen on purpose: you are inspecting a
/// detail of the month you are still looking at, and the month should stay
/// visible behind it.
Future<void> showDayBreakdown(
  BuildContext context, {
  required DateTime date,
  required List<HabitDayEntry> entries,
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
            child: _Breakdown(date: date, entries: entries),
          ),
        ],
      );
    },
  );
}

class _Breakdown extends StatelessWidget {
  const _Breakdown({required this.date, required this.entries});

  final DateTime date;
  final List<HabitDayEntry> entries;

  String get _title {
    final weekday = AppConstants.weekdayNames[date.weekday - 1];
    final month = AppConstants.monthNames[date.month - 1];
    return '$weekday ${date.day} $month';
  }

  @override
  Widget build(BuildContext context) {
    final done = entries.where((e) => e.complete || e.frozen).length;

    return TideSheet(
      title: _title,
      onDismiss: () => Navigator.of(context).pop(),
      maxHeightFactor: 0.7,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 26),
        child: entries.isEmpty
            ? const TideEmptyNote(message: 'Nothing was scheduled on this day.')
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$done of ${entries.length} logged',
                    style: TideType.labelMuted,
                  ),
                  const SizedBox(height: 14),
                  StaggerColumn(
                    spacing: 8,
                    children: [for (final entry in entries) _Row(entry: entry)],
                  ),
                ],
              ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.entry});

  final HabitDayEntry entry;

  @override
  Widget build(BuildContext context) {
    // Frozen is ice, logged is the accent. Both used to be lantern, so a
    // day you held and a day you earned came back identical apart from the
    // word beside them.
    final color = entry.frozen
        ? TideColors.frost
        : entry.complete
        ? TideColors.lantern
        : TideColors.silt;

    final status = entry.frozen
        ? 'frozen'
        : entry.complete
        ? 'logged'
        : entry.amount > 0
        ? '${entry.amount} of ${entry.habit.target}'
        : 'missed';

    return TideSurface(
      radius: TideElevation.radius12,
      color: TideColors.trench,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          TideRing(
            progress: entry.frozen ? 1 : entry.amount / entry.habit.target,
            size: 26,
            strokeWidth: 2,
            color: color,
            animate: false,
            child: HabitGlyph(glyph: entry.habit.glyph, size: 11, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              entry.habit.name,
              style: TideType.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(status, style: TideType.labelMuted.copyWith(color: color)),
        ],
      ),
    );
  }
}
