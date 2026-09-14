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
import 'widgets/detail_hero.dart';
import 'widgets/month_heatmap.dart';

/// Everything about one habit: its history, its numbers, and the controls
/// for changing or ending it.
///
/// Read top to bottom as an argument. The name is the title. One card
/// answers "how is this going" — the streak, qualified by best, 30-day rate
/// and days kept. Then the evidence, flat on the page: the month as a real
/// calendar, and the trend with its own current figure. Then the controls,
/// each saying what it will do.
class HabitDetailScreen extends StatefulWidget {
  const HabitDetailScreen({super.key, required this.habitId});

  final String habitId;

  @override
  State<HabitDetailScreen> createState() => _HabitDetailScreenState();
}

class _HabitDetailScreenState extends State<HabitDetailScreen>
    with SingleTickerProviderStateMixin {
  /// Drives the "drain" — pausing a habit desaturates its history over 400ms
  /// rather than flipping to a grey state, so the habit reads as going quiet
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

    if (habit.paused) {
      store.resume(habit.id);
      _drain.reverse();
    } else {
      store.pause(habit.id);
      _drain.forward();
    }
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
    final trend = StreakCalculator.habitTrend(habit);

    return ListView(
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.paddingOf(context).top + 16,
        20,
        TideTabBar.reservedHeight(context) + 28,
      ),
      children: [
        AnimatedBuilder(
          animation: _drain,
          builder: (context, _) => DetailHeader(
            habit: habit,
            onBack: () => context.pop(),
            onEdit: () => context.push(Routes.editHabit(habit.id)),
            drain: _drain.value,
          ),
        ),
        const SizedBox(height: 24),
        DetailHero(
          habit: habit,
          current: current,
          best: StreakCalculator.bestStreak(habit),
          rate: StreakCalculator.completionRate(habit),
          kept: StreakCalculator.keptDays(habit),
          onResume: _togglePause,
        ),
        const SizedBox(height: 36),

        // The evidence drains with a pause; the card above and the controls
        // below stay at full strength, because the Resume they carry has to
        // read as the live thing on the screen.
        AnimatedBuilder(
          animation: _drain,
          builder: (context, child) => Opacity(
            opacity: 1 - 0.3 * _drain.value,
            child: ColorFiltered(
              colorFilter: _desaturate(0.75 * _drain.value),
              child: child,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MonthHeatmap(habit: habit, month: DateTime.now()),
              const SizedBox(height: 34),
              const TideRule(),
              const SizedBox(height: 26),
              _TrendHead(latest: trend.isEmpty ? 0 : trend.last),
              const SizedBox(height: 18),
              TrendChart(
                values: trend,
                height: 112,
                fill: true,
                delay: const Duration(milliseconds: 260),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Text(
                    '8 weeks ago',
                    style: TideType.labelMuted.copyWith(fontSize: 12),
                  ),
                  const Spacer(),
                  Text(
                    'This week',
                    style: TideType.labelMuted.copyWith(fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 36),
        DetailActions(
          paused: habit.paused,
          onEdit: () => context.push(Routes.editHabit(habit.id)),
          onPause: _togglePause,
          onDelete: _delete,
        ),
      ],
    );
  }
}

/// Takes [amount] of the colour out of whatever is under it, leaving alpha
/// alone.
///
/// A matrix rather than `ColorFilter.mode(…, BlendMode.saturation)`: the
/// blend mode paints its colour into transparent pixels too, so the drained
/// section came out as a grey slab the size of its bounds on the page.
ColorFilter _desaturate(double amount) {
  final s = 1 - amount.clamp(0.0, 1.0);
  const r = 0.2126, g = 0.7152, b = 0.0722;
  return ColorFilter.matrix(<double>[
    r + (1 - r) * s, g - g * s, b - b * s, 0, 0, //
    r - r * s, g + (1 - g) * s, b - b * s, 0, 0, //
    r - r * s, g - g * s, b + (1 - b) * s, 0, 0, //
    0, 0, 0, 1, 0, //
  ]);
}

/// The trend's name, what it measures, and where it stands now.
class _TrendHead extends StatelessWidget {
  const _TrendHead({required this.latest});

  final double latest;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Completion trend',
                style: TideType.hero.copyWith(fontSize: 19),
              ),
              const SizedBox(height: 4),
              Text('Two-week rolling rate', style: TideType.labelMuted),
            ],
          ),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            GaugeNumber(
              value: (latest * 100).round(),
              style: TideType.gauge(26, letterSpacing: -1),
            ),
            Text('%', style: TideType.gauge(14, color: TideColors.silt)),
          ],
        ),
      ],
    );
  }
}
