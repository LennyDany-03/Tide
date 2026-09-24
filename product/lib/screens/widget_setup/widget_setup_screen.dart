import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../config/app_routes.dart';
import '../../services/app_window.dart';
import '../../services/home_widget/home_widget_bridge.dart';
import '../../services/models/habit.dart';
import '../../services/streak_calculator.dart';
import '../../services/tide_scope.dart';
import '../../theme/tide_colors.dart';
import '../../theme/tide_typography.dart';
import '../../widgets/habit_glyph.dart';
import '../../widgets/press_scale.dart';
import '../../widgets/tide_backdrop.dart';
import '../../widgets/tide_button.dart';
import '../../widgets/tide_flame.dart';
import '../../widgets/tide_surface.dart';

/// "Which habit is this widget for?" — opened by tapping a Streak or Heatmap
/// widget that has no habit yet.
///
/// The whole errand happens from the home screen, so it ends there too:
/// choosing a habit redraws that one widget and sends Tide to the
/// background, and so does backing out. Nothing here navigates further into
/// the app unless there is nothing to choose from.
class WidgetSetupScreen extends StatefulWidget {
  const WidgetSetupScreen({
    super.key,
    required this.widgetId,
    required this.kind,
  });

  final int widgetId;
  final HabitWidgetKind kind;

  @override
  State<WidgetSetupScreen> createState() => _WidgetSetupScreenState();
}

class _WidgetSetupScreenState extends State<WidgetSetupScreen> {
  String? _saving;

  String get _widgetName =>
      widget.kind == HabitWidgetKind.heatmap ? 'Heatmap' : 'Streak';

  Future<void> _choose(Habit habit) async {
    if (_saving != null) return;
    setState(() => _saving = habit.id);
    await TideScope.read(context).assignWidgetHabit(widget.widgetId, habit.id);
    if (!mounted) return;
    _leave();
  }

  /// Back to the home screen: pop this page (so the next open of Tide is
  /// Today, not a stale picker), then hand the window back to the launcher.
  void _leave() {
    if (context.canPop()) context.pop();
    unawaited(AppWindow.moveToBack());
  }

  @override
  Widget build(BuildContext context) {
    final store = TideScope.of(context);
    final habits = [...store.habits, ...store.pausedHabits];
    final current = store.widgetHabitId(widget.widgetId);
    final top = MediaQuery.viewPaddingOf(context).top;
    final bottom = MediaQuery.paddingOf(context).bottom;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        backgroundColor: TideColors.deepWater,
        body: Stack(
          children: [
            const Positioned.fill(child: TideBackdrop()),
            ListView(
              padding: EdgeInsets.fromLTRB(20, top + 16, 20, bottom + 40),
              children: [
                Row(
                  children: [
                    PressScale(
                      onTap: _leave,
                      child: SizedBox(
                        width: 38,
                        height: 38,
                        child: Icon(
                          Icons.close_rounded,
                          size: 22,
                          color: TideColors.bone,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text('Choose a habit', style: TideType.screenTitle),
                const SizedBox(height: 6),
                Text(
                  'For this $_widgetName widget. You can add another widget '
                  'for a different habit.',
                  style: TideType.labelMuted,
                ),
                const SizedBox(height: 24),
                if (habits.isEmpty)
                  _NoHabits(
                    onAdd: () {
                      context.go(Routes.today);
                      unawaited(context.push(Routes.newHabit));
                    },
                  )
                else
                  for (final habit in habits) ...[
                    _HabitChoice(
                      habit: habit,
                      selected: habit.id == current,
                      saving: _saving == habit.id,
                      enabled: _saving == null,
                      onTap: () => _choose(habit),
                    ),
                    const SizedBox(height: 10),
                  ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HabitChoice extends StatelessWidget {
  const _HabitChoice({
    required this.habit,
    required this.selected,
    required this.saving,
    required this.enabled,
    required this.onTap,
  });

  final Habit habit;
  final bool selected;
  final bool saving;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final streak = StreakCalculator.currentStreak(habit);
    return PressScale(
      enabled: enabled,
      onTap: onTap,
      child: TideSurface(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: selected
            ? Border.all(color: TideColors.lantern.withValues(alpha: 0.6))
            : null,
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: TideColors.shoal,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: HabitGlyph(
                  glyph: habit.glyph,
                  size: 18,
                  color: TideColors.lantern,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    habit.name,
                    style: TideType.body,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    habit.paused
                        ? 'Paused'
                        : streak == 0
                        ? 'No streak yet'
                        : '$streak-day streak',
                    style: TideType.labelMuted,
                  ),
                ],
              ),
            ),
            if (saving)
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: TideColors.lantern,
                ),
              )
            else if (selected)
              Icon(Icons.check_rounded, color: TideColors.lantern, size: 22)
            else if (streak > 0)
              SizedBox(
                width: 22,
                height: 26,
                child: TideFlame(intensity: (streak / 30).clamp(0.3, 1.0)),
              ),
          ],
        ),
      ),
    );
  }
}

class _NoHabits extends StatelessWidget {
  const _NoHabits({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return TideSurface(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('No habits yet', style: TideType.heading),
          const SizedBox(height: 6),
          Text(
            'Add one, then tap the widget again to show it here.',
            style: TideType.bodyMuted,
          ),
          const SizedBox(height: 18),
          TideButton(label: 'Add a habit', onPressed: onAdd),
        ],
      ),
    );
  }
}
