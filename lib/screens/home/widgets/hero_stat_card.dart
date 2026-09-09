import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../config/milestone_catalog.dart';
import '../../../services/models/milestone.dart';
import '../../../theme/tide_colors.dart';
import '../../../theme/tide_elevation.dart';
import '../../../theme/tide_gradients.dart';
import '../../../theme/tide_motion.dart';
import '../../../theme/tide_typography.dart';
import '../../../widgets/gauge_number.dart';
import '../../../widgets/press_scale.dart';
import '../../../widgets/tide_flame.dart';
import '../../../widgets/tide_level.dart';
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
                dayComplete ? 'all marked' : 'marked today',
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

/// The week, as a percentage, against the eight weeks behind it.
///
/// Three readings of one fact at three levels of effort, which is what a
/// summary card is for: the figure says how this week went, the mark beside
/// it names the comparison outright, and the area underneath says whether
/// this is the week you have been having.
///
/// The chart went from a bare stroke to a filled area on the same argument
/// the tide curve is built on. A line is a boundary, and a boundary between
/// two nothings has no weight — at 26px tall the old one was a wire. Filled
/// with the same lantern ramp the waterline uses, a good run of weeks
/// becomes *heavy*, which is the only thing anyone reads a sparkline for.
class _RateChip extends StatelessWidget {
  const _RateChip({required this.rate, required this.series});

  final double rate;
  final List<double> series;

  /// This week against last, in percentage points. Null when there is not
  /// enough history to compare — the one case where saying nothing beats
  /// saying zero, because a flat "level" on a first week is a lie about
  /// having measured something.
  int? get _delta {
    if (series.length < 2) return null;
    return ((series.last - series[series.length - 2]) * 100).round();
  }

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
          Row(
            children: [
              GaugeCountUp(
                value: (rate * 100).round(),
                style: TideType.gauge(24),
                suffix: '%',
                suffixStyle: TideType.gauge(15, color: TideColors.silt),
              ),
              const Spacer(),
              _TrendMark(delta: _delta),
            ],
          ),
          const SizedBox(height: 2),
          Text('this week', style: TideType.labelMuted),
          const SizedBox(height: 12),
          SizedBox(
            height: 30,
            width: double.infinity,
            child: _Sparkline(series: series),
          ),
        ],
      ),
    );
  }
}

/// Which way the week moved, in one glyph and one figure.
///
/// Up is [TideColors.lantern]; everything else is [TideColors.silt]. A
/// quieter week than the last one is not a failure to be marked in red, and
/// the red is spoken for regardless — coral means destruction in this
/// palette and means nothing else.
class _TrendMark extends StatelessWidget {
  const _TrendMark({required this.delta});

  final int? delta;

  @override
  Widget build(BuildContext context) {
    final value = delta;
    if (value == null) return const SizedBox.shrink();

    final rising = value > 0;
    final colour = rising ? TideColors.lantern : TideColors.silt;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          value == 0
              ? Icons.remove_rounded
              : rising
              ? Icons.north_rounded
              : Icons.south_rounded,
          size: 11,
          color: colour,
        ),
        const SizedBox(width: 2),
        Text(
          value == 0 ? 'level' : '${value.abs()}',
          style: TideType.gauge(11, color: colour),
        ),
      ],
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
    var head = points.first;
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i <= whole; i++) {
      path.lineTo(points[i].dx, points[i].dy);
      head = points[i];
    }
    if (whole < series.length - 1) {
      final t = travelled - whole;
      head = Offset(
        points[whole].dx + (points[whole + 1].dx - points[whole].dx) * t,
        points[whole].dy + (points[whole + 1].dy - points[whole].dy) * t,
      );
      path.lineTo(head.dx, head.dy);
    }

    // The area, closed down to the floor and back. Built from the drawn
    // path rather than the whole series, so the fill arrives *with* the
    // stroke — a full-width wash sitting under a line that is still being
    // drawn gives the ending away.
    //
    // The ramp is the waterline's, and it reaches zero rather than
    // bottoming out at a low alpha, for the reason written where it is
    // defined: a fill that keeps a floor is a solid mass with a top edge on
    // it, which reads as sand rather than as water.
    canvas.drawPath(
      Path.from(path)
        ..lineTo(head.dx, size.height)
        ..lineTo(points.first.dx, size.height)
        ..close(),
      Paint()
        ..shader = TideGradients.tideFill.createShader(
          Rect.fromLTWH(0, 0, size.width, size.height),
        ),
    );

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

