import 'package:flutter/material.dart';

import '../../../theme/tide_colors.dart';
import '../../../theme/tide_elevation.dart';
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
///
/// The time used to be bare accent text sitting in the title row: the same
/// weight as a readout, no border, no icon, nothing at all saying it could
/// be changed. People read it as a status line and never tapped it. It is
/// now a chip on its own row, with a clock, a caret and a sentence in front
/// of it — a control that looks like a control.
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Reminder', style: TideType.heading),
                    const SizedBox(height: 4),
                    Text(
                      enabled ? 'Every scheduled day at' : 'Off',
                      style: TideType.labelMuted,
                    ),
                  ],
                ),
              ),
              TideSwitch(value: enabled, onChanged: onToggled),
            ],
          ),

          // The time and the preview collapse away with the toggle rather
          // than sitting there describing something that will not happen.
          AnimatedSize(
            duration: TideMotion.tabSwitch,
            curve: TideMotion.tabCurve,
            alignment: Alignment.topLeft,
            child: !enabled
                ? const SizedBox(width: double.infinity)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 12),
                      _TimeChip(label: _timeLabel, onTap: onTimeTapped),
                      const SizedBox(height: 12),
                      Text(preview, style: TideType.labelMuted),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

/// The time, as something you can obviously press.
class _TimeChip extends StatelessWidget {
  const _TimeChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: PressScale(
        onTap: onTap,
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: TideColors.shelf,
            borderRadius: TideElevation.radius12,
            border: Border.all(
              color: TideColors.lantern.withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.schedule_rounded,
                size: 17,
                color: TideColors.lantern,
              ),
              const SizedBox(width: 9),
              Text(
                label,
                style: TideType.gauge(17, color: TideColors.lantern),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.expand_more_rounded,
                size: 18,
                color: TideColors.lantern.withValues(alpha: 0.7),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
