import 'package:flutter/material.dart';

import '../../../theme/tide_colors.dart';
import '../../../theme/tide_motion.dart';
import '../../../theme/tide_typography.dart';
import '../../../widgets/press_scale.dart';
import '../../../widgets/tide_surface.dart';
import '../../../widgets/tide_switch.dart';

/// The reminder toggle, its time, and an honest preview of the copy.
///
/// The preview is the real notification text with the real habit name in
/// it — the same honesty pattern onboarding uses before asking for
/// permission. Nobody should have to grant a permission to find out what
/// the app will actually say to them.
class ReminderRow extends StatelessWidget {
  const ReminderRow({
    super.key,
    required this.enabled,
    required this.time,
    required this.preview,
    required this.onToggled,
    required this.onTimeTapped,
  });

  final bool enabled;
  final TimeOfDay time;
  final String preview;
  final ValueChanged<bool> onToggled;
  final VoidCallback onTimeTapped;

  String get _timeLabel =>
      '${time.hour.toString().padLeft(2, '0')}:'
      '${time.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return TideSurface(
      color: TideColors.trench,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Reminder', style: TideType.heading)),
              PressScale(
                onTap: onTimeTapped,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  child: Text(
                    _timeLabel,
                    style: TideType.gauge(
                      15,
                      color: enabled
                          ? TideColors.lantern
                          : TideColors.silt,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              TideSwitch(value: enabled, onChanged: onToggled),
            ],
          ),
          // The preview collapses away with the toggle rather than sitting
          // there describing something that will not happen.
          AnimatedSize(
            duration: TideMotion.tabSwitch,
            curve: TideMotion.tabCurve,
            alignment: Alignment.topLeft,
            child: AnimatedOpacity(
              opacity: enabled ? 1 : 0,
              duration: TideMotion.tabSwitch,
              child: enabled
                  ? Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(preview, style: TideType.labelMuted),
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ),
        ],
      ),
    );
  }
}
