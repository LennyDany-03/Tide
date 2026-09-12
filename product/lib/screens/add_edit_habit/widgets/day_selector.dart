import 'dart:math' as math;

import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter/material.dart';

import '../../../config/app_constants.dart';
import '../../../theme/tide_colors.dart';
import '../../../theme/tide_elevation.dart';
import '../../../theme/tide_motion.dart';
import '../../../theme/tide_typography.dart';
import '../../../widgets/press_scale.dart';
import '../../../widgets/ripple_burst.dart';

/// The schedules the selector offers in one tap, and the words for whatever
/// set of days is chosen. The live preview reads the same names, so the two
/// can never describe one schedule differently.
abstract final class DaySchedule {
  static const Set<int> everyDay = {1, 2, 3, 4, 5, 6, 7};
  static const Set<int> weekdays = {1, 2, 3, 4, 5};
  static const Set<int> weekends = {6, 7};

  /// Offered above the days, in this order.
  static const List<(String, Set<int>)> presets = [
    ('Every day', everyDay),
    ('Weekdays', weekdays),
    ('Weekends', weekends),
  ];

  /// The name of the preset [days] matches exactly, or null.
  static String? nameOf(Set<int> days) {
    for (final (name, preset) in presets) {
      if (setEquals(days, preset)) return name;
    }
    return null;
  }

  /// "Weekdays", or the days spelled out — "Mon, Wed, Fri" — when they are
  /// not a preset. Empty for no days.
  static String describe(Set<int> days) {
    final named = nameOf(days);
    if (named != null) return named;
    final sorted = days.toList()..sort();
    return [
      for (final day in sorted) _short(AppConstants.weekdayNames[day - 1]),
    ].join(', ');
  }

  static String _short(String name) =>
      name.length <= 3 ? name : name.substring(0, 3);
}

/// Which days a habit runs on: three presets, the M T W T F S S toggles, and
/// a line naming the choice.
///
/// It starts empty on a new habit. Seven days already lit was a schedule
/// chosen on the person's behalf, and the path of least resistance through
/// the form turned every habit into a daily promise nobody had decided to
/// make. The presets are what keep an empty start from costing seven taps
/// for the most common answer.
///
/// Switching a day on ripples in tide blue, reusing the ripple-strip
/// language from the habit cards — turning a day on is the same kind of act
/// as filling one in.
class DaySelector extends StatefulWidget {
  const DaySelector({
    super.key,
    required this.days,
    required this.onChanged,
    this.errorTick = 0,
  });

  /// Weekday numbers, [DateTime.monday]..[DateTime.sunday].
  final Set<int> days;

  final ValueChanged<Set<int>> onChanged;

  /// Increment to play the error pulse — a save tried with no days chosen.
  final int errorTick;

  @override
  State<DaySelector> createState() => _DaySelectorState();
}

