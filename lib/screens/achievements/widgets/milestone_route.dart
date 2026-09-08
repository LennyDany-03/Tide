import 'package:flutter/material.dart';

import '../../../services/models/milestone.dart';
import '../../../theme/tide_colors.dart';
import '../../../theme/tide_motion.dart';
import '../../../theme/tide_typography.dart';
import '../../../widgets/habit_glyph.dart';
import '../../../widgets/press_scale.dart';
import '../../../widgets/tide_ring.dart';

/// The milestones, as a route you are somewhere along.
///
/// This was a 3×3 wall of badges. A wall answers "what is there" and
/// nothing else — nine tiles, one of them lit, no order between them and no
/// indication of where you stand, so the honest reading of it was "eight
/// things you have not done". Which is a strange thing for a habit app to
/// open with.
///
/// A route answers the question people actually have, which is *how far*.
/// The line runs from the first day to the last, the lit part is the
/// distance already covered, and the lantern sits exactly where the streak
/// currently stands — between two markers, most of the time, which is the
/// truthful place for it to be and the one a grid can never show.
class MilestoneRoute extends StatefulWidget {
  const MilestoneRoute({
    super.key,
    required this.statuses,
    required this.streak,
    required this.onTap,
  });

  /// In order, easiest first.
  final List<MilestoneStatus> statuses;

  /// The figure the route is measured against — the best streak so far.
  final int streak;

  final ValueChanged<MilestoneStatus> onTap;

  /// Vertical room per marker.
  static const double stepHeight = 118;

  /// The badge, and the margin it keeps from the page edge.
  static const double discSize = 58;
  static const double edge = 24;

  /// The air between a badge and the caption reading off it.
  static const double labelGap = 16;

  /// Where each marker stands, as a signed fraction: the sign picks the
  /// side, and the magnitude is how far in from that edge the badge sits,
  /// where 1 would be the centre of the page.
  ///
  /// Hand-authored rather than hashed off the index, because the two things
  /// that make this table work are the two a hash gets wrong. No magnitude
  /// passes 0.62, so a badge never reaches the middle — the caption lives in
  /// the column the badge is not using, and a marker parked in the centre
  /// leaves it nowhere to go and puts the line straight through it. And the
  /// sides deliberately do not strictly alternate: several pairs run the
  /// same way twice, which is what stops the route reading as a zigzag with
  /// a fixed period. Twenty-nine entries against twenty-eight markers, so a
  /// longer catalogue never wraps onto the same phase either.
  static const List<double> _lanes = [
    -0.04, 0.30, -0.46, 0.12, 0.58, -0.20, -0.62, 0.36,
    0.02, -0.34, 0.60, -0.08, 0.26, -0.54, 0.44, -0.16,
    0.10, -0.60, 0.52, 0.18, -0.30, 0.62, -0.42, 0.06,
    -0.24, 0.48, -0.12, 0.34, -0.50,
  ];

  static double _laneAt(int index) => _lanes[index % _lanes.length];

  /// Whether marker [index] stands in the left half, so its caption takes
  /// the right.
  static bool onLeftAt(int index) => _laneAt(index) < 0;

  /// How far marker [index] has wandered in from its edge, 0..1. The
  /// painter leans its control points by this, so a leg that travels a long
  /// way sideways is drawn with more slack than one that barely moves.
  static double laneReachAt(int index) =>
      (_laneAt(index).abs() / 0.62).clamp(0.0, 1.0);

  /// Where marker [index]'s badge is centred, in pixels.
  ///
  /// Two *sides*, not two columns. The badges used to sit hard against the
  /// same two x positions the whole way down, which reads as a ladder —
  /// correct about the order and silent about everything else. Letting each
  /// one wander in from its edge by its own amount turns the same
  /// information into a route that was walked rather than ruled, which is
  /// the whole conceit of the screen.
  ///
  /// The wander obeys the rule the two-column version was already obeying:
  /// a badge stays in its own half, because the caption has to fit in the
  /// other one. A serpentine through the middle was tried and was worse —
  /// with the badges near the centre their captions sat under them, in the
  /// same band the line had to cross to reach the next badge, so the route
  /// ran through its own labels.
  static double columnAt(int index, double width) {
    final lane = _laneAt(index);
    final rest = edge + discSize / 2;
    final reach = (width / 2 - rest).clamp(0.0, double.infinity);
    return lane < 0
        ? rest + lane.abs() * reach
        : width - rest - lane.abs() * reach;
  }

  @override
  State<MilestoneRoute> createState() => _MilestoneRouteState();
}

