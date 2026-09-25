import 'package:flutter/material.dart';

import 'tide_colors.dart';

/// Radii and shadows.
///
/// Two radii, not four. A screen carrying an 8, a 12, a 16 and a 24 at once
/// reads as assembled from parts; one carrying two reads as designed.
///
/// And almost no shadow. On a near-black ground a drop shadow is invisible
/// as light and visible as mud — it fogs the edge it was meant to sharpen.
/// Depth here is luminance separation plus a one-pixel lit top edge, which
/// is how a surface actually looks when light falls on it from above. The
/// deep shadow survives for the two or three objects genuinely floating
/// over the page.
abstract final class TideElevation {
  // --- Radii ------------------------------------------------------------

  /// Rows, inputs, chips, small controls.
  static const double r12 = 12;

  /// Cards, sheets, the FAB.
  static const double r20 = 20;

  static const radius12 = BorderRadius.all(Radius.circular(r12));
  static const radius20 = BorderRadius.all(Radius.circular(r20));

  /// Sheets are rounded on the top edge only.
  static const sheetRadius = BorderRadius.vertical(top: Radius.circular(r20));

  // --- Shadows ----------------------------------------------------------

  /// A card at rest casts nothing. Kept as an empty list so call sites can
  /// stay uniform rather than branching on null.
  static const List<BoxShadow> resting = <BoxShadow>[];

  /// Genuinely floating: sheets, the context menu, the FAB. Wide and soft,
  /// so it reads as occlusion rather than as a dark halo. Its strength comes
  /// from the palette — heavy on a dark ground, faint on a light one.
  static List<BoxShadow> get floating => [
    BoxShadow(
      color: TideColors.shadow,
      blurRadius: 40,
      offset: const Offset(0, 16),
      spreadRadius: -8,
    ),
  ];

  /// The one glow in the app, on the one object allowed to emit light.
  static List<BoxShadow> lanternGlow({double intensity = 1}) => [
    BoxShadow(
      color: TideColors.lantern.withValues(alpha: 0.22 * intensity),
      blurRadius: 32 * intensity,
      spreadRadius: -4 * intensity,
    ),
    ...floating,
  ];

  /// Light the tab pool throws onto the glass around it. Glow only — the
  /// pool sits inside the bar, and [floating]'s drop shadow under it would
  /// darken the label it sits over. On a light palette the accent is ink,
  /// and ink cannot glow — it would be a smudge — so it all but goes.
  static List<BoxShadow> get tabGlow => [
    BoxShadow(
      color: TideColors.lantern.withValues(
        alpha: TideColors.palette.isLight ? 0.08 : 0.26,
      ),
      blurRadius: 14,
      spreadRadius: -3,
      offset: const Offset(0, 2),
    ),
  ];

  // --- Inner highlight --------------------------------------------------

  /// Flutter has no inset shadow, so `TideSurface` draws this as a one-pixel
  /// line pinned inside the top edge. A fixed pixel rather than a gradient
  /// stop means it reads identically on a 56px row and a 300px card.
  static const double innerHighlightWidth = 1;

  /// Horizontal falloff for that line — brightest across the middle, gone
  /// before the corners so it never clips oddly on the radius.
  static Gradient get innerHighlightGradient => LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [
      Colors.transparent,
      TideColors.innerHighlight,
      TideColors.innerHighlight,
      Colors.transparent,
    ],
    stops: const [0, 0.1, 0.9, 1],
  );
}
