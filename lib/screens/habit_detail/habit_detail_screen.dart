import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../config/app_routes.dart';
import '../../services/streak_calculator.dart';
import '../../services/tide_scope.dart';
import '../../theme/tide_colors.dart';
import '../../theme/tide_motion.dart';
import '../../theme/tide_typography.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/gauge_number.dart';
import '../../widgets/tide_section.dart';
import '../../widgets/tide_tab_bar.dart';
import '../../widgets/trend_chart.dart';
import 'widgets/detail_actions.dart';
import 'widgets/detail_header.dart';
import 'widgets/month_heatmap.dart';

/// Everything about one habit: its history, its numbers, and the controls
/// for changing or ending it.
///
/// Built from the same sections as Insights rather than from its own stack of
/// panels. It used to open with three equal stat chips side by side — current
/// streak, best streak, 30-day rate — which gave the screen no answer to
/// "how is this going", only three numbers of identical weight. The current
/// streak is the answer, so it is the headline, and the other two are the
/// footnotes they always were.
class HabitDetailScreen extends StatefulWidget {
  const HabitDetailScreen({super.key, required this.habitId});

  final String habitId;

  @override
  State<HabitDetailScreen> createState() => _HabitDetailScreenState();
}

class _HabitDetailScreenState extends State<HabitDetailScreen>
    with SingleTickerProviderStateMixin {
  /// Drives the "drain" — pausing a habit desaturates it over 400ms rather
  /// than flipping to a grey state, so the habit reads as going quiet
  /// instead of being switched off.
  late final AnimationController _drain = AnimationController(
    vsync: this,
    duration: TideMotion.drain,
  );

  @override
  void initState() {
    super.initState();
    final habit = TideScope.read(context).habitById(widget.habitId);
    if (habit?.paused ?? false) _drain.value = 1;
  }

  @override
  void dispose() {
    _drain.dispose();
    super.dispose();
  }

  void _togglePause() {
    final store = TideScope.read(context);
    final habit = store.habitById(widget.habitId);
    if (habit == null) return;

    store.togglePause(habit.id);
    habit.paused ? _drain.reverse() : _drain.forward();
  }

  void _delete() {
    TideScope.read(context).deleteHabit(widget.habitId);
    if (mounted) context.go(Routes.today);
  }

  @override
  Widget build(BuildContext context) {
    final store = TideScope.of(context);
    final habit = store.habitById(widget.habitId);

    if (habit == null) {
      return Center(
        child: TideEmptyNote(message: 'This habit is no longer here.'),
      );
    }

    final current = StreakCalculator.currentStreak(habit);
    final best = StreakCalculator.bestStreak(habit);
    final rate = StreakCalculator.completionRate(habit);

    return AnimatedBuilder(
      animation: _drain,
      builder: (context, child) {
        // Desaturating the whole screen at once is what makes "drain" read
        // as one action rather than several widgets changing colour.
        return Opacity(
          opacity: 1 - 0.25 * _drain.value,
          child: ColorFiltered(
            colorFilter: ColorFilter.mode(
              TideColors.silt.withValues(alpha: 0.3 * _drain.value),
              BlendMode.saturation,
            ),
            child: child,
          ),
        );
      },
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          20,
          MediaQuery.paddingOf(context).top + 20,
          20,
          TideTabBar.reservedHeight(context) + 28,
        ),
        children: [
          DetailHeader(
            habit: habit,
            onBack: () => context.pop(),
            drain: _drain.value,
          ),
          const SizedBox(height: 34),

          // The headline: how long this has been running.
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              GaugeNumber(value: current, style: TideType.gaugeHero()),
              const SizedBox(width: 10),
              Text(
                current == 1 ? 'day' : 'days',
                style: TideType.gauge(18, color: TideColors.silt),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            current == 0 ? 'no streak running' : 'running streak',
            style: TideType.labelMuted,
          ),
          const SizedBox(height: 30),

          const TideRule(),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: TideFigure(value: '$best', caption: 'best streak'),
              ),
              Expanded(
                child: TideFigure(
                  value: '${(rate * 100).round()}%',
                  caption: 'last 30 days',
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),

          const TideRule(),
          const SizedBox(height: 26),
          MonthHeatmap(habit: habit, month: DateTime.now()),
          const SizedBox(height: 30),

          const TideRule(),
          const SizedBox(height: 26),
          const TideSectionTitle('Completion trend'),
          const SizedBox(height: 22),
          TrendChart(
            values: StreakCalculator.habitTrend(habit),
            delay: const Duration(milliseconds: 260),
          ),
          const SizedBox(height: 12),
          Text(
            'Rolling two-week rate, eight weeks',
            style: TideType.labelMuted,
          ),
          const SizedBox(height: 30),

          const TideRule(),
          const SizedBox(height: 12),
          DetailActions(
            paused: habit.paused,
            onEdit: () => context.push(Routes.editHabit(habit.id)),
            onPause: _togglePause,
            onDelete: _delete,
          ),
        ],
      ),
    );
  }
}
