import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../config/app_constants.dart';
import '../../config/app_routes.dart';
import '../../services/tide_scope.dart';
import '../../theme/tide_colors.dart';
import '../../theme/tide_typography.dart';
import '../../widgets/gauge_number.dart';
import '../../widgets/press_scale.dart';
import '../../widgets/stagger_list.dart';
import '../../widgets/tide_section.dart';
import '../../widgets/tide_tab_bar.dart';
import '../../widgets/trend_chart.dart';

/// The weekly recap.
///
/// Sequenced rather than simultaneous: the headline rolls up, the trend line
/// draws, and only once the line lands do the rest of the figures arrive.
/// Everything at once reads as a dashboard; in order, it reads as a report
/// being delivered.
///
/// Nothing here is in a card. The screen was five stacked rounded panels of
/// identical radius and fill, one per fact, which is the house style of every
/// analytics page ever shipped and says nothing about this product. Sections
/// separated by space and a hairline hold the same structure, and let the
/// figures themselves be the thing you notice.
class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  bool _chartDrawn = false;

  int get _weekNumber {
    final now = DateTime.now();
    final firstDay = DateTime(now.year);
    return ((now.difference(firstDay).inDays + firstDay.weekday) / 7).ceil();
  }

  @override
  Widget build(BuildContext context) {
    final store = TideScope.of(context);
    final rates = store.weekdayRates;

    var best = 0;
    var worst = 0;
    for (var i = 1; i < rates.length; i++) {
      if (rates[i] > rates[best]) best = i;
      if (rates[i] < rates[worst]) worst = i;
    }

    // With no history, argmax and argmin both land on Monday and the screen
    // confidently reports Monday as the strongest day and Monday as the
    // quietest, each at 0%. A week with nothing in it has no strongest day,
    // so say that instead of naming one.
    final hasPattern = rates[best] > rates[worst];

    return ListView(
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.paddingOf(context).top + 28,
        20,
        TideTabBar.reservedHeight(context) + 28,
      ),
      children: [
        const Text('Insights', style: TideType.screenTitle),
        const SizedBox(height: 6),
        Text('Week $_weekNumber', style: TideType.labelMuted),
        const SizedBox(height: 40),

        _Headline(rate: store.weeklyRate, previousRate: store.lastWeeklyRate),
        const SizedBox(height: 40),

        const TideRule(),
        const SizedBox(height: 26),

        const TideSectionTitle('Eight weeks'),
        const SizedBox(height: 24),
        TrendChart(
          values: store.weeklySeries(),
          height: 96,
          showPoints: true,
          delay: const Duration(milliseconds: 340),
          onFinished: () {
            if (mounted && !_chartDrawn) setState(() => _chartDrawn = true);
          },
        ),
        const SizedBox(height: 10),
        // A line with no ends is a shape, not a reading. Two words fix it.
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Eight weeks ago', style: TideType.labelMuted),
            Text('This week', style: TideType.labelMuted),
          ],
        ),
        const SizedBox(height: 32),

        // Held back until the line lands.
        AnimatedOpacity(
          opacity: _chartDrawn ? 1 : 0,
          duration: const Duration(milliseconds: 420),
          child: _chartDrawn
              ? StaggerColumn(
                  spacing: 0,
                  children: [
                    const TideRule(),
                    const SizedBox(height: 26),
                    if (hasPattern) ...[
                      TideStatLine(
                        label: 'Strongest day',
                        value: AppConstants.weekdayNames[best],
                        detail: '${(rates[best] * 100).round()}% logged',
                        accent: true,
                      ),
                      const SizedBox(height: 20),
                      TideStatLine(
                        label: 'Quietest day',
                        value: AppConstants.weekdayNames[worst],
                        detail: '${(rates[worst] * 100).round()}% logged',
                      ),
                    ] else ...[
                      const TideSectionTitle('Your week'),
                      const SizedBox(height: 6),
                      Text(
                        'Log a few days and the pattern across the week '
                        'shows up here.',
                        style: TideType.bodyMuted,
                      ),
                    ],
                    const SizedBox(height: 30),

                    const TideRule(),
                    const SizedBox(height: 26),
                    TideStatLine(
                      label: 'Streak freezes',
                      value: '${store.freezesRemaining} left',
                      detail: store.freezesSpent() == 0
                          ? 'None spent in the last 30 days'
                          : '${store.freezesSpent()} spent in the last 30 days',
                      accent: true,
                    ),
                    const SizedBox(height: 30),

                    const TideRule(),
                    _MilestonesRow(
                      unlocked: store.unlockedMilestoneCount,
                      total: store.milestones.length,
                      onTap: () => context.push(Routes.milestones),
                    ),
                  ],
                )
              : const SizedBox(height: 300, width: double.infinity),
        ),
      ],
    );
  }
}

/// This week's completion, rolling up from zero — the reveal the screen is
/// built around.
class _Headline extends StatelessWidget {
  const _Headline({required this.rate, required this.previousRate});

  final double rate;
  final double previousRate;

  int get _delta => ((rate - previousRate) * 100).round();

  /// Written as a sentence. It used to be joined with a middle dot —
  /// "completed this week · up 7 points on last" — which is a formatting
  /// habit, not a way anyone says anything.
  String get _comparison {
    if (previousRate == 0) return 'completed this week';
    if (_delta == 0) return 'completed this week, level with last';
    final direction = _delta > 0 ? 'up' : 'down';
    final points = _delta.abs() == 1 ? 'point' : 'points';
    return 'completed this week, $direction ${_delta.abs()} $points on last';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GaugeCountUp(
          value: (rate * 100).round(),
          style: TideType.gaugeHero(),
          suffix: '%',
          suffixStyle: TideType.gauge(20, color: TideColors.silt),
        ),
        const SizedBox(height: 10),
        Text(_comparison, style: TideType.labelMuted),
      ],
    );
  }
}

class _MilestonesRow extends StatelessWidget {
  const _MilestonesRow({
    required this.unlocked,
    required this.total,
    required this.onTap,
  });

  final int unlocked;
  final int total;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 22),
        child: Row(
          children: [
            Expanded(child: Text('Milestones', style: TideType.heading)),
            Text('$unlocked of $total', style: TideType.labelMuted),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: TideColors.silt,
            ),
          ],
        ),
      ),
    );
  }
}
