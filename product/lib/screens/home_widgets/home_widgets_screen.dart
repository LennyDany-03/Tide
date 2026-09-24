import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:home_widget/home_widget.dart';

import '../../theme/tide_colors.dart';
import '../../theme/tide_typography.dart';
import '../../widgets/press_scale.dart';
import '../../widgets/tide_backdrop.dart';
import 'widgets/widget_gallery_card.dart';
import 'widgets/widget_previews.dart';

/// Every home-screen widget Tide offers, drawn the way it sits on the home
/// screen, with the system "add to home screen" action under each.
///
/// Streak and Heatmap widgets are each tied to one habit, chosen by tapping
/// the widget once it is placed — so there is no habit picker here.
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TideColors.deepWater,
      body: Stack(
        children: [
          const Positioned.fill(child: TideBackdrop()),
          ListView(
            padding: EdgeInsets.fromLTRB(
              20,
              MediaQuery.viewPaddingOf(context).top + 16,
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
                  'Habits and to-dos, right on your home screen. Every widget '
                  'resizes — long-press it on the home screen.',
                  style: TideType.labelMuted,
                ),
              ),
              const SizedBox(height: 24),

              WidgetGalleryCard(
                title: 'Today',
                subtitle: "What's due today, and how much of it is kept.",
                preview: const TodayHabitsPreview(),
                onAdd: () => _pin(context, 'TodayHabitsWidgetProvider'),
              ),
              const SizedBox(height: 16),
              WidgetGalleryCard(
                title: 'Streak',
                subtitle:
                    "One habit's streak. Tap the widget to choose which.",
                preview: const SingleHabitStreakPreview(),
                onAdd: () => _pin(context, 'SingleHabitStreakWidgetProvider'),
              ),
              const SizedBox(height: 16),
              WidgetGalleryCard(
                title: 'Tasks',
                subtitle: "What's due or overdue.",
                preview: const TodayTasksPreview(),
                onAdd: () => _pin(context, 'TodayTasksWidgetProvider'),
              ),
              const SizedBox(height: 16),
              WidgetGalleryCard(
                title: 'Quick add',
                subtitle: 'One tap into a new habit.',
                preview: const QuickAddPreview(),
                onAdd: () => _pin(context, 'QuickAddWidgetProvider'),
              ),
              const SizedBox(height: 16),
              WidgetGalleryCard(
                title: 'Heatmap',
                subtitle:
                    'Half a year of one habit. Tap the widget to choose which.',
                preview: const HeatmapPreview(),
                onAdd: () => _pin(context, 'HabitHeatmapWidgetProvider'),
              ),
              const SizedBox(height: 16),
              WidgetGalleryCard(
                title: 'Streaks',
                subtitle: 'Every habit, its week, and the run behind it.',
                preview: const HabitDashboardPreview(),
                onAdd: () => _pin(context, 'HabitDashboardWidgetProvider'),
              ),
              const SizedBox(height: 16),
              WidgetGalleryCard(
                title: 'This week',
                subtitle: 'Your rate, last week to beat, and your best run.',
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
