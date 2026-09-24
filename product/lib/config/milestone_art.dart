import '../services/models/milestone.dart';

/// The picture on each milestone's share card.
///
/// One scene per badge, never shared. The card is the thing people post to
/// say "I did this", and twenty-eight badges that all printed the same
/// layout with a different word on it made every post after the first look
/// like a repeat. Each scene is drawn from what the badge is called — a
/// single drop for the first tide, two ring sets crossing for a ripple, a
/// spiral of 365 points for a year — so the card says the milestone before
/// the name does.
enum MilestoneScene {
  drop,
  interference,
  swell,
  slack,
  moonWeek,
  ebbAndFlow,
  fortnightChart,
  thirdQuarter,
  fullMoon,
  undertow,
  halfHundred,
  springTide,
  headland,
  openWater,
  hundred,
  tradeWind,
  meridian,
  solstice,
  gulfStream,
  blueWater,
  stormGlass,
  deepWater,
  abyssal,
  twoYears,
  cleanChain,
  unbroken,
  thaw,
  glassWater,
}

/// Which of the palette's lights a scene is drawn in.
///
/// Named roles, not colours: they resolve through `TideColors`, so a card
/// shared from Paper is ink on paper and one from Midnight is sky-blue on
/// black, and no card can bring a hue of its own.
enum MilestoneInk { lantern, flare, ember, frost, coral }

class MilestoneArt {
  const MilestoneArt(this.scene, this.primary, this.secondary);

  final MilestoneScene scene;

  /// The scene's main line, and the card's figure and eyebrow.
  final MilestoneInk primary;

  /// Its one accent — the drop, the sun, the last of the seven moons.
  final MilestoneInk secondary;
}

abstract final class MilestoneArtCatalog {
  static const Map<String, MilestoneArt> byId = {
    'first-tide': MilestoneArt(
      MilestoneScene.drop,
      MilestoneInk.lantern,
      MilestoneInk.flare,
    ),
    'ripple': MilestoneArt(
      MilestoneScene.interference,
      MilestoneInk.lantern,
      MilestoneInk.frost,
    ),
    'swell': MilestoneArt(
      MilestoneScene.swell,
      MilestoneInk.lantern,
      MilestoneInk.flare,
    ),
    'slack-water': MilestoneArt(
      MilestoneScene.slack,
      MilestoneInk.frost,
      MilestoneInk.lantern,
    ),
    'one-week': MilestoneArt(
      MilestoneScene.moonWeek,
      MilestoneInk.flare,
      MilestoneInk.lantern,
    ),
    'ebb-and-flow': MilestoneArt(
      MilestoneScene.ebbAndFlow,
      MilestoneInk.lantern,
      MilestoneInk.coral,
    ),
    'fortnight': MilestoneArt(
      MilestoneScene.fortnightChart,
      MilestoneInk.lantern,
      MilestoneInk.flare,
    ),
    'third-quarter': MilestoneArt(
      MilestoneScene.thirdQuarter,
      MilestoneInk.frost,
      MilestoneInk.flare,
    ),
    'full-moon': MilestoneArt(
      MilestoneScene.fullMoon,
      MilestoneInk.flare,
      MilestoneInk.lantern,
    ),
    'undertow': MilestoneArt(
      MilestoneScene.undertow,
      MilestoneInk.ember,
      MilestoneInk.lantern,
    ),
    'half-hundred': MilestoneArt(
      MilestoneScene.halfHundred,
      MilestoneInk.lantern,
      MilestoneInk.coral,
    ),
    'spring-tide': MilestoneArt(
      MilestoneScene.springTide,
      MilestoneInk.coral,
      MilestoneInk.flare,
    ),
    'headland': MilestoneArt(
      MilestoneScene.headland,
      MilestoneInk.lantern,
      MilestoneInk.flare,
    ),
    'open-water': MilestoneArt(
      MilestoneScene.openWater,
      MilestoneInk.lantern,
      MilestoneInk.frost,
    ),
    'hundred': MilestoneArt(
      MilestoneScene.hundred,
      MilestoneInk.flare,
      MilestoneInk.coral,
    ),
    'trade-wind': MilestoneArt(
      MilestoneScene.tradeWind,
      MilestoneInk.frost,
      MilestoneInk.lantern,
    ),
    'meridian': MilestoneArt(
      MilestoneScene.meridian,
      MilestoneInk.lantern,
      MilestoneInk.flare,
    ),
    'solstice': MilestoneArt(
      MilestoneScene.solstice,
      MilestoneInk.coral,
      MilestoneInk.flare,
    ),
    'gulf-stream': MilestoneArt(
      MilestoneScene.gulfStream,
      MilestoneInk.coral,
      MilestoneInk.lantern,
    ),
    'blue-water': MilestoneArt(
      MilestoneScene.blueWater,
      MilestoneInk.ember,
      MilestoneInk.lantern,
    ),
    'storm-glass': MilestoneArt(
      MilestoneScene.stormGlass,
      MilestoneInk.frost,
      MilestoneInk.flare,
    ),
    'deep-water': MilestoneArt(
      MilestoneScene.deepWater,
      MilestoneInk.lantern,
      MilestoneInk.flare,
    ),
    'abyssal': MilestoneArt(
      MilestoneScene.abyssal,
      MilestoneInk.flare,
      MilestoneInk.ember,
    ),
    'two-years': MilestoneArt(
      MilestoneScene.twoYears,
      MilestoneInk.flare,
      MilestoneInk.lantern,
    ),
    'clean-fortnight': MilestoneArt(
      MilestoneScene.cleanChain,
      MilestoneInk.frost,
      MilestoneInk.lantern,
    ),
    'unbroken': MilestoneArt(
      MilestoneScene.unbroken,
      MilestoneInk.lantern,
      MilestoneInk.coral,
    ),
    'no-freezes': MilestoneArt(
      MilestoneScene.thaw,
      MilestoneInk.frost,
      MilestoneInk.coral,
    ),
    'glass-water': MilestoneArt(
      MilestoneScene.glassWater,
      MilestoneInk.frost,
      MilestoneInk.flare,
    ),
  };

  /// A badge from a newer build that this one has no picture for still gets
  /// a card — the first tide's, which suits anything.
  static MilestoneArt of(Milestone milestone) =>
      byId[milestone.id] ??
      const MilestoneArt(
        MilestoneScene.drop,
        MilestoneInk.lantern,
        MilestoneInk.flare,
      );
}
