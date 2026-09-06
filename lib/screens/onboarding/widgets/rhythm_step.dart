import 'package:flutter/material.dart';

import '../../../config/app_constants.dart';
import '../../../config/habit_templates.dart';
import '../../../theme/tide_colors.dart';
import '../../../theme/tide_elevation.dart';
import '../../../theme/tide_motion.dart';
import '../../../theme/tide_typography.dart';
import '../../../widgets/habit_glyph.dart';
import '../../../widgets/press_scale.dart';
import '../../../widgets/tide_surface.dart';

/// Step three: confirm the rhythm.
///
/// Each habit is one collapsed row carrying a smart default. The full
/// picker only appears if the row is tapped, so a user who agrees with the
/// defaults — which is most of them — can move on without touching
/// anything. The expansion animates rather than snapping, so opening one
/// does not feel like arriving on a different screen.
class RhythmStep extends StatefulWidget {
  const RhythmStep({
    super.key,
    required this.templates,
    required this.days,
    required this.times,
    required this.onDaysChanged,
    required this.onTimeChanged,
  });

  final List<HabitTemplate> templates;
  final Map<int, Set<int>> days;
  final Map<int, TimeOfDay> times;
  final void Function(int index, Set<int> days) onDaysChanged;
  final void Function(int index, TimeOfDay time) onTimeChanged;

  @override
  State<RhythmStep> createState() => _RhythmStepState();
}

class _RhythmStepState extends State<RhythmStep> {
  int? _expanded;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Set the rhythm', style: TideType.hero),
        const SizedBox(height: 10),
        Text(
          'Sensible defaults are already in. Tap a row only if you want to '
          'change one.',
          style: TideType.bodyMuted,
        ),
        const SizedBox(height: 22),
        Expanded(
          child: ListView.separated(
            padding: EdgeInsets.zero,
            itemCount: widget.templates.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              return _RhythmRow(
                template: widget.templates[i],
                days: widget.days[i] ?? widget.templates[i].days,
                time: widget.times[i] ?? widget.templates[i].reminderTime,
                expanded: _expanded == i,
                onToggleExpanded: () =>
                    setState(() => _expanded = _expanded == i ? null : i),
                onDaysChanged: (days) => widget.onDaysChanged(i, days),
                onTimeChanged: (time) => widget.onTimeChanged(i, time),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _RhythmRow extends StatelessWidget {
  const _RhythmRow({
    required this.template,
    required this.days,
    required this.time,
    required this.expanded,
    required this.onToggleExpanded,
    required this.onDaysChanged,
    required this.onTimeChanged,
  });

  final HabitTemplate template;
  final Set<int> days;
  final TimeOfDay time;
  final bool expanded;
  final VoidCallback onToggleExpanded;
  final ValueChanged<Set<int>> onDaysChanged;
  final ValueChanged<TimeOfDay> onTimeChanged;

  String get _summary {
    final schedule = days.length == 7
        ? 'Daily'
        : days.isEmpty
        ? 'No days'
        : days.length == 5 && !days.contains(6) && !days.contains(7)
        ? 'Weekdays'
        : '${days.length}x a week';
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$schedule at $hour:$minute';
  }

  Future<void> _pickTime(BuildContext context) async {
    final picked = await showTimePicker(context: context, initialTime: time);
    if (picked != null) onTimeChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    return TideSurface(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          PressScale(
            onTap: onToggleExpanded,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
              child: Row(
                children: [
                  HabitGlyph(glyph: template.glyph, size: 15),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          template.name,
                          style: TideType.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(_summary, style: TideType.labelMuted),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: TideMotion.tabSwitch,
                    child: const Icon(
                      Icons.expand_more_rounded,
                      size: 20,
                      color: TideColors.silt,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: TideMotion.sheetIn,
            curve: TideMotion.sheetCurve,
            alignment: Alignment.topCenter,
            child: expanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            for (var weekday = 1; weekday <= 7; weekday++) ...[
                              if (weekday > 1) const SizedBox(width: 6),
                              Expanded(
                                child: _DayChip(
                                  label:
                                      AppConstants.weekdayInitials[weekday - 1],
                                  active: days.contains(weekday),
                                  onTap: () {
                                    final next = Set<int>.from(days);
                                    next.contains(weekday)
                                        ? next.remove(weekday)
                                        : next.add(weekday);
                                    onDaysChanged(next);
                                  },
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 12),
                        PressScale(
                          onTap: () => _pickTime(context),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: TideColors.trench,
                              borderRadius: TideElevation.radius12,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Reminder',
                                    style: TideType.labelMuted,
                                  ),
                                ),
                                Text(
                                  '${time.hour.toString().padLeft(2, '0')}:'
                                  '${time.minute.toString().padLeft(2, '0')}',
                                  style: TideType.gauge(
                                    14,
                                    color: TideColors.lantern,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onTap,
      child: AspectRatio(
        aspectRatio: 1,
        child: AnimatedContainer(
          duration: TideMotion.tabSwitch,
          decoration: BoxDecoration(
            color: active
                ? TideColors.lantern.withValues(alpha: 0.16)
                : TideColors.trench,
            borderRadius: TideElevation.radius12,
            border: Border.all(
              color: active
                  ? TideColors.lantern.withValues(alpha: 0.5)
                  : Colors.transparent,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TideType.labelMuted.copyWith(
                fontSize: 11.5,
                color: active ? TideColors.bone : TideColors.silt,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
