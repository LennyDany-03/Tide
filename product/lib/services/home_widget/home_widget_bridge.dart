import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import '../models/habit.dart';
import '../tasks/task.dart';
import 'heatmap_export.dart';
import 'widget_payload.dart';

/// Pushes a signed-in account's habits and tasks to the Android home-screen
/// widgets.
///
/// Takes plain data rather than [TideStore]/[TaskStore] themselves, so it
/// never needs to import either back (and stays trivially fakeable in a
/// test). Habits and tasks are debounced on separate timers — the same
/// shape as [SupabaseHabitRepository.remember]'s debounced write — so a
/// burst of habit logs and a burst of task edits each coalesce into one
/// native update apiece instead of stepping on each other's timer. Never
/// throws — a widget write failing must not be able to take the rest of the
/// app down with it.
class HomeWidgetBridge {
  static const _keyToday = 'today_habits';
  static const _keyDashboard = 'habit_dashboard';
  static const _keyStreak = 'single_habit_streak';
  static const _keyHeatmapMeta = 'habit_heatmap_meta';
  static const _keyHeatmapImage = 'habit_heatmap_image';
  static const _keyRecap = 'weekly_recap';
  static const _keyTasks = 'today_tasks';

  static const _todayProvider = 'TodayHabitsWidgetProvider';
  static const _dashboardProvider = 'HabitDashboardWidgetProvider';
  static const _streakProvider = 'SingleHabitStreakWidgetProvider';
  static const _heatmapProvider = 'HabitHeatmapWidgetProvider';
  static const _recapProvider = 'WeeklyRecapWidgetProvider';
  static const _tasksProvider = 'TodayTasksWidgetProvider';

  static const _delay = Duration(milliseconds: 600);

  Timer? _habitsTimer;
  ({bool signedIn, List<Habit> habits, bool isPro, String? pinnedHabitId})?
  _pendingHabits;

  Timer? _tasksTimer;
  ({bool signedIn, List<Task> tasks})? _pendingTasks;

  void scheduleHabitSync({
    required bool signedIn,
    required List<Habit> habits,
    required bool isPro,
    String? pinnedHabitId,
  }) {
    _pendingHabits = (
      signedIn: signedIn,
      habits: habits,
      isPro: isPro,
      pinnedHabitId: pinnedHabitId,
    );
    _habitsTimer ??= Timer(_delay, () {
      _habitsTimer = null;
      final next = _pendingHabits;
      if (next != null) unawaited(_writeHabits(next));
    });
  }

  void scheduleTaskSync({required bool signedIn, required List<Task> tasks}) {
    _pendingTasks = (signedIn: signedIn, tasks: tasks);
    _tasksTimer ??= Timer(_delay, () {
      _tasksTimer = null;
      final next = _pendingTasks;
      if (next != null) unawaited(_writeTasks(next));
    });
  }

  Future<void> _writeHabits(
    ({bool signedIn, List<Habit> habits, bool isPro, String? pinnedHabitId})
    state,
  ) async {
    try {
      if (!state.signedIn) {
        final out = jsonEncode(WidgetPayload.signedOut());
        await HomeWidget.saveWidgetData<String>(_keyToday, out);
        await HomeWidget.saveWidgetData<String>(_keyDashboard, out);
        await HomeWidget.saveWidgetData<String>(_keyStreak, out);
        await HomeWidget.saveWidgetData<String>(_keyHeatmapMeta, out);
        await HomeWidget.saveWidgetData<String>(_keyRecap, out);
      } else {
        final pinned = _find(state.habits, state.pinnedHabitId);
        await HomeWidget.saveWidgetData<String>(
          _keyToday,
          jsonEncode(WidgetPayload.todayHabits(state.habits)),
        );
        await HomeWidget.saveWidgetData<String>(
          _keyDashboard,
          jsonEncode(
            WidgetPayload.habitDashboard(state.habits, isPro: state.isPro),
          ),
        );
        await HomeWidget.saveWidgetData<String>(
          _keyStreak,
          jsonEncode(WidgetPayload.singleHabitStreak(pinned)),
        );
        await HomeWidget.saveWidgetData<String>(
          _keyHeatmapMeta,
          jsonEncode(
            WidgetPayload.heatmapMeta(
              isPro: state.isPro,
              configured: pinned != null,
            ),
          ),
        );
        if (state.isPro && pinned != null) {
          final series = WidgetPayload.heatmapSeries(pinned);
          await HomeWidget.renderFlutterWidget(
            HeatmapExport(series: series),
            key: _keyHeatmapImage,
            logicalSize: HeatmapExport.sizeFor(series.length),
          );
        }
        await HomeWidget.saveWidgetData<String>(
          _keyRecap,
          jsonEncode(
            WidgetPayload.weeklyRecap(state.habits, isPro: state.isPro),
          ),
        );
      }
      await HomeWidget.updateWidget(androidName: _todayProvider);
      await HomeWidget.updateWidget(androidName: _dashboardProvider);
      await HomeWidget.updateWidget(androidName: _streakProvider);
      await HomeWidget.updateWidget(androidName: _heatmapProvider);
      await HomeWidget.updateWidget(androidName: _recapProvider);
    } catch (error) {
      debugPrint('Habit widget sync failed: $error');
    }
  }

  Future<void> _writeTasks(({bool signedIn, List<Task> tasks}) state) async {
    try {
      final payload = state.signedIn
          ? WidgetPayload.todayTasks(state.tasks)
          : WidgetPayload.signedOut();
      await HomeWidget.saveWidgetData<String>(_keyTasks, jsonEncode(payload));
      await HomeWidget.updateWidget(androidName: _tasksProvider);
    } catch (error) {
      debugPrint('Task widget sync failed: $error');
    }
  }

  Habit? _find(List<Habit> habits, String? id) {
    if (id == null) return null;
    for (final habit in habits) {
      if (habit.id == id) return habit;
    }
    return null;
  }

  void dispose() {
    _habitsTimer?.cancel();
    _tasksTimer?.cancel();
  }
}
