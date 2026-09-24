import 'package:flutter/material.dart';

import '../../../config/app_constants.dart';
import '../../../config/reminder_copy.dart';
import '../../../services/models/reminder_options.dart';
import '../../../theme/tide_colors.dart';
import '../../../theme/tide_elevation.dart';
import '../../../theme/tide_motion.dart';
import '../../../theme/tide_typography.dart';
import '../../../widgets/press_scale.dart';
import '../../../widgets/reminder_options_editor.dart';
import '../../../widgets/tide_surface.dart';
import '../../../widgets/tide_switch.dart';

/// The habit's reminder: on or off, when, and how it arrives.
///
/// The preview at the foot is the real copy with the real name and time in
/// it — the same honesty onboarding keeps before it asks for a permission.
/// Nobody should have to wait for a reminder to find out what it will say.
///
/// The time is a chip on its own row, with a clock, a caret and a sentence
/// before it, because bare accent text in the title row was read as a status
/// line and never tapped. It opens the tide dial.
///
/// The days are not asked again: a reminder follows the habit's own
/// schedule, and says so, rather than keeping a second list of weekdays that
/// could disagree with the first.
class ReminderSection extends StatelessWidget {
  const ReminderSection({
    super.key,
    required this.enabled,
    required this.time,
    required this.options,
    required this.days,
    required this.name,
    required this.onToggled,
    required this.onTimeTapped,
    required this.onOptions,
    this.fullScreenCalls = true,
    this.onPreviewTone,
  });

  final bool enabled;
  final TimeOfDay time;
  final ReminderOptions options;

  /// The habit's weekdays, as the form has them now.
  final Set<int> days;

  /// The habit's name, as typed so far.
  final String name;

  final ValueChanged<bool> onToggled;
  final VoidCallback onTimeTapped;
  final ValueChanged<ReminderOptions> onOptions;
  final bool fullScreenCalls;
  final ValueChanged<ReminderTone>? onPreviewTone;

  String get _schedule {
    final sorted = days.toList()..sort();
    if (sorted.isEmpty) return 'on the days you pick above';
    if (sorted.length == 7) return 'every day';
    return 'on ${sorted.map((d) => AppConstants.weekdayNames[d - 1].substring(0, 3)).join(' · ')}';
  }

  /// What will actually arrive, in order.
  String get _preview {
    final subject = name.trim().isEmpty ? 'New habit' : name.trim();
    final at = ReminderCopy.clock(time);
    final heads = options.leadMinutes > 0
        ? () {
            final minutes =
                (time.hour * 60 + time.minute - options.leadMinutes) %
                (24 * 60);
            final early = ReminderCopy.clock(
              TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
            );
            return 'At $early, "$subject · ${ReminderCopy.risingTide(options.leadMinutes)}". ';
          }()
        : '';
    final main = options.style == AlarmStyle.call
        ? 'At $at the Tide Call ${fullScreenCalls ? 'takes the screen' : 'rings'}: swipe up to ride it in.'
        : 'At $at, "${ReminderCopy.callBody(subject, subject)}"';
    return '$heads$main';
  }

  @override
  Widget build(BuildContext context) {
    return TideSurface(
      color: TideColors.trench,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
                      enabled ? 'Repeats $_schedule, at' : 'Off',
                      style: TideType.labelMuted,
                    ),
                  ],
                ),
              ),
              TideSwitch(value: enabled, onChanged: onToggled),
            ],
          ),

          // Everything below collapses away with the toggle rather than
          // sitting there describing something that will not happen.
          AnimatedSize(
            duration: TideMotion.tabSwitch,
            curve: TideMotion.tabCurve,
            alignment: Alignment.topLeft,
            child: !enabled
                ? const SizedBox(width: double.infinity)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 12),
                      _TimeChip(
                        label: ReminderCopy.clock(time),
                        onTap: onTimeTapped,
                      ),
                      const SizedBox(height: 18),
                      ReminderOptionsEditor(
                        options: options,
                        onChanged: onOptions,
                        fullScreenCalls: fullScreenCalls,
                        onPreviewTone: onPreviewTone,
                        foldSoundAndSnooze: true,
                      ),
                      const SizedBox(height: 12),
                      Text(_preview, style: TideType.labelMuted),
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
      child: Semantics(
        button: true,
        label: 'Reminder time, $label',
        child: ExcludeSemantics(
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
                  Icon(
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
        ),
      ),
    );
  }
}
