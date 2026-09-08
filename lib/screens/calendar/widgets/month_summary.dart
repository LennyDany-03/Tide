import 'package:flutter/material.dart';

import '../../../config/app_constants.dart';
import '../../../services/models/habit.dart';
import '../../../services/streak_calculator.dart';
import '../../../theme/tide_colors.dart';
import '../../../theme/tide_motion.dart';
import '../../../theme/tide_typography.dart';
import '../../../widgets/tide_surface.dart';

/// What the month above actually came to.
///
/// The grid used to end halfway down the screen with two bare figures under
/// it. A month of cells answers "which days" precisely and "how did it go"
/// not at all — and two numbers on open ground answer it so quietly that
/// nobody reads them.
///
/// Three figures on a raised surface, over a bar that draws itself to the
/// month's rate. The bar is the part that earns its place: a percentage is
/// a number you have to think about, and a line filling three-quarters of
/// the way across is not.
class MonthSummary extends StatefulWidget {
  const MonthSummary({super.key, required this.month, required this.habits});

  final DateTime month;
  final List<Habit> habits;

  @override
  State<MonthSummary> createState() => _MonthSummaryState();
}

class _MonthSummaryState extends State<MonthSummary> {
  @override
  Widget build(BuildContext context) {
    final shape = StreakCalculator.monthShape(widget.habits, widget.month);
    final monthName = AppConstants.monthNames[widget.month.month - 1];

    if (shape.elapsed == 0) {
      return TideSurface(
        color: TideColors.shelf,
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
        child: Text(
          'Nothing logged yet in $monthName.',
          style: TideType.bodyMuted,
        ),
      );
    }

    final rate = shape.carried / shape.elapsed;

    return TideSurface(
      color: TideColors.shelf,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _Figure(
                  value: '${shape.full}',
                  caption: 'days fully\nlogged',
                  accent: true,
                ),
              ),
              _Divider(),
              Expanded(
                child: _Figure(
                  value: '${(rate * 100).round()}%',
                  caption: 'of the\nmonth',
                ),
              ),
              _Divider(),
              Expanded(
                child: _Figure(
                  value: '${shape.longest}',
                  caption: 'longest\nrun',
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _RateBar(rate: rate),
          const SizedBox(height: 10),
          Text(
            shape.longest >= 7
                ? 'A full week or more without a gap in $monthName.'
                : '${shape.elapsed} days of $monthName so far.',
            style: TideType.labelMuted,
          ),
        ],
      ),
    );
  }
}

/// The month's rate, as a length rather than a number.
class _RateBar extends StatelessWidget {
  const _RateBar({required this.rate});

  final double rate;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        height: 6,
        child: Stack(
          children: [
            const Positioned.fill(
              child: ColoredBox(color: TideColors.trench),
            ),
            // Draws itself on arrival and re-draws when the month is paged,
            // because the value it is reporting genuinely changed.
            TweenAnimationBuilder<double>(
              tween: Tween<double>(end: rate.clamp(0.0, 1.0)),
              duration: TideMotion.chartDraw,
              curve: TideMotion.tabCurve,
              builder: (context, value, _) => FractionallySizedBox(
                widthFactor: value,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        TideColors.lantern.withValues(alpha: 0.55),
                        TideColors.lantern,
                      ],
                    ),
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A hairline between two figures, inset so it does not reach the panel's
/// own padding.
class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 40,
      margin: const EdgeInsets.symmetric(horizontal: 14),
      color: TideColors.hairline,
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({
    required this.value,
    required this.caption,
    this.accent = false,
  });

  final String value;
  final String caption;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TideType.gaugeStat(
            color: accent ? TideColors.lantern : TideColors.bone,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          caption,
          style: TideType.labelMuted.copyWith(fontSize: 12, height: 1.3),
        ),
      ],
    );
  }
}
