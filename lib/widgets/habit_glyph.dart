import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/models/tide_glyph.dart';
import '../theme/tide_colors.dart';

/// Draws the abstract glyph set.
///
/// Painted rather than shipped as an icon font so the shapes inherit the
/// exact stroke weight of the rings beside them — a habit card's glyph and
/// its progress ring are the same instrument, drawn at the same weight.
class HabitGlyph extends StatelessWidget {
  const HabitGlyph({
    super.key,
    required this.glyph,
    this.size = 16,
    this.color,
    this.strokeWidth = 1.6,
  });

  final TideGlyph glyph;
  final double size;
  final Color? color;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _GlyphPainter(
          glyph: glyph,
          color: color ?? TideColors.lantern,
          strokeWidth: strokeWidth,
        ),
      ),
    );
  }
}

class _GlyphPainter extends CustomPainter {
  const _GlyphPainter({
    required this.glyph,
    required this.color,
    required this.strokeWidth,
  });

  final TideGlyph glyph;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = math.min(size.width, size.height) / 2;

    final fill = Paint()
      ..style = PaintingStyle.fill
      ..color = color
      ..isAntiAlias = true;

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeJoin = StrokeJoin.round
      ..color = color
      ..isAntiAlias = true;

    switch (glyph) {
      case TideGlyph.dot:
        canvas.drawCircle(center, radius * 0.42, fill);

      case TideGlyph.ring:
        canvas.drawCircle(center, radius - strokeWidth / 2, stroke);

      case TideGlyph.crescent:
        // The contrast circle: outlined, with the left half filled.
        final circle = Rect.fromCircle(
          center: center,
          radius: radius - strokeWidth / 2,
        );
        canvas.drawArc(circle, math.pi / 2, math.pi, true, fill);
        canvas.drawCircle(center, radius - strokeWidth / 2, stroke);

      case TideGlyph.halfMoon:
        final circle = Rect.fromCircle(
          center: center,
          radius: radius - strokeWidth / 2,
        );
        canvas.drawArc(circle, 0, math.pi, true, fill);
        canvas.drawCircle(center, radius - strokeWidth / 2, stroke);

      case TideGlyph.striped:
        // A circle ruled with vertical bars — the "full moon" badge.
        final circle = Rect.fromCircle(
          center: center,
          radius: radius - strokeWidth / 2,
        );
        canvas.save();
        canvas.clipPath(Path()..addOval(circle));
        final gap = size.width / 6;
        for (var x = gap / 2; x < size.width; x += gap) {
          canvas.drawLine(
            Offset(x, 0),
            Offset(x, size.height),
            Paint()
              ..color = color
              ..strokeWidth = gap * 0.42,
          );
        }
        canvas.restore();
        canvas.drawCircle(center, radius - strokeWidth / 2, stroke);

      case TideGlyph.lines:
        // Stacked rules, like text on a page.
        final inset = size.width * 0.16;
        final rows = 4;
        final spacing = (size.height - inset * 2) / (rows - 1);
        for (var i = 0; i < rows; i++) {
          final y = inset + spacing * i;
          final shorten = i == rows - 1 ? size.width * 0.28 : 0.0;
          canvas.drawLine(
            Offset(inset, y),
            Offset(size.width - inset - shorten, y),
            Paint()
              ..color = color
              ..strokeWidth = strokeWidth
              ..strokeCap = StrokeCap.round,
          );
        }

      case TideGlyph.peak:
        final path = Path()
          ..moveTo(center.dx, size.height * 0.2)
          ..lineTo(size.width * 0.82, size.height * 0.78)
          ..lineTo(size.width * 0.18, size.height * 0.78)
          ..close();
        canvas.drawPath(path, fill);

      case TideGlyph.diamond:
        canvas.drawPath(_diamond(rect, 0.5), fill);

      case TideGlyph.diamondOutline:
        canvas.drawPath(_diamond(rect, 0.5 - strokeWidth / size.width), stroke);

      case TideGlyph.square:
        final side = size.width * 0.56;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: center, width: side, height: side),
            const Radius.circular(2),
          ),
          fill,
        );

      case TideGlyph.hexagon:
        final path = Path();
        for (var i = 0; i < 6; i++) {
          final angle = math.pi / 3 * i - math.pi / 2;
          final point = Offset(
            center.dx + (radius - strokeWidth) * math.cos(angle),
            center.dy + (radius - strokeWidth) * math.sin(angle),
          );
          i == 0
              ? path.moveTo(point.dx, point.dy)
              : path.lineTo(point.dx, point.dy);
        }
        path.close();
        canvas.drawPath(path, stroke);

      case TideGlyph.sparkle:
        // A four-point star with concave sides — the rarest badges.
        final path = Path();
        const points = 4;
        for (var i = 0; i < points * 2; i++) {
          final isOuter = i.isEven;
          final r = isOuter ? radius : radius * 0.34;
          final angle = math.pi / points * i - math.pi / 2;
          final point = Offset(
            center.dx + r * math.cos(angle),
            center.dy + r * math.sin(angle),
          );
          i == 0
              ? path.moveTo(point.dx, point.dy)
              : path.lineTo(point.dx, point.dy);
        }
        path.close();
        canvas.drawPath(path, fill);
    }
  }

  Path _diamond(Rect rect, double scale) {
    final center = rect.center;
    final dx = rect.width * scale;
    final dy = rect.height * scale;
    return Path()
      ..moveTo(center.dx, center.dy - dy)
      ..lineTo(center.dx + dx, center.dy)
      ..lineTo(center.dx, center.dy + dy)
      ..lineTo(center.dx - dx, center.dy)
      ..close();
  }

  @override
  bool shouldRepaint(_GlyphPainter old) =>
      old.glyph != glyph ||
      old.color != color ||
      old.strokeWidth != strokeWidth;
}
