import 'package:flutter/material.dart';

/// One complete colour vocabulary for the app.
///
/// Every screen reads its colours through [TideColors], and [TideColors]
/// reads them from whichever palette is active. So a palette has to name
/// *roles*, never hues: [deepWater] is "the page", [lantern] is "the one
/// accent", [onLantern] is "ink sitting on the accent". A light palette
/// fills the same roles with light values, and nothing downstream needs to
/// know it is light.
///
/// The roles, and the relationships every palette has to keep:
///
/// * [deepWater] is the page. [shelf] is a card one step off it, [shoal] a
///   sheet or menu one step further, and [trench] a recess cut *into* a
///   surface — darker than the page on a dark palette, and on a light one
///   too, because a hole always shows shadow.
/// * [bone] is primary ink and [silt] muted ink. Both must read on the page
///   and on a card.
/// * [lantern] is the only accent, and [onLantern] is the ink that sits on
///   a solid lantern fill — a primary button, a done check.
/// * [coral] means destruction and [frost] means a frozen day. Neither may
///   be mistaken for the accent, which is why a blue accent gets a pale
///   frost and a pink accent gets a red-orange coral.
/// * [flare] and [ember] are the streak flame's hot and cool ends.
@immutable
class TidePalette {
  const TidePalette({
    required this.id,
    required this.name,
    required this.description,
    required this.brightness,
    required this.deepWater,
    required this.shelf,
    required this.shoal,
    required this.trench,
    required this.bone,
    required this.silt,
    required this.lantern,
    required this.onLantern,
    required this.coral,
    required this.frost,
    required this.flare,
    required this.ember,
    required this.glint,
    required this.innerHighlight,
    required this.scrim,
    required this.shadow,
  });

  final String id;

  /// Shown in Settings — a name, not a description of the colours.
  final String name;

  /// One line under the name, saying what the palette looks like.
  final String description;

  /// Drives the status-bar icons and Material's own defaults.
  final Brightness brightness;

  final Color deepWater;
  final Color shelf;
  final Color shoal;
  final Color trench;
  final Color bone;
  final Color silt;
  final Color lantern;
  final Color onLantern;
  final Color coral;
  final Color frost;
  final Color flare;
  final Color ember;

  /// The palette's brightest light — a lit face on the flame, the grain on
  /// a dark ground. Near-white on every palette, dark ones included.
  final Color glint;

  /// The one-pixel lit top edge on a raised surface. Faint warm ink on a
  /// dark palette; strong white on a light one, where a surface catches
  /// light by being brighter rather than by glowing.
  final Color innerHighlight;

  /// The dim behind modals and the long-press menu.
  final Color scrim;

  /// The colour of the one floating shadow. Heavy on dark grounds, where a
  /// light shadow is invisible; faint on light ones, where a heavy shadow is
  /// mud.
  final Color shadow;

  bool get isLight => brightness == Brightness.light;
}

/// The palettes Tide ships.
///
/// Each one is tuned against the same contrast floors, which
/// `test/palette_test.dart` enforces: primary ink on the page, muted ink on
/// the page, the accent on the page, and ink on the accent.
abstract final class TidePalettes {
  /// The original: warm lantern light over cold deep water.
  static const deepWater = TidePalette(
    id: 'deep_water',
    name: 'Deep water',
    description: 'Warm lantern light over dark water',
    brightness: Brightness.dark,
    deepWater: Color(0xFF071216),
    shelf: Color(0xFF0E1D22),
    shoal: Color(0xFF17272D),
    trench: Color(0xFF040D10),
    bone: Color(0xFFEDE6DA),
    silt: Color(0xFF948C80),
    lantern: Color(0xFFE9B466),
    onLantern: Color(0xFF071216),
    coral: Color(0xFFD2685C),
    frost: Color(0xFFD3E9F4),
    flare: Color(0xFFFACC4C),
    ember: Color(0xFFED621D),
    glint: Color(0xFFEDE6DA),
    innerHighlight: Color(0x0FEDE6DA),
    scrim: Color(0xB802080A),
    shadow: Color(0xB3010507),
  );

