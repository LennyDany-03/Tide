import 'package:flutter/material.dart';

import '../../config/app_constants.dart';
import '../../config/pro_features.dart';
import '../../services/models/habit.dart';
import '../../services/tide_scope.dart';
import '../../theme/tide_colors.dart';
import '../../theme/tide_elevation.dart';
import '../../theme/tide_motion.dart';
import '../../theme/tide_typography.dart';
import '../../widgets/press_scale.dart';
import '../../widgets/pro_lock.dart';
import '../../widgets/tide_section.dart';
import '../../widgets/tide_tab_bar.dart';
import 'widgets/day_breakdown_sheet.dart';
import 'widgets/intensity_legend.dart';
import 'widgets/month_grid.dart';
import 'widgets/month_pager_header.dart';
import 'widgets/month_summary.dart';
import 'widgets/weekday_rhythm.dart';
import 'widgets/year_grid.dart';

/// History — every habit at once, month by month, then year and week.
///
/// Where Habit detail answers "how is this one going", this answers "how
/// am I going", which is why its cells are aggregates rather than a single
/// habit's logs.
///
/// It used to stop dead under the month grid: two bare figures on open
/// ground and then two hundred pixels of nothing. A month is the wrong and
/// only scale to read a habit at — thirty cells is too few to show a
/// pattern and too many to show a day — so the screen now steps out to a
/// year and back in to a week, and each of the three answers a question the
/// others cannot.
///
/// **Month** — which days. **Year** — what the shape of this looks like at
/// a distance, which is the view that makes a long run feel like something.
/// **Week** — where it actually breaks, which is the only one of the three
/// you can act on.
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

  /// The earliest month this plan may open, or null on Pro.
  DateTime? _floor(BuildContext context) {
    final horizon = TideScope.read(context).historyHorizon;
    return horizon == null ? null : DateTime(horizon.year, horizon.month);
  }

  bool _canGoPrevious(BuildContext context) {
    final floor = _floor(context);
    return floor == null || _month.isAfter(floor);
  }

  void _page(int delta) {
    // Going back past the window is a request for Pro, not a no-op. The
    // history is all there and all still syncing — the free plan has a
    // window onto it, and the arrow is where that window ends.
    if (delta < 0 && !_canGoPrevious(context)) {
      askForPro(context, ProFeature.fullHistory);
      return;
    }
    setState(() {
      _forward = delta > 0;
      _month = DateTime(_month.year, _month.month + delta);
    });
  }

  void _openDay(DateTime date) {
    final store = TideScope.read(context);
    // A day outside the window opens the paywall instead of the breakdown.
    // The cell is drawn and pressable on purpose — a grid that simply
    // swallowed the tap would read as broken rather than as a boundary.
    if (!store.canSee(date)) {
      askForPro(context, ProFeature.fullHistory);
      return;
    }
    showDayBreakdown(
      context,
      date: date,
      entries: store.breakdownFor(date),
    );
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
        Text('History', style: TideType.screenTitle),
        const SizedBox(height: 6),
        Text(
          'Everything you have marked, at three distances.',
          style: TideType.labelMuted,
        ),
        const SizedBox(height: 26),

        MonthPagerHeader(
          month: _month,
          forward: _forward,
          canGoNext: _canGoNext,
          canGoPrevious: _canGoPrevious(context),
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
            horizon: store.historyHorizon,
            onDayTapped: _openDay,
          ),
        ),
        const SizedBox(height: 20),
        const IntensityLegend(),
        const SizedBox(height: 26),

        MonthSummary(month: _month, habits: store.allHabits),
        const SizedBox(height: 34),

        _SectionHead(
          title: 'The last year',
          detail: store.locked(ProFeature.fullHistory)
              ? 'Every day, one square — the whole year comes with Pro.'
              : 'Every day, one square. Tap one to open it.',
        ),
        const SizedBox(height: 18),
        // The year is the clearest thing Pro buys, so the free plan is shown
        // it rather than told about it: the grid is drawn, and the months
        // outside the window are drawn empty behind a mark. A section that
        // simply disappeared would make the free app look complete and the
        // paywall look like it invented a feature.
        if (store.locked(ProFeature.fullHistory))
          _LockedYear(habits: store.allHabits, onDayTapped: _openDay)
        else
          YearGrid(habits: store.allHabits, onDayTapped: _openDay),
        const SizedBox(height: 34),

        const _SectionHead(
          title: 'Your rhythm',
          detail: 'How each weekday has held over the last eight weeks.',
        ),
        const SizedBox(height: 18),
        WeekdayRhythm(rates: store.weekdayRates),
      ],
    );
  }
}

/// A section's name and the one line explaining what it is showing.
///
/// The rule sits above the title rather than under it: a line under a
/// heading underlines the heading, where a line above it closes the section
/// before — which is the job that actually needed doing on a screen this
/// long.
class _SectionHead extends StatelessWidget {
  const _SectionHead({required this.title, required this.detail});

  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const TideRule(),
        const SizedBox(height: 22),
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

/// The year grid with only the free window filled in.
///
/// Drawn from the habits the free plan may see rather than from a blurred
/// screenshot: the squares inside the window are real and tappable, and the
/// months before it are the empty grid they would be on a new account. The
/// row underneath says what opens them.
class _LockedYear extends StatelessWidget {
  const _LockedYear({required this.habits, required this.onDayTapped});

  final List<Habit> habits;
  final ValueChanged<DateTime> onDayTapped;

  @override
  Widget build(BuildContext context) {
    final store = TideScope.of(context);
    final horizon = store.historyHorizon;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The grid keeps its full year of columns so the shape of the screen
        // does not change when somebody upgrades — only the squares fill in.
        Opacity(
          opacity: 0.55,
          child: IgnorePointer(
            child: YearGrid(
              habits: [
                for (final habit in habits)
                  habit.copyWith(
                    logs: {
                      for (final day in habit.logs.keys)
                        if (horizon == null || !day.isBefore(horizon))
                          day: habit.logs[day]!,
                    },
                    frozenDays: {
                      for (final day in habit.frozenDays)
                        if (horizon == null || !day.isBefore(horizon)) day,
                    },
                  ),
              ],
              onDayTapped: onDayTapped,
            ),
          ),
        ),
        const SizedBox(height: 16),
        PressScale(
          onTap: () => askForPro(context, ProFeature.fullHistory),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
            decoration: BoxDecoration(
              color: TideColors.lantern.withValues(alpha: 0.08),
              borderRadius: TideElevation.radius12,
              border: Border.all(
                color: TideColors.lantern.withValues(alpha: 0.28),
              ),
            ),
            child: Row(
              children: [
                const ProBadge(compact: true),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'The last ${AppConstants.freeHistoryDays} days are open. '
                    'Pro opens every month you have logged.',
                    style: TideType.label.copyWith(
                      color: TideColors.lantern,
                      height: 1.35,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: TideColors.lantern,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
