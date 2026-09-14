import 'package:flutter/material.dart';

import '../../theme/tide_colors.dart';
import 'widget_payload.dart';

/// A habit's last [WidgetPayload.heatmapWeeks] weeks as a grid image, for
/// the native Habit Heatmap widget.
///
/// RemoteViews has no grid-of-coloured-cells primitive, so
/// [HomeWidget.renderFlutterWidget] draws this off-screen and the widget
/// shows the PNG. Columns are weeks, oldest on the left; rows are Monday to
/// Sunday. The days of this week still to come are left blank, and today
/// carries a thin lantern outline so the grid has a "you are here".
class HeatmapExport extends StatelessWidget {
  const HeatmapExport({super.key, required this.series});

  /// From [WidgetPayload.heatmapSeries]: one ratio per day up to today.
  final List<double> series;

  static const double cell = 10;
  static const double gap = 3;
  static const int _weeks = WidgetPayload.heatmapWeeks;

  static Size get size => const Size(
    _weeks * (cell + gap) - gap,
    7 * (cell + gap) - gap,
  );

  @override
  Widget build(BuildContext context) {
    return SizedBox.fromSize(
      size: size,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var week = 0; week < _weeks; week++) ...[
            if (week > 0) const SizedBox(width: gap),
            Column(
              children: [
                for (var weekday = 0; weekday < 7; weekday++) ...[
                  if (weekday > 0) const SizedBox(height: gap),
                  _cell(week * 7 + weekday),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _cell(int index) {
    if (index >= series.length) return const SizedBox(width: cell, height: cell);
    final t = series[index];
    return Container(
      width: cell,
      height: cell,
      decoration: BoxDecoration(
        color: t < 0
            ? TideColors.bone.withValues(alpha: 0.035)
            : TideColors.intensity(t),
        borderRadius: BorderRadius.circular(2.5),
        border: index == series.length - 1
            ? Border.all(color: TideColors.lantern, width: 1.2)
            : null,
      ),
    );
  }
}
