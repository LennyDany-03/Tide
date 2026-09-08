import 'package:flutter/material.dart';

import '../../../config/milestone_catalog.dart';
import '../../../services/models/milestone.dart';
import '../../../theme/tide_colors.dart';
import '../../../theme/tide_elevation.dart';
import '../../../theme/tide_motion.dart';
import '../../../theme/tide_typography.dart';
import '../../../widgets/gauge_number.dart';
import '../../../widgets/press_scale.dart';
import '../../../widgets/tide_level.dart';
import '../../../widgets/tide_ring.dart';
import '../../../widgets/tide_surface.dart';

/// The day's headline: how much of today is done, as water standing at a
/// level behind the figure.
///
/// There is no card. The figure and the water sit directly on the page,
/// full-bleed to both edges — a hero inside a rounded rectangle is one more
/// object on a screen already full of them, and the panel said nothing the
/// type and the water were not already saying.
///
/// The figure sits clear above the water rather than inside it. Running the
/// water behind the whole block gave the level somewhere to travel, but at
/// a half-finished day the lit waterline lands exactly across the caption
/// and cuts the letterforms in half — and where the line falls is decided by
/// the data, so there is no layout that survives every value. Text above,
/// water below, and the crest is free to be as bright as it needs to be.
///
/// The two chips below were flat readouts: an icon, a number, a caption,
/// nothing moving and nothing to press. The streak one especially, which is
/// the single figure people open a habit app to look at, and which had a
/// destination sitting one tap away that it never offered. Both now report
/// themselves — the rate draws its own eight weeks, the streak fills a ring
/// toward whatever it is heading for — and the streak carries you through
/// to the route it is measured against.
class HeroStatCard extends StatelessWidget {
  const HeroStatCard({
    super.key,
    required this.completed,
    required this.scheduled,
    required this.weeklyRate,
    required this.weeklySeries,
    required this.bestStreak,
    required this.dayComplete,
    required this.onStreakTap,
  });

  final int completed;
  final int scheduled;
  final double weeklyRate;

  /// Eight weekly rates, oldest first — the shape behind the percentage.
  final List<double> weeklySeries;

  final int bestStreak;
  final bool dayComplete;

  /// Through to Milestones, which is the screen the streak is measured on.
  final VoidCallback onStreakTap;

  double get _level => scheduled == 0 ? 0 : completed / scheduled;

  /// Tall enough that the difference between a quarter done and half done
  /// is a distance you can see, not a two-pixel nudge.
  static const double _waterHeight = 96;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              GaugeNumber(value: completed, style: TideType.gaugeHero()),
              const SizedBox(width: 8),
              Text(
                'of $scheduled',
                style: TideType.gauge(18, color: TideColors.silt),
              ),
              const Spacer(),
              Text(
                dayComplete ? 'all logged' : 'logged today',
                style: TideType.labelMuted.copyWith(
                  color: dayComplete ? TideColors.lantern : TideColors.silt,
                ),
              ),
            ],
          ),
        ),

        // Full-bleed: the water runs off both edges of the screen, so it
        // reads as a body of water the page sits in rather than as a widget
        // with a left and a right end.
        SizedBox(
          height: _waterHeight,
          child: TideLevel(level: _level, amplitude: 9),
        ),
        const SizedBox(height: 20),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          // Intrinsic rather than a stretch alone: the row sits in a sliver
          // with no bounded height to stretch against, and the two chips
          // have genuinely different content — the sparkline makes one
          // taller — so the shorter one has to be told to match.
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _RateChip(rate: weeklyRate, series: weeklySeries),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StreakChip(streak: bestStreak, onTap: onStreakTap),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// The week, as a percentage over the eight weeks behind it.
///
/// The number alone says how this week went. The line says whether that is
/// the week you have been having, which is a different and more useful
/// fact — and it costs nothing but the space the icon was using.
class _RateChip extends StatelessWidget {
  const _RateChip({required this.rate, required this.series});

  final double rate;
  final List<double> series;

  @override
  Widget build(BuildContext context) {
    return TideSurface(
      radius: TideElevation.radius20,
      color: TideColors.shelf,
      padding: const EdgeInsets.fromLTRB(15, 13, 15, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          GaugeCountUp(
            value: (rate * 100).round(),
            style: TideType.gauge(24),
            suffix: '%',
            suffixStyle: TideType.gauge(15, color: TideColors.silt),
          ),
          const SizedBox(height: 2),
          Text('this week', style: TideType.labelMuted),
          const SizedBox(height: 12),
          SizedBox(
            height: 26,
            width: double.infinity,
            child: _Sparkline(series: series),
          ),
        ],
      ),
    );
  }
}

/// Eight weeks, drawing themselves in.
class _Sparkline extends StatefulWidget {
  const _Sparkline({required this.series});

