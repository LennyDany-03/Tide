import 'package:flutter/material.dart';

import '../../../config/app_constants.dart';
import '../../../services/models/habit.dart';
import '../../../theme/tide_colors.dart';
import '../../../theme/tide_motion.dart';
import '../../../theme/tide_typography.dart';
import '../../../widgets/gauge_number.dart';

/// One month of a single habit, as a calendar lit in lantern.
///
/// It was a block of fixed 30px squares with no dates in them, pinned to
/// the left edge. Kept small because a month of large *empty* squares is a
/// dark grid that dominates the screen — true, and the cure was worse: a
/// third of the width sat unused, and without dates or weekday letters the
/// grid could not answer the one question anybody brings to it, "what
/// happened on Tuesday". Dates are what make big cells earn their size. With
/// a number in every cell and the weekdays over the columns it reads as a
/// calendar, so it can take the full width without reading as a void.
///
/// A kept day is lantern by intensity, a frozen day frost, a paused day an
/// outline with nothing in it — a rest, visibly neither earned nor missed —
/// and today carries a lantern edge.
///
/// Cells fill in staggered by day rather than all at once, so the month reads
/// as filling the way it was actually lived.
class MonthHeatmap extends StatelessWidget {
  const MonthHeatmap({super.key, required this.habit, required this.month});

  final Habit habit;
  final DateTime month;

  static const double _gap = 6;

  /// Past this a cell stops looking like a day and starts looking like a
  /// button — it only matters on tablets and landscape.
  static const double _maxCell = 46;

  int get _daysInMonth => DateUtils.getDaysInMonth(month.year, month.month);

  /// Due days so far this month, and how many of them were kept.
  ({int due, int kept, bool frozen, bool paused}) _tally(DateTime today) {
    var due = 0;
    var kept = 0;
    var frozen = false;
    var paused = false;
    final created = DateUtils.dateOnly(habit.createdAt);

    for (var day = 1; day <= _daysInMonth; day++) {
      final date = DateTime(month.year, month.month, day);
      if (date.isAfter(today)) break;
      if (habit.isPausedOn(date)) paused = true;
      if (date.isBefore(created) || !habit.isDueOn(date)) continue;
      if (habit.isFrozenOn(date)) frozen = true;
      // Today is still open; it joins the count once it is kept.
      if (date == today && !habit.countsTowardStreak(date)) continue;
      due++;
      if (habit.countsTowardStreak(date)) kept++;
    }
    return (due: due, kept: kept, frozen: frozen, paused: paused);
  }

