import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:home_widget/home_widget.dart';

import '../../config/pro_features.dart';
import '../../services/models/habit.dart';
import '../../services/tide_scope.dart';
import '../../services/tide_store.dart';
import '../../theme/tide_colors.dart';
import '../../theme/tide_elevation.dart';
import '../../theme/tide_typography.dart';
import '../../widgets/press_scale.dart';
import '../../widgets/tide_backdrop.dart';
import '../../widgets/tide_surface.dart';
import 'widgets/locked_widget_preview.dart';
import 'widgets/widget_gallery_card.dart';
import 'widgets/widget_previews.dart';

/// Every home-screen widget Tide offers, laid out the way each sits on the
/// home screen, with the system "add to home screen" action underneath.
///
/// Every widget here is deep-link only: a tap opens the app (see
/// `_openFromWidget` in lib/main.dart) rather than acting natively — there is
/// no interactive logging on the home screen itself in this first pass.
class HomeWidgetsScreen extends StatelessWidget {
  const HomeWidgetsScreen({super.key});

  Future<void> _pin(BuildContext context, String androidName) async {
    final supported = await HomeWidget.isRequestPinWidgetSupported() ?? false;
    if (!context.mounted) return;
    if (!supported) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "This launcher doesn't support adding widgets this way — "
            'long-press the home screen and add Tide from there instead.',
            style: TideType.label,
          ),
        ),
      );
      return;
    }
    await HomeWidget.requestPinWidget(androidName: androidName);
  }

  Future<void> _pickPinnedHabit(BuildContext context, TideStore store) async {
    final habits = store.allHabits;
    if (habits.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Add a habit first, then pin it here.', style: TideType.label),
        ),
      );
      return;
    }
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _HabitPickerSheet(habits: habits),
    );
    if (picked != null) store.setStreakWidgetHabit(picked);
  }

  @override
  Widget build(BuildContext context) {
    final store = TideScope.of(context);
    final pinnedHabit = store.streakWidgetHabitId == null
        ? null
        : store.habitById(store.streakWidgetHabitId!);

    return Scaffold(
      backgroundColor: TideColors.deepWater,
      body: Stack(
        children: [
          const Positioned.fill(child: TideBackdrop()),
          ListView(
            padding: EdgeInsets.fromLTRB(
              20,
              MediaQuery.paddingOf(context).top + 16,
              20,
              40 + MediaQuery.paddingOf(context).bottom,
            ),
            children: [
              Row(
                children: [
                  PressScale(
                    onTap: () => context.pop(),
                    child: SizedBox(
                      width: 38,
                      height: 38,
                      child: Icon(
                        Icons.arrow_back_rounded,
                        size: 21,
                        color: TideColors.bone,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Home screen widgets',
                      style: TideType.screenTitle,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(left: 48),
                child: Text(
                  'Habits and to-dos, right on your home screen.',
                  style: TideType.labelMuted,
                ),
              ),
              const SizedBox(height: 24),

              // Single Habit Streak and Habit Heatmap both show one pinned
              // habit — one picker for both, rather than two that could
              // disagree about which habit is shown where.
              PressScale(
                onTap: () => _pickPinnedHabit(context, store),
                child: TideSurface(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Widget habit', style: TideType.sectionHeader),
                            const SizedBox(height: 2),
                            Text(
                              pinnedHabit?.name ??
                                  'None chosen — tap to pick one',
                              style: TideType.labelMuted,
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: TideColors.silt,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              WidgetGalleryCard(
                title: "Today's Habits",
                subtitle: "A checklist of what's due today.",
                preview: const TodayHabitsPreview(),
                onAdd: () => _pin(context, 'TodayHabitsWidgetProvider'),
              ),
              const SizedBox(height: 16),

              WidgetGalleryCard(
                title: 'Single Habit Streak',
                subtitle: pinnedHabit == null
                    ? 'Pick a habit above to show its streak.'
                    : 'Shows ${pinnedHabit.name}\'s current streak.',
                preview: SingleHabitStreakPreview(habitName: pinnedHabit?.name),
                onAdd: () => _pin(context, 'SingleHabitStreakWidgetProvider'),
              ),
              const SizedBox(height: 16),

              WidgetGalleryCard(
                title: "Today's Tasks",
                subtitle: "What's due or overdue today.",
                preview: const TodayTasksPreview(),
                onAdd: () => _pin(context, 'TodayTasksWidgetProvider'),
              ),
              const SizedBox(height: 16),

              WidgetGalleryCard(
                title: 'Quick Add',
                subtitle: 'One tap into a new habit.',
                preview: const QuickAddPreview(),
                onAdd: () => _pin(context, 'QuickAddWidgetProvider'),
              ),
              const SizedBox(height: 16),

              if (store.locked(ProFeature.habitDashboardWidget))
                const LockedWidgetPreview(
                  title: 'Habit Dashboard',
                  feature: ProFeature.habitDashboardWidget,
                )
              else
                WidgetGalleryCard(
                  title: 'Habit Dashboard',
                  subtitle: 'Every habit, and the streak behind it.',
                  preview: const HabitDashboardPreview(),
                  onAdd: () => _pin(context, 'HabitDashboardWidgetProvider'),
                ),
              const SizedBox(height: 16),

              if (store.locked(ProFeature.habitHeatmapWidget))
                const LockedWidgetPreview(
                  title: 'Habit Heatmap',
                  feature: ProFeature.habitHeatmapWidget,
                )
              else
                WidgetGalleryCard(
                  title: 'Habit Heatmap',
                  subtitle: pinnedHabit == null
                      ? 'Pick a habit above to show its history.'
                      : '${pinnedHabit.name}\'s last five weeks.',
                  preview: const HeatmapPreview(),
                  onAdd: () => _pin(context, 'HabitHeatmapWidgetProvider'),
                ),
              const SizedBox(height: 16),

              if (store.locked(ProFeature.weeklyRecapWidget))
                const LockedWidgetPreview(
                  title: 'Weekly Recap',
                  feature: ProFeature.weeklyRecapWidget,
                )
              else
                WidgetGalleryCard(
                  title: 'Weekly Recap',
                  subtitle: "This week's rate, and your best streak.",
                  preview: const WeeklyRecapPreview(),
                  onAdd: () => _pin(context, 'WeeklyRecapWidgetProvider'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HabitPickerSheet extends StatelessWidget {
  const _HabitPickerSheet({required this.habits});

  final List<Habit> habits;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(12),
        constraints: const BoxConstraints(maxHeight: 420),
        decoration: BoxDecoration(
          color: TideColors.shelf,
          borderRadius: TideElevation.radius20,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            for (final habit in habits)
              PressScale(
                onTap: () => Navigator.of(context).pop(habit.id),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  child: Text(
                    habit.name,
                    style: TideType.label.copyWith(color: TideColors.bone),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
