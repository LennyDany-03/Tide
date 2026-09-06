import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'tide_colors.dart';
import 'tide_elevation.dart';
import 'tide_typography.dart';

/// Assembles the Material theme from the Tide tokens.
///
/// Note the transparent splash and highlight: press feedback in this app is
/// always `PressScale`, never a Material ink ripple. Leaving ink enabled
/// would put two different press languages on screen at once.
abstract final class TideTheme {
  static ThemeData get dark {
    const scheme = ColorScheme.dark(
      primary: TideColors.lantern,
      onPrimary: TideColors.deepWater,
      secondary: TideColors.lantern,
      onSecondary: TideColors.deepWater,
      tertiary: TideColors.lantern,
      error: TideColors.coral,
      onError: TideColors.bone,
      surface: TideColors.shelf,
      onSurface: TideColors.bone,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
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

  /// Light status-bar icons on the deep-water ground, edge-to-edge.
  ///
  /// The ground is flat now, so the navigation bar simply takes the token.
  static final SystemUiOverlayStyle overlayStyle = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: TideColors.deepWater,
    systemNavigationBarDividerColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.light,
    systemNavigationBarContrastEnforced: false,
  );
}
