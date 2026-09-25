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
  static const List<double> _bloomFalloff = [
    1,
    0.86,
    0.66,
    0.44,
    0.24,
    0.09,
    0,
  ];

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

  /// The water in the tab pool. Same idea as [tideFill] — brightest at the
  /// lit surface, thinning downward — but it keeps a floor: the pool is a
  /// few pixels deep, and water that fades to nothing that fast reads as a
  /// line rather than as something with depth.
  ///
  /// Far lighter on a light palette, where the accent is ink: at dark
  /// strength the pool went to a grey blob that drowned the icon in it.
  static LinearGradient get tabWater {
    final light = TideColors.palette.isLight;
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        TideColors.lantern.withValues(alpha: light ? 0.14 : 0.42),
        TideColors.lantern.withValues(alpha: light ? 0.04 : 0.12),
      ],
    );
  }

  // --- Milestone cards --------------------------------------------------

  /// The share card's ground: lit where the app's one light falls, deepest
  /// in the far corner. A flat ground made the exported image look like a
  /// screenshot of a sheet rather than a thing made to be posted.
  static LinearGradient get cardGround => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [TideColors.shelf, TideColors.deepWater, TideColors.trench],
    stops: const [0, 0.55, 1],
  );

  /// Light pooled around a scene's bright object — a moon, a lamp, the
  /// last point of a spiral. Falls to nothing, so it has no edge to find.
  static RadialGradient cardGlow(Color light, {double strength = 1}) =>
      RadialGradient(
        colors: [
          light.withValues(alpha: 0.34 * strength),
          light.withValues(alpha: 0.1 * strength),
          light.withValues(alpha: 0),
        ],
        stops: const [0, 0.45, 1],
      );

  /// The mask a card's scene is drawn through: whole at the top, gone by
  /// its foot, so the picture dissolves into the ground under the name
  /// instead of stopping at a line.
  static LinearGradient get cardSceneFade => const LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Colors.white, Colors.white, Colors.transparent],
    stops: [0, 0.62, 1],
  );

  // --- Reminders --------------------------------------------------------

  /// The ground of a Tide Call: night at the top, deepening toward the
  /// palette's deep end at the floor, where the water is. Top to bottom, the
  /// same light as everywhere else; the ember is what lets Midnight read as
  /// navy going to sea-blue rather than as black.
  static LinearGradient get callDepth {
    final light = TideColors.palette.isLight;
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        TideColors.trench,
        TideColors.deepWater,
        Color.lerp(TideColors.deepWater, TideColors.ember, light ? 0.08 : 0.3)!,
      ],
      stops: const [0, 0.5, 1],
    );
  }

  /// One layer of the call's water, far ([depth] 0) to near (2). Each is
  /// lantern at a low alpha, so three stacked read as depth and text over
  /// them keeps its contrast. Far lighter on a light palette, where the
  /// accent is ink and the same alphas turned the page to slate.
  static Color callWaterLayer(int depth) {
    final light = TideColors.palette.isLight;
    const dark = [0.10, 0.14, 0.2];
    const pale = [0.04, 0.06, 0.08];
    return TideColors.lantern.withValues(
      alpha: (light ? pale : dark)[depth.clamp(0, 2)],
    );
  }

  /// Under one layer's surface: lit at the waterline, thinning with depth.
  static LinearGradient callWater(Color surface) => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      surface,
      surface.withValues(alpha: surface.a * 0.4),
    ],
  );

  /// The Lighthouse's sky, from the top of the screen down to the horizon:
  /// night overhead, lifting to a faint haze of the lamp's own light where
  /// the air sits on the water. The haze is what puts the horizon at a
  /// distance; without it the sky and sea are two flat panels.
  static LinearGradient get lighthouseSky {
    final light = TideColors.palette.isLight;
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        TideColors.trench,
        TideColors.deepWater,
        Color.lerp(
          TideColors.deepWater,
          TideColors.lantern,
          light ? 0.035 : 0.075,
        )!,
      ],
      stops: const [0, 0.62, 1],
    );
  }

  /// The sea under it: a step darker than the haze at the horizon, so the
  /// line reads without being drawn hard, and darker still toward the
  /// controls that float on it.
  static LinearGradient get lighthouseSea => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color.lerp(TideColors.deepWater, TideColors.shelf, 0.55)!,
      TideColors.trench,
    ],
    stops: const [0, 0.7],
  );

  /// The tower, lit on the side the app's one light comes from and falling
  /// away into the night on the other.
  static LinearGradient get lighthouseTower => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color.lerp(TideColors.trench, TideColors.shoal, 0.7)!,
      TideColors.trench,
    ],
    stops: const [0, 0.75],
  );

  /// The beam, across its width: nothing at its edges, a hot core down the
  /// middle, falling away smoothly either side — a sweep round the lamp, so
  /// the edge is as soft a screen away as it is at the glass. [angle] is
  /// where it points and [spread] its half-width, both in radians; create
  /// the shader over a rect centred on where the beam starts.
  ///
  /// On a light palette the accent is ink, and a beam of ink is a shadow,
  /// so it is kept to a faint shade there.
  static SweepGradient beam({
    required double angle,
    required double spread,
    double strength = 1,
  }) {
    final alpha = (TideColors.palette.isLight ? 0.1 : 0.4) * strength;
    const shape = [0.0, 0.1, 0.3, 0.58, 1.0, 0.58, 0.3, 0.1, 0.0];
    return SweepGradient(
      endAngle: spread * 2,
      colors: [
        for (final share in shape)
          TideColors.lantern.withValues(alpha: alpha * share),
      ],
      stops: const [0, 0.16, 0.3, 0.42, 0.5, 0.58, 0.7, 0.84, 1],
      transform: GradientRotation(angle - spread),
    );
  }

  /// The beam along its length: whole at the glass, thinning to nothing by
  /// the far side of the screen. A mask — only its alpha counts — laid over
  /// [beam] with `BlendMode.dstIn`, since a gradient cannot vary both round
  /// a point and away from it.
  static RadialGradient get beamReach => RadialGradient(
    colors: [
      Colors.white,
      Colors.white.withValues(alpha: 0.46),
      Colors.white.withValues(alpha: 0.14),
      Colors.white.withValues(alpha: 0),
    ],
    stops: const [0, 0.26, 0.6, 1],
  );

  /// The glow round the lamp's glass at [glow] 0..1. Faint on a light
  /// palette, where a bloom of ink is a smudge rather than a light.
  static RadialGradient lampBloom(double glow) => bloom(
    color: TideColors.lantern,
    alpha: (TideColors.palette.isLight ? 0.18 : 0.55) * glow,
    center: Alignment.center,
    radius: 0.5,
  );

  /// The flash as the lamp turns to face you: a thin streak through the
  /// glass, the way an eye or a lens catches a point of light at night.
  static LinearGradient lampStreak(double alpha) => LinearGradient(
    colors: [
      TideColors.flare.withValues(alpha: 0),
      TideColors.flare.withValues(alpha: alpha),
      TideColors.flare.withValues(alpha: 0),
    ],
  );

  /// The beam passing across the to-do's slip: a soft band of the lamp's
  /// light at [at] (0 the top-left corner, 1 the bottom-right), as bright as
  /// [strength]. Top-left to bottom-right, the way the beam falls on it from
  /// a lamp below and to the left.
  static LinearGradient slipSheen({
    required double at,
    required double strength,
  }) {
    final alpha = (TideColors.palette.isLight ? 0.07 : 0.14) * strength;
    const half = 0.28;
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        TideColors.lantern.withValues(alpha: 0),
        TideColors.lantern.withValues(alpha: alpha),
        TideColors.lantern.withValues(alpha: 0),
      ],
      stops: [
        (at - half).clamp(0.0, 1.0),
        at.clamp(0.0, 1.0),
        (at + half).clamp(0.0, 1.0),
      ],
    );
  }

  /// "Slide to dock", with a gleam running through it toward the dock:
  /// muted ink either side of a band of full ink at phase [t] in 0..1. Used
  /// through a `ShaderMask`, so the words keep their own shape.
  static LinearGradient dockShimmer(double t) => LinearGradient(
    colors: [TideColors.silt, TideColors.bone, TideColors.silt],
    stops: const [0.38, 0.5, 0.62],
    transform: _Slide(-0.75 + 1.5 * t),
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

/// Slides a gradient sideways by [fraction] of the box it fills — how
/// [TideGradients.dockShimmer] moves its gleam without rewriting its stops,
/// which have to stay in order and inside 0..1.
class _Slide extends GradientTransform {
  const _Slide(this.fraction);

  final double fraction;

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(bounds.width * fraction, 0, 0);
}