/// The streak, as a fire, and how far it is from the next thing it unlocks.
///
/// The ring came off this card. A ring is an accurate instrument answering
/// the wrong question — it reports how far through a leg you are, when a
/// streak's entire emotional content is that it is *still alight* and that
/// letting it go out would cost something. So the fire is the card now, and
/// the leg being walked is a 3px rule underneath, which is about as much
/// room as "four days into the thirty between full moon and undertow"
/// deserves.
///
/// Still pressable, and it still goes somewhere: Milestones is the screen
/// this number is measured against.
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

  /// The one behind it, so the track measures the leg being walked rather
  /// than the whole distance from zero — at day 34 of 40 a bar drawn from
  /// zero sits at 85%, which says nothing about the four days just done.
  int get _from {
    var last = 0;
    for (final milestone in MilestoneCatalog.all) {
      if (milestone.kind != MilestoneKind.streak) continue;
      if (milestone.threshold > streak) break;
      last = milestone.threshold;
    }
    return last;
  }

  /// How hard the fire burns, 0..1.
  ///
  /// Square-rooted rather than linear on purpose. Most of the range is
  /// spent on the first three weeks, because that is the stretch where a
  /// run is fragile and the fire is doing actual work; past a couple of
  /// months it is a fire either way and a linear ramp would spend its whole
  /// budget on days nobody is worried about.
  double get _heat => math.sqrt((streak / 90).clamp(0.0, 1.0));

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
        padding: const EdgeInsets.fromLTRB(15, 13, 12, 14),
        child: Stack(
          // The fire burns up out of the bottom corner and is cut off by the
          // card's own radius — `TideSurface` clips, so the flame is allowed
          // to overrun the padding and be trimmed by the shape rather than
          // sitting politely inside it like an illustration.
          clipBehavior: Clip.none,
          children: [
            Positioned(
              // Standing on the card's bottom edge in its right-hand third,
              // and — this is the part that took three tries — very nearly
              // whole. An 86px flame in the middle of a 158px card stopped
              // being the card's light and became its subject. Burying it in
              // the corner instead overcorrected: clipped to a sliver it
              // read as a rendering artefact rather than as a fire, which is
              // worse than too big. It needs enough room to show the whole
              // silhouette — foot, bulge, neck, tip — because that shape is
              // the only thing separating fire from a smudge of warm light.
              right: -8,
              bottom: -16,
              width: 60,
              height: 84,
              child: TideFlame(intensity: _heat),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    GaugeCountUp(value: streak, style: TideType.gauge(24)),
                    const Spacer(),
                    // Small, and the only chevron on the screen: it is the
                    // one readout here that leads anywhere.
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: TideColors.silt.withValues(alpha: 0.8),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'day streak',
                  style: TideType.labelMuted,
                  // The card is half the page wide and the fire takes a
                  // third of what is left; a caption that wraps here pushes
                  // the whole footer down past the flame's shoulder.
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                // The whole footer is held to the left two thirds, clear of
                // the fire standing in the right one. Both halves of it
                // needed it: a rule that runs the full width has to cross
                // whatever is in the corner, and a hard bright line laid
                // over a soft glow is the cheapest thing two good elements
                // can do to each other — but the caption underneath was the
                // worse offender, because it ellipsised straight into the
                // brightest part of the flame and simply became unreadable.
                FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: 0.66,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _NextTrack(progress: progress),
                      const SizedBox(height: 7),
                      Text(
                        detail,
                        style: TideType.labelMuted.copyWith(fontSize: 11.5),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The distance to the next badge, demoted to a rule.
///
/// Two pixels rather than three, and the accent held back to 0.7. At full
/// strength on a 3px bar this read as a hard cream line ruled across the
/// card — the loudest object on a surface whose headline is a number and
/// whose atmosphere is a fire. A progress detail should be legible when
/// looked for and quiet when not.
class _NextTrack extends StatelessWidget {
  const _NextTrack({required this.progress});

  final double progress;

  static const double _height = 2;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(_height),
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: progress),
        duration: TideMotion.ringFill,
        curve: TideMotion.overshoot,
        builder: (context, value, _) => Stack(
          children: [
            const SizedBox(
              height: _height,
              width: double.infinity,
              child: ColoredBox(color: TideColors.trench),
            ),
            FractionallySizedBox(
              // Clamped, and it has to be: the signature Tide curve
              // overshoots past its end value, which on a width factor is a
              // bar wider than the track it sits in.
              widthFactor: value.clamp(0.0, 1.0),
              child: ColoredBox(
                color: TideColors.lantern.withValues(alpha: 0.7),
                child: const SizedBox(height: _height),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
