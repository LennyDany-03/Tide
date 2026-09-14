import 'package:flutter/material.dart';

import '../../theme/tide_colors.dart';

/// Renders a habit's daily-ratio series as a small grid image for the
/// native Habit Heatmap widget.
///
/// RemoteViews has no grid-of-coloured-cells primitive, and hand-rolling one
/// in XML would mean re-deriving the app's own heatmap look natively and by
/// hand. [HomeWidget.renderFlutterWidget] draws this off-screen instead and
/// hands back a PNG path the native side just shows in an `ImageView` — the
/// same shortcut the plugin's own example uses for its icon.
class HeatmapExport extends StatelessWidget {
  const HeatmapExport({super.key, required this.series, this.columns = 7});

  /// One ratio per day, oldest first: -1 for a rest day, 0..1 for how much
  /// of that day's schedule was kept. See [StreakCalculator.dailySeries].
  final List<double> series;

  final int columns;

  static const double cellSize = 14;
  static const double gap = 3;

  static Size sizeFor(int seriesLength, {int columns = 7}) {
    final rows = (seriesLength / columns).ceil();
    return Size(
      columns * cellSize + (columns - 1) * gap,
      rows * cellSize + (rows - 1) * gap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = sizeFor(series.length, columns: columns);
    return SizedBox(
      width: size.width,
      height: size.height,
      child: Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final t in series)
            Container(
              width: cellSize,
              height: cellSize,
              decoration: BoxDecoration(
                color: TideColors.intensity(t < 0 ? 0 : t),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
        ],
      ),
    );
  }
}
