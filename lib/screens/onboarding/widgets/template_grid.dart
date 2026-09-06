import 'package:flutter/material.dart';

import '../../../config/app_constants.dart';
import '../../../config/habit_templates.dart';
import '../../../theme/tide_colors.dart';
import '../../../theme/tide_elevation.dart';
import '../../../theme/tide_motion.dart';
import '../../../theme/tide_typography.dart';
import '../../../widgets/gauge_number.dart';
import '../../../widgets/habit_glyph.dart';
import '../../../widgets/press_scale.dart';
import '../../../widgets/ripple_burst.dart';
import '../../../widgets/stagger_list.dart';

/// Step two: pick what to track.
///
/// Selecting a template ripples with the *same* animation that logging a
/// habit uses. That is deliberate — the first time a new user taps
/// anything, they are shown the reward the whole app runs on, before they
/// have any habits to earn it with.
class TemplateGrid extends StatefulWidget {
  const TemplateGrid({
    super.key,
    required this.selected,
    required this.onChanged,
    required this.onCustom,
  });

  final Set<int> selected;
  final ValueChanged<Set<int>> onChanged;
  final VoidCallback onCustom;

  @override
  State<TemplateGrid> createState() => _TemplateGridState();
}

class _TemplateGridState extends State<TemplateGrid> {
  final Map<int, int> _ticks = {};

  void _toggle(int index) {
    final next = Set<int>.from(widget.selected);
    if (next.contains(index)) {
      next.remove(index);
    } else {
      next.add(index);
      setState(() => _ticks[index] = (_ticks[index] ?? 0) + 1);
    }
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.selected.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('What should we track?', style: TideType.hero),
        const SizedBox(height: 10),
        Row(
          children: [
            GaugeNumber(
              value: count,
              style: TideType.gauge(
                14,
                color: count == 0 ? TideColors.silt : TideColors.lantern,
              ),
            ),
            Text(
              ' of ${AppConstants.onboardingTarget} selected',
              style: TideType.labelMuted,
            ),
          ],
        ),
        const SizedBox(height: 20),
        Expanded(
          child: GridView.builder(
            padding: EdgeInsets.zero,
            itemCount: HabitTemplate.all.length + 1,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 2.05,
            ),
            itemBuilder: (context, index) {
              if (index == HabitTemplate.all.length) {
                return StaggerIn(
                  index: index,
                  child: _CustomCard(onTap: widget.onCustom),
                );
              }
              return StaggerIn(
                index: index,
                child: _TemplateCard(
                  template: HabitTemplate.all[index],
                  selected: widget.selected.contains(index),
                  rippleTick: _ticks[index] ?? 0,
                  onTap: () => _toggle(index),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({
    required this.template,
    required this.selected,
    required this.rippleTick,
    required this.onTap,
  });

  final HabitTemplate template;
  final bool selected;
  final int rippleTick;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: TideElevation.radius20,
        child: RippleBurst(
          trigger: rippleTick,
          color: TideColors.lantern,
          child: AnimatedContainer(
            duration: TideMotion.tabSwitch,
            curve: TideMotion.tabCurve,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: selected
                  ? Color.lerp(TideColors.shelf, TideColors.lantern, 0.14)
                  : TideColors.shelf,
              borderRadius: TideElevation.radius20,
              border: Border.all(
                color: selected
                    ? TideColors.lantern.withValues(alpha: 0.55)
                    : Colors.transparent,
              ),
              boxShadow: TideElevation.resting,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                HabitGlyph(
                  glyph: template.glyph,
                  size: 17,
                  color: selected ? TideColors.lantern : TideColors.silt,
                ),
                Text(
                  template.name,
                  style: TideType.label.copyWith(
                    color: selected
                        ? TideColors.bone
                        : TideColors.silt,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CustomCard extends StatelessWidget {
  const _CustomCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: TideElevation.radius20,
          border: Border.all(
            color: TideColors.silt.withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Icon(
              Icons.add_rounded,
              size: 18,
              color: TideColors.silt,
            ),
            Text('Create custom', style: TideType.labelMuted),
          ],
        ),
      ),
    );
  }
}
