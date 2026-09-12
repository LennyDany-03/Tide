import 'package:flutter/material.dart';

import '../../../theme/tide_colors.dart';
import '../../../theme/tide_motion.dart';
import '../../../widgets/tide_tick.dart';

/// The envelope the code went out in, and the tick it becomes.
///
/// Drawn in the logo's own line: one lantern stroke, round caps, drawing
/// itself in rather than appearing. Once it is closed, a lit point sets off
/// round its edge and keeps going — the same point that orbits the mark on
/// the splash, saying the same thing here: the loop is still running while
/// the code is on its way.
///
/// When the code is accepted the envelope does not cut to a checkmark. It
/// shrinks away as a ring draws round the space it left, the tick draws
/// through the ring, and two rings leave it — the splash's reading of "it
/// landed". The ring and tick are [TideTick], shared with the farewell after
/// an account is deleted.
class MailMark extends StatefulWidget {
  const MailMark({super.key, required this.accepted, this.size = 84});

  /// 0..1 through the acceptance. Owned by the screen, because the cells
  /// light on the same clock.
  final Animation<double> accepted;

  final double size;

  @override
  State<MailMark> createState() => _MailMarkState();
}

class _MailMarkState extends State<MailMark> with TickerProviderStateMixin {
  late final AnimationController _draw = AnimationController(
    vsync: this,
    duration: TideMotion.mailDraw,
  );

  late final AnimationController _orbit = AnimationController(
    vsync: this,
    duration: TideMotion.orbit,
  );

  @override
  void initState() {
    super.initState();
    widget.accepted.addListener(_onAccepted);
    _draw.forward().whenComplete(() {
      if (mounted && widget.accepted.value == 0) _orbit.repeat();
    });
  }

  @override
  void didUpdateWidget(MailMark old) {
    super.didUpdateWidget(old);
    if (old.accepted != widget.accepted) {
      old.accepted.removeListener(_onAccepted);
      widget.accepted.addListener(_onAccepted);
    }
  }

  /// The point stops where it is once the tick starts; it has nothing left
  /// to wait for.
  void _onAccepted() {
    if (widget.accepted.value > 0 && _orbit.isAnimating) _orbit.stop();
  }

  @override
  void dispose() {
    widget.accepted.removeListener(_onAccepted);
    _draw.dispose();
    _orbit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: widget.size,
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _MailPainter(
            draw: _draw,
            orbit: _orbit,
            accepted: widget.accepted,
            lantern: TideColors.lantern,
          ),
        ),
      ),
    );
  }
}

class _MailPainter extends CustomPainter {
  _MailPainter({
    required this.draw,
    required this.orbit,
    required this.accepted,
    required this.lantern,
  }) : super(repaint: Listenable.merge([draw, orbit, accepted]));

  final Animation<double> draw;
  final Animation<double> orbit;
  final Animation<double> accepted;
  final Color lantern;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final c = size.center(Offset.zero);
    final stroke = s * 0.04;
    final d = draw.value;
    final a = accepted.value;

    Paint line(double alpha) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = lantern.withValues(alpha: alpha);

    // --- The envelope, leaving as the tick arrives ------------------------
    final leave = TideTick.span(a, 0, 0.35);
    if (leave < 1) {
      final body = Rect.fromCenter(
        center: c.translate(0, s * 0.02),
        width: s * 0.78,
        height: s * 0.54,
      );
      final corner = Radius.circular(s * 0.07);
      final outline = Path()..addRRect(RRect.fromRectAndRadius(body, corner));
      final inset = s * 0.045;
      final flap = Path()
        ..moveTo(body.left + inset, body.top + inset)
        ..lineTo(c.dx, body.top + body.height * 0.55)
        ..lineTo(body.right - inset, body.top + inset);

      final alpha = 1 - leave;
      canvas
        ..save()
        ..translate(c.dx, c.dy)
        ..scale(1 - 0.3 * leave)
        ..translate(-c.dx, -c.dy);

      final fill = TideTick.span(d, 0.35, 1);
      if (fill > 0) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(body, corner),
          Paint()..color = lantern.withValues(alpha: 0.08 * fill * alpha),
        );
      }
      canvas
        ..drawPath(
          TideTick.trace(outline, TideTick.span(d, 0, 0.65)),
          line(alpha),
        )
        ..drawPath(
          TideTick.trace(flap, TideTick.span(d, 0.45, 0.9)),
          line(alpha),
        );

      final point = TideTick.span(d, 0.85, 1) * alpha;
      if (point > 0) {
        final metric = outline.computeMetrics().first;
        final at = metric
            .getTangentForOffset(metric.length * orbit.value)
            ?.position;
        if (at != null) {
          canvas
            ..drawCircle(
              at,
              stroke * 2.4,
              Paint()..color = lantern.withValues(alpha: 0.18 * point),
            )
            ..drawCircle(
              at,
              stroke * 0.95,
              Paint()..color = lantern.withValues(alpha: point),
            );
        }
      }
      canvas.restore();
    }

    // --- The ring and the tick --------------------------------------------
    TideTick.paint(canvas, size, a, lantern);
  }

  @override
  bool shouldRepaint(_MailPainter old) =>
      old.lantern != lantern ||
      old.draw != draw ||
      old.orbit != orbit ||
      old.accepted != accepted;
}
