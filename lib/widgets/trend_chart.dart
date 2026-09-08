import 'package:flutter/material.dart';

import '../theme/tide_colors.dart';
import '../theme/tide_motion.dart';

/// A line that draws itself left to right.
///
/// Two screens plot a trend — Habit detail's completion rate and Insights'
/// eight weeks — so they share one chart. The draw-in is not decoration: it
/// is what sequences Insights, where the callouts are held back until this
/// finishes rather than everything arriving at once.
class TrendChart extends StatefulWidget {
  const TrendChart({
    super.key,
    required this.values,
    this.color = TideColors.lantern,
    this.height = 96,
    this.strokeWidth = 2,
    this.showEndDot = true,
    this.showPoints = false,
    this.fill = false,
    this.delay = Duration.zero,
    this.onFinished,
  });

  /// 0..1, oldest first. Needs at least two points to draw a line.
  final List<double> values;

  final Color color;
  final double height;
  final double strokeWidth;

  /// A dot on the most recent point — where the trend has got to.
  final bool showEndDot;

  /// Dots on every point, for the shorter series on Insights.
  final bool showPoints;

  /// A graded wash under the line, fading out toward the floor.
  ///
  /// Off for the sparkline on a habit card, where the chart is 26px tall
  /// and a fill would be a smear. On for the one on Insights, which is the
  /// largest figure on the screen after the headline and reads as a bare
  /// wire without it — the fill is what turns a plotted series into
  /// something with a water level under it.
  final bool fill;

  final Duration delay;

  /// Fires when the draw completes, so a caller can stagger what comes next.
  final VoidCallback? onFinished;

  @override
  State<TrendChart> createState() => _TrendChartState();
}

class _TrendChartState extends State<TrendChart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: TideMotion.chartDraw,
  );

  @override
  void initState() {
    super.initState();
    _controller.addStatusListener(_onStatus);
    Future<void>.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) widget.onFinished?.call();
  }

  @override
  void dispose() {
    _controller
      ..removeStatusListener(_onStatus)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            painter: _TrendPainter(
              values: widget.values,
              progress: Curves.easeInOutCubic.transform(_controller.value),
              color: widget.color,
              strokeWidth: widget.strokeWidth,
              showEndDot: widget.showEndDot,
              showPoints: widget.showPoints,
              fill: widget.fill,
            ),
          );
        },
      ),
    );
  }
}

class _TrendPainter extends CustomPainter {
  const _TrendPainter({
    required this.values,
    required this.progress,
    required this.color,
    required this.strokeWidth,
    required this.showEndDot,
    required this.showPoints,
    required this.fill,
  });

  final List<double> values;
  final double progress;
  final Color color;
  final double strokeWidth;
  final bool showEndDot;
  final bool showPoints;
  final bool fill;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2 || size.width <= 0) return;

    const padding = 6.0;
    final usableHeight = size.height - padding * 2;
    final step = size.width / (values.length - 1);

    // Auto-range rather than plotting against an absolute 0..1 axis. A
    // series that runs between 0.85 and 0.95 is a real trend, but on a full
    // axis it is a flat line pinned to the top of the box. [minSpan] keeps
    // genuinely steady data from being amplified into noise.
    const minSpan = 0.28;
    var low = values.reduce((a, b) => a < b ? a : b);
    var high = values.reduce((a, b) => a > b ? a : b);
    if (high - low < minSpan) {
      final centre = (high + low) / 2;
      low = centre - minSpan / 2;
      high = centre + minSpan / 2;
    }
    final span = high - low;

    Offset pointAt(int i) => Offset(
      step * i,
      padding + usableHeight * (1 - ((values[i] - low) / span).clamp(0.0, 1.0)),
    );

    // How far along the series the draw has reached, as a fractional index.
    final head = progress * (values.length - 1);
    final path = Path()..moveTo(pointAt(0).dx, pointAt(0).dy);

    for (var i = 1; i < values.length; i++) {
      if (head >= i) {
        final point = pointAt(i);
        path.lineTo(point.dx, point.dy);
      } else if (head > i - 1) {
        // Partway along this segment: interpolate so the line grows
        // smoothly rather than snapping point to point.
        final t = head - (i - 1);
        final from = pointAt(i - 1);
        final to = pointAt(i);
        path.lineTo(
          from.dx + (to.dx - from.dx) * t,
          from.dy + (to.dy - from.dy) * t,
        );
        break;
      }
    }

    // The wash first, so the line sits on top of its own fill rather than
    // being half-covered by it.
    if (fill) {
      final metrics = path.computeMetrics().toList();
      final end = metrics.isEmpty
          ? pointAt(0)
          : metrics.last.getTangentForOffset(metrics.last.length)!.position;

      canvas.drawPath(
        Path.from(path)
          ..lineTo(end.dx, size.height)
          ..lineTo(0, size.height)
          ..close(),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              color.withValues(alpha: 0.22),
              color.withValues(alpha: 0),
            ],
          ).createShader(Offset.zero & size),
      );
    }

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );

    if (showPoints) {
      for (var i = 0; i < values.length; i++) {
        if (head < i) break;
        canvas.drawCircle(
          pointAt(i),
          strokeWidth * 1.1,
          Paint()..color = color.withValues(alpha: 0.7),
        );
      }
    }

    if (showEndDot && progress >= 1) {
      canvas.drawCircle(
        pointAt(values.length - 1),
        strokeWidth * 1.9,
        Paint()..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(_TrendPainter old) =>
      old.progress != progress ||
      old.values != values ||
      old.color != color ||
      old.fill != fill;
}
