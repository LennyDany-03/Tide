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
import '../../../widgets/stagger_list.dart';
import '../../../widgets/tide_flame.dart';
import '../../../widgets/tide_level.dart';
import '../../../widgets/tide_surface.dart';

/// The day's headline, as a bento: one dominant tile and two that support
/// it.
///
/// **Why the layout changed.** The hero used to be a figure on open ground,
/// a full-bleed band of water under it, and then two identical half-width
/// chips. Three horizontal slabs of roughly equal weight stacked down the
/// screen — nothing about it said which of the three mattered most, and the
/// water, ending at both screen edges, read as a divider between the title
/// and the stats rather than as the day filling up.
///
/// An asymmetric grid fixes the hierarchy with position alone. The day takes
/// the tall left tile, because it is the fact you open the app for; the week
/// and the streak stack in the narrower right column, because they are
/// context for it. The eye lands left, large, first — and every tile is the
/// same material with the same edge, so it reads as one instrument, not
/// three widgets that happen to be adjacent.
///
/// The water survived and is better for it: confined to the bottom of its
/// own tile it is unmistakably *that tile's* level, and it can never run
/// through the figure, because the figure sits in the part of the tile the
/// water is not allowed into.
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

  /// Space between tiles, both ways. One number, so the grid's gutters are
  /// identical and the three tiles lock together as a single block.
  static const double _gutter = 10;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      // Intrinsic rather than a fixed height: the text scales, and the tall
      // tile has to stay exactly as tall as the two it stands beside at
      // every size, or the grid stops being a grid.
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 11 : 9 rather than 2 : 1. At phone width a true two-to-one
            // leaves the right column too narrow for a figure and a caption
            // side by side with anything else, and the streak tile needs
            // room for its fire.
            Expanded(
              flex: 11,
              child: StaggerIn(
                index: 0,
                child: _DayTile(
                  completed: completed,
                  scheduled: scheduled,
                  dayComplete: dayComplete,
                ),
              ),
            ),
            const SizedBox(width: _gutter),
            Expanded(
              flex: 9,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  StaggerIn(
                    index: 1,
                    child: _RateChip(rate: weeklyRate, series: weeklySeries),
                  ),
                  const SizedBox(height: _gutter),
                  // Takes whatever height is left, so the bottom edges of
                  // the two columns always meet.
                  Expanded(
                    child: StaggerIn(
                      index: 2,
                      child: _StreakChip(
                        streak: bestStreak,
                        onTap: onStreakTap,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// How much of today is done: the figure, where the day stands, and the
/// water at that level along the bottom of the tile.
class _DayTile extends StatelessWidget {
  const _DayTile({
    required this.completed,
    required this.scheduled,
    required this.dayComplete,
  });

  final int completed;
  final int scheduled;
  final bool dayComplete;

  double get _level => scheduled == 0 ? 0 : completed / scheduled;

  /// The band the water may occupy. The text column reserves exactly this
  /// much below itself, so at a full day the crest still stops short of the
  /// caption — where the waterline falls is decided by the data, and no
  /// value is allowed to put it through a letterform.
  static const double _waterHeight = 76;

  @override
  Widget build(BuildContext context) {
    return TideSurface(
      radius: TideElevation.radius20,
      // A finished day warms the tile, at the lowest intensity lantern is
      // used anywhere — the same tint a finished habit card takes.
      color: dayComplete
          ? Color.lerp(TideColors.shelf, TideColors.lantern, 0.05)
          : TideColors.shelf,
      border: Border.all(
        color: dayComplete
            ? TideColors.lantern.withValues(alpha: 0.2)
            : TideColors.hairline,
      ),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: _waterHeight,
            child: TideLevel(level: _level, amplitude: 5),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _LiveStatus(
                  remaining: scheduled - completed,
                  scheduled: scheduled,
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    GaugeNumber(
                      value: completed,
                      style: TideType.gaugeHero(),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '/',
                      style: TideType.gauge(22, color: TideColors.silt),
                    ),
                    GaugeNumber(
                      value: scheduled,
                      style: TideType.gauge(22, color: TideColors.silt),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'marked today',
                  style: TideType.labelMuted,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: _waterHeight),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Where the day stands, in three words and a pulse.
///
/// The pulse is the one perpetual motion on the tile, and it runs only while
/// something is still open. A live dot on a finished day is an alarm about
/// nothing; once the day is marked it stops and sits solid, which is its own
/// small moment of rest.
class _LiveStatus extends StatefulWidget {
  const _LiveStatus({required this.remaining, required this.scheduled});

  final int remaining;
  final int scheduled;

  @override
  State<_LiveStatus> createState() => _LiveStatusState();
}

class _LiveStatusState extends State<_LiveStatus>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: TideMotion.syncPulse,
  );

  bool get _live => widget.scheduled > 0 && widget.remaining > 0;

  /// Not "All marked": the log sheet already says that about one habit, and
  /// a day and a habit finishing are different claims.
  String get _label {
    if (widget.scheduled == 0) return 'Nothing due';
    if (!_live) return 'Day complete';
    return '${widget.remaining} to go';
  }

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(_LiveStatus old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    if (_live) {
      if (!_pulse.isAnimating) _pulse.repeat();
    } else {
      _pulse
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context);
    const dot = SizedBox.square(
      dimension: 6,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: TideColors.lantern,
        ),
      ),
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(7, 4, 10, 4),
      decoration: BoxDecoration(
        color: TideColors.lantern.withValues(alpha: _live ? 0.10 : 0.16),
        borderRadius: TideElevation.radius12,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox.square(
            dimension: 14,
            child: AnimatedBuilder(
              animation: _pulse,
              builder: (context, _) {
                final t = _pulse.value;
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    // A ring of the dot's own light leaving it and fading —
                    // the pulse a live indicator gives, without a second
                    // colour or a glow.
                    if (_live && !still)
                      Opacity(
                        opacity: (1 - t) * 0.55,
                        child: Transform.scale(scale: 1 + 1.3 * t, child: dot),
                      ),
                    dot,
                  ],
                );
              },
            ),
          ),
          const SizedBox(width: 5),
          Text(
            _label,
            style: TideType.labelMuted.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: TideColors.lantern,
            ),
          ),
        ],
      ),
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
      border: Border.all(color: TideColors.hairline),
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
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
          Text(
            'this week',
            style: TideType.labelMuted,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 28,
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
/// the leg being walked is a 2px rule underneath, which is about as much
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
        border: Border.all(color: TideColors.hairline),
        padding: const EdgeInsets.fromLTRB(14, 13, 12, 14),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              // In the right-hand third, below the chevron, and whole. The
              // flame is a crisp mark rather than a haze of light, and a
              // mark cut off by the card's edge reads as a layout accident.
              // It is also kept small: an emblem the size of the number
              // stops being the card's light and becomes its subject.
              right: 0,
              bottom: -4,
              width: 44,
              height: 60,
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
                    // Small, and the only chevron in the grid: it is the one
                    // tile here that leads anywhere.
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
                  // The tile is under half the page wide and the fire takes
                  // a third of it; a caption that wraps here pushes the
                  // whole footer down past the flame's shoulder.
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                // The footer is held to the left two thirds, clear of the
                // fire standing in the right one. A rule running the full
                // width has to cross whatever is in the corner, and a caption
                // there ellipsised straight into the brightest part of the
                // flame and became unreadable.
                FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: 0.68,
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
