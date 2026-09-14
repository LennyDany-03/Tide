import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:home_widget/home_widget.dart';

import '../../config/pro_features.dart';
import '../../services/tide_scope.dart';
import '../../theme/tide_colors.dart';
import '../../theme/tide_typography.dart';
import '../../widgets/press_scale.dart';
import '../../widgets/tide_backdrop.dart';
import 'widgets/locked_widget_preview.dart';
import 'widgets/widget_gallery_card.dart';

/// Today's Habits and Habit Dashboard, laid out the way they'll sit on the
/// home screen, with the system "add to home screen" action underneath each.
///
/// Both widgets are deep-link only: a tap opens the app (see
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

  @override
  Widget build(BuildContext context) {
    final store = TideScope.of(context);
    final dashboardLocked = store.locked(ProFeature.habitDashboardWidget);

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
                  'A checklist and a dashboard, right on your home screen.',
                  style: TideType.labelMuted,
                ),
              ),
              const SizedBox(height: 24),

              WidgetGalleryCard(
                title: "Today's Habits",
                subtitle: "A checklist of what's due today.",
                preview: const _TodayHabitsPreview(),
                onAdd: () => _pin(context, 'TodayHabitsWidgetProvider'),
              ),
              const SizedBox(height: 16),

              if (dashboardLocked)
                const LockedWidgetPreview(
                  title: 'Habit Dashboard',
                  feature: ProFeature.habitDashboardWidget,
                )
              else
                WidgetGalleryCard(
                  title: 'Habit Dashboard',
                  subtitle: 'Every habit, and the streak behind it.',
                  preview: const _HabitDashboardPreview(),
                  onAdd: () => _pin(context, 'HabitDashboardWidgetProvider'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A static stand-in for the native RemoteViews row layout — a mock, not a
/// live preview of real habits. Deliberately simple next to the real widget:
/// there is no glyph rendering on the home screen either (see
/// widget_status_done.xml's comment), so the preview shouldn't promise one.
class _TodayHabitsPreview extends StatelessWidget {
  const _TodayHabitsPreview();

  @override
  Widget build(BuildContext context) {
    return _PreviewRows(
      rows: const [('Morning water', true), ('Evening walk', false)],
    );
  }
}

class _HabitDashboardPreview extends StatelessWidget {
  const _HabitDashboardPreview();

  @override
  Widget build(BuildContext context) {
    return _PreviewRows(
      rows: const [('Morning water', true), ('Evening walk', false)],
      streaks: const [12, 4],
    );
  }
}

class _PreviewRows extends StatelessWidget {
  const _PreviewRows({required this.rows, this.streaks});

  final List<(String, bool)> rows;
  final List<int>? streaks;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: TideColors.shoal,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: rows[i].$2
                        ? TideColors.lantern
                        : Colors.transparent,
                    border: rows[i].$2
                        ? null
                        : Border.all(color: TideColors.silt, width: 1.2),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    rows[i].$1,
                    style: TideType.label.copyWith(color: TideColors.bone),
                  ),
                ),
                if (streaks != null)
                  Text(
                    '${streaks![i]}',
                    style: TideType.gauge(12, color: TideColors.lantern),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
