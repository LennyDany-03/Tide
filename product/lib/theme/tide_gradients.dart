import 'package:flutter/material.dart';

import 'tide_colors.dart';
import 'tide_palette.dart';

/// The few ramps the app is allowed.
///
/// This file used to hold a gradient for every surface in the product —
/// page, card, row, well, pill, button, title text. When every object ramps,
/// none of them reads as lit; the screen just reads as busy. What survives
/// here is the page ground, one bloom recipe, the glass the tab bar is made
/// of, the accent ramp used *only* inside the tide curve, and the streak
/// flame's fill.
///
/// Cards are flat. They separate from the page on luminance, which is what
/// the palette was rebuilt to allow.
abstract final class TideGradients {
  // --- The page ---------------------------------------------------------
  //
  // There is no page gradient. The ground is flat [TideColors.deepWater],
  // and that is a functional requirement rather than only a stylistic one:
  // habit rows paint themselves in the page colour so they stay invisible
  // at rest but travel opaquely over the swipe backdrop when dragged. Any
  // variation in the ground — a vertical ramp, a bloom, a vignette — and
  // those rows stop matching what is behind them and appear as a lighter
  // slab down the middle of the screen.
  //
  // Depth on this page comes from luminance steps between the ground and
  // the surfaces on it, which is what the palette was rebuilt to allow.

  // --- Blooms -----------------------------------------------------------

  /// Seven-stop falloff approximating a gaussian.
  ///
  /// A two-stop radial fades its alpha linearly and the eye finds the exact
  /// circle where the ramp hits zero — you read a disc pasted on the page
  /// rather than light in water. Front-loading the falloff leaves almost no
  /// alpha to terminate at the rim, so the bloom has no findable edge.
  static const List<double> _bloomStops = [0, 0.12, 0.26, 0.42, 0.6, 0.8, 1];
  static const List<double> _bloomFalloff = [1, 0.86, 0.66, 0.44, 0.24, 0.09, 0];

  static RadialGradient bloom({
    required Color color,
    required double alpha,
    required Alignment center,
    required double radius,
  }) {
    return RadialGradient(
      center: center,
      radius: radius,
      stops: _bloomStops,
      colors: [
        for (final falloff in _bloomFalloff)
          color.withValues(alpha: alpha * falloff),
      ],
    );
  }

  /// The light on the water, at drift phase [t] in 0..1.
  ///
  /// One warm source, anchored off-canvas so only the outer half of the
  /// falloff — the part with no structure in it — is ever on screen. There
  /// used to be three of these in two hues; a single light is what makes a
  /// direction readable.
  ///
  /// Only onboarding paints these. It is the one screen with no rows to
  /// mismatch and no history to show, where a still ground reads as a page
  /// that has not finished loading.
  static List<RadialGradient> pageBlooms(double t) {
    final drift = Curves.easeInOut.transform(t.clamp(0.0, 1.0));
    return [
      bloom(
        color: TideColors.lantern,
        alpha: 0.07,
        center: Alignment(-0.75 + 0.18 * drift, -1.0 + 0.1 * drift),
        radius: 1.3 + 0.12 * drift,
      ),
    ];
  }

  // --- Glass ------------------------------------------------------------

  /// Fill for the one frosted panel in the app, the tab bar. Painted over a
  /// [BackdropFilter]: the blur supplies the colour, this supplies the sheen.
  static LinearGradient get glass => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      TideColors.bone.withValues(alpha: 0.055),
      TideColors.bone.withValues(alpha: 0.02),
    ],
  );

  // --- Accent -----------------------------------------------------------

  /// The lantern ramp under the waterline — bright where the light catches
  /// the surface, gone entirely a little way down.
  ///
  /// It has to reach zero rather than bottoming out at a low alpha. A fill
  /// that keeps a floor is a solid mass with a top edge on it, and a warm
  /// solid mass reads as sand, not as water. Fading out completely leaves
  /// only the lit surface, which is the part that says "water".
  static LinearGradient get tideFill => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      TideColors.lantern.withValues(alpha: 0.20),
      TideColors.lantern.withValues(alpha: 0),
    ],
    stops: const [0, 0.6],
  );

  // --- Fire -------------------------------------------------------------

  /// The streak flame's fill: pale and hot on the side the app's one light
  /// falls on, deepening to ember away from it. Top-left to bottom-right
  /// like every other ramp, so the mark is lit from the same side as the
  /// page it sits on.
  static LinearGradient get flame => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [TideColors.flare, TideColors.lantern, TideColors.ember],
    stops: const [0, 0.42, 1],
  );

  // --- The mark ---------------------------------------------------------
  //
  // These take a palette rather than reading the active tokens: the same
  // logo is drawn in the live palette inside the app and in Midnight on the
  // app icon, which is rendered once and does not change with the theme.

  /// The logo's ring: pale where the light falls on it, deep away from it.
  static LinearGradient markRing(TidePalette palette) => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [palette.flare, palette.lantern, palette.ember],
    stops: const [0, 0.45, 1],
  );

  /// The water inside the ring: bright at the surface, deepening to ember
  /// and thinning out toward the floor.
  static LinearGradient markWater(TidePalette palette) => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      palette.lantern.withValues(alpha: 0.9),
      palette.ember.withValues(alpha: 0.5),
    ],
  );

  /// The moon, lit from the top left like everything else.
  static RadialGradient markMoon(TidePalette palette) => RadialGradient(
    center: const Alignment(-0.35, -0.4),
    radius: 0.9,
    colors: [palette.flare, palette.lantern],
  );

  // --- Hairlines --------------------------------------------------------

  /// A separator that fades out at both ends rather than butting into a
  /// rounded corner.
  static LinearGradient get hairline => LinearGradient(
    colors: [
      Colors.transparent,
      TideColors.hairline,
      TideColors.hairline,
      Colors.transparent,
    ],
    stops: const [0, 0.06, 0.94, 1],
  );
}
