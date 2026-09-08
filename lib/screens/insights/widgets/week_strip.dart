import 'package:flutter/material.dart';

import '../../../config/app_constants.dart';
import '../../../theme/tide_colors.dart';
import '../../../theme/tide_motion.dart';
import '../../../theme/tide_typography.dart';

/// The seven days of the week you are actually in.
///
/// Insights could tell you what your best weekday is over two months and
/// what your rate was eight weeks ago, and could not tell you which days of
/// *this* week you had logged — the one thing you can still do something
/// about. Seven pips fix that, and they cost a row.
///
/// Each pip fills to the day's completion the way a calendar cell does, on
/// the same [TideColors.intensity] ramp, so a half-done Wednesday reads
/// identically here and in History. Days still to come are left as bare
/// outlines: an empty circle for Saturday on a Wednesday is not a miss.
class WeekStrip extends StatefulWidget {
  const WeekStrip({
    super.key,
    required this.ratios,
    required this.todayIndex,
  });

  /// Seven values, Monday first. Negative means the day has not happened.
  final List<double> ratios;

  /// 0..6, or -1 if the strip is not showing the current week.
  final int todayIndex;

  @override
  State<WeekStrip> createState() => _WeekStripState();
}

class _WeekStripState extends State<WeekStrip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fill = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 760),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fill.forward();
    });
  }

  @override
  void dispose() {
    _fill.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _fill,
      builder: (context, _) {
        return Row(
          children: [
            for (var day = 0; day < 7; day++) ...[
              if (day > 0) const SizedBox(width: 8),
              Expanded(
                child: _Pip(
                  label: AppConstants.weekdayInitials[day],
                  ratio: widget.ratios[day],
                  isToday: day == widget.todayIndex,
                  // Filled left to right, the way the week runs.
                  progress: Curves.easeOutCubic.transform(
                    ((_fill.value - day * 0.07) / 0.55).clamp(0.0, 1.0),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _Pip extends StatelessWidget {
  const _Pip({
    required this.label,
    required this.ratio,
    required this.isToday,
    required this.progress,
  });

  final String label;

  /// Negative for a day that has not happened yet.
  final double ratio;

  final bool isToday;
  final double progress;

  static const double _size = 26;

  @override
  Widget build(BuildContext context) {
    final ahead = ratio < 0;
    final level = ahead ? 0.0 : ratio * progress;

    return Column(
      children: [
        // Capped, not stretched to the column. Seven circles sized by a
        // full-width card come out at ninety pixels each and stop being
        // pips — they read as the subject of the panel rather than as a
        // footnote under the figure that is.
        SizedBox(
          width: _size,
          height: _size,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: ahead
                  ? Colors.transparent
                  : TideColors.intensity(level).withValues(
                      alpha: TideColors.intensity(level).a * progress,
                    ),
              border: Border.all(
                color: isToday
                    ? TideColors.lantern.withValues(alpha: 0.9)
                    : ahead
                    ? TideColors.hairline
                    : Colors.transparent,
                width: isToday ? 1.6 : 1,
              ),
            ),
            child: const SizedBox.expand(),
          ),
        ),
        const SizedBox(height: 8),
        AnimatedDefaultTextStyle(
          duration: TideMotion.tabSwitch,
          style: TideType.gauge(
            11,
            color: isToday ? TideColors.lantern : TideColors.silt,
          ),
          child: Text(label),
        ),
      ],
    );
  }
}
