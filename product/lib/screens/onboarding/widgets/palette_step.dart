import 'package:flutter/material.dart';

import '../../../services/tide_scope.dart';
import '../../../theme/tide_colors.dart';
import '../../../theme/tide_palette.dart';
import '../../../theme/tide_typography.dart';
import '../../../widgets/palette_option.dart';
import '../../../widgets/stagger_list.dart';

/// The one question onboarding asks: which light the app is drawn in.
///
/// Everything else the old wizard asked has an answer inside the product,
/// but a palette is different — it is the first thing seen on every launch
/// after this one, and someone who reads on paper-white all day should not
/// have to find Settings before Tide stops glaring at them.
///
/// A tap repaints the whole flow, this page included, so the choice is
/// previewed by living in it rather than on a swatch. The default is
/// already selected, so Next is always a valid answer and the question never
/// blocks anyone.
class PaletteStep extends StatelessWidget {
  const PaletteStep({super.key});

  @override
  Widget build(BuildContext context) {
    final store = TideScope.of(context);
    final current = store.palette;

    Widget group(String name, String hint, bool light) {
      final palettes = TidePalettes.all.where((p) => p.isLight == light);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(name, style: TideType.sectionHeader),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  hint,
                  style: TideType.labelMuted,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final palette in palettes) ...[
            PaletteOption(
              palette: palette,
              selected: identical(palette, current),
              onTap: () => store.setPalette(palette),
            ),
            const SizedBox(height: 10),
          ],
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StaggerColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 10,
          children: [
            Text(
              'Make it yours',
              style: TideType.labelMuted.copyWith(color: TideColors.lantern),
            ),
            Text('Choose the light Tide is drawn in', style: TideType.hero),
            Text(
              'Tap one and every screen repaints in it, this one included. '
              'You can change it any time in Settings → Appearance.',
              style: TideType.bodyMuted,
            ),
          ],
        ),
        const SizedBox(height: 18),
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              group('Dark', 'Easy on the eyes at night', false),
              const SizedBox(height: 8),
              group('Light', 'Reads like paper in daylight', true),
            ],
          ),
        ),
      ],
    );
  }
}
