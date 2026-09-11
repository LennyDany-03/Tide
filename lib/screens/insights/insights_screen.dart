import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../config/app_constants.dart';
import '../../config/app_routes.dart';
import '../../services/models/tide_glyph.dart';
import '../../services/tide_scope.dart';
import '../../theme/tide_colors.dart';
import '../../theme/tide_motion.dart';
import '../../theme/tide_typography.dart';
import '../../widgets/gauge_number.dart';
import '../../widgets/habit_glyph.dart';
import '../../widgets/press_scale.dart';
import '../../widgets/stagger_list.dart';
import '../../widgets/tide_line_gauge.dart';
import '../../widgets/tide_surface.dart';
import '../../widgets/tide_tab_bar.dart';
import '../../widgets/trend_chart.dart';
import 'widgets/rate_hero.dart';
import 'widgets/week_strip.dart';

/// The weekly recap.
///
/// Sequenced rather than simultaneous: the arc sweeps and the headline rolls
/// up, the trend line draws, and only once the line lands do the rest of the
/// figures arrive. Everything at once reads as a dashboard; in order, it
/// reads as a report being delivered.
///
/// **What changed.** The screen was a title, one big percentage on open
/// ground, a bare wire of a line chart and then four hairline-separated stat
/// rows. Every fact on it was true and none of them was *presented* — a
/// figure with nothing around it is a figure you scroll past, and four rows
/// of "label left, value right" is a settings screen wearing a different
/// title. It also managed to report your best weekday over eight weeks
/// without ever telling you which days of *this* week you had logged, which
/// is the only part of it you can still do anything about.
///
/// Now: a hero panel where the rate is an arc you can read before the
/// digits, with this week's seven days under it; the eight-week series as a
/// filled area rather than a wire; the strongest and quietest days as a
/// matched pair of cards; and consistency as three figures in one block.
/// Sections are titled and spaced rather than ruled, and each one arrives
/// in turn.
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

  /// Monday of the week we are standing in.
  DateTime get _monday {
    final today = DateUtils.dateOnly(DateTime.now());
    return today.subtract(Duration(days: today.weekday - 1));
  }

  /// "8 – 14 September", or across a month boundary, both months.
  String get _range {
    final start = _monday;
    final end = start.add(const Duration(days: 6));
    final startMonth = AppConstants.monthNames[start.month - 1];
    final endMonth = AppConstants.monthNames[end.month - 1];
    return start.month == end.month
        ? '${start.day}–${end.day} $endMonth'
        : '${start.day} $startMonth – ${end.day} $endMonth';
  }

  @override
  Widget build(BuildContext context) {
    final store = TideScope.of(context);
    final rates = store.weekdayRates;
    final today = DateUtils.dateOnly(DateTime.now());

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

    // This week's seven days. -1 for the ones that have not happened, which
    // the strip draws as outlines rather than as misses.
    final week = [
      for (var i = 0; i < 7; i++)
        if (_monday.add(Duration(days: i)).isAfter(today))
          -1.0
        else
          store.summaryFor(_monday.add(Duration(days: i))).ratio,
    ];

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
        Text('Week $_weekNumber · $_range', style: TideType.labelMuted),
        const SizedBox(height: 26),

        TideSurface(
          color: TideColors.shelf,
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RateHero(
                rate: store.weeklyRate,
                previousRate: store.lastWeeklyRate,
              ),
              const SizedBox(height: 22),
              Container(height: 1, color: TideColors.hairline),
              const SizedBox(height: 18),
              WeekStrip(ratios: week, todayIndex: today.weekday - 1),
            ],
          ),
        ),
        const SizedBox(height: 30),

        const _SectionHead(
          title: 'Eight weeks',
          detail: 'Where this week sits against the two months behind it.',
        ),
        const SizedBox(height: 16),
        TideSurface(
          color: TideColors.shelf,
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
          child: Column(
            children: [
              TrendChart(
                values: store.weeklySeries(),
                height: 104,
                showPoints: true,
                fill: true,
                delay: const Duration(milliseconds: 420),
                onFinished: () {
                  if (mounted && !_chartDrawn) {
                    setState(() => _chartDrawn = true);
                  }
                },
              ),
              const SizedBox(height: 12),
              // A line with no ends is a shape, not a reading. Two words
              // fix it.
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Eight weeks ago', style: TideType.labelMuted),
                  Text(
                    'This week',
                    style: TideType.labelMuted.copyWith(
                      color: TideColors.lantern,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 30),

        // Held back until the line lands.
        AnimatedOpacity(
          opacity: _chartDrawn ? 1 : 0,
          duration: const Duration(milliseconds: 420),
          child: _chartDrawn
              ? StaggerColumn(
                  spacing: 30,
                  children: [
                    _WeekPattern(
                      rates: rates,
                      best: best,
                      worst: worst,
                      hasPattern: hasPattern,
                    ),
                    _Consistency(
                      freezesLeft: store.freezesRemaining,
                      freezesSpent: store.freezesSpent(),
                      cleanDays: store.cleanStreak,
                    ),
                    _MilestonesRow(
                      unlocked: store.unlockedMilestoneCount,
                      total: store.milestones.length,
                      onTap: () => context.push(Routes.milestones),
                    ),
                  ],
                )
              : const SizedBox(height: 400, width: double.infinity),
        ),
      ],
    );
  }
}

/// The strongest and quietest weekday, as a matched pair.
class _WeekPattern extends StatelessWidget {
  const _WeekPattern({
    required this.rates,
    required this.best,
    required this.worst,
    required this.hasPattern,
  });

