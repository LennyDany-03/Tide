import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../config/app_constants.dart';
import '../../../services/reminders/reminder_plan.dart';
import '../../../theme/tide_colors.dart';
import '../../../theme/tide_typography.dart';

/// The last seven days as a row of small waves: full where the habit was
/// kept, frost where a freeze held it, a faint outline where it was missed,
/// a dot where nothing was asked, and today's still open.
///
/// Waves rather than the dots and cells the rest of the app uses, because
/// this is the one screen whose whole vocabulary is water.
class WaveMarks extends StatelessWidget {
  const WaveMarks({super.key, required this.marks, required this.lastDay});

  /// Oldest first, seven of them.
  final List<WeekMark> marks;

  /// The day the last mark stands for.
  final DateTime lastDay;

  static List<WeekMark> parse(Object? raw) {
    if (raw is! List) return const [];
    return [
      for (final value in raw)
        if (value is int && value >= 0 && value < WeekMark.values.length)
          WeekMark.values[value],
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (marks.isEmpty) return const SizedBox.shrink();
    final kept = marks.where((m) => m == WeekMark.kept).length;
    return Semantics(
      label: '$kept of the last ${marks.length} days kept',
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < marks.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CustomPaint(
                      size: const Size(22, 12),
                      painter: _MarkPainter(marks[i]),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      AppConstants.weekdayInitials[lastDay
                              .subtract(Duration(days: marks.length - 1 - i))
                              .weekday -
                          1],
                      style: TideType.labelMuted.copyWith(fontSize: 10.5),
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

class _MarkPainter extends CustomPainter {
  const _MarkPainter(this.mark);

  final WeekMark mark;

  Path _wave(Size size) {
    final path = Path()..moveTo(0, size.height * 0.6);
    const steps = 16;
    for (var i = 0; i <= steps; i++) {
      final u = i / steps;
      path.lineTo(
        size.width * u,
        size.height * 0.55 - math.sin(u * 2 * math.pi) * size.height * 0.3,
      );
    }
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    switch (mark) {
      case WeekMark.rest:
        canvas.drawCircle(
          size.center(Offset.zero),
          1.6,
          Paint()..color = TideColors.silt.withValues(alpha: 0.5),
        );
      case WeekMark.kept:
      case WeekMark.frozen:
        final color = mark == WeekMark.kept
            ? TideColors.lantern
            : TideColors.frost;
        final crest = _wave(size);
        final body = Path.from(crest)
          ..lineTo(size.width, size.height)
          ..lineTo(0, size.height)
          ..close();
        canvas.drawPath(body, Paint()..color = color.withValues(alpha: 0.35));
        canvas.drawPath(
          crest,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..strokeCap = StrokeCap.round
            ..color = color,
        );
      case WeekMark.missed:
      case WeekMark.open:
        canvas.drawPath(
          _wave(size),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = mark == WeekMark.open ? 1.8 : 1.4
            ..strokeCap = StrokeCap.round
            ..color = mark == WeekMark.open
                ? TideColors.lantern.withValues(alpha: 0.7)
                : TideColors.silt.withValues(alpha: 0.45),
        );
    }
  }

  @override
  bool shouldRepaint(_MarkPainter old) => old.mark != mark;
}
