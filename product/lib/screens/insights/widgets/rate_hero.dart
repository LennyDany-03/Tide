import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../theme/tide_colors.dart';
import '../../../theme/tide_motion.dart';
import '../../../theme/tide_typography.dart';
import '../../../widgets/gauge_number.dart';

/// This week's completion, as an arc that sweeps to it.
///
/// The figure alone was doing the whole job, and it is a good figure — but
/// a percentage on open ground is a number you have to convert into a
/// feeling before it means anything. An arc filling four-fifths of the way
/// round has already done that conversion by the time you have read the
/// digits.
///
/// The arc is a three-quarter sweep rather than a full ring, opening at the
/// bottom. A closed ring is the habit-card object and means "this one thing,
/// today"; leaving it open keeps that reading for the cards and gives the
/// week its own shape.
class RateHero extends StatefulWidget {
  const RateHero({
    super.key,
    required this.rate,
    required this.previousRate,
  });

  final double rate;
  final double previousRate;

  static const double size = 108;

  @override
  State<RateHero> createState() => _RateHeroState();
}

class _RateHeroState extends State<RateHero>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sweep = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  );

  int get _delta => ((widget.rate - widget.previousRate) * 100).round();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _sweep.forward();
    });
  }

  @override
  void didUpdateWidget(RateHero old) {
    super.didUpdateWidget(old);
    // Logging something while the screen is up genuinely moves the week.
    if (old.rate != widget.rate) {
      _sweep
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: RateHero.size,
          height: RateHero.size,
          child: RepaintBoundary(
            child: AnimatedBuilder(
              animation: _sweep,
              builder: (context, child) => CustomPaint(
                painter: _ArcPainter(
                  value:
                      widget.rate *
                      TideMotion.routeCurve.transform(_sweep.value),
                ),
                child: child,
              ),
              child: Center(
                child: GaugeCountUp(
                  value: (widget.rate * 100).round(),
                  style: TideType.gauge(30, letterSpacing: -1.4),
                  suffix: '%',
                  suffixStyle: TideType.gauge(14, color: TideColors.silt),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Completed this week', style: TideType.heading),
              const SizedBox(height: 10),
              _DeltaPill(delta: _delta, hadPrevious: widget.previousRate > 0),
            ],
          ),
        ),
      ],
    );
  }
}

/// The change on last week, as a chip rather than a clause.
///
/// It used to run on from the caption — "completed this week, up 13 points
/// on last" — where the one number anybody scans for was the fourth thing
/// in a sentence set in muted grey.
class _DeltaPill extends StatelessWidget {
  const _DeltaPill({required this.delta, required this.hadPrevious});

  final int delta;

  /// A first week has nothing to be up or down on, and saying "level with
  /// last" about a week that did not exist is a small lie.
  final bool hadPrevious;

  @override
  Widget build(BuildContext context) {
    if (!hadPrevious) {
      return Text('Your first week of this', style: TideType.labelMuted);
    }

    final (icon, tint, words) = switch (delta) {
      > 0 => (
        Icons.arrow_upward_rounded,
        TideColors.lantern,
        '$delta ${delta.abs() == 1 ? 'point' : 'points'} on last week',
      ),
      < 0 => (
        Icons.arrow_downward_rounded,
        TideColors.coral,
        '${delta.abs()} ${delta.abs() == 1 ? 'point' : 'points'} on last week',
      ),
      _ => (
        Icons.remove_rounded,
        TideColors.silt,
        'Level with last week',
      ),
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: tint.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 14, color: tint),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            words,
            style: TideType.labelMuted,
            maxLines: 2,
          ),
        ),
      ],
    );
  }
}

/// The open arc, its track, and the head of the sweep.
class _ArcPainter extends CustomPainter {
  const _ArcPainter({required this.value});

  /// 0..1 of the arc, already eased.
  final double value;

  /// Three quarters of a turn, opening at the bottom.
  static const double _sweep = math.pi * 1.5;
  static const double _start = math.pi * 0.75;

  static const double _stroke = 7;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: size.shortestSide / 2 - _stroke / 2,
    );

    canvas.drawArc(
      rect,
      _start,
      _sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _stroke
        ..strokeCap = StrokeCap.round
        ..color = TideColors.bone.withValues(alpha: 0.07),
    );

    final travelled = _sweep * value.clamp(0.0, 1.0);
    if (travelled <= 0) return;

    canvas.drawArc(
      rect,
      _start,
      travelled,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _stroke
        ..strokeCap = StrokeCap.round
        // Graded round the sweep, so the arc has a beginning and an end
        // rather than reading as a ring somebody rubbed part of out.
        ..shader = SweepGradient(
          startAngle: _start,
          endAngle: _start + _sweep,
          colors: [
            TideColors.lantern.withValues(alpha: 0.45),
            TideColors.lantern,
          ],
          transform: GradientRotation(_start),
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_ArcPainter old) => old.value != value;
}
