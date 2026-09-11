import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'tide_colors.dart';
import 'tide_elevation.dart';
import 'tide_palette.dart';
import 'tide_typography.dart';

/// Assembles the Material theme from the Tide tokens, and switches palettes.
///
/// Note the transparent splash and highlight: press feedback in this app is
/// always `PressScale`, never a Material ink ripple. Leaving ink enabled
/// would put two different press languages on screen at once.
abstract final class TideTheme {
  /// Material's theme for whichever palette is active.
  static ThemeData get current {
    final palette = TideColors.palette;

    final scheme = ColorScheme(
      brightness: palette.brightness,
      primary: TideColors.lantern,
      onPrimary: TideColors.onLantern,
      secondary: TideColors.lantern,
      onSecondary: TideColors.onLantern,
      tertiary: TideColors.lantern,
      error: TideColors.coral,
      onError: TideColors.shoal,
      surface: TideColors.shelf,
      onSurface: TideColors.bone,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: palette.brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: TideColors.deepWater,
      canvasColor: TideColors.deepWater,
      fontFamily: TideType.bodyFamily,
      textTheme: TideType.textTheme,

      // Press feedback is PressScale everywhere — kill Material ink.
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
      splashFactory: NoSplash.splashFactory,

      textSelectionTheme: TextSelectionThemeData(
        cursorColor: TideColors.lantern,
        selectionColor: TideColors.lantern.withValues(alpha: 0.3),
        selectionHandleColor: TideColors.lantern,
      ),
      dividerTheme: DividerThemeData(
        color: TideColors.hairline,
        thickness: 1,
        space: 1,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      // Left unstyled, a snackbar is the one Material default that still
      // showed through: `fixed` behaviour paints an edge-to-edge slab in
      // `inverseSurface`, which on a dark scheme is a near-white band with
      // square corners sitting on top of the tab bar. Floating, shoal-filled
      // and hairlined, it becomes the same object as every other raised
      // surface in the app.
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: TideColors.shoal,
        contentTextStyle: TideType.label,
        actionTextColor: TideColors.lantern,
        elevation: 0,
        showCloseIcon: false,
        insetPadding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        shape: RoundedRectangleBorder(
          borderRadius: TideElevation.radius12,
          side: BorderSide(color: TideColors.bone.withValues(alpha: 0.08)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: TideColors.shoal,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: TideElevation.radius20,
        ),
      ),
      // One transition family on every platform. go_router supplies the
      // screen-specific transitions; this is only the fallback.
      pageTransitionsTheme: PageTransitionsTheme(
        builders: {
          for (final platform in TargetPlatform.values)
            platform: const FadeForwardsPageTransitionsBuilder(),
        },
      ),
    );
  }

  /// Status-bar and navigation-bar icons that read on the active ground,
  /// edge-to-edge: light icons on a dark palette, dark icons on a light one.
  static SystemUiOverlayStyle get overlayStyle {
    final light = TideColors.palette.isLight;
    final icons = light ? Brightness.dark : Brightness.light;

    return SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: icons,
      // iOS names the *bar*, not the icons, so it is the other way round.
      statusBarBrightness: light ? Brightness.light : Brightness.dark,
      systemNavigationBarColor: TideColors.deepWater,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness: icons,
      systemNavigationBarContrastEnforced: false,
    );
  }

  /// Makes [palette] the app's palette and repaints everything on screen in
  /// it, in the next frame, without losing any state.
  ///
  /// Every widget reads its colours from [TideColors] at build or paint
  /// time, but nothing *subscribes* to them — there are hundreds of reads,
  /// and threading a listener through every one would put theme plumbing in
  /// every file in the app. A palette change is rare and deliberate, so it
  /// pays for a single walk of the tree instead: every element is marked to
  /// rebuild and every render object to repaint. Scroll positions, open
  /// sheets, running animations and the tab you are on all survive, because
  /// nothing is torn down — the tree is only asked to draw itself again.
  ///
  /// The repaint matters as much as the rebuild. A painter whose inputs have
  /// not changed tells its render object nothing needs repainting, and it
  /// would keep the old palette's pixels until something else moved.
  static void applyPalette(TidePalette palette) {
    if (identical(TideColors.palette, palette)) return;
    TideColors.use(palette);
    SystemChrome.setSystemUIOverlayStyle(overlayStyle);

    final root = WidgetsBinding.instance.rootElement;
    if (root == null) return;

    void refresh(Element element) {
      element.markNeedsBuild();
      if (element is RenderObjectElement) {
        element.renderObject.markNeedsPaint();
      }
      element.visitChildren(refresh);
    }

    root.visitChildren(refresh);
  }
}
