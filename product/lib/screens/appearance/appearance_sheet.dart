import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../services/tide_scope.dart';
import '../../theme/tide_colors.dart';
import '../../theme/tide_elevation.dart';
import '../../theme/tide_motion.dart';
import '../../theme/tide_palette.dart';
import '../../theme/tide_typography.dart';
import '../../widgets/press_scale.dart';
import '../../widgets/tide_sheet.dart';

/// The palette picker, raised from Settings → Appearance.
///
/// Choosing applies immediately — there is no confirm button. The sheet is
/// translucent over Settings, so the tap repaints the screen behind it and
/// the sheet itself in the same frame, and the app you are looking at *is*
/// the preview. A separate "apply" step would ask you to commit to a colour
/// you had already seen.
///
/// Each option carries a swatch drawn in its own palette, whatever palette
/// is active, so all five can be compared side by side without trying each
/// one on.
class AppearanceSheet extends StatelessWidget {
  const AppearanceSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final store = TideScope.of(context);
    final current = store.palette;

    Widget option(TidePalette palette) => _PaletteOption(
      palette: palette,
      selected: identical(palette, current),
      onTap: () => store.setPalette(palette),
    );

    final dark = TidePalettes.all.where((p) => !p.isLight).toList();
    final light = TidePalettes.all.where((p) => p.isLight).toList();

    return TideSheet(
      eyebrow: 'Appearance',
      title: 'Palette',
      onDismiss: () => context.pop(),
      maxHeightFactor: 0.9,
      child: ListView(
        shrinkWrap: true,
        padding: EdgeInsets.fromLTRB(
          20,
          4,
          20,
          24 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          Text(
            'Every screen repaints in the one you pick.',
            style: TideType.bodyMuted,
          ),
          const SizedBox(height: 20),
          Text('Dark', style: TideType.sectionHeader),
          const SizedBox(height: 10),
          for (var i = 0; i < dark.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            option(dark[i]),
          ],
          const SizedBox(height: 24),
          Text('Light', style: TideType.sectionHeader),
          const SizedBox(height: 10),
          for (var i = 0; i < light.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            option(light[i]),
          ],
        ],
      ),
    );
  }
}

class _PaletteOption extends StatelessWidget {
  const _PaletteOption({
    required this.palette,
    required this.selected,
    required this.onTap,
  });

  final TidePalette palette;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '${palette.name} palette',
      excludeSemantics: true,
      child: PressScale(
        onTap: onTap,
        scale: 0.985,
        child: AnimatedContainer(
          duration: TideMotion.tabSwitch,
          curve: TideMotion.tabCurve,
          // 8, so the swatch's 12 sits concentric inside the card's 20.
          padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
          decoration: BoxDecoration(
            color: TideColors.shelf,
            borderRadius: TideElevation.radius20,
            // One width in both states, so selecting never nudges the
            // layout by half a pixel; only the colour moves.
            border: Border.all(
              color: selected ? TideColors.lantern : TideColors.hairline,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              _Swatch(palette: palette),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      palette.name,
                      style: TideType.heading,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      palette.description,
                      style: TideType.labelMuted,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _Tick(selected: selected),
            ],
          ),
        ),
      ),
    );
  }
}

/// Today in miniature, painted in [palette] rather than the active one: the
/// page, a title and its caption, and a card carrying the accent.
class _Swatch extends StatelessWidget {
  const _Swatch({required this.palette});

  final TidePalette palette;

  @override
  Widget build(BuildContext context) {
    Widget bar(double width, double height, Color color) => Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(height),
      ),
    );

    return Container(
      width: 64,
      height: 64,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: palette.deepWater,
        borderRadius: TideElevation.radius12,
        border: Border.all(color: palette.bone.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          bar(24, 4, palette.bone),
          const SizedBox(height: 4),
          bar(15, 3, palette.silt),
          const Spacer(),
          Container(
            height: 20,
            padding: const EdgeInsets.symmetric(horizontal: 5),
            decoration: BoxDecoration(
              color: palette.shelf,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: palette.bone.withValues(alpha: 0.08)),
            ),
            child: Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: palette.lantern,
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(child: bar(double.infinity, 3, palette.silt)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The selection mark: a solid accent disc with a check, or an empty ring.
class _Tick extends StatelessWidget {
  const _Tick({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: TideMotion.tabSwitch,
      curve: TideMotion.tabCurve,
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? TideColors.lantern : Colors.transparent,
        border: Border.all(
          color: selected
              ? TideColors.lantern
              : TideColors.bone.withValues(alpha: 0.2),
          width: 1.5,
        ),
      ),
      child: selected
          ? Icon(Icons.check_rounded, size: 15, color: TideColors.onLantern)
          : null,
    );
  }
}