class _DaySelectorState extends State<DaySelector>
    with SingleTickerProviderStateMixin {
  final Map<int, int> _ticks = {};

  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: TideMotion.errorShake,
  );

  @override
  void didUpdateWidget(DaySelector old) {
    super.didUpdateWidget(old);
    if (old.errorTick != widget.errorTick && widget.errorTick > 0) {
      _shake
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  void _toggle(int weekday) {
    final next = Set<int>.from(widget.days);
    if (next.contains(weekday)) {
      next.remove(weekday);
    } else {
      next.add(weekday);
      // Only turning a day *on* is a claim, so only that direction ripples.
      setState(() => _ticks[weekday] = (_ticks[weekday] ?? 0) + 1);
    }
    widget.onChanged(next);
  }

  /// Applies [preset], or clears it when it is already the whole choice — the
  /// same tap that turned it on turns it off, like a day.
  void _applyPreset(Set<int> preset) {
    if (setEquals(widget.days, preset)) {
      widget.onChanged({});
      return;
    }
    setState(() {
      for (final weekday in preset.difference(widget.days)) {
        _ticks[weekday] = (_ticks[weekday] ?? 0) + 1;
      }
    });
    widget.onChanged(Set<int>.from(preset));
  }

  @override
  Widget build(BuildContext context) {
    final days = widget.days;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (name, preset) in DaySchedule.presets)
              _PresetChip(
                label: name,
                active: setEquals(days, preset),
                onTap: () => _applyPreset(preset),
              ),
          ],
        ),
        const SizedBox(height: 12),

        AnimatedBuilder(
          animation: _shake,
          builder: (context, _) {
            final t = _shake.value;
            // The name field's nudge: three decaying swings, and an edge that
            // flashes coral on the days still waiting to be chosen.
            final offset = math.sin(t * math.pi * 6) * 7 * (1 - t);
            final alarm = t > 0 ? 1 - t : 0.0;

            return Transform.translate(
              offset: Offset(offset, 0),
              child: Row(
                children: [
                  for (var weekday = 1; weekday <= 7; weekday++) ...[
                    if (weekday > 1) const SizedBox(width: 8),
                    Expanded(
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: PressScale(
                          onTap: () => _toggle(weekday),
                          child: ClipRRect(
                            borderRadius: TideElevation.radius12,
                            child: RippleBurst(
                              trigger: _ticks[weekday] ?? 0,
                              color: TideColors.lantern,
                              accent: TideColors.lantern,
                              child: _DayTile(
                                label:
                                    AppConstants.weekdayInitials[weekday - 1],
                                active: days.contains(weekday),
                                alarm: alarm,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),

        // Names the choice, the way the icon picker names its icon: seven
        // initials are quick to tap and slow to read back.
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: AnimatedSwitcher(
            duration: TideMotion.tabSwitch,
            switchInCurve: TideMotion.tabCurve,
            layoutBuilder: (current, previous) => Stack(
              alignment: Alignment.centerLeft,
              children: [...previous, ?current],
            ),
            child: Text(
              days.isEmpty
                  ? 'Pick at least one day'
                  : DaySchedule.describe(days),
              key: ValueKey(days.isEmpty ? '' : DaySchedule.describe(days)),
              style: TideType.labelMuted,
            ),
          ),
        ),
      ],
    );
  }
}

/// A one-tap schedule, sized by its label like the icon picker's group tabs.
class _PresetChip extends StatelessWidget {
  const _PresetChip({
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
      child: AnimatedContainer(
        duration: TideMotion.tabSwitch,
        curve: TideMotion.tabCurve,
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
        decoration: _chosen(active, radius: TideElevation.radius12),
        child: Text(
          label,
          style: TideType.label.copyWith(
            color: active ? TideColors.bone : TideColors.silt,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

/// One day.
class _DayTile extends StatelessWidget {
  const _DayTile({
    required this.label,
    required this.active,
    required this.alarm,
  });

  final String label;
  final bool active;

  /// 0..1, how strongly an unchosen day is flashing for a failed save.
  final double alarm;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: TideMotion.tabSwitch,
      curve: TideMotion.tabCurve,
      decoration: _chosen(
        active,
        radius: TideElevation.radius12,
        alarm: alarm,
      ),
      child: Center(
        child: Text(
          label,
          style: TideType.label.copyWith(
            color: active ? TideColors.bone : TideColors.silt,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

/// Selection here is the icon tile's recipe: a raised neutral chip with a
/// lantern edge.
///
/// The days used to be the neutral chip alone. Directly under an icon grid
/// whose chosen tile has a lit edge, that read as a different kind of
/// control, and a grey block on Midnight reads as disabled rather than
/// chosen. The accent is carried by the hairline edge, not a fill: a solid
/// or tinted lantern block on seven days made every chip as loud as the save
/// button, and lantern fill means progress in this app, not "you tapped
/// this".
BoxDecoration _chosen(
  bool active, {
  required BorderRadius radius,
  double alarm = 0,
}) {
  return BoxDecoration(
    color: TideColors.bone.withValues(alpha: active ? 0.14 : 0.04),
    borderRadius: radius,
    border: Border.all(
      color: active
          ? TideColors.lantern.withValues(alpha: 0.55)
          : Color.lerp(Colors.transparent, TideColors.coral, alarm)!,
    ),
  );
}
