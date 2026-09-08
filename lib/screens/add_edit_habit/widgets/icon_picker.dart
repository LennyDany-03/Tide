import 'package:flutter/material.dart';

import '../../../services/models/tide_glyph.dart';
import '../../../theme/tide_colors.dart';
import '../../../theme/tide_elevation.dart';
import '../../../theme/tide_motion.dart';
import '../../../theme/tide_typography.dart';
import '../../../widgets/habit_glyph.dart';
import '../../../widgets/press_scale.dart';
import '../../../widgets/ripple_burst.dart';

/// The icon picker.
///
/// It used to be a single row of seven abstract marks, which is two
/// problems in one control. Seven is not a choice, it is a shortlist; and
/// abstract marks make every habit look like every other habit at a
/// glance, which is exactly when a habit list is read.
///
/// So: six groups, forty-odd glyphs, and a tab strip to move between them.
/// The chosen icon is named under the grid, because a picture the user
/// cannot name is a picture they will not trust they picked correctly.
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
  /// Opens on whichever group already holds the habit's icon, so editing an
  /// existing habit does not start by hiding its own choice.
  late int _group = GlyphCatalog.groupIndexOf(widget.selected);

  /// One tick per glyph, so a ripple plays on the tile that was tapped
  /// rather than across the whole grid.
  final Map<TideGlyph, int> _ticks = {};

  /// Six across is the widest the tiles can go before they stop reading as
  /// buttons on a narrow phone.
  static const int _columns = 6;
  static const double _gap = 8;

  void _select(TideGlyph glyph) {
    setState(() => _ticks[glyph] = (_ticks[glyph] ?? 0) + 1);
    widget.onChanged(glyph);
  }

  @override
  Widget build(BuildContext context) {
    final glyphs = GlyphCatalog.groups[_group].glyphs;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.zero,
            itemCount: GlyphCatalog.groups.length,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (context, index) => _GroupChip(
              label: GlyphCatalog.groups[index].name,
              active: index == _group,
              onTap: () => setState(() => _group = index),
            ),
          ),
        ),
        const SizedBox(height: 12),

        LayoutBuilder(
          builder: (context, constraints) {
            final tile =
                (constraints.maxWidth - _gap * (_columns - 1)) / _columns;

            // The grid changes height between groups; resizing into it
            // keeps the fields below from jumping under the thumb.
            return AnimatedSize(
              duration: TideMotion.tabSwitch,
              curve: TideMotion.tabCurve,
              alignment: Alignment.topCenter,
              child: Wrap(
                spacing: _gap,
                runSpacing: _gap,
                children: [
                  for (final glyph in glyphs)
                    SizedBox(
                      width: tile,
                      height: tile,
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
                ],
              ),
            );
          },
        ),

        // Names the choice. The abstract marks have no subject to name, so
        // the line simply says so rather than inventing one.
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Text(
            widget.selected.label.isEmpty
                ? 'An abstract mark'
                : widget.selected.label,
            style: TideType.labelMuted,
          ),
        ),
      ],
    );
  }
}

/// One group tab.
class _GroupChip extends StatelessWidget {
  const _GroupChip({
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
      // Sized by its label, not by an alignment — see the note on the unit
      // chips in target_fields.dart.
      child: AnimatedContainer(
        duration: TideMotion.tabSwitch,
        curve: TideMotion.tabCurve,
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
        decoration: BoxDecoration(
          color: TideColors.bone.withValues(alpha: active ? 0.14 : 0.04),
          borderRadius: TideElevation.radius12,
        ),
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

/// Selection is neutral contrast, not accent.
///
/// Two wrong versions came before this one. Accent at 16% alpha behind an
/// accent border turned olive on deep water, and with a whole grid selected
/// the block was mud. Solid accent fixed the mud and created a worse
/// problem: an editor where the icon tile, the type pill, seven day chips,
/// a toggle and the save button were all the same warm block, so the one
/// action that matters stopped being the loudest thing on the screen.
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
        border: Border.all(
          color: selected
              ? TideColors.lantern.withValues(alpha: 0.55)
              : Colors.transparent,
        ),
      ),
      child: Center(
        child: HabitGlyph(
          glyph: glyph,
          size: 19,
          color: selected ? TideColors.bone : TideColors.silt,
        ),
      ),
    );
  }
}
