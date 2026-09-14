import 'package:flutter/material.dart';

import '../../../config/habit_copy.dart';
import '../../../services/models/habit.dart';
import '../../../theme/tide_colors.dart';
import '../../../theme/tide_elevation.dart';
import '../../../theme/tide_motion.dart';
import '../../../theme/tide_typography.dart';
import '../../../widgets/gauge_number.dart';
import '../../../widgets/habit_glyph.dart';
import '../../../widgets/hold_to_fill.dart';
import '../../../widgets/press_scale.dart';
import '../../../widgets/tide_button.dart';

/// The long-press sheet, raised from anywhere on a habit card.
///
/// **A glance first, verbs second.** The menu this replaced was a floating
/// card of verbs: an icon in a tinted tile, a dot and a status, a list of
/// icon-chevron rows in a box inside the box, and a coral slab at the
/// bottom. Every piece of that is the default kit, and together they said
/// nothing about the habit that the card behind it had not already said. The
/// sheet opens on the habit itself — its name at display size, the streak as
/// a figure, and the last two weeks as fourteen days — so a long-press is
/// worth doing even when you only wanted to look.
///
/// **Rises from the bottom, where the thumb already is.** A centred panel put
/// the primary action in the middle of the screen, the one place a thumb on
/// a long-pressed card has to travel furthest to reach.
///
/// **One primary, three quiet tiles, one hidden danger.** Logging is the one
/// lantern button. Details, Edit and Pause sit side by side as equal tiles —
/// three verbs of the same weight read faster as a row than as a list.
/// Delete keeps the coral hold used everywhere else, but quiet: coral words
/// until it is held, so the rarest action is no longer the loudest shape.
///
/// On a paused habit the sheet changes its question. Resume becomes the
/// primary — logging a habit that is not due makes no sense — and the line
/// under the name says since when, and that the streak is being held.
///
/// Plain scrim, no blur, as with [showTideDialog]. The blur banded into
/// posterised colour blobs on some GPUs — hues the palette does not contain
/// — and it cost a `BackdropFilter` at the exact moment the sheet opens.
Future<void> showHabitContextMenu(
  BuildContext context, {
  required Habit habit,
  required int streak,
  required VoidCallback onDetails,
  required VoidCallback onEdit,
  required VoidCallback onPause,
  required VoidCallback onDelete,
  VoidCallback? onComplete,
  VoidCallback? onLogProgress,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss',
    barrierColor: TideColors.scrim,
    transitionDuration: TideMotion.sheetIn,
    pageBuilder: (context, animation, secondary) => Align(
      alignment: Alignment.bottomCenter,
      child: Material(
        type: MaterialType.transparency,
        child: _Sheet(
          habit: habit,
          streak: streak,
          onDetails: onDetails,
          onEdit: onEdit,
          onPause: onPause,
          onDelete: onDelete,
          onComplete: onComplete,
          onLogProgress: onLogProgress,
        ),
      ),
    ),
    transitionBuilder: (context, animation, secondary, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: TideMotion.sheetCurve,
        reverseCurve: Curves.easeInCubic,
      );
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 1),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      );
    },
  );
}

class _Sheet extends StatelessWidget {
  const _Sheet({
    required this.habit,
    required this.streak,
    required this.onDetails,
    required this.onEdit,
    required this.onPause,
    required this.onDelete,
    this.onComplete,
    this.onLogProgress,
  });

  final Habit habit;
  final int streak;
  final VoidCallback onDetails;
  final VoidCallback onEdit;
  final VoidCallback onPause;
  final VoidCallback onDelete;
  final VoidCallback? onComplete;
  final VoidCallback? onLogProgress;

