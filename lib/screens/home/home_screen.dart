import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../config/app_routes.dart';
import '../../services/models/habit.dart';
import '../../services/streak_calculator.dart';
import '../../services/tide_scope.dart';
import '../../theme/tide_typography.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/tide_button.dart';
import '../../widgets/tide_tab_bar.dart';
import 'widgets/day_complete_overlay.dart';
import 'widgets/habit_card.dart';
import 'widgets/habit_context_menu.dart';
import 'widgets/habit_log_sheet.dart';
import 'widgets/hero_stat_card.dart';
import 'widgets/home_header.dart';
import 'widgets/reordering_habit_list.dart';
import 'widgets/wave_refresh_indicator.dart';

/// Today — the screen the app opens into and the one that gets used daily.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _dayCompleteTick = 0;
  bool _wasDayComplete = false;

  /// The seven days behind a habit card's strip, oldest first.
  List<DateTime> _week() {
    final today = DateTime.now();
    return [for (var i = 0; i < 7; i++) today.subtract(Duration(days: 6 - i))];
  }

  /// Seven completion levels for the strip on a habit card, oldest first.
  List<double> _weekLevels(Habit habit) {
    return [
      for (final day in _week())
        if (!habit.isScheduledOn(day))
          0.0
        else if (habit.isFrozenOn(day))
          0.5
        else
          habit.progressOn(day),
    ];
  }

  /// Which of those seven were frozen. Kept alongside the levels rather
  /// than folded into them: a frozen day and a half-logged day both sit at
  /// 0.5, and they should not come out the same colour.
  List<bool> _weekFrozen(Habit habit) =>
      [for (final day in _week()) habit.isFrozenOn(day)];

  void _log(Habit habit, num amount) {
    final store = TideScope.read(context);
    store.log(habit.id, amount: amount);
    _checkDayComplete();
  }

  void _freeze(Habit habit) {
    final store = TideScope.read(context);
    final spent = store.freeze(habit.id);
    if (!spent && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No freezes left on ${habit.name}.',
            style: TideType.label,
          ),
        ),
      );
      return;
    }
    _checkDayComplete();
  }

  /// Fires the day-complete moment once, on the transition into a finished
  /// day — never on a rebuild that happens to find the day already done.
  void _checkDayComplete() {
    final summary = TideScope.read(context).today;
    final complete = summary.isFullyLogged;
    if (complete && !_wasDayComplete) {
      setState(() => _dayCompleteTick++);
    }
    _wasDayComplete = complete;
  }

  /// Counted habits log from their own sheet, one unit at a time.
  ///
  /// Routed through [_log] rather than writing to the store from inside the
  /// sheet, so the last unit of the last habit still lands the day-complete
  /// moment out here.
  void _openLogSheet(Habit habit) {
    showHabitLogSheet(
      context,
      habitId: habit.id,
      onLog: (amount) => _log(habit, amount),
    );
  }

  void _openMenu(Habit habit) {
    final store = TideScope.read(context);
    showHabitContextMenu(
      context,
      habit: habit,
      streak: StreakCalculator.currentStreak(habit),
      onDetails: () => context.push(Routes.habit(habit.id)),
      onEdit: () => context.push(Routes.editHabit(habit.id)),
      onPause: () => store.togglePause(habit.id),
      onDelete: () => store.deleteHabit(habit.id),
    );
  }

  Future<void> _refresh() async {
    final store = TideScope.read(context);
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (mounted) store.sync();
  }

  @override
  Widget build(BuildContext context) {
    final store = TideScope.of(context);
    final habits = store.habits;
    final summary = store.today;
    _wasDayComplete = summary.isFullyLogged;

    return Stack(
      children: [
        WaveRefreshIndicator(
          onRefresh: _refresh,
          child: CustomScrollView(
            physics: tidePullPhysics,
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  MediaQuery.paddingOf(context).top + 28,
                  20,
                  0,
                ),
                sliver: SliverToBoxAdapter(
                  child: HomeHeader(
                    date: DateTime.now(),
                    onMilestones: () => context.push(Routes.milestones),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 12)),
              SliverToBoxAdapter(
                child: HeroStatCard(
                    completed: summary.completed,
                    scheduled: summary.scheduled,
                    weeklyRate: store.weeklyRate,
                    bestStreak: store.bestActiveStreak,
                  dayComplete: summary.isFullyLogged,
                ),
              ),
              if (habits.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: TideEmptyState(
                    title: 'No habits yet',
                    body:
                        'Pick something small and daily. The rhythm matters '
                        'more than the size.',
                    action: TideButton(
                      label: 'Add your first habit',
                      expand: false,
                      onPressed: () => context.push(Routes.newHabit),
                    ),
                  ),
                )
              else ...[
                // No section header above the list. "HABITS ———— 4" was
                // labelling the only list on the screen, ruling it off and
                // then counting it — three pieces of chrome to introduce
                // four cards that introduce themselves.
                const SliverToBoxAdapter(child: SizedBox(height: 28)),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverToBoxAdapter(
                    child: ReorderingHabitList(
                      itemHeight: HabitCard.height,
                      spacing: HabitCard.gap,
                      itemKeys: [for (final habit in habits) habit.id],
                      itemBuilder: (context, id) {
                        final habit = store.habitById(id);
                        if (habit == null) return const SizedBox.shrink();
                        return HabitCard(
                          habit: habit,
                          streak: StreakCalculator.currentStreak(habit),
                          weekLevels: _weekLevels(habit),
                          frozenDays: _weekFrozen(habit),
                          onOpen: () => context.push(Routes.habit(habit.id)),
                          onMenu: () => _openMenu(habit),
                          onLog: (amount) => _log(habit, amount),
                          onCount: () => _openLogSheet(habit),
                          onFreeze: () => _freeze(habit),
                        );
                      },
                    ),
                  ),
                ),
              ],
              // Clears the FAB and the floating tab bar it sits above.
              SliverToBoxAdapter(
                child: SizedBox(
                  height: TideTabBar.reservedHeight(context) + 40,
                ),
              ),
            ],
          ),
        ),
        Positioned.fill(child: DayCompleteOverlay(trigger: _dayCompleteTick)),
      ],
    );
  }
}