  final List<double> series;

  @override
  State<_Sparkline> createState() => _SparklineState();
}

class _SparklineState extends State<_Sparkline>
    with SingleTickerProviderStateMixin {
  late final AnimationController _draw = AnimationController(
    vsync: this,
    duration: TideMotion.chartDraw,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _draw.forward();
    });
  }

  @override
  void dispose() {
    _draw.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _draw,
        builder: (context, _) => CustomPaint(
          painter: _SparkPainter(
            series: widget.series,
            progress: Curves.easeOutCubic.transform(_draw.value),
          ),
        ),
      ),
    );
  }
}

class _SparkPainter extends CustomPainter {
  const _SparkPainter({required this.series, required this.progress});

  final List<double> series;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (series.length < 2 || progress <= 0) return;

    final step = size.width / (series.length - 1);
    // A floor and a ceiling inside the box, so a flat run of zeroes still
    // draws a line rather than vanishing into the bottom edge.
    double yFor(double value) =>
        size.height - 2 - (size.height - 4) * value.clamp(0.0, 1.0);

    final points = [
      for (var i = 0; i < series.length; i++)
        Offset(i * step, yFor(series[i])),
    ];

    // Drawn to a fraction of the way along, so the line arrives rather than
    // appearing. Partial segments are interpolated, which keeps the head
    // moving smoothly instead of snapping week to week.
    final travelled = progress * (series.length - 1);
    final whole = travelled.floor();
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i <= whole; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    if (whole < series.length - 1) {
      final t = travelled - whole;
      path.lineTo(
        points[whole].dx + (points[whole + 1].dx - points[whole].dx) * t,
        points[whole].dy + (points[whole + 1].dy - points[whole].dy) * t,
      );
    }

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = TideColors.lantern.withValues(alpha: 0.9),
    );

    // The head of the line, once it has arrived — a full stop on this week
    // rather than a line that trails off.
    if (progress >= 1) {
      canvas.drawCircle(
        points.last,
        2.6,
        Paint()..color = TideColors.lantern,
      );
    }
  }

  @override
  bool shouldRepaint(_SparkPainter old) =>
      old.progress != progress || old.series != series;
}

/// The streak, and how far it is from the next thing it unlocks.
///
/// Pressable, and it goes somewhere: Milestones is the screen this number
/// is measured against, and it was previously reachable only from a single
/// glyph in the header. A figure that is the reason people open the app
/// should be the way into the screen about it.
class _StreakChip extends StatelessWidget {
  const _StreakChip({required this.streak, required this.onTap});

  final int streak;
  final VoidCallback onTap;

  /// The first streak milestone still ahead of [streak].
  Milestone? get _next {
    for (final milestone in MilestoneCatalog.all) {
      if (milestone.kind != MilestoneKind.streak) continue;
      if (milestone.threshold > streak) return milestone;
    }
    return null;
  }

  /// The one behind it, so the ring measures the leg being walked rather
  /// than the whole distance from zero — at day 34 of 60 a ring drawn from
  /// zero sits at 57%, which says nothing about the thirty days just done.
  int get _from {
    var last = 0;
    for (final milestone in MilestoneCatalog.all) {
      if (milestone.kind != MilestoneKind.streak) continue;
      if (milestone.threshold > streak) break;
      last = milestone.threshold;
    }
    return last;
  }

  @override
  Widget build(BuildContext context) {
    final next = _next;
    final progress = next == null
        ? 1.0
        : ((streak - _from) / (next.threshold - _from)).clamp(0.0, 1.0);

    final detail = next == null
        ? 'every one surfaced'
        : '${next.threshold - streak} to ${next.name.toLowerCase()}';

    return PressScale(
      onTap: onTap,
      scale: 0.985,
      child: TideSurface(
        radius: TideElevation.radius20,
        color: TideColors.shelf,
        padding: const EdgeInsets.fromLTRB(13, 13, 12, 14),
        child: Row(
          children: [
            // Fills on arrival, and refills whenever a log moves the
            // streak — the ring is the only thing on Today that reports
            // where the run stands rather than where the day does.
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: progress),
              duration: TideMotion.ringFill,
              curve: TideMotion.overshoot,
              builder: (context, value, child) => TideRing(
                progress: value,
                size: 46,
                strokeWidth: 3,
                animate: false,
                child: child,
              ),
              child: GaugeCountUp(
                value: streak,
                style: TideType.gauge(16, color: TideColors.bone),
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'day streak',
                    style: TideType.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    detail,
                    style: TideType.labelMuted.copyWith(fontSize: 11.5),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // Small, and the only chevron on the screen: it is the one
            // readout here that leads anywhere.
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: TideColors.silt.withValues(alpha: 0.8),
            ),
          ],
        ),
      ),
    );
  }
}
