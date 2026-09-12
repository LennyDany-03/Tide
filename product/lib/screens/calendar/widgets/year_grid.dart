import 'package:flutter/material.dart';

import '../../../config/app_constants.dart';
import '../../../services/models/habit.dart';
import '../../../services/streak_calculator.dart';
import '../../../theme/tide_colors.dart';
import '../../../theme/tide_typography.dart';

/// A year of days, one square each.
///
/// The month grid above answers "which days, this month". This answers the
/// question a month can never reach: what does a *year* of this look like.
/// It is the only view in the app where a run of two hundred days is one
/// shape rather than seven screens of paging, and seeing that shape is most
/// of the reason anybody keeps a habit log at all.
///
/// Painted rather than built. Fifty-three weeks is three hundred and
/// seventy-one cells, and three hundred and seventy-one widgets — each with
/// its own decoration, clip and layout — is a scroll that stutters on the
/// hardware this app is meant to run well on. One painter draws the lot in
/// a single pass.
///
/// Scrolls horizontally and opens at the right-hand edge, because the
/// interesting end of a year is the end you are standing on.
class YearGrid extends StatefulWidget {
  const YearGrid({
    super.key,
    required this.habits,
    required this.onDayTapped,
  });

  final List<Habit> habits;
  final ValueChanged<DateTime> onDayTapped;

  /// Fifty-three columns covers a year and the part-week either side of it.
  static const int columns = 53;
  static const int rows = 7;

  /// One cell, and the space between two.
  static const double cell = 12;
  static const double gap = 4;
  static const double step = cell + gap;

  static const double gridWidth = columns * step - gap;
  static const double gridHeight = rows * step - gap;

  /// Room above the grid for the month labels.
  static const double labelHeight = 20;

  @override
  State<YearGrid> createState() => _YearGridState();
}

class _YearGridState extends State<YearGrid>
    with SingleTickerProviderStateMixin {
  final ScrollController _scroll = ScrollController();

  /// The wipe that reveals the year, left to right, on arrival.
  late final AnimationController _reveal = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  /// One ratio per day, oldest first. -1 means nothing was scheduled.
  late List<double> _series;

  /// The Monday the first column starts on.
  late DateTime _start;

  @override
  void initState() {
    super.initState();
    _rebuildSeries();
    // Opens on the present. Jumping after layout rather than using a
    // reversed viewport: a reversed scroll also reverses how the child is
    // positioned, which would put January at the right-hand edge.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
      if (mounted) _reveal.forward();
    });
  }

  @override
  void didUpdateWidget(YearGrid old) {
    super.didUpdateWidget(old);
    // Logging a day changes exactly one cell, but the whole series is one
    // pass over four habits — cheaper than working out which cell moved.
    if (!identical(old.habits, widget.habits)) _rebuildSeries();
  }

  @override
  void dispose() {
    _scroll.dispose();
    _reveal.dispose();
    super.dispose();
  }

  void _rebuildSeries() {
    final today = DateUtils.dateOnly(DateTime.now());
    // The last column is the week today falls in, so the grid always ends
    // flush rather than trailing a ragged part-week.
    final thisMonday = today.subtract(Duration(days: today.weekday - 1));
    _start = thisMonday.subtract(
      const Duration(days: 7 * (YearGrid.columns - 1)),
    );

    final total = YearGrid.columns * YearGrid.rows;
    final elapsed = today.difference(_start).inDays + 1;
    final logged = StreakCalculator.dailySeries(
      widget.habits,
      days: elapsed,
      asOf: today,
    );

    // Everything past today is left blank rather than drawn as a miss.
    _series = List<double>.generate(
      total,
      (index) => index < logged.length ? logged[index] : double.nan,
    );
  }

  DateTime _dateAt(int index) => _start.add(Duration(days: index));

  /// How many days in the window were fully logged.
  int get _fullDays => _series.where((value) => value >= 1).length;

  void _handleTap(Offset local) {
    final column = (local.dx / YearGrid.step).floor();
    final row = (local.dy / YearGrid.step).floor();
    if (column < 0 ||
        column >= YearGrid.columns ||
        row < 0 ||
        row >= YearGrid.rows) {
      return;
    }

    final index = column * YearGrid.rows + row;
    if (index >= _series.length || _series[index].isNaN) return;
    widget.onDayTapped(_dateAt(index));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Fixed outside the scroll, so the weekday key stays put while
            // the year moves under it.
            Padding(
              padding: const EdgeInsets.only(top: YearGrid.labelHeight),
              child: SizedBox(
                width: 22,
                height: YearGrid.gridHeight,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var row = 0; row < YearGrid.rows; row++) ...[
                      if (row > 0) const SizedBox(height: YearGrid.gap),
                      SizedBox(
                        height: YearGrid.cell,
                        // Every other row. Seven labels in twelve pixels
                        // each is a wall of letters, not a key.
                        child: row.isEven
                            ? Text(
                                AppConstants.weekdayInitials[row],
                                style: TideType.labelMuted.copyWith(
                                  fontSize: 10,
                                  height: 1.2,
                                ),
                              )
                            : null,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                controller: _scroll,
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (details) => _handleTap(
                    details.localPosition.translate(
                      0,
                      -YearGrid.labelHeight,
                    ),
                  ),
                  child: RepaintBoundary(
                    child: AnimatedBuilder(
                      animation: _reveal,
                      builder: (context, _) => CustomPaint(
                        size: const Size(
                          YearGrid.gridWidth,
                          YearGrid.gridHeight + YearGrid.labelHeight,
                        ),
                        painter: _YearPainter(
                          series: _series,
                          start: _start,
                          reveal: _reveal.value,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Text(
                '$_fullDays full days in the last year',
                style: TideType.labelMuted,
              ),
            ),
            const _MiniLegend(),
          ],
        ),
      ],
    );
  }
}

/// The smaller key that belongs to the year grid, at its own cell size.
class _MiniLegend extends StatelessWidget {
  const _MiniLegend();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Less', style: TideType.labelMuted.copyWith(fontSize: 11)),
        const SizedBox(width: 6),
        for (final level in const [0.0, 0.34, 0.67, 1.0]) ...[
          if (level > 0) const SizedBox(width: 3),
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              color: TideColors.intensity(level),
              borderRadius: BorderRadius.circular(2.5),
            ),
          ),
        ],
        const SizedBox(width: 6),
        Text('More', style: TideType.labelMuted.copyWith(fontSize: 11)),
      ],
    );
  }
}

