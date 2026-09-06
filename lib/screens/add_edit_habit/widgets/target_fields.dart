import 'package:flutter/material.dart';

import '../../../services/models/habit.dart';
import '../../../theme/tide_colors.dart';
import '../../../theme/tide_elevation.dart';
import '../../../theme/tide_motion.dart';
import '../../../theme/tide_typography.dart';
import '../../../widgets/press_scale.dart';

/// Target amount and unit, shown only for quantity and duration habits.
///
/// It expands and collapses under the type control rather than appearing
/// and disappearing, so choosing a type never makes the rest of the form
/// jump under the user's thumb.
class TargetFields extends StatelessWidget {
  const TargetFields({
    super.key,
    required this.type,
    required this.target,
    required this.unit,
    required this.onTargetChanged,
    required this.onUnitChanged,
  });

  final HabitType type;
  final num target;
  final String unit;
  final ValueChanged<num> onTargetChanged;
  final ValueChanged<String> onUnitChanged;

  static const List<String> _quantityUnits = ['glasses', 'pages', 'reps'];
  static const List<String> _durationUnits = ['min', 'hours'];

  bool get _visible => type != HabitType.binary;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: TideMotion.sheetIn,
      curve: TideMotion.sheetCurve,
      alignment: Alignment.topCenter,
      child: AnimatedOpacity(
        opacity: _visible ? 1 : 0,
        duration: TideMotion.tabSwitch,
        child: _visible
            ? Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Row(
                  children: [
                    _Stepper(
                      value: target,
                      onChanged: onTargetChanged,
                      step: type == HabitType.duration ? 5 : 1,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _UnitRow(
                        units: type == HabitType.duration
                            ? _durationUnits
                            : _quantityUnits,
                        selected: unit,
                        onChanged: onUnitChanged,
                      ),
                    ),
                  ],
                ),
              )
            : const SizedBox(width: double.infinity),
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.value,
    required this.onChanged,
    required this.step,
  });

  final num value;
  final ValueChanged<num> onChanged;
  final num step;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: TideColors.trench,
        borderRadius: TideElevation.radius12,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepButton(
            icon: Icons.remove_rounded,
            onTap: () => onChanged((value - step).clamp(1, 999)),
          ),
          SizedBox(
            width: 44,
            child: Center(
              child: Text(
                '$value',
                style: TideType.gauge(16, color: TideColors.bone),
              ),
            ),
          ),
          _StepButton(
            icon: Icons.add_rounded,
            onTap: () => onChanged((value + step).clamp(1, 999)),
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: TideColors.shelf,
          borderRadius: TideElevation.radius12,
        ),
        child: Icon(icon, size: 17, color: TideColors.bone),
      ),
    );
  }
}

class _UnitRow extends StatelessWidget {
  const _UnitRow({
    required this.units,
    required this.selected,
    required this.onChanged,
  });

  final List<String> units;
  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final unit in units) ...[
          if (unit != units.first) const SizedBox(width: 8),
          Expanded(
            child: PressScale(
              onTap: () => onChanged(unit),
              child: AnimatedContainer(
                duration: TideMotion.tabSwitch,
                height: 44,
                decoration: BoxDecoration(
                  color: unit == selected
                      ? TideColors.lantern.withValues(alpha: 0.16)
                      : TideColors.trench,
                  borderRadius: TideElevation.radius12,
                  border: Border.all(
                    color: unit == selected
                        ? TideColors.lantern.withValues(alpha: 0.55)
                        : Colors.transparent,
                  ),
                ),
                child: Center(
                  child: Text(
                    unit,
                    style: TideType.labelMuted.copyWith(
                      color: unit == selected
                          ? TideColors.bone
                          : TideColors.silt,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
