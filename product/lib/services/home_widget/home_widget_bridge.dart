import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import '../models/habit.dart';
import 'widget_payload.dart';

/// Pushes a signed-in account's habits to both Android home-screen widgets.
///
/// Takes plain data rather than [TideStore] itself, so it never needs to
/// import the store back (and stays trivially fakeable in a test). Debounced
/// the same way the habit cache write is (`SupabaseHabitRepository.remember`):
/// a burst of logs coalesces into one native update instead of one per tap.
/// Never throws — a widget write failing must not be able to take the rest
/// of the app down with it.
class HomeWidgetBridge {
  static const _keyToday = 'today_habits';
  static const _keyDashboard = 'habit_dashboard';
  static const _todayProvider = 'TodayHabitsWidgetProvider';
  static const _dashboardProvider = 'HabitDashboardWidgetProvider';
  static const _delay = Duration(milliseconds: 600);

  Timer? _timer;
  ({bool signedIn, List<Habit> habits, bool isPro})? _pending;

  void scheduleSync({
    required bool signedIn,
    required List<Habit> habits,
    required bool isPro,
  }) {
    _pending = (signedIn: signedIn, habits: habits, isPro: isPro);
    _timer ??= Timer(_delay, () {
      _timer = null;
      final next = _pending;
      if (next != null) unawaited(_write(next));
    });
  }

  Future<void> _write(({bool signedIn, List<Habit> habits, bool isPro}) state) async {
    try {
      final today = state.signedIn
          ? WidgetPayload.todayHabits(state.habits)
          : WidgetPayload.signedOut();
      final dashboard = state.signedIn
          ? WidgetPayload.habitDashboard(state.habits, isPro: state.isPro)
          : WidgetPayload.signedOut();

      await HomeWidget.saveWidgetData<String>(_keyToday, jsonEncode(today));
      await HomeWidget.saveWidgetData<String>(
        _keyDashboard,
        jsonEncode(dashboard),
      );
      await HomeWidget.updateWidget(androidName: _todayProvider);
      await HomeWidget.updateWidget(androidName: _dashboardProvider);
    } catch (error) {
      debugPrint('Widget sync failed: $error');
    }
  }

  void dispose() {
    _timer?.cancel();
  }
}