  /// Near-black with a sky-blue accent. Frost goes pale grey here rather
  /// than icy blue, so a frozen day cannot be mistaken for a finished one.
  static const midnight = TidePalette(
    id: 'midnight',
    name: 'Midnight',
    description: 'Sky-blue light on near-black',
    brightness: Brightness.dark,
    deepWater: Color(0xFF05080B),
    shelf: Color(0xFF0C1217),
    shoal: Color(0xFF141C23),
    trench: Color(0xFF020406),
    bone: Color(0xFFE8F1F6),
    silt: Color(0xFF7F8E99),
    lantern: Color(0xFF62C6F0),
    onLantern: Color(0xFF03131B),
    coral: Color(0xFFE0675E),
    frost: Color(0xFFE0E7EE),
    flare: Color(0xFFB9ECFF),
    ember: Color(0xFF1F86C9),
    glint: Color(0xFFE8F1F6),
    innerHighlight: Color(0x0FE8F1F6),
    scrim: Color(0xB8010305),
    shadow: Color(0xB3010204),
  );

  /// Black and white, and nothing else. The accent *is* the ink, so state
  /// reads by fill and weight rather than by colour; frost keeps a muted
  /// blue because a frozen day still has to be told apart at a glance.
  static const ink = TidePalette(
    id: 'ink',
    name: 'Ink',
    description: 'Black and white, nothing else',
    brightness: Brightness.dark,
    deepWater: Color(0xFF0A0A0B),
    shelf: Color(0xFF141415),
    shoal: Color(0xFF1E1E20),
    trench: Color(0xFF050506),
    bone: Color(0xFFF2F1EE),
    silt: Color(0xFF8D8C89),
    lantern: Color(0xFFF2F1EE),
    onLantern: Color(0xFF0A0A0B),
    coral: Color(0xFFE0625A),
    frost: Color(0xFF8FB8D4),
    flare: Color(0xFFFFFFFF),
    ember: Color(0xFF8A8A8E),
    glint: Color(0xFFF2F1EE),
    innerHighlight: Color(0x0FF2F1EE),
    scrim: Color(0xB8030303),
    shadow: Color(0xB3020202),
  );

  /// Soft pink paper with a rose accent. The rose is deep enough to carry
  /// white text; coral swings red-orange so destruction never reads as the
  /// accent.
  static const blossom = TidePalette(
    id: 'blossom',
    name: 'Blossom',
    description: 'Pink paper with rose accents',
    brightness: Brightness.light,
    deepWater: Color(0xFFF9EEF1),
    shelf: Color(0xFFFFF9FB),
    shoal: Color(0xFFFFFFFF),
    trench: Color(0xFFEFDCE2),
    bone: Color(0xFF3A1E28),
    silt: Color(0xFF8A6874),
    lantern: Color(0xFFC93A6C),
    onLantern: Color(0xFFFFFFFF),
    coral: Color(0xFFB83A22),
    frost: Color(0xFF4E86B3),
    flare: Color(0xFFF28DB2),
    ember: Color(0xFF9E1F4F),
    glint: Color(0xFFFFFFFF),
    innerHighlight: Color(0xCCFFFFFF),
    scrim: Color(0x663A1E28),
    shadow: Color(0x243A1E28),
  );

  /// White paper and black ink. Frost turns a real blue here: a near-white
  /// frost on a white page would be invisible.
  static const paper = TidePalette(
    id: 'paper',
    name: 'Paper',
    description: 'White paper, black ink',
    brightness: Brightness.light,
    deepWater: Color(0xFFF4F3EF),
    shelf: Color(0xFFFFFFFF),
    shoal: Color(0xFFFFFFFF),
    trench: Color(0xFFE7E5DF),
    bone: Color(0xFF161616),
    silt: Color(0xFF716E67),
    lantern: Color(0xFF161616),
    onLantern: Color(0xFFFAFAF7),
    coral: Color(0xFFBF3B2A),
    frost: Color(0xFF4A82AE),
    flare: Color(0xFF6E6E6E),
    ember: Color(0xFF0B0B0B),
    glint: Color(0xFFFFFFFF),
    innerHighlight: Color(0xCCFFFFFF),
    scrim: Color(0x5C161616),
    shadow: Color(0x1F161616),
  );

  /// In the order Settings lists them: the dark palettes, then the light.
  static const List<TidePalette> all = [
    deepWater,
    midnight,
    ink,
    blossom,
    paper,
  ];

  static TidePalette byId(String id) =>
      all.firstWhere((palette) => palette.id == id, orElse: () => deepWater);
}
