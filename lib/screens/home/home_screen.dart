import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../config/app_routes.dart';
import '../../config/tour_catalog.dart';
import '../../services/models/habit.dart';
import '../../services/streak_calculator.dart';
import '../../services/tide_scope.dart';
import '../../theme/tide_colors.dart';
import '../../theme/tide_typography.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/gauge_number.dart';
import '../../widgets/tide_button.dart';
import '../../widgets/tide_tab_bar.dart';
import '../../widgets/tour/tour_anchor.dart';
import 'widgets/add_habit_tile.dart';
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
  }

  void _unfreeze(Habit habit) {
    TideScope.read(context).unfreeze(habit.id);
  }

  /// Clears today's log, from a swipe back across a finished card.
  void _undo(Habit habit) {
    TideScope.read(context).unlog(habit.id);
  }

  /// Fires the day-complete moment once, on the transition into a finished
  /// day — never on a rebuild that happens to find the day already done.
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
      onComplete: habit.type == HabitType.binary
          ? () => _log(habit, habit.target)
          : null,
      onLogProgress: habit.type == HabitType.binary
          ? null
          : () => _openLogSheet(habit),
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
                  MediaQuery.paddingOf(context).top + 24,
                  20,
                  0,
                ),
                // Anchored for the guided tour. The header carries two of
                // its five stops — the title block and the add control —
                // and the inner one is marked inside HomeHeader itself, so
                // the light lands on the button rather than on the row it
                // happens to sit in.
                sliver: SliverToBoxAdapter(
                  child: TourAnchor(
                    stop: TourStop.header,
                    child: HomeHeader(
                      date: DateTime.now(),
                      milestonesUnlocked: store.unlockedMilestoneCount,
                      onMilestones: () => context.push(Routes.milestones),
                    ),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 22)),
              SliverToBoxAdapter(
                child: TourAnchor(
                  stop: TourStop.hero,
                  child: HeroStatCard(
                    completed: summary.completed,
                    scheduled: summary.scheduled,
                    weeklyRate: store.weeklyRate,
                    weeklySeries: store.weeklySeries(),
                    bestStreak: store.bestActiveStreak,
                    dayComplete: summary.isFullyLogged,
                    onStreakTap: () => context.push(Routes.milestones),
                  ),
                ),
              ),
              if (habits.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: TourAnchor(
                    stop: TourStop.list,
                    child: TideEmptyState(
                      title: 'No habits yet',
                      body:
                          'Pick something small and daily. The rhythm '
                          'matters more than the size.',
                      // The tour's last stop. On an empty Today this is the
                      // only add control there is, so the light has to land
                      // here rather than on the tile below the list.
                      action: TourAnchor(
                        stop: TourStop.add,
                        child: TideButton(
                          label: 'Add your first habit',
                          expand: false,
                          onPressed: () => context.push(Routes.newHabit),
                        ),
                      ),
                    ),
                  ),
                )
              else ...[
                // A title over the list again, but not the one that was
                // taken out. "HABITS ———— 4" was tracked capitals, a rule and
                // a count: three pieces of chrome. What replaces it is the
                // Insights section head — a lantern tick and a sentence-case
                // name — because the list now sits under a grid of tiles,
                // and without a name the first card reads as a fourth tile
                // that fell out of the grid.
                const SliverToBoxAdapter(child: SizedBox(height: 30)),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                  sliver: SliverToBoxAdapter(
                    child: _ListHead(active: habits.length),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverToBoxAdapter(
                    child: TourAnchor(
                      stop: TourStop.list,
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
                            onMenu: () => _openMenu(habit),
                            onCount: () => _openLogSheet(habit),
                            onComplete: () => _log(habit, habit.target),
                            onFreeze: () => _freeze(habit),
                            onUnfreeze: () => _unfreeze(habit),
                            onUndo: () => _undo(habit),
                          );
                        },
                      ),
                    ),
                  ),
                ),
                // One slot below the last habit, where the next one would
                // go. This is the tour's add stop on a Today that already
                // has something on it.
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, HabitCard.gap, 20, 0),
                  sliver: SliverToBoxAdapter(
                    child: TourAnchor(
                      stop: TourStop.add,
                      child: AddHabitTile(
                        atLimit: !store.canAddHabit,
                        used: store.isPro ? null : store.activeHabitCount,
                        onTap: () => context.push(
                          store.canAddHabit ? Routes.newHabit : Routes.upgrade,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
              // Clears the floating tab bar the list sits under.
              SliverToBoxAdapter(
                child: SizedBox(
                  height: TideTabBar.reservedHeight(context) + 40,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The list's name, and how many habits are in it.
///
/// Built like the Insights section head — a short lantern tick and a
/// sentence-case title — so the two screens introduce a block the same
/// way. It counts the list rather than repeating the day's status, which
/// the tile directly above already says.
class _ListHead extends StatelessWidget {
  const _ListHead({required this.active});

  final int active;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
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
        Text('Habits', style: TideType.hero.copyWith(fontSize: 19)),
        const Spacer(),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            GaugeNumber(
              value: active,
              style: TideType.gauge(14, color: TideColors.silt),
            ),
            Text(' active', style: TideType.labelMuted),
          ],
        ),
      ],
    );
  }
}
