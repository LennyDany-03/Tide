import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../services/models/habit.dart';
import '../../../theme/tide_colors.dart';
import '../../../theme/tide_elevation.dart';
import '../../../theme/tide_motion.dart';
import '../../../theme/tide_typography.dart';
import '../../../widgets/press_scale.dart';
import '../../../widgets/tide_surface.dart';

/// The daily target, shown only for quantity and duration habits.
///
/// The two types get genuinely different controls, which is the fix for the
/// thing that was wrong here. Both used to be a bare stepper beside three
/// word-chips, so a duration habit read as "30" next to the word "min" with
/// nothing saying either one could be changed, and the ceiling on what you
/// could be counting was glasses, pages or reps.
///
/// Quantity now offers eleven units and a custom one you can type. Duration
/// drops the unit choice entirely — it is always minutes underneath — and
/// spends the space on presets and a readout that says "1 hr 30 min" rather
/// than "90", because nobody thinks about their evening in minutes past
/// sixty.
class TargetFields extends StatefulWidget {
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

  /// The offered units. Anything outside this list is a custom one the user
  /// typed, and the picker opens on the text field to show it.
  static const List<String> quantityUnits = [
    'glasses',
    'cups',
    'pages',
    'reps',
    'sets',
    'steps',
    'km',
    'miles',
    'servings',
    'pieces',
    'times',
  ];

  /// Common durations, in minutes.
  static const List<int> durationPresets = [10, 15, 20, 30, 45, 60, 90];

  /// "45 min", "1 hr", "1 hr 30 min". The one spelling lives on [Minutes], so
  /// the editor and the log sheet cannot write the same length differently.
  static String durationLabel(num minutes) => Minutes.label(minutes);

  @override
  State<TargetFields> createState() => _TargetFieldsState();
}

class _TargetFieldsState extends State<TargetFields> {
  late final TextEditingController _custom = TextEditingController(
    text: _isCustom(widget.unit) ? widget.unit : '',
  );

  /// Whether the custom-unit field is open. Starts open when the habit is
  /// already wearing a unit that is not on the list.
  late bool _customOpen = _isCustom(widget.unit);

  static bool _isCustom(String unit) =>
      unit.isNotEmpty && !TargetFields.quantityUnits.contains(unit);

  @override
  void dispose() {
    _custom.dispose();
    super.dispose();
  }

  bool get _visible => widget.type != HabitType.binary;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: TideMotion.sheetIn,
      curve: TideMotion.sheetCurve,
      alignment: Alignment.topCenter,
      child: !_visible
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.only(top: 14),
              child: widget.type == HabitType.duration
                  ? _duration()
                  : _quantity(),
            ),
    );
  }

  // --- Duration ---------------------------------------------------------

  Widget _duration() {
    final minutes = widget.target;

    return TideSurface(
      color: TideColors.trench,
      highlight: false,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _RoundButton(
                icon: Icons.remove_rounded,
                enabled: minutes > 5,
                onTap: () =>
                    widget.onTargetChanged(_snap(minutes - _stepFor(minutes))),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      TargetFields.durationLabel(minutes),
                      style: TideType.gauge(24, color: TideColors.bone),
                      maxLines: 1,
                    ),
                    const SizedBox(height: 4),
                    Text('a day', style: TideType.labelMuted),
                  ],
                ),
              ),
              _RoundButton(
                icon: Icons.add_rounded,
                enabled: minutes < 600,
                onTap: () =>
                    widget.onTargetChanged(_snap(minutes + _stepFor(minutes))),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final preset in TargetFields.durationPresets)
                _Chip(
                  label: TargetFields.durationLabel(preset),
                  selected: widget.target.round() == preset,
                  onTap: () => widget.onTargetChanged(preset),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// Five-minute steps up to an hour, quarter-hours past it. Nudging a
  /// two-hour target five minutes at a time is twenty-four taps.
  num _stepFor(num minutes) => minutes >= 60 ? 15 : 5;

  num _snap(num minutes) => minutes.clamp(5, 600);

  // --- Quantity ---------------------------------------------------------

  Widget _quantity() {
    final unitSuffix = widget.unit.isEmpty ? '' : ' ${widget.unit}';

    return TideSurface(
      color: TideColors.trench,
      highlight: false,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _RoundButton(
                icon: Icons.remove_rounded,
                enabled: widget.target > 1,
                onTap: () =>
                    widget.onTargetChanged((widget.target - 1).clamp(1, 999)),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      '${widget.target}$unitSuffix',
                      style: TideType.gauge(24, color: TideColors.bone),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text('a day', style: TideType.labelMuted),
                  ],
                ),
              ),
              _RoundButton(
                icon: Icons.add_rounded,
                enabled: widget.target < 999,
                onTap: () =>
                    widget.onTargetChanged((widget.target + 1).clamp(1, 999)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text('Counted in', style: TideType.labelMuted),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final unit in TargetFields.quantityUnits)
                _Chip(
                  label: unit,
                  selected: !_customOpen && unit == widget.unit,
                  onTap: () {
                    setState(() => _customOpen = false);
                    widget.onUnitChanged(unit);
                  },
                ),
              _Chip(
                label: 'Custom',
                selected: _customOpen,
                onTap: () {
                  setState(() => _customOpen = true);
                  final typed = _custom.text.trim();
                  if (typed.isNotEmpty) widget.onUnitChanged(typed);
                },
              ),
            ],
          ),
          AnimatedSize(
            duration: TideMotion.tabSwitch,
            curve: TideMotion.tabCurve,
            alignment: Alignment.topCenter,
            child: !_customOpen
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: TideColors.shelf,
                        borderRadius: TideElevation.radius12,
                      ),
                      child: TextField(
                        controller: _custom,
                        style: TideType.body,
                        cursorColor: TideColors.lantern,
                        maxLength: 14,
                        textInputAction: TextInputAction.done,
                        inputFormatters: [
                          FilteringTextInputFormatter.singleLineFormatter,
                        ],
                        onChanged: (value) => widget.onUnitChanged(value.trim()),
                        decoration: InputDecoration(
                          isDense: true,
                          counterText: '',
                          hintText: 'e.g. laps, chapters, litres',
                          hintStyle: TideType.bodyMuted,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// A word chip: a unit, or a preset duration.
class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onTap,
      // No `alignment`, and no fixed height. A Container given an alignment
      // wraps its child in an Align, and an Align under loose constraints
      // expands to fill them — inside a Wrap that means every chip claims
      // the full width of the row, which is exactly what these were doing:
      // eleven units stacked one per line down the form. Padding around the
      // label sizes the chip to the word, which is what a chip is.
      child: AnimatedContainer(
        duration: TideMotion.tabSwitch,
        curve: TideMotion.tabCurve,
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
        decoration: BoxDecoration(
          color: TideColors.bone.withValues(alpha: selected ? 0.14 : 0.04),
          borderRadius: TideElevation.radius12,
          border: Border.all(
            color: selected
                ? TideColors.lantern.withValues(alpha: 0.55)
                : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: TideType.label.copyWith(
            color: selected ? TideColors.bone : TideColors.silt,
          ),
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: enabled ? onTap : null,
      enabled: enabled,
      child: Opacity(
        opacity: enabled ? 1 : 0.35,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: TideColors.shelf,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 19, color: TideColors.bone),
        ),
      ),
    );
  }
}
