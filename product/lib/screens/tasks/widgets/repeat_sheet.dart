import 'package:flutter/material.dart';

import '../../../config/app_constants.dart';
import '../../../config/task_copy.dart';
import '../../../services/tasks/task.dart';
import '../../../theme/tide_colors.dart';
import '../../../theme/tide_elevation.dart';
import '../../../theme/tide_typography.dart';
import '../../../widgets/press_scale.dart';
import 'task_sheet.dart';

typedef RepeatChoice = ({TaskRecurrence recurrence, int? months});

/// How often a task comes back, as a list of plain sentences rather than a
/// row of five cramped segments.
///
/// "Custom" opens a months stepper in place, with the yearly case named, so
/// "renew the licence every year" is two taps and needs no arithmetic.
Future<RepeatChoice?> showRepeatSheet(
  BuildContext context, {
  required TaskRecurrence current,
  required int? months,
}) {
  return showTaskSheet<RepeatChoice>(
    context,
    title: 'Repeat',
    builder: (context) =>
        _RepeatOptions(current: current, months: months ?? 12),
  );
}

class _RepeatOptions extends StatefulWidget {
  const _RepeatOptions({required this.current, required this.months});

  final TaskRecurrence current;
  final int months;

  @override
  State<_RepeatOptions> createState() => _RepeatOptionsState();
}

class _RepeatOptionsState extends State<_RepeatOptions> {
  late bool _custom = widget.current == TaskRecurrence.custom;
  late int _months = widget.months;

  void _choose(TaskRecurrence recurrence) => Navigator.of(
    context,
  ).pop<RepeatChoice>((recurrence: recurrence, months: null));

  @override
  Widget build(BuildContext context) {
    const plain = [
      (TaskRecurrence.none, Icons.block_rounded, 'Never'),
      (TaskRecurrence.daily, Icons.wb_sunny_outlined, 'Every day'),
      (TaskRecurrence.weekly, Icons.view_week_outlined, 'Every week'),
      (
        TaskRecurrence.monthly,
        Icons.calendar_view_month_rounded,
        'Every month',
      ),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (recurrence, icon, label) in plain)
          TaskSheetOption(
            icon: icon,
            label: label,
            selected: !_custom && widget.current == recurrence,
            onTap: () => _choose(recurrence),
          ),
        TaskSheetOption(
          icon: Icons.event_repeat_rounded,
          label: 'Custom',
          detail: _custom ? null : 'Every few months',
          selected: _custom,
          onTap: () => setState(() => _custom = true),
        ),
        if (_custom) ...[
          const SizedBox(height: 8),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
            decoration: BoxDecoration(
              color: TideColors.shelf,
              borderRadius: TideElevation.radius12,
              border: Border.all(color: TideColors.hairline),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(TaskCopy.months(_months), style: TideType.heading),
                      const SizedBox(height: 2),
                      Text(
                        'Counted from the due date',
                        style: TideType.labelMuted,
                      ),
                    ],
                  ),
                ),
                _Step(
                  icon: Icons.remove_rounded,
                  onTap: _months > 1 ? () => setState(() => _months--) : null,
                ),
                const SizedBox(width: 8),
                _Step(
                  icon: Icons.add_rounded,
                  onTap: _months < AppConstants.maxCustomRepeatMonths
                      ? () => setState(() => _months++)
                      : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                for (final preset in const [3, 6, 12]) ...[
                  Expanded(
                    child: PressScale(
                      onTap: () => setState(() => _months = preset),
                      child: Container(
                        height: 38,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _months == preset
                              ? TideColors.lantern.withValues(alpha: 0.14)
                              : TideColors.shelf,
                          borderRadius: BorderRadius.circular(19),
                          border: Border.all(
                            color: _months == preset
                                ? TideColors.lantern.withValues(alpha: 0.4)
                                : TideColors.hairline,
                          ),
                        ),
                        child: Text(
                          preset == 12 ? 'Yearly' : '$preset months',
                          style: TideType.label.copyWith(
                            fontSize: 13,
                            color: _months == preset
                                ? TideColors.lantern
                                : TideColors.bone,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (preset != 12) const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: _SetButton(
              onTap: () => Navigator.of(context).pop<RepeatChoice>((
                recurrence: TaskRecurrence.custom,
                months: _months,
              )),
            ),
          ),
        ],
      ],
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: TideColors.bone.withValues(alpha: 0.05),
          border: Border.all(color: TideColors.hairline),
        ),
        child: Icon(
          icon,
          size: 18,
          color: onTap == null
              ? TideColors.silt.withValues(alpha: 0.4)
              : TideColors.bone,
        ),
      ),
    );
  }
}

class _SetButton extends StatelessWidget {
  const _SetButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onTap,
      child: Container(
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: TideColors.lantern,
          borderRadius: TideElevation.radius12,
        ),
        child: Text(
          'Set repeat',
          style: TideType.button.copyWith(color: TideColors.onLantern),
        ),
      ),
    );
  }
}
