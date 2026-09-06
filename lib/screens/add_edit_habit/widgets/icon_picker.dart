import 'package:flutter/material.dart';

import '../../../services/models/tide_glyph.dart';
import '../../../theme/tide_colors.dart';
import '../../../theme/tide_elevation.dart';
import '../../../theme/tide_motion.dart';
import '../../../widgets/habit_glyph.dart';
import '../../../widgets/press_scale.dart';
import '../../../widgets/ripple_burst.dart';

/// The glyph row.
///
/// Selecting an icon ripples exactly the way picking an onboarding template
/// does, and the way logging a habit does — the app has one "claimed"
/// animation and this is another place it applies.
class IconPicker extends StatefulWidget {
  const IconPicker({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final TideGlyph selected;
  final ValueChanged<TideGlyph> onChanged;

  @override
  State<IconPicker> createState() => _IconPickerState();
}

class _IconPickerState extends State<IconPicker> {
  /// One tick per glyph, so a ripple plays on the tile that was tapped
  /// rather than across the whole row.
  final Map<TideGlyph, int> _ticks = {};

  void _select(TideGlyph glyph) {
    setState(() => _ticks[glyph] = (_ticks[glyph] ?? 0) + 1);
    widget.onChanged(glyph);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final glyph in TideGlyph.pickable) ...[
          if (glyph != TideGlyph.pickable.first) const SizedBox(width: 8),
          Expanded(
            child: AspectRatio(
              aspectRatio: 1,
              child: PressScale(
                onTap: () => _select(glyph),
                child: ClipRRect(
                  borderRadius: TideElevation.radius12,
                  child: RippleBurst(
                    trigger: _ticks[glyph] ?? 0,
                    color: TideColors.lantern,
                    accent: TideColors.lantern,
                    child: _Tile(
                      glyph: glyph,
                      selected: glyph == widget.selected,
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
class _Tile extends StatelessWidget {
  const _Tile({required this.glyph, required this.selected});

  final TideGlyph glyph;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: TideMotion.tabSwitch,
      curve: TideMotion.tabCurve,
      decoration: BoxDecoration(
        color: TideColors.bone.withValues(alpha: selected ? 0.14 : 0.04),
        borderRadius: TideElevation.radius12,
      ),
      child: Center(
        child: HabitGlyph(
          glyph: glyph,
          size: 17,
          color: selected ? TideColors.bone : TideColors.silt,
        ),
      ),
    );
  }
}