  final List<double> rates;
  final int best;
  final int worst;
  final bool hasPattern;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHead(
          title: 'Your pattern',
          detail: 'Measured across the last eight weeks.',
        ),
        const SizedBox(height: 16),
        if (!hasPattern)
          TideSurface(
            color: TideColors.shelf,
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
            child: Text(
              'Mark a few days and the shape of your week shows up here.',
              style: TideType.bodyMuted,
            ),
          )
        else
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _DayCard(
                    caption: 'Strongest day',
                    day: AppConstants.weekdayNames[best],
                    rate: rates[best],
                    accent: true,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _DayCard(
                    caption: 'Quietest day',
                    day: AppConstants.weekdayNames[worst],
                    rate: rates[worst],
                    accent: false,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// One end of the week's range.
class _DayCard extends StatelessWidget {
  const _DayCard({
    required this.caption,
    required this.day,
    required this.rate,
    required this.accent,
  });

  final String caption;
  final String day;
  final double rate;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final tint = accent ? TideColors.lantern : TideColors.silt;

    return TideSurface(
      color: TideColors.shelf,
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(caption, style: TideType.labelMuted.copyWith(fontSize: 12)),
          const SizedBox(height: 10),
          Text(
            day,
            style: TideType.hero.copyWith(fontSize: 20, color: tint),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          // A short bar under each, so the two cards are comparable at a
          // glance rather than only through their two percentages.
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: SizedBox(
              height: 5,
              child: Stack(
                children: [
                  const Positioned.fill(
                    child: ColoredBox(color: TideColors.trench),
                  ),
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0, end: rate.clamp(0.0, 1.0)),
                    duration: TideMotion.chartDraw,
                    curve: TideMotion.tabCurve,
                    builder: (context, value, _) => FractionallySizedBox(
                      widthFactor: value,
                      child: ColoredBox(
                        color: accent
                            ? TideColors.lantern
                            : TideColors.bone.withValues(alpha: 0.28),
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${(rate * 100).round()}% marked',
            style: TideType.labelMuted.copyWith(fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/// What is holding the run together: freezes, and how clean it has been.
class _Consistency extends StatelessWidget {
  const _Consistency({
    required this.freezesLeft,
    required this.freezesSpent,
    required this.cleanDays,
  });

  final int freezesLeft;
  final int freezesSpent;
  final int cleanDays;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHead(
          title: 'Holding it together',
          detail: 'Freezes are the reason a missed day is not a reset.',
        ),
        const SizedBox(height: 16),
        TideSurface(
          color: TideColors.shelf,
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _Figure(
                  value: freezesLeft,
                  caption: 'freezes\nleft',
                  accent: true,
                ),
              ),
              const _Divider(),
              Expanded(
                child: _Figure(
                  value: freezesSpent,
                  caption: 'spent in\n30 days',
                ),
              ),
              const _Divider(),
              Expanded(
                child: _Figure(value: cleanDays, caption: 'days\nclean'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 42,
      margin: const EdgeInsets.symmetric(horizontal: 12),
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

  final int value;
  final String caption;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        GaugeCountUp(
          value: value,
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

/// The way through to the route, with the badges it is counting.
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
      child: TideSurface(
        color: TideColors.shelf,
        padding: const EdgeInsets.fromLTRB(18, 16, 14, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: TideColors.lantern.withValues(alpha: 0.12),
                  ),
                  child: const HabitGlyph(
                    glyph: TideGlyph.sparkle,
                    size: 17,
                    color: TideColors.lantern,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Milestones', style: TideType.heading),
                      const SizedBox(height: 4),
                      Text(
                        '$unlocked of $total surfaced',
                        style: TideType.labelMuted,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: TideColors.silt,
                ),
              ],
            ),
            const SizedBox(height: 16),
            // The route in miniature sits under the title, not beside it.
            // Fixed-width pips in the title row only fitted while the
            // catalogue was a handful long; at 28 they took every pixel the
            // text column had, and "Milestones" wrapped one letter per line.
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: _MilestoneTrack(unlocked: unlocked, total: total),
            ),
          ],
        ),
      ),
    );
  }
}

/// One segment per milestone, lit as far as you have got. Segments share
/// the card's width rather than claiming a fixed size, so the track fits
/// however long the catalogue grows.
class _MilestoneTrack extends StatelessWidget {
  const _MilestoneTrack({required this.unlocked, required this.total});

  final int unlocked;
  final int total;

  static const double _gap = 3;
  static const double _height = 4;

  @override
  Widget build(BuildContext context) {
    if (total <= 0) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final segment = (constraints.maxWidth - _gap * (total - 1)) / total;
        // Below a few pixels a segment is no longer a legible mark — only
        // the gaps read. One continuous level says the same thing cleanly.
        if (segment < 3) {
          return TideLineGauge(progress: unlocked / total, height: _height);
        }
        return Row(
          children: [
            for (var i = 0; i < total; i++) ...[
              if (i > 0) const SizedBox(width: _gap),
              Expanded(
                child: Container(
                  height: _height,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(_height / 2),
                    color: i < unlocked
                        ? TideColors.lantern
                        : TideColors.bone.withValues(alpha: 0.1),
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

/// A section's name and the one line explaining what it is showing.
class _SectionHead extends StatelessWidget {
  const _SectionHead({required this.title, required this.detail});

  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 3,
              height: 15,
              decoration: BoxDecoration(
                color: TideColors.lantern,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Text(title, style: TideType.hero.copyWith(fontSize: 19)),
          ],
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(left: 13),
          child: Text(detail, style: TideType.labelMuted),
        ),
      ],
    );
  }
}
