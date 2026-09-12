import 'package:flutter/material.dart';

import 'tide_palette.dart';

/// The complete Tide colour vocabulary, read from the active [TidePalette].
///
/// The tokens used to be compile-time constants holding one fixed set of
/// values. They are getters now, because the app ships several palettes and
/// every widget has to pick up the one in use without being told — the
/// palette is swapped here, in one place, and [TideTheme.applyPalette]
/// repaints the tree. Nothing outside `lib/theme/` names a colour value;
/// everything else names a role.
///
/// The discipline that makes it work is what is *not* here: there is no
/// second bright accent and no separate "completed" hue.
///
/// The organising idea is that the ground is the ground and the light is
/// the accent. The page is the entire canvas rather than a colour applied to
/// things on it, the ink is warm (or cool, on a cool palette — but always of
/// a piece with the ground), and [lantern] is the only chromatic mark in the
/// app.
///
/// Two hues sit outside that and are not accents: [coral] for destruction
/// and [frost] for a frozen day. Both are reserved — each one means exactly
/// one thing, and nothing else may reach for them. That is what keeps them
/// from becoming a second and third accent by drift.
abstract final class TideColors {
  static TidePalette _palette = TidePalettes.standard;

  /// The palette every token below is currently reading from.
  static TidePalette get palette => _palette;

  /// Points every token at [palette]. Use [TideTheme.applyPalette] from
  /// app code, which also repaints what is already on screen.
  static void use(TidePalette palette) => _palette = palette;

  // --- Ground -----------------------------------------------------------

  /// Page background. Far enough from a surface that the surface separates
  /// on luminance alone, which is what lets every card drop its gradient.
  static Color get deepWater => _palette.deepWater;

  /// A card, or a row that has lifted off the page.
  static Color get shelf => _palette.shelf;

  /// One step above a card: sheets, menus, the thing you just opened.
  static Color get shoal => _palette.shoal;

  /// Cut *into* a surface — inputs, empty grid cells, an inactive track.
  /// Darker than the page, because a recess shows what is below.
  static Color get trench => _palette.trench;

  // --- Ink --------------------------------------------------------------

  /// Primary text.
  ///
  /// The single highest-leverage token in the file. On Deep water it is
  /// warm on purpose: cool text on a cool ground gives a screen no
  /// temperature and reads as dim rather than deep.
  static Color get bone => _palette.bone;

  /// Muted text. Same temperature as [bone], lower in value, so secondary
  /// copy recedes without breaking the one-light-source illusion.
  static Color get silt => _palette.silt;

  // --- Accent -----------------------------------------------------------

  /// The only accent in the app: progress, active state, completion.
  ///
  /// State is carried by the *intensity* of this one hue rather than by a
  /// second colour — a habit part-done is lantern at low alpha, a habit
  /// done is lantern solid. One hue for the whole state machine is what
  /// stops a screen looking like a status dashboard.
  static Color get lantern => _palette.lantern;

  /// Ink sitting on a solid [lantern] fill: a primary button's label, the
  /// check in a finished habit's mark.
  ///
  /// Its own token because it cannot be derived. On a dark palette it is
  /// the page colour; on a light palette with a dark accent it is near
  /// white. Using [deepWater] for this, as the app once did, puts a pale
  /// page colour on a black Paper button.
  static Color get onLantern => _palette.onLantern;

  /// Destructive only. Deliberately the rarest thing on screen.
  static Color get coral => _palette.coral;

  /// Frozen only — the temperature opposite of [lantern].
  ///
  /// A freeze holds a streak; it does not advance one, and it must not read
  /// as though it did. The left swipe used to paint itself in lantern,
  /// exactly like the right one, telling the two apart only by which icon
  /// had faded in. Ice is the obvious reading of "held, not earned".
  ///
  /// This is not a second accent. Nothing reaches for it except a freeze,
  /// the same way nothing reaches for [coral] except destruction.
  static Color get frost => _palette.frost;

  // --- Fire -------------------------------------------------------------

  /// The two ends of the streak flame's ramp, tuned per palette to sit
  /// either side of [lantern].
  ///
  /// A flame filled in flat lantern read as a sticker — one colour with no
  /// heat moving through it. Fire runs from a pale hot face to a deeper end
  /// where it cools. Only the flame reaches for these, and on every palette
  /// the ember stops well short of [coral].
  static Color get flare => _palette.flare;

  static Color get ember => _palette.ember;

  // --- Derived ----------------------------------------------------------

  /// The palette's brightest light: the lit face on the flame, the grain.
  static Color get glint => _palette.glint;

  /// Hairline separator. Same temperature as the ink it divides.
  static Color get hairline => bone.withValues(alpha: 0.09);

  /// The 1px lit top edge on a raised surface.
  static Color get innerHighlight => _palette.innerHighlight;

  /// Backdrop behind modals and the long-press menu.
  static Color get scrim => _palette.scrim;

  /// The floating shadow's colour.
  static Color get shadow => _palette.shadow;

  // --- Intensity --------------------------------------------------------

  /// The accent at completion level [t] in 0..1 — the single source of
  /// truth for "how full is this", shared by the heatmap, the calendar
  /// cells and the week strips so a given level always reads the same
  /// everywhere.
  ///
  /// Zero is a faint ink wash rather than transparent or a trench. A cell
  /// darker than the page reads as a hole punched in the grid, and at these
  /// sizes a hole is indistinguishable from missing data — the week strip
  /// has to show seven days whether or not anything happened on them.
  /// Pass [hue] to shade a cell in something other than the accent — the
  /// only caller that does is a frozen day, which is [frost].
  static Color intensity(double t, {Color? hue}) {
    final level = t.clamp(0.0, 1.0);
    if (level <= 0) return bone.withValues(alpha: 0.07);
    return (hue ?? lantern).withValues(
      alpha: 0.16 + 0.84 * Curves.easeIn.transform(level),
    );
  }

  /// Desaturated [color], for the drain transition on a paused habit and
  /// for locked milestones.
  static Color drained(Color color, double amount) {
    final grey = Color.lerp(silt, deepWater, 0.45)!;
    return Color.lerp(color, grey, amount.clamp(0.0, 1.0))!;
  }
}
