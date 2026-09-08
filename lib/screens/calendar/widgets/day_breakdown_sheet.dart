import 'package:flutter/material.dart';

import '../../../config/app_constants.dart';
import '../../../services/models/day_summary.dart';
import '../../../services/models/habit.dart';
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
///
/// The redesign is about what the sheet leads with. It used to open on a
/// date and the line "4 of 4 logged" in muted grey, then four flat rows
/// each ending in the word "logged" — four identical labels doing the work
/// a single mark does better, and a headline fact set smaller than the
/// habit names underneath it. The day's own result now sits in the header
/// as a filled ring, each row carries its actual amount rather than only a
/// verdict, and the verdict itself is a chip you can read without reading.
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

  int get _done => entries.where((e) => e.complete || e.frozen).length;

  /// The day in one line. Named rather than counted where a name exists:
  /// "every habit in" is the thing you want told, and "4 of 4" is the
  /// arithmetic behind it.
  String get _verdict {
    if (entries.isEmpty) return 'Nothing scheduled';
    if (_done == entries.length) {
      return entries.length == 1 ? 'Marked' : 'Every habit in';
    }
    if (_done == 0) return 'Nothing marked';
    return '$_done of ${entries.length} marked';
  }

  @override
  Widget build(BuildContext context) {
    final ratio = entries.isEmpty ? 0.0 : _done / entries.length;

    return TideSheet(
      title: _title,
      eyebrow: _verdict,
      // The day's result, in the corner every sheet puts its subject in.
      leading: entries.isEmpty
          ? null
          : TideRing(
              progress: ratio,
              size: 44,
              strokeWidth: 3,
              child: Text(
                '$_done',
                style: TideType.gauge(
                  15,
                  color: ratio >= 1 ? TideColors.lantern : TideColors.bone,
                ),
              ),
            ),
      onDismiss: () => Navigator.of(context).pop(),
      maxHeightFactor: 0.72,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 26),
        child: entries.isEmpty
            ? const TideEmptyNote(message: 'Nothing was scheduled on this day.')
            : StaggerColumn(
                spacing: 9,
                children: [for (final entry in entries) _Row(entry: entry)],
              ),
      ),
    );
  }
}

/// One habit's day: its mark, its name, what it actually came to, and how
/// that day is being counted.
class _Row extends StatelessWidget {
  const _Row({required this.entry});

  final HabitDayEntry entry;

  /// Frozen is ice, logged is the accent. Both used to be lantern, so a day
  /// you held and a day you earned came back identical apart from the word
  /// beside them.
  Color get _tint => entry.frozen
      ? TideColors.frost
      : entry.complete
      ? TideColors.lantern
      : entry.amount > 0
      ? TideColors.lantern
      : TideColors.silt;

  /// The amount, in the habit's own units. A binary habit has no number
  /// worth printing, so it gets its schedule instead of a bare "1 of 1".
  String get _detail {
    final habit = entry.habit;
    if (entry.frozen) return 'Held with a freeze';
    if (habit.type == HabitType.binary) {
      return entry.complete ? 'Done' : 'Not marked';
    }
    return '${entry.amount.round()} of ${habit.targetLabel}';
  }

  @override
  Widget build(BuildContext context) {
    final progress = entry.frozen
        ? 1.0
        : (entry.amount / entry.habit.target).clamp(0.0, 1.0).toDouble();

    return TideSurface(
      radius: TideElevation.radius20,
      color: TideColors.trench,
      highlight: false,
      padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
      child: Row(
        children: [
          // A disc rather than a bare ring: at this size an unfilled ring
          // around a dim glyph is two thin circles, and the rows stopped
          // being scannable.
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _tint.withValues(alpha: entry.complete ? 0.14 : 0.06),
            ),
            child: HabitGlyph(glyph: entry.habit.glyph, size: 17, color: _tint),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  entry.habit.name,
                  style: TideType.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(_detail, style: TideType.labelMuted.copyWith(fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _Status(entry: entry, progress: progress),
        ],
      ),
    );
  }
}

/// The verdict, as a mark rather than a word.
///
/// Four rows each ending in the word "logged" is four labels saying the
/// same thing in the place the eye is trying to scan. A filled check reads
/// at a glance; the partial case keeps its ring, because "how far" is the
/// only thing a half-done day has to say.
class _Status extends StatelessWidget {
  const _Status({required this.entry, required this.progress});

  final HabitDayEntry entry;
  final double progress;

  @override
  Widget build(BuildContext context) {
    if (entry.frozen) {
      return const _Mark(
        icon: Icons.ac_unit_rounded,
        colour: TideColors.frost,
        filled: true,
      );
    }
    if (entry.complete) {
      return const _Mark(
        icon: Icons.check_rounded,
        colour: TideColors.lantern,
        filled: true,
      );
    }
    if (entry.amount > 0) {
      return TideRing(
        progress: progress,
        size: 28,
        strokeWidth: 2.5,
        animate: false,
        color: TideColors.lantern,
      );
    }
    return _Mark(
      icon: Icons.remove_rounded,
      colour: TideColors.silt.withValues(alpha: 0.7),
      filled: false,
    );
  }
}

class _Mark extends StatelessWidget {
  const _Mark({
    required this.icon,
    required this.colour,
    required this.filled,
  });

  final IconData icon;
  final Color colour;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: filled ? colour : Colors.transparent,
        border: filled
            ? null
            : Border.all(color: TideColors.bone.withValues(alpha: 0.12)),
      ),
      child: Icon(
        icon,
        size: 17,
        color: filled ? TideColors.deepWater : colour,
      ),
    );
  }
}