class _MilestoneRouteState extends State<MilestoneRoute>
    with TickerProviderStateMixin {
  /// The route drawing itself down the screen on arrival.
  late final AnimationController _draw = AnimationController(
    vsync: this,
    duration: TideMotion.routeDraw,
  );

  /// The lantern travelling to where the streak actually stands. Slower
  /// than the line on purpose: the route is context and arrives first, then
  /// the eye follows the one moving thing to the only part of the screen
  /// that is about *you*.
  late final AnimationController _travel = AnimationController(
    vsync: this,
    duration: TideMotion.routeTravel,
  );

  @override
  void initState() {
    super.initState();
    _draw.forward();
    Future<void>.delayed(const Duration(milliseconds: 240), () {
      if (mounted) _travel.forward();
    });
  }

  @override
  void didUpdateWidget(MilestoneRoute old) {
    super.didUpdateWidget(old);
    // A simulated unlock moves the destination while the screen is up. The
    // lantern re-runs the leg rather than teleporting.
    //
    // Keyed off the streak rather than off the status list: the store hands
    // out a freshly built list on every read, so comparing the lists would
    // restart the travel on any notification at all, including the one that
    // fires when a celebration is acknowledged.
    if (old.streak != widget.streak) {
      _travel
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _draw.dispose();
    _travel.dispose();
    super.dispose();
  }

  /// How far along the line the streak currently stands, 0..1.
  ///
  /// The line has a lead-in above the first marker and a run-out below the
  /// last, so marker *i* sits at `(i + 0.5) / n` — which is what lets the
  /// lantern show progress toward the very first milestone instead of
  /// starting pinned to it.
  double get _progress {
    final statuses = widget.statuses;
    final count = statuses.length;
    if (count == 0) return 0;

    // The first badge still locked, rather than the last one unlocked.
    // Those are the same index only while the unlocked badges form an
    // unbroken prefix, which the catalogue's ordering rule exists to
    // guarantee — but reading it this way means a badge that unlocks out of
    // turn costs one marker's worth of accuracy instead of throwing the
    // lantern to the end of the route.
    final next = statuses.indexWhere((status) => !status.unlocked);

    if (next < 0) return 1;
    if (next == 0) return (statuses.first.progress * 0.5) / count;
    return (next - 0.5 + statuses[next].progress) / count;
  }

  @override
  Widget build(BuildContext context) {
    final statuses = widget.statuses;
    final height = MilestoneRoute.stepHeight * statuses.length;

    // The first locked marker: the one the route is currently heading for,
    // and the only one that gets told how far away it is.
    final nextIndex = statuses.indexWhere((status) => !status.unlocked);

    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              Positioned.fill(
                child: RepaintBoundary(
                  child: AnimatedBuilder(
                    animation: Listenable.merge([_draw, _travel]),
                    builder: (context, _) => CustomPaint(
                      painter: _RoutePainter(
                        count: statuses.length,
                        drawn: TideMotion.routeCurve.transform(_draw.value),
                        travelled:
                            _progress *
                            TideMotion.routeTravelCurve.transform(
                              _travel.value,
                            ),
                      ),
                    ),
                  ),
                ),
              ),

              for (var i = 0; i < statuses.length; i++)
                Positioned(
                  left: 0,
                  right: 0,
                  top: MilestoneRoute.stepHeight * i,
                  height: MilestoneRoute.stepHeight,
                  child: _Marker(
                    status: statuses[i],
                    isNext: i == nextIndex,
                    onLeft: MilestoneRoute.onLeftAt(i),
                    column: MilestoneRoute.columnAt(i, constraints.maxWidth),
                    bandWidth: constraints.maxWidth,
                    remaining: statuses[i].milestone.threshold - widget.streak,
                    delay: TideMotion.routeDraw ~/ (statuses.length + 1) * i,
                    onTap: () => widget.onTap(statuses[i]),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// One marker on the route.
class _Marker extends StatefulWidget {
  const _Marker({
    required this.status,
    required this.isNext,
    required this.onLeft,
    required this.column,
    required this.bandWidth,
    required this.remaining,
    required this.delay,
    required this.onTap,
  });

  final MilestoneStatus status;

  /// The next one to fall. It carries the ring and the distance.
  final bool isNext;

  /// Which half the badge stands in. The caption takes the other one.
  final bool onLeft;

  /// The badge's centre, in pixels across the band — wherever the route's
  /// lane table put it.
  final double column;

  final double bandWidth;

  /// Days still to go. Only shown on [isNext].
  final int remaining;

  final Duration delay;
  final VoidCallback onTap;

  @override
  State<_Marker> createState() => _MarkerState();
}

class _MarkerState extends State<_Marker> with SingleTickerProviderStateMixin {
  late final AnimationController _in = AnimationController(
    vsync: this,
    duration: TideMotion.staggerItem,
  );

  @override
  void initState() {
    super.initState();
    // Each marker arrives as the line reaches it, so the route reads as
    // being drawn *through* them rather than as a list fading in behind a
    // decoration.
    Future<void>.delayed(widget.delay, () {
      if (mounted) _in.forward();
    });
  }

  @override
  void dispose() {
    _in.dispose();
    super.dispose();
  }

  /// How far in the caption's block begins, measured from the same edge the
  /// badge is standing against: past the disc, plus its air.
  double get _labelStart {
    final clear = MilestoneRoute.discSize / 2 + MilestoneRoute.labelGap;
    return widget.onLeft
        ? widget.column + clear
        : widget.bandWidth - widget.column + clear;
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.status;
    final unlocked = status.unlocked;

    final accent = unlocked
        ? TideColors.lantern
        : widget.isNext
        ? TideColors.bone.withValues(alpha: 0.7)
        : TideColors.drained(TideColors.lantern, 0.85);

    final caption = unlocked
        ? status.milestone.caption
        : widget.isNext && widget.remaining > 0
        ? '${widget.remaining} to go'
        : status.milestone.caption;

    return FadeTransition(
      opacity: CurvedAnimation(parent: _in, curve: TideMotion.staggerCurve),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.10),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: _in, curve: TideMotion.staggerCurve)),
        child: PressScale(
          onTap: unlocked ? widget.onTap : null,
          enabled: unlocked,
          // A stack rather than the two-cell row this used to be. A row can
          // only put the badge in one of two places — hard left or hard
          // right — which was the whole reason the route was a zigzag. The
          // badge is placed at its own x here, and the caption is measured
          // off the badge rather than off the page, so a marker that has
          // wandered a long way in neither leaves a gap its label fails to
          // fill nor runs its label underneath itself.
          child: SizedBox.expand(
            child: Stack(
              children: [
                Positioned(
                  top: 0,
                  bottom: 0,
                  left: widget.onLeft ? _labelStart : MilestoneRoute.edge,
                  right: widget.onLeft ? MilestoneRoute.edge : _labelStart,
                  child: Align(
                    alignment: widget.onLeft
                        ? Alignment.centerLeft
                        : Alignment.centerRight,
                    child: _Label(
                      status: status,
                      caption: caption,
                      unlocked: unlocked,
                      isNext: widget.isNext,
                      alignEnd: !widget.onLeft,
                    ),
                  ),
                ),
                Positioned(
                  left: widget.column - MilestoneRoute.discSize / 2,
                  top:
                      (MilestoneRoute.stepHeight - MilestoneRoute.discSize) / 2,
                  width: MilestoneRoute.discSize,
                  height: MilestoneRoute.discSize,
                  child: _Disc(
                    status: status,
                    isNext: widget.isNext,
                    accent: accent,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A marker's name and its distance, in the column the badge is not using.
class _Label extends StatelessWidget {
  const _Label({
    required this.status,
    required this.caption,
    required this.unlocked,
    required this.isNext,
    required this.alignEnd,
  });

  final MilestoneStatus status;
  final String caption;
  final bool unlocked;
  final bool isNext;

  /// True when the badge is on the right, so the text runs back toward it.
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          status.milestone.name,
          style: TideType.heading.copyWith(
            color: unlocked || isNext ? TideColors.bone : TideColors.silt,
          ),
          textAlign: alignEnd ? TextAlign.right : TextAlign.left,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 5),
        Text(
          caption,
          style: TideType.gauge(
            12,
            color: unlocked ? TideColors.lantern : TideColors.silt,
          ),
        ),
      ],
    );
  }
}

/// The badge disc: solid once surfaced, an open ring while it is the one
/// being headed for, and a bare outline for everything further out.
class _Disc extends StatelessWidget {
  const _Disc({
    required this.status,
    required this.isNext,
    required this.accent,
  });

  final MilestoneStatus status;
  final bool isNext;
  final Color accent;

  static const double _size = MilestoneRoute.discSize;

  @override
  Widget build(BuildContext context) {
    final unlocked = status.unlocked;

    if (isNext && !unlocked) {
      // The one milestone whose progress is worth drawing: the ring is the
      // same instrument as a habit card's, filling toward the next marker.
      return Container(
        width: _size,
        height: _size,
        alignment: Alignment.center,
        // Same opaque ground as the other badges, so the line stops at the
        // marker rather than crossing the ring that is measuring it.
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: TideColors.deepWater,
        ),
        child: TideRing(
          progress: status.progress,
          size: _size,
          strokeWidth: 2.5,
          color: TideColors.lantern,
          child: HabitGlyph(
            glyph: status.milestone.glyph,
            size: 22,
            color: accent,
            strokeWidth: 1.8,
          ),
        ),
      );
    }

    return Container(
      width: _size,
      height: _size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        // Opaque, both states. A translucent fill let the route line show
        // straight through the badge it was supposed to be passing behind,
        // so every surfaced marker had a wire running across its face.
        color: unlocked
            ? Color.lerp(TideColors.deepWater, TideColors.lantern, 0.14)
            : TideColors.trench,
        border: Border.all(
          color: unlocked
              ? TideColors.lantern.withValues(alpha: 0.8)
              : TideColors.hairline,
          width: unlocked ? 2 : 1,
        ),
      ),
      child: HabitGlyph(
        glyph: status.milestone.glyph,
        size: 22,
        color: accent,
        strokeWidth: 1.8,
      ),
    );
  }
}

/// The line itself: the whole route in outline, the covered part lit, and
/// the lantern at the head of it.
class _RoutePainter extends CustomPainter {
  const _RoutePainter({
    required this.count,
    required this.drawn,
    required this.travelled,
  });

  final int count;

  /// 0..1 of the outline that has been drawn in.
  final double drawn;

  /// 0..1 of the route that has been covered.
  final double travelled;

  /// The marker sits centred in its band, so the line's waypoint is simply
  /// half a step down from the band's top.
  static const double _discCentre = MilestoneRoute.stepHeight / 2;

  /// One control point's pull, as a fraction of a step. Capped so that any
  /// two of them together stay under a whole step.
  static double _slackAt(int index) =>
      0.28 + 0.19 * MilestoneRoute.laneReachAt(index);

  Path _buildPath(Size size) {
    final points = <Offset>[
      for (var i = 0; i < count; i++)
        Offset(
          MilestoneRoute.columnAt(i, size.width),
          MilestoneRoute.stepHeight * i + _discCentre,
        ),
    ];

    // A lead-in above the first marker and a run-out below the last, so the
    // line does not begin and end abruptly inside two badges.
    final first = points.first;
    final last = points.last;
    final path = Path()..moveTo(first.dx, first.dy - _discCentre);

    path.lineTo(first.dx, first.dy);
    for (var i = 0; i < points.length - 1; i++) {
      final a = points[i];
      final b = points[i + 1];
      // A pair of vertical-tangent control points: the line leaves each
      // badge going straight down and arrives at the next one the same way,
      // which is what keeps the curve from crowding the labels.
      //
      // The two lean by different amounts, and by an amount tied to how far
      // that particular leg has to travel sideways. A fixed 0.45 on both
      // ends drew the same S-bend twenty-seven times over, which is a motif
      // rather than a path. They stay well short of summing to a whole
      // step, so the line never doubles back on itself vertically — messy
      // is the look, a kink is a bug.
      path.cubicTo(
        a.dx,
        a.dy + MilestoneRoute.stepHeight * _slackAt(i),
        b.dx,
        b.dy - MilestoneRoute.stepHeight * _slackAt(i + 7),
        b.dx,
        b.dy,
      );
    }
    // A short run-out, not a full step: a tail as long as the lead-in
    // dangles down past the last marker and into whatever is under the
    // route.
    path.lineTo(last.dx, last.dy + MilestoneRoute.discSize * 0.6);

    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (count == 0) return;

    final path = _buildPath(size);
    final metrics = path.computeMetrics().toList();
    if (metrics.isEmpty) return;

    final metric = metrics.first;
    final length = metric.length;

    // The outline, drawing itself downward.
    canvas.drawPath(
      metric.extractPath(0, length * drawn.clamp(0.0, 1.0)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..color = TideColors.bone.withValues(alpha: 0.10),
    );

    final covered = length * travelled.clamp(0.0, 1.0);
    if (covered <= 0) return;

    // The part already walked.
    canvas.drawPath(
      metric.extractPath(0, covered),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..color = TideColors.lantern.withValues(alpha: 0.65),
    );

    // And the lantern at the head of it — the only thing on this screen
    // that says where *you* are rather than what exists.
    final head = metric.getTangentForOffset(covered)?.position;
    if (head == null) return;

    canvas.drawCircle(
      head,
      9,
      Paint()..color = TideColors.lantern.withValues(alpha: 0.16),
    );
    canvas.drawCircle(head, 4.5, Paint()..color = TideColors.lantern);
  }

  @override
  bool shouldRepaint(_RoutePainter old) =>
      old.drawn != drawn || old.travelled != travelled || old.count != count;
}