  /// Closes the sheet before acting, so a pushed route or an opened sheet
  /// never arrives underneath it.
  void _run(BuildContext context, VoidCallback action) {
    Navigator.of(context).pop();
    action();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;

    final primary = habit.paused
        ? (label: 'Resume habit', icon: Icons.play_arrow_rounded, act: onPause)
        : onComplete != null
        ? (label: 'Mark complete', icon: Icons.check_rounded, act: onComplete!)
        : onLogProgress != null
        ? (label: 'Mark progress', icon: Icons.add_rounded, act: onLogProgress!)
        : null;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: TideColors.shoal,
          borderRadius: TideElevation.sheetRadius,
          boxShadow: TideElevation.floating,
        ),
        child: ClipRRect(
          borderRadius: TideElevation.sheetRadius,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: TideElevation.innerHighlightWidth,
                decoration: BoxDecoration(
                  gradient: TideElevation.innerHighlightGradient,
                ),
              ),
              const SizedBox(height: 10),
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: TideColors.bone.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(20, 18, 20, 12 + bottom),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Header(habit: habit, streak: streak),
                    const SizedBox(height: 22),
                    _Fortnight(habit: habit),
                    const SizedBox(height: 22),
                    if (primary != null) ...[
                      TideButton(
                        label: primary.label,
                        icon: Icon(
                          primary.icon,
                          size: 19,
                          color: TideColors.onLantern,
                        ),
                        onPressed: () => _run(context, primary.act),
                      ),
                      const SizedBox(height: 10),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: _Tile(
                            icon: Icons.insights_rounded,
                            label: 'Habit details',
                            onTap: () => _run(context, onDetails),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _Tile(
                            icon: Icons.tune_rounded,
                            label: 'Edit habit',
                            onTap: () => _run(context, onEdit),
                          ),
                        ),
                        if (!habit.paused) ...[
                          const SizedBox(width: 10),
                          Expanded(
                            child: _Tile(
                              icon: Icons.pause_rounded,
                              label: 'Pause habit',
                              onTap: () => _run(context, onPause),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    HoldToConfirmButton(
                      label: 'Hold to delete',
                      holdingLabel: 'Keep holding…',
                      quiet: true,
                      onConfirm: () => _run(context, onDelete),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The habit's name at display size, what it asks for, and the streak as a
/// figure rather than a phrase.
class _Header extends StatelessWidget {
  const _Header({required this.habit, required this.streak});

  final Habit habit;
  final int streak;

  String get _subline {
    if (habit.paused) return HabitCopy.pausedSince(habit);
    final target = habit.targetLabel;
    final schedule = HabitCopy.schedule(habit);
    return target.isEmpty ? schedule : '$target · $schedule';
  }

  @override
  Widget build(BuildContext context) {
    final accent = habit.paused
        ? TideColors.drained(TideColors.lantern, 0.7)
        : TideColors.lantern;

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
                  HabitGlyph(glyph: habit.glyph, size: 14, color: accent),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      _subline,
                      style: TideType.labelMuted,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                habit.name,
                style: TideType.hero.copyWith(
                  fontSize: 26,
                  letterSpacing: -0.8,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            GaugeNumber(
              value: streak,
              style: TideType.gauge(
                34,
                letterSpacing: -1.4,
                color: streak > 0 && !habit.paused
                    ? TideColors.bone
                    : TideColors.silt,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              habit.paused ? 'streak held' : 'day streak',
              style: TideType.labelMuted,
            ),
          ],
        ),
      ],
    );
  }
}

/// The last fourteen days, one square each, today on the right.
///
/// The same mark as the card's week strip and the detail heatmap, stretched
/// to the sheet's width so it reads as a row of days rather than a gauge. A
/// paused day is an outline with nothing in it: a rest, not a miss.
class _Fortnight extends StatelessWidget {
  const _Fortnight({required this.habit});

  final Habit habit;

  static const int _days = 14;
  static const double _gap = 4;

  @override
  Widget build(BuildContext context) {
    final today = DateUtils.dateOnly(DateTime.now());
    final created = DateUtils.dateOnly(habit.createdAt);
    final days = [
      for (var i = _days - 1; i >= 0; i--) DateUtils.addDaysToDate(today, -i),
    ];

    var due = 0;
    var kept = 0;
    for (final day in days) {
      if (day.isBefore(created) || !habit.isDueOn(day)) continue;
      // Today is still open, so it only counts once it has been kept.
      if (day == today && !habit.countsTowardStreak(day)) continue;
      due++;
      if (habit.countsTowardStreak(day)) kept++;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text('Last two weeks', style: TideType.sectionHeader),
            const Spacer(),
            GaugeNumber(
              value: kept,
              style: TideType.gauge(13, color: TideColors.bone),
            ),
            Text(' of $due kept', style: TideType.labelMuted),
          ],
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final size = (constraints.maxWidth - _gap * (_days - 1)) / _days;
            return Row(
              children: [
                for (var i = 0; i < _days; i++) ...[
                  if (i > 0) const SizedBox(width: _gap),
                  _DayMark(
                    size: size,
                    habit: habit,
                    day: days[i],
                    today: today,
                    beforeHabit: days[i].isBefore(created),
                    delay: TideMotion.cellStep * i * 2,
                  ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _DayMark extends StatelessWidget {
  const _DayMark({
    required this.size,
    required this.habit,
    required this.day,
    required this.today,
    required this.beforeHabit,
    required this.delay,
  });

  final double size;
  final Habit habit;
  final DateTime day;
  final DateTime today;
  final bool beforeHabit;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    final paused = habit.isPausedOn(day);
    final due = habit.isDueOn(day) && !beforeHabit;
    final frozen = due && habit.isFrozenOn(day);
    final level = !due ? 0.0 : (frozen ? 0.45 : habit.progressOn(day));
    final isToday = day == today;

    final empty = TideColors.bone.withValues(alpha: 0.06);
    final Color fill = paused || beforeHabit
        ? Colors.transparent
        : !due
        ? TideColors.bone.withValues(alpha: 0.03)
        : TideColors.intensity(
            level,
            hue: frozen ? TideColors.frost : TideColors.lantern,
          );

    final Border? border = isToday
        ? Border.all(
            color: TideColors.lantern.withValues(alpha: 0.7),
            width: 1.4,
          )
        : paused
        ? Border.all(color: TideColors.bone.withValues(alpha: 0.16))
        : null;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: 1),
      duration: TideMotion.cellFill + delay,
      curve: Interval(
        delay.inMilliseconds /
            (TideMotion.cellFill.inMilliseconds + delay.inMilliseconds),
        1,
        curve: Curves.easeOutCubic,
      ),
      builder: (context, t, _) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Color.lerp(empty, fill, t),
          borderRadius: BorderRadius.circular(size * 0.26),
          border: border,
        ),
      ),
    );
  }
}

/// One of the three quiet verbs: an icon over its name, on a tile a step
/// back from the sheet.
class _Tile extends StatelessWidget {
  const _Tile({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onTap,
      child: Container(
        height: 76,
        decoration: BoxDecoration(
          color: TideColors.shelf,
          borderRadius: TideElevation.radius12,
          border: Border.all(color: TideColors.hairline),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 20,
              color: TideColors.bone.withValues(alpha: 0.85),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TideType.labelMuted.copyWith(
                color: TideColors.bone,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
