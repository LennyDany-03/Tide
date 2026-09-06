import 'package:flutter/material.dart';

import '../../../config/app_constants.dart';
import '../../../theme/tide_colors.dart';
import '../../../theme/tide_elevation.dart';
import '../../../theme/tide_motion.dart';
import '../../../theme/tide_typography.dart';
import '../../../widgets/press_scale.dart';
import '../../../widgets/ripple_burst.dart';

/// The M T W T F S S toggles.
///
/// Switching a day on ripples in tide blue, reusing the ripple-strip
/// language from the habit cards — turning a day on is the same kind of act
/// as filling one in.
class DaySelector extends StatefulWidget {
  const DaySelector({super.key, required this.days, required this.onChanged});

  /// Weekday numbers, [DateTime.monday]..[DateTime.sunday].
  final Set<int> days;

  final ValueChanged<Set<int>> onChanged;

  @override
  State<DaySelector> createState() => _DaySelectorState();
}

class _DaySelectorState extends State<DaySelector> {
  final Map<int, int> _ticks = {};

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

  @override
  Widget build(BuildContext context) {
    return Row(
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
                    child: _DayTile(
                      label: AppConstants.weekdayInitials[weekday - 1],
                      active: widget.days.contains(weekday),
                    ),
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

/// Selection is neutral contrast, not accent.
///
/// Two wrong versions came before this one. Accent at 16% alpha behind an
/// accent border turned olive on deep water, and with all seven days on, the
/// row was mud. Solid accent fixed the mud and created a worse problem: an
/// editor where the icon tile, the type pill, seven day chips, a toggle and
/// the save button were all the same warm block, so the one action that
/// matters stopped being the loudest thing on the sheet.
///
/// Lantern means progress in this app — a streak, a logged day, water coming
/// in. It does not mean "you tapped this". A raised neutral chip says chosen
/// perfectly well, and leaves the accent free to mean what it means.
class _DayTile extends StatelessWidget {
  const _DayTile({required this.label, required this.active});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: TideMotion.tabSwitch,
      curve: TideMotion.tabCurve,
      decoration: BoxDecoration(
        color: TideColors.bone.withValues(alpha: active ? 0.14 : 0.04),
        borderRadius: TideElevation.radius12,
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
