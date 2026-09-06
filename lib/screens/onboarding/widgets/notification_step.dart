import 'package:flutter/material.dart';

import '../../../theme/tide_colors.dart';
import '../../../theme/tide_elevation.dart';
import '../../../theme/tide_motion.dart';
import '../../../theme/tide_typography.dart';
import '../../../widgets/habit_glyph.dart';
import '../../../services/models/tide_glyph.dart';

/// Step four: ask for notifications, honestly.
///
/// The mock bubble shows the real copy, with the user's own habit name in
/// it, *before* the OS dialog appears. Asking for permission to send
/// something the user has not seen is how apps end up permanently denied;
/// showing it first costs one screen and earns the yes.
class NotificationStep extends StatelessWidget {
  const NotificationStep({
    super.key,
    required this.habitName,
    required this.glyph,
    required this.time,
  });

  final String habitName;
  final TideGlyph glyph;
  final TimeOfDay time;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('One nudge a day', style: TideType.hero),
        const SizedBox(height: 10),
        Text(
          'This is exactly what it will look like. Nothing else, and never '
          'more than once per habit.',
          style: TideType.bodyMuted,
        ),
        const Spacer(),
        _MockNotification(habitName: habitName, glyph: glyph, time: time),
        const Spacer(flex: 2),
      ],
    );
  }
}

/// The preview bubble. Drifts gently in on load so it reads as a
/// notification arriving rather than a static screenshot of one.
class _MockNotification extends StatefulWidget {
  const _MockNotification({
    required this.habitName,
    required this.glyph,
    required this.time,
  });

  final String habitName;
  final TideGlyph glyph;
  final TimeOfDay time;

  @override
  State<_MockNotification> createState() => _MockNotificationState();
}

class _MockNotificationState extends State<_MockNotification>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: TideMotion.sheetIn,
  );

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 260), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curve = CurvedAnimation(
      parent: _controller,
      curve: TideMotion.overshoot,
    );

    return AnimatedBuilder(
      animation: curve,
      builder: (context, child) {
        return Opacity(
          opacity: _controller.value.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, -18 * (1 - curve.value)),
            child: child,
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: TideColors.shoal,
          borderRadius: TideElevation.radius20,
          boxShadow: TideElevation.floating,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: TideColors.lantern.withValues(alpha: 0.18),
                borderRadius: TideElevation.radius12,
              ),
              child: Center(child: HabitGlyph(glyph: widget.glyph, size: 15)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text('Tide', style: TideType.label)),
                      Text(
                        '${widget.time.hour.toString().padLeft(2, '0')}:'
                        '${widget.time.minute.toString().padLeft(2, '0')}',
                        style: TideType.gauge(11, color: TideColors.silt),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${widget.habitName} — day 1 of your streak.',
                    style: TideType.bodyMuted.copyWith(fontSize: 13.5),
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
