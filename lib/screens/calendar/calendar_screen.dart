import 'package:flutter/material.dart';

import '../../services/models/habit.dart';
import '../../services/streak_calculator.dart';
import '../../services/tide_scope.dart';
import '../../theme/tide_motion.dart';
import '../../theme/tide_typography.dart';
import '../../widgets/tide_section.dart';
import '../../widgets/tide_tab_bar.dart';
import 'widgets/day_breakdown_sheet.dart';
import 'widgets/intensity_legend.dart';
import 'widgets/month_grid.dart';
import 'widgets/month_pager_header.dart';

/// History — every habit at once, month by month.
///
/// Where Habit detail answers "how is this one going", this answers "how
/// am I going", which is why its cells are aggregates rather than a single
/// habit's logs.
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  bool _forward = true;

  bool get _canGoNext {
    final now = DateTime.now();
    return _month.year < now.year ||
        (_month.year == now.year && _month.month < now.month);
  }

  void _page(int delta) {
    setState(() {
      _forward = delta > 0;
      _month = DateTime(_month.year, _month.month + delta);
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = TideScope.of(context);

    return ListView(
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.paddingOf(context).top + 28,
        20,
        TideTabBar.reservedHeight(context) + 28,
      ),
      children: [
        const Text('History', style: TideType.screenTitle),
        const SizedBox(height: 26),
        MonthPagerHeader(
          month: _month,
          forward: _forward,
          canGoNext: _canGoNext,
          onPrevious: () => _page(-1),
          onNext: () => _page(1),
        ),
        const SizedBox(height: 22),

        // Keying by month makes the whole grid a new widget each page, so
        // the cells replay their staggered fill instead of silently swapping
        // values in place.
        AnimatedSwitcher(
          duration: TideMotion.tabSwitch,
          switchInCurve: TideMotion.tabCurve,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: Offset(_forward ? 0.06 : -0.06, 0),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          ),
          child: MonthGrid(
            key: ValueKey('${_month.year}-${_month.month}'),
            month: _month,
            habits: store.allHabits,
            onDayTapped: (date) => showDayBreakdown(
              context,
              date: date,
              entries: store.breakdownFor(date),
            ),
          ),
        ),
        const SizedBox(height: 24),
        const IntensityLegend(),
        const SizedBox(height: 30),
        const TideRule(),
        const SizedBox(height: 22),
        _MonthSummary(month: _month, habits: store.allHabits),
      ],
    );
  }
}

/// What the month above actually came to.
///
/// The grid used to end halfway down the screen with nothing under it. A
/// month of cells answers "which days" precisely and "how did it go" not at
/// all, so this says the second thing in one line.
class _MonthSummary extends StatelessWidget {
  const _MonthSummary({required this.month, required this.habits});

  final DateTime month;
  final List<Habit> habits;

  @override
  Widget build(BuildContext context) {
    final today = DateUtils.dateOnly(DateTime.now());
    final days = DateUtils.getDaysInMonth(month.year, month.month);

    var elapsed = 0;
    var full = 0;
    var carried = 0.0;

    for (var day = 1; day <= days; day++) {
      final date = DateTime(month.year, month.month, day);
      if (date.isAfter(today)) break;
      elapsed++;
      final ratio = StreakCalculator.daySummary(habits, date).ratio;
      carried += ratio;
      if (ratio >= 1) full++;
    }

    if (elapsed == 0) {
      return Text('Nothing logged yet this month', style: TideType.bodyMuted);
    }

    final rate = (carried / elapsed * 100).round();

    return Row(
      children: [
        Expanded(
          child: TideFigure(value: '$full', caption: 'days fully logged'),
        ),
        Expanded(child: TideFigure(value: '$rate%', caption: 'of the month')),
      ],
    );
  }
}
