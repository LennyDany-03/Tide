import 'package:flutter/material.dart';

import 'tide_colors.dart';

/// Two families, split hard by role.
///
/// * **Space Grotesk** — every figure, and headings from 22px up. It is
///   held back from text sizes deliberately: a display face that only ever
///   appears large keeps its character, where one used at 13px for a switch
///   label is just another sans.
/// * **Manrope** — everything at reading size.
///
/// JetBrains Mono is gone. Space Grotesk descends from Space Mono and its
/// numerals are already uniform width, so the odometer stays stable without
/// a third family — and a monospace face on small data labels is a tell
/// that makes an interface look like a developer tool rather than a
/// finished product.
///
/// The scale is 12 / 14 / 16 / 22 / 34 / 56. The previous one ran
/// 11 / 12.5 / 13.5 / 14.5 / 17 — five sizes inside six pixels, which is
/// why every screen read as one flat plane. Hierarchy needs real distance.
abstract final class TideType {
  static const displayFamily = 'Space Grotesk';
  static const bodyFamily = 'Manrope';

  /// Uniform-width figures, so a roll from 9 to 10 never shifts the digits
  /// beside it.
  static const _tabular = <FontFeature>[FontFeature.tabularFigures()];

  // --- Display (Space Grotesk) ------------------------------------------

  /// Screen titles. Large and *medium* weight, not bold — at 34px the size
  /// already carries the emphasis, and bold on top of it reads shouty.
  static const screenTitle = TextStyle(
    fontFamily: displayFamily,
    fontWeight: FontWeight.w500,
    fontSize: 34,
    height: 1.05,
    letterSpacing: -1.2,
    color: TideColors.bone,
  );

  /// Sheet and card headlines, the onboarding hero.
  static const hero = TextStyle(
    fontFamily: displayFamily,
    fontWeight: FontWeight.w500,
    fontSize: 22,
    height: 1.2,
    letterSpacing: -0.6,
    color: TideColors.bone,
  );

  // --- Text (Manrope) ---------------------------------------------------

  /// Row titles and habit names.
  static const heading = TextStyle(
    fontFamily: bodyFamily,
    fontWeight: FontWeight.w500,
    fontSize: 16,
    height: 1.25,
    letterSpacing: -0.1,
    color: TideColors.bone,
  );

  static const body = TextStyle(
    fontFamily: bodyFamily,
    fontWeight: FontWeight.w400,
    fontSize: 14.5,
    height: 1.5,
    color: TideColors.bone,
  );

  static const bodyMuted = TextStyle(
    fontFamily: bodyFamily,
    fontWeight: FontWeight.w400,
    fontSize: 14.5,
    height: 1.5,
    color: TideColors.silt,
  );

  static const label = TextStyle(
    fontFamily: bodyFamily,
    fontWeight: FontWeight.w500,
    fontSize: 14,
    height: 1.3,
    color: TideColors.bone,
  );

  static const labelMuted = TextStyle(
    fontFamily: bodyFamily,
    fontWeight: FontWeight.w400,
    fontSize: 13,
    height: 1.35,
    color: TideColors.silt,
  );

  /// Group headers in settings and elsewhere.
  ///
  /// Sentence case, no tracking. Tracked-out capitals above every block are
  /// the loudest piece of template chrome an interface can wear; a group
  /// label is a quiet signpost, and it should look like one.
  static const sectionHeader = TextStyle(
    fontFamily: bodyFamily,
    fontWeight: FontWeight.w500,
    fontSize: 13,
    height: 1.3,
    letterSpacing: 0,
    color: TideColors.silt,
  );

  static const button = TextStyle(
    fontFamily: bodyFamily,
    fontWeight: FontWeight.w700,
    fontSize: 15,
    height: 1.2,
    letterSpacing: 0,
    color: TideColors.bone,
  );

  // --- Figures (Space Grotesk, tabular) ---------------------------------

  /// Every streak, percentage and count goes through here.
  static TextStyle gauge(
    double size, {
    Color color = TideColors.bone,
    FontWeight weight = FontWeight.w500,
    double? height,
    double letterSpacing = -0.4,
  }) {
    return TextStyle(
      fontFamily: displayFamily,
      fontWeight: weight,
      fontSize: size,
      height: height ?? 1.0,
      letterSpacing: letterSpacing,
      color: color,
      fontFeatures: _tabular,
    );
  }

  /// The one enormous figure on a screen. Nothing else comes close to it,
  /// which is the entire point.
  static TextStyle gaugeHero({Color color = TideColors.bone}) =>
      gauge(56, color: color, letterSpacing: -3);

  /// Stat figures on habit detail and insights.
  static TextStyle gaugeStat({Color color = TideColors.bone}) =>
      gauge(22, color: color, letterSpacing: -0.9);

  /// Small inline counters — streak numbers, "5/8", freeze counts.
  static TextStyle gaugeSmall({Color color = TideColors.lantern}) =>
      gauge(13, color: color, letterSpacing: -0.2);

  static TextTheme get textTheme => const TextTheme(
    displayLarge: screenTitle,
    displayMedium: hero,
    titleLarge: heading,
    titleMedium: label,
    bodyLarge: body,
    bodyMedium: body,
    bodySmall: labelMuted,
    labelLarge: button,
    labelSmall: sectionHeader,
  );
}
