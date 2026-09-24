import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../services/reminders/reminder_platform.dart';
import '../../../theme/tide_colors.dart';
import '../../../theme/tide_gradients.dart';
import '../../../theme/tide_motion.dart';

/// A small drawing of what each permission is for, in the app's water and
/// nothing pictographic:
///
/// * notifications — a drop landing, and the rings it sends out;
/// * exact alarms — a dial whose water rises to meet the mark at the top;
/// * full-screen alerts — a screen filling from the bottom;
/// * background running — a vessel whose level holds while bubbles keep
///   rising through it.
///
/// Each loops slowly. Reduced motion holds the last frame of the loop, which
/// is the one that says it best.
class PermissionArt extends StatefulWidget {
  const PermissionArt({super.key, required this.permission, this.size = 104});

  /// Null draws the summary: a full ring.
  final ReminderPermission? permission;
  final double size;

  @override
  State<PermissionArt> createState() => _PermissionArtState();
}

class _PermissionArtState extends State<PermissionArt>
    with SingleTickerProviderStateMixin {
  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: TideMotion.breathe,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _loop
        ..stop()
        ..value = 0.85;
    } else if (!_loop.isAnimating) {
      _loop.repeat();
    }
  }

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: widget.size,
        child: CustomPaint(
          painter: _ArtPainter(permission: widget.permission, loop: _loop),
        ),
      ),
    );
  }
}

class _ArtPainter extends CustomPainter {
  _ArtPainter({required this.permission, required this.loop})
    : super(repaint: loop);

  final ReminderPermission? permission;
  final Animation<double> loop;

  Paint get _stroke => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.4
    ..strokeCap = StrokeCap.round
    ..color = TideColors.lantern;

  @override
  void paint(Canvas canvas, Size size) {
    final t = loop.value;
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;

    // The same soft light behind every one of them.
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = TideGradients.bloom(
          color: TideColors.lantern,
          alpha: 0.14,
          center: Alignment.center,
          radius: 0.5,
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );

    switch (permission) {
      case ReminderPermission.notifications:
        _drop(canvas, c, r, t);
      case ReminderPermission.exactAlarms:
        _dial(canvas, c, r, t);
      case ReminderPermission.fullScreen:
        _screen(canvas, c, r, t);
      case ReminderPermission.battery:
        _vessel(canvas, c, r, t);
      case null:
        _full(canvas, c, r, t);
    }
  }

  void _water(Canvas canvas, Rect box, double level, double t) {
    final surface = box.bottom - box.height * level.clamp(0.0, 1.0);
    final path = Path()..moveTo(box.left, surface);
    const steps = 24;
    for (var i = 0; i <= steps; i++) {
      final u = i / steps;
      path.lineTo(
        box.left + box.width * u,
        surface + math.sin(u * math.pi * 2 + t * 2 * math.pi) * 2.2,
      );
    }
    path
      ..lineTo(box.right, box.bottom)
      ..lineTo(box.left, box.bottom)
      ..close();
    canvas.drawPath(
      path,
      Paint()..color = TideColors.lantern.withValues(alpha: 0.32),
    );
  }

  void _drop(Canvas canvas, Offset c, double r, double t) {
    final waterline = c.dy + r * 0.3;
    // The drop falls for the first third, then the rings go out.
    if (t < 0.33) {
      final y = c.dy - r * 0.7 + (waterline - c.dy + r * 0.7) * (t / 0.33);
      final drop = Path()
        ..moveTo(c.dx, y - 9)
        ..quadraticBezierTo(c.dx + 7, y + 2, c.dx, y + 6)
        ..quadraticBezierTo(c.dx - 7, y + 2, c.dx, y - 9);
      canvas.drawPath(drop, Paint()..color = TideColors.lantern);
    } else {
      final spread = (t - 0.33) / 0.67;
      for (var i = 0; i < 3; i++) {
        final p = (spread - i * 0.18).clamp(0.0, 1.0);
        if (p <= 0) continue;
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(c.dx, waterline),
            width: r * 1.7 * p,
            height: r * 0.42 * p,
          ),
          _stroke
            ..strokeWidth = 2
            ..color = TideColors.lantern.withValues(alpha: 1 - p),
        );
      }
    }
    canvas.drawLine(
      Offset(c.dx - r * 0.85, waterline),
      Offset(c.dx + r * 0.85, waterline),
      _stroke..color = TideColors.lantern.withValues(alpha: 0.35),
    );
  }

  void _dial(Canvas canvas, Offset c, double r, double t) {
    final face = Rect.fromCircle(center: c, radius: r * 0.62);
    canvas.save();
    canvas.clipPath(Path()..addOval(face));
    _water(canvas, face, Curves.easeInOut.transform(t), t);
    canvas.restore();
    canvas.drawOval(face, _stroke);
    // The mark at the top the water rises to meet.
    canvas.drawLine(
      Offset(c.dx, face.top - 8),
      Offset(c.dx, face.top + 6),
      _stroke..strokeWidth = 3,
    );
  }

  void _screen(Canvas canvas, Offset c, double r, double t) {
    final phone = Rect.fromCenter(center: c, width: r * 0.95, height: r * 1.55);
    final rounded = RRect.fromRectAndRadius(phone, const Radius.circular(12));
    canvas.save();
    canvas.clipRRect(rounded);
    _water(canvas, phone, Curves.easeOut.transform(t), t);
    canvas.restore();
    canvas.drawRRect(rounded, _stroke);
  }

  void _vessel(Canvas canvas, Offset c, double r, double t) {
    final vessel = Rect.fromCenter(center: c, width: r * 0.8, height: r * 1.4);
    final rounded = RRect.fromRectAndRadius(vessel, Radius.circular(r * 0.4));
    canvas.save();
    canvas.clipRRect(rounded);
    _water(canvas, vessel, 0.62, t);
    for (var i = 0; i < 4; i++) {
      final p = (t + i / 4) % 1;
      canvas.drawCircle(
        Offset(
          vessel.left + vessel.width * (0.25 + 0.17 * i),
          vessel.bottom - vessel.height * 0.6 * p,
        ),
        2.2,
        Paint()..color = TideColors.lantern.withValues(alpha: 0.8 * (1 - p)),
      );
    }
    canvas.restore();
    canvas.drawRRect(rounded, _stroke);
  }

  void _full(Canvas canvas, Offset c, double r, double t) {
    final ring = Rect.fromCircle(center: c, radius: r * 0.62);
    canvas.save();
    canvas.clipPath(Path()..addOval(ring));
    _water(canvas, ring, 0.92, t);
    canvas.restore();
    canvas.drawOval(ring, _stroke);
  }

  @override
  bool shouldRepaint(_ArtPainter old) =>
      old.permission != permission || old.loop != loop;
}