  @override
  Widget build(BuildContext context) {
    final today = DateUtils.dateOnly(DateTime.now());
    final first = DateTime(month.year, month.month);
    final tally = _tally(today);

    // Monday-first leading blanks, so a month always lines up under the
    // same weekday columns as the calendar screen.
    final leading = first.weekday - 1;
    final rows = ((leading + _daysInMonth) / 7).ceil();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              AppConstants.monthNames[month.month - 1],
              style: TideType.hero.copyWith(fontSize: 19),
            ),
            const Spacer(),
            GaugeNumber(
              value: tally.kept,
              style: TideType.gauge(15, color: TideColors.bone),
            ),
            Text(' of ${tally.due} kept', style: TideType.labelMuted),
          ],
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final cell = ((constraints.maxWidth - _gap * 6) / 7).clamp(
              0.0,
              _maxCell,
            );
            final width = cell * 7 + _gap * 6;

            return Center(
              child: SizedBox(
                width: width,
                child: Column(
                  children: [
                    Row(
                      children: [
                        for (var col = 0; col < 7; col++) ...[
                          if (col > 0) const SizedBox(width: _gap),
                          SizedBox(
                            width: cell,
                            child: Text(
                              AppConstants.weekdayInitials[col],
                              textAlign: TextAlign.center,
                              style: TideType.labelMuted.copyWith(fontSize: 11),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 10),
                    for (var row = 0; row < rows; row++) ...[
                      if (row > 0) const SizedBox(height: _gap),
                      Row(
                        children: [
                          for (var col = 0; col < 7; col++) ...[
                            if (col > 0) const SizedBox(width: _gap),
                            _cell(
                              index: row * 7 + col,
                              leading: leading,
                              today: today,
                              size: cell,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
        if (tally.frozen || tally.paused) ...[
          const SizedBox(height: 16),
          Wrap(
            spacing: 18,
            runSpacing: 8,
            children: [
              _Key(
                label: 'Kept',
                swatch: BoxDecoration(
                  color: TideColors.lantern,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              if (tally.frozen)
                _Key(
                  label: 'Frozen',
                  swatch: BoxDecoration(
                    color: TideColors.intensity(0.45, hue: TideColors.frost),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              if (tally.paused)
                _Key(
                  label: 'Paused',
                  swatch: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(
                      color: TideColors.bone.withValues(alpha: 0.22),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _cell({
    required int index,
    required int leading,
    required DateTime today,
    required double size,
  }) {
    final dayNumber = index - leading + 1;

    if (dayNumber < 1 || dayNumber > _daysInMonth) {
      return SizedBox(width: size, height: size);
    }

    final date = DateTime(month.year, month.month, dayNumber);
    final future = date.isAfter(today);
    final paused = habit.isPausedOn(date);
    final due =
        habit.isDueOn(date) &&
        !date.isBefore(DateUtils.dateOnly(habit.createdAt));

    final frozen = !future && due && habit.isFrozenOn(date);
    final level = future || !due
        ? 0.0
        : frozen
        ? 0.45
        : habit.progressOn(date);

    return _HeatCell(
      size: size,
      day: dayNumber,
      level: level,
      frozen: frozen,
      paused: paused && !future,
      rest: !due && !paused,
      // Staggering by day index is what makes the fill sweep across the
      // month instead of appearing all at once.
      delay: TideMotion.cellStep * index,
      future: future,
      isToday: date == today,
    );
  }
}

class _HeatCell extends StatelessWidget {
  const _HeatCell({
    required this.size,
    required this.day,
    required this.level,
    required this.delay,
    required this.future,
    required this.frozen,
    required this.paused,
    required this.rest,
    required this.isToday,
  });

  final double size;
  final int day;
  final double level;
  final Duration delay;
  final bool future;
  final bool frozen;
  final bool paused;

  /// Not a scheduled weekday for this habit.
  final bool rest;

  final bool isToday;

  @override
  Widget build(BuildContext context) {
    // An unlogged day is a faint ink wash, matching the calendar's empty
    // cell. Anything darker than the page reads as a hole.
    final empty = TideColors.bone.withValues(alpha: 0.05);
    final Color target = future || paused
        ? Colors.transparent
        : rest
        ? TideColors.bone.withValues(alpha: 0.025)
        : TideColors.intensity(
            level,
            hue: frozen ? TideColors.frost : TideColors.lantern,
          );

    // The number has to survive every fill: ink on a solid lantern day,
    // plain ink on a partial one, and receding on days that asked nothing.
    final Color ink = level >= 0.85 && !frozen
        ? TideColors.onLantern
        : future || rest || paused
        ? TideColors.silt.withValues(alpha: 0.55)
        : level > 0
        ? TideColors.bone
        : TideColors.silt;

    final Border? border = isToday
        ? Border.all(
            color: TideColors.lantern.withValues(alpha: 0.8),
            width: 1.5,
          )
        : paused
        ? Border.all(color: TideColors.bone.withValues(alpha: 0.16))
        : future
        ? Border.all(color: TideColors.bone.withValues(alpha: 0.05))
        : null;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: 1),
      duration: TideMotion.cellFill + delay,
      curve: Interval(
        // Converting the delay into a curve interval keeps every cell on
        // one animation clock rather than scheduling dozens of timers.
        (delay.inMilliseconds /
                (TideMotion.cellFill.inMilliseconds + delay.inMilliseconds))
            .clamp(0.0, 0.85),
        1,
        curve: Curves.easeOutCubic,
      ),
      builder: (context, t, _) {
        return Transform.scale(
          scale: 0.86 + 0.14 * t,
          child: Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Color.lerp(empty, target, t),
              borderRadius: BorderRadius.circular(size * 0.28),
              border: border,
            ),
            child: Text(
              '$day',
              style: TideType.gauge(
                (size * 0.3).clamp(10.0, 13.0),
                color: Color.lerp(TideColors.silt, ink, t),
                letterSpacing: -0.2,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({required this.label, required this.swatch});

  final String label;
  final BoxDecoration swatch;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: swatch),
        const SizedBox(width: 6),
        Text(label, style: TideType.labelMuted.copyWith(fontSize: 12)),
      ],
    );
  }
}
