import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../services/tide_scope.dart';
import '../../theme/tide_palette.dart';
import '../../theme/tide_typography.dart';
import '../../widgets/palette_option.dart';
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

    Widget option(TidePalette palette) => PaletteOption(
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
