import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import '../models/habit.dart';
import '../tasks/task.dart';
import 'widget_payload.dart';

/// The two widgets that are each tied to one habit, chosen per placed widget.
enum HabitWidgetKind {
  streak('SingleHabitStreakWidgetProvider'),
  heatmap('HabitHeatmapWidgetProvider');

  const HabitWidgetKind(this.provider);

  /// The Kotlin `AppWidgetProvider` class name, as the launcher reports it.
  final String provider;

  static HabitWidgetKind? byName(String? name) {
    for (final kind in values) {
      if (kind.name == name) return kind;
    }
    return null;
  }
}

/// The verb in a widget tap URI.
///
/// Native writes `tide://widget/setup?id=…` — Dart's [Uri.host] is then
/// `widget`, not `setup`. The action is the first path segment. `tide://setup`
/// (host only) is accepted too, so an older link still routes.
abstract final class WidgetLaunch {
  static String? action(Uri uri) {
    if (uri.host == 'widget') {
      return uri.pathSegments.isEmpty ? null : uri.pathSegments.first;
    }
    return uri.host.isEmpty ? null : uri.host;
  }
}

/// Pushes a signed-in account's habits and tasks to the Android home-screen
/// widgets.
///
/// Takes plain data rather than [TideStore]/[TaskStore], so it never imports
/// either back. Habits and tasks debounce on separate timers — a burst of
/// habit logs and a burst of task edits each coalesce into one native update
/// instead of resetting each other's. Never throws: a widget write failing
/// must not take the app down with it.
class HomeWidgetBridge {
  static const _keyToday = 'today_habits';
  static const _keyDashboard = 'habit_dashboard';
  static const _keyRecap = 'weekly_recap';
  static const _keyTasks = 'today_tasks';

  /// Read directly by the native providers, so a widget placed a moment ago
  /// — before this bridge has heard of it — can already draw its lock or its
  /// signed-out state instead of a setup prompt it could not honour.
  static const _keySignedIn = 'tide_signed_in';

  static String _streakKey(int id) => 'single_habit_streak_$id';
  static String _heatmapKey(int id) => 'habit_heatmap_$id';

  static const _todayProvider = 'TodayHabitsWidgetProvider';
  static const _dashboardProvider = 'HabitDashboardWidgetProvider';
  static const _recapProvider = 'WeeklyRecapWidgetProvider';
  static const _tasksProvider = 'TodayTasksWidgetProvider';

  static const _delay = Duration(milliseconds: 600);

  Timer? _habitsTimer;
  _HabitState? _pendingHabits;

  Timer? _tasksTimer;
  ({bool signedIn, List<Task> tasks})? _pendingTasks;

  void scheduleHabitSync({
    required bool signedIn,
    required List<Habit> habits,
    required Map<int, String> widgetHabits,
  }) {
    _pendingHabits = _HabitState(signedIn, habits, widgetHabits);
    _habitsTimer ??= Timer(_delay, () {
      _habitsTimer = null;
      final next = _pendingHabits;
      _pendingHabits = null;
      if (next != null) unawaited(_writeHabits(next));
    });
  }

  /// The same write, now, and awaited — for the habit picker, which sends
  /// the app to the background the moment it returns and wants the widget
  /// already redrawn when the home screen comes back.
  Future<void> syncHabitsNow({
    required bool signedIn,
    required List<Habit> habits,
    required Map<int, String> widgetHabits,
  }) {
    _habitsTimer?.cancel();
    _habitsTimer = null;
    _pendingHabits = null;
    return _writeHabits(_HabitState(signedIn, habits, widgetHabits));
  }

  void scheduleTaskSync({required bool signedIn, required List<Task> tasks}) {
    _pendingTasks = (signedIn: signedIn, tasks: tasks);
    _tasksTimer ??= Timer(_delay, () {
      _tasksTimer = null;
      final next = _pendingTasks;
      _pendingTasks = null;
      if (next != null) unawaited(_writeTasks(next));
    });
  }

  Future<void> _writeHabits(_HabitState state) async {
    try {
      final installed = await _installed();
      await HomeWidget.saveWidgetData<bool>(_keySignedIn, state.signedIn);

      final out = jsonEncode(WidgetPayload.signedOut());
      await HomeWidget.saveWidgetData<String>(
        _keyToday,
        state.signedIn ? jsonEncode(WidgetPayload.todayHabits(state.habits)) : out,
      );
      await HomeWidget.saveWidgetData<String>(
        _keyDashboard,
        state.signedIn
            ? jsonEncode(WidgetPayload.habitDashboard(state.habits))
            : out,
      );
      await HomeWidget.saveWidgetData<String>(
        _keyRecap,
        state.signedIn
            ? jsonEncode(WidgetPayload.weeklyRecap(state.habits))
            : out,
      );

      for (final id in installed[HabitWidgetKind.streak.provider] ?? const <int>[]) {
        final habit = state.signedIn ? state.habitFor(id) : null;
        await HomeWidget.saveWidgetData<String>(
          _streakKey(id),
          jsonEncode(WidgetPayload.singleHabitStreak(habit)),
        );
      }

      for (final id in installed[HabitWidgetKind.heatmap.provider] ?? const <int>[]) {
        final habit = state.signedIn ? state.habitFor(id) : null;
        // The grid is drawn natively from the series inside this payload,
        // at the widget's own size — no off-screen render to wait on.
        await HomeWidget.saveWidgetData<String>(
          _heatmapKey(id),
          jsonEncode(WidgetPayload.heatmapHeader(habit)),
        );
      }

      for (final provider in [
        _todayProvider,
        _dashboardProvider,
        _recapProvider,
        HabitWidgetKind.streak.provider,
        HabitWidgetKind.heatmap.provider,
      ]) {
        await HomeWidget.updateWidget(androidName: provider);
      }
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

  /// Placed widget ids by provider class, oldest first. The launcher reports
  /// the class as `.SomethingProvider`; only the part after the last dot is
  /// kept.
  static Future<Map<String, List<int>>> _installed() async {
    final byProvider = <String, List<int>>{};
    for (final info in await HomeWidget.getInstalledWidgets()) {
      final id = info.androidWidgetId;
      final name = info.androidClassName;
      if (id == null || name == null) continue;
      (byProvider[name.substring(name.lastIndexOf('.') + 1)] ??= []).add(id);
    }
    for (final ids in byProvider.values) {
      ids.sort();
    }
    return byProvider;
  }

  void dispose() {
    _habitsTimer?.cancel();
    _tasksTimer?.cancel();
  }
}

class _HabitState {
  _HabitState(this.signedIn, this.habits, this.widgetHabits);

  final bool signedIn;
  final List<Habit> habits;
  final Map<int, String> widgetHabits;

  Habit? habitFor(int widgetId) {
    final habitId = widgetHabits[widgetId];
    if (habitId == null) return null;
    for (final habit in habits) {
      if (habit.id == habitId) return habit;
    }
    return null;
  }
}
