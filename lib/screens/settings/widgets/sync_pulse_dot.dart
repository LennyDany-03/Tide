import 'package:flutter/material.dart';

import '../../../theme/tide_colors.dart';
import '../../../theme/tide_motion.dart';
import '../../../theme/tide_typography.dart';

/// The sync indicator: a slowly pulsing dot, never a spinner.
///
/// A spinner would imply the user is waiting on something. Sync is
/// background work that already happened, so it gets a heartbeat instead —
/// present, calm, not asking for attention.
class SyncPulseDot extends StatefulWidget {
  const SyncPulseDot({super.key, required this.lastSync});

  final DateTime lastSync;

  @override
  State<SyncPulseDot> createState() => _SyncPulseDotState();
}

class _SyncPulseDotState extends State<SyncPulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: TideMotion.syncPulse,
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _label {
    final delta = DateTime.now().difference(widget.lastSync);
    if (delta.inMinutes < 1) return 'just now';
    if (delta.inMinutes < 60) return '${delta.inMinutes} min ago';
    if (delta.inHours < 24) return '${delta.inHours} h ago';
    return '${delta.inDays} d ago';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final t = Curves.easeInOut.transform(_controller.value);
            return Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: TideColors.lantern.withValues(alpha: 0.45 + 0.55 * t),
                boxShadow: [
                  BoxShadow(
                    color: TideColors.lantern.withValues(alpha: 0.35 * t),
                    blurRadius: 6 * t,
                    spreadRadius: 1.5 * t,
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(width: 9),
        Text(_label, style: TideType.gauge(12, color: TideColors.silt)),
      ],
    );
  }
}