/// The cells, and the month names above them.
class _YearPainter extends CustomPainter {
  const _YearPainter({
    required this.series,
    required this.start,
    required this.reveal,
  });

  /// One ratio per cell, column-major. NaN is a day that has not happened;
  /// -1 is a day nothing was scheduled on.
  final List<double> series;

  final DateTime start;

  /// 0..1 of the left-to-right wipe.
  final double reveal;

  /// How much of the wipe any one column gets. Columns overlap heavily —
  /// a strict hand-off would take a second and a half to cross the year.
  static const double _columnShare = 0.45;

  static final Radius _radius = const Radius.circular(3);

  @override
  void paint(Canvas canvas, Size size) {
    _paintMonths(canvas);

    for (var column = 0; column < YearGrid.columns; column++) {
      final head = (column / YearGrid.columns) * (1 - _columnShare);
      final local = ((reveal - head) / _columnShare).clamp(0.0, 1.0);
      if (local <= 0) continue;
      final eased = Curves.easeOutCubic.transform(local);

      for (var row = 0; row < YearGrid.rows; row++) {
        final index = column * YearGrid.rows + row;
        if (index >= series.length) continue;
        final value = series[index];
        if (value.isNaN) continue;

        final rect = Rect.fromLTWH(
          column * YearGrid.step,
          YearGrid.labelHeight + row * YearGrid.step,
          YearGrid.cell,
          YearGrid.cell,
        );

        // A rest day is a faint ghost, not an empty square: the grid has to
        // say "nothing was asked of you here" differently from "you were
        // asked and did not".
        final colour = value < 0
            ? TideColors.bone.withValues(alpha: 0.035)
            : TideColors.intensity(value);

        canvas.drawRRect(
          RRect.fromRectAndRadius(
            // Cells arrive by growing into place from their own centre,
            // which is what stops the wipe reading as a bar sliding across.
            Rect.lerp(rect.deflate(YearGrid.cell / 2), rect, eased)!,
            _radius,
          ),
          Paint()..color = colour.withValues(alpha: colour.a * eased),
        );
      }
    }
  }

  /// A month name over the first column that starts inside it.
  void _paintMonths(Canvas canvas) {
    var lastMonth = -1;

    for (var column = 0; column < YearGrid.columns; column++) {
      final monday = start.add(Duration(days: column * YearGrid.rows));
      if (monday.month == lastMonth) continue;
      lastMonth = monday.month;

      // Only where the label has room to sit before the next one.
      if (column > YearGrid.columns - 4) continue;

      final painter = TextPainter(
        text: TextSpan(
          text: AppConstants.monthNames[monday.month - 1].substring(0, 3),
          style: TideType.labelMuted.copyWith(fontSize: 10, height: 1.2),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      painter.paint(
        canvas,
        Offset(column * YearGrid.step, 2),
      );
    }
  }

  @override
  bool shouldRepaint(_YearPainter old) =>
      old.reveal != reveal || old.series != series || old.start != start;
}
