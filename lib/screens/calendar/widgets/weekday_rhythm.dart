import 'package:flutter/material.dart';

import '../../../config/app_constants.dart';
import '../../../theme/tide_colors.dart';
import '../../../theme/tide_motion.dart';
import '../../../theme/tide_typography.dart';

/// Which days of the week actually hold.
///
/// A calendar shows you *when*; this shows you the pattern underneath it.
/// It is the one fact on the History screen that changes behaviour rather
/// than reporting it — knowing Thursday is where the run breaks is the
/// difference between "I keep slipping" and "I keep slipping on Thursdays",
/// and only one of those is a thing you can do something about.
///
/// The bars grow up from the floor on arrival: an entrance, not an idle.
///
/// They are drawn against the *best* day rather than against 100%, and the
/// rate is printed over each one. Scaled absolutely, a week that runs
/// between 72% and 90% — which is what a week anybody is still using this
/// app looks like — comes out as seven bars of visually identical height,
/// and a chart where every column is the same is a chart that has told you
/// nothing. Relative height makes the comparison legible; the figure above
/// each bar keeps it honest about what the height is not saying.
class WeekdayRhythm extends StatefulWidget {
  const WeekdayRhythm({super.key, required this.rates});

  /// Seven completion rates, Monday first.
  final List<double> rates;

  @override
  State<WeekdayRhythm> createState() => _WeekdayRhythmState();
}

class _WeekdayRhythmState extends State<WeekdayRhythm>
    with SingleTickerProviderStateMixin {
  late final AnimationController _grow = AnimationController(
    vsync: this,
    duration: TideMotion.chartDraw,
  );

  static const double _height = 132;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _grow.forward();
    });
  }

  @override
  void dispose() {
    _grow.dispose();
    super.dispose();
  }

  /// The best day, or null when there is nothing to compare yet.
  int? get _strongest {
    var best = -1;
    var bestValue = 0.0;
    for (var i = 0; i < widget.rates.length; i++) {
      if (widget.rates[i] > bestValue) {
        bestValue = widget.rates[i];
        best = i;
      }
    }
    return best < 0 ? null : best;
  }

  /// And the one that gives way first. Only named when it is meaningfully
  /// behind the best — calling a day "weakest" when every day is level is
  /// inventing a problem.
  int? get _weakest {
    if (widget.rates.every((rate) => rate == 0)) return null;
    var worst = -1;
    var worstValue = 2.0;
    for (var i = 0; i < widget.rates.length; i++) {
      if (widget.rates[i] < worstValue) {
        worstValue = widget.rates[i];
        worst = i;
      }
    }
    final best = _strongest;
    if (best == null || worst < 0) return null;
    return widget.rates[best] - worstValue < 0.15 ? null : worst;
  }

  String get _caption {
    final best = _strongest;
    if (best == null) return 'Not enough logged yet to see a pattern.';

    final bestName = AppConstants.weekdayNames[best];
    final weak = _weakest;
    if (weak == null) return '$bestName is your steadiest day.';
    return '$bestName holds best. '
        '${AppConstants.weekdayNames[weak]} is where it gives.';
  }

  /// The best rate on the row, and the floor a bar is measured against.
  double get _peak {
    var peak = 0.0;
    for (final rate in widget.rates) {
      if (rate > peak) peak = rate;
    }
    return peak;
  }

  @override
  Widget build(BuildContext context) {
    final strongest = _strongest;
    final peak = _peak;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: _height,
          child: AnimatedBuilder(
            animation: _grow,
            builder: (context, _) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var day = 0; day < 7; day++) ...[
                    if (day > 0) const SizedBox(width: 8),
                    Expanded(
                      child: _Bar(
                        label: AppConstants.weekdayInitials[day],
                        rate: widget.rates[day],
                        peak: peak,
                        // Staggered across the week, so the row reads left
                        // to right the way the week does.
                        progress: Curves.easeOutCubic.transform(
                          ((_grow.value - day * 0.06) / 0.6).clamp(0.0, 1.0),
                        ),
                        best: day == strongest,
                        maxHeight: _height - 52,
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 14),
        Text(_caption, style: TideType.bodyMuted),
      ],
    );
  }
}

/// One weekday: the column, its percentage, and its initial.
class _Bar extends StatelessWidget {
  const _Bar({
    required this.label,
    required this.rate,
    required this.peak,
    required this.progress,
    required this.best,
    required this.maxHeight,
  });

  final String label;
  final double rate;

  /// The best rate across the week, which the column is drawn against.
  final double peak;

  final double progress;
  final bool best;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    // Against the best day, with a floor. A day at a fifth of your best
    // drawn strictly to scale is a sliver, which reads as missing data
    // rather than as a bad day.
    final relative = peak <= 0 ? 0.0 : (rate / peak).clamp(0.0, 1.0);
    final fraction = 0.14 + 0.86 * relative;

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        SizedBox(
          height: 16,
          child: Text(
            rate <= 0 ? '—' : '${(rate * 100).round()}',
            style: TideType.gauge(
              11,
              color: best ? TideColors.lantern : TideColors.silt,
            ),
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: maxHeight,
          // Narrower than the column it sits in. A bar as wide as its slot
          // reads as a block of colour; a bar with air either side reads as
          // a measurement.
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: 26,
              height: (maxHeight * fraction * progress).clamp(2.0, maxHeight),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(7),
                // Only the best day takes the accent. Seven warm columns is
                // a bar chart with no subject.
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: best
                      ? [
                          TideColors.lantern.withValues(alpha: 0.55),
                          TideColors.lantern,
                        ]
                      : [
                          TideColors.bone.withValues(alpha: 0.07),
                          TideColors.bone.withValues(alpha: 0.16),
                        ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TideType.gauge(
            12,
            color: best ? TideColors.lantern : TideColors.silt,
          ),
        ),
      ],
    );
  }
}
