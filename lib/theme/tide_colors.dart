import 'package:flutter/material.dart';

/// The complete Tide palette.
///
/// The discipline that makes it work is what is *not* here: there is no
/// second bright accent and no separate "completed" hue.
///
/// The organising idea is that the water is the ground and the light is the
/// accent. Deep water is the entire canvas rather than a colour applied to
/// things on it, the ink is warm, and [lantern] is the only chromatic mark
/// in the app.
///
/// Two hues sit outside that and are not accents: [coral] for destruction
/// and [frost] for a frozen day. Both are reserved — each one means exactly
/// one thing, and nothing else may reach for them. That is what keeps them
/// from becoming a second and third accent by drift. A screen lit by one warm source over cold water has a
/// temperature to it; a screen where every element is a different shade of
/// the same cool blue does not, which is the failure this palette replaces.
abstract final class TideColors {
  // --- Ground -----------------------------------------------------------

  /// Page background. Deep enough that a surface can separate from it on
  /// luminance alone, which is what lets every card drop its gradient.
  static const deepWater = Color(0xFF071216);

  /// A card, or a row that has lifted off the page.
  static const shelf = Color(0xFF0E1D22);

  /// One step above a card: sheets, menus, the thing you just opened.
  static const shoal = Color(0xFF17272D);

  /// Cut *into* a surface — inputs, empty grid cells, an inactive track.
  /// Darker than the page, because a recess shows the water below.
  static const trench = Color(0xFF040D10);

  // --- Ink --------------------------------------------------------------

  /// Primary text. Warm on purpose.
  ///
  /// This is the single highest-leverage token in the file. Cool text
  /// (#E8F1F0) on a cool ground gives a screen no temperature and reads as
  /// dim rather than deep. Warm ink over cold water reads as light falling
  /// on something.
  static const bone = Color(0xFFEDE6DA);

  /// Muted text. A warm grey, so secondary copy recedes in *value* without
  /// changing temperature and breaking the one-light-source illusion.
  static const silt = Color(0xFF948C80);

  // --- Accent -----------------------------------------------------------

  /// The only accent in the app: progress, active state, completion.
  ///
  /// State is carried by the *intensity* of this one hue rather than by a
  /// second colour — a habit part-done is lantern at low alpha, a habit
  /// done is lantern solid. One hue for the whole state machine is what
  /// stops a screen looking like a status dashboard.
  static const lantern = Color(0xFFE9B466);

  /// Destructive only. Deliberately the rarest thing on screen.
  static const coral = Color(0xFFD2685C);

  /// Frozen only. A cold near-white — the temperature opposite of
  /// [lantern], and the one other place this palette admits a hue.
  ///
  /// A freeze holds a streak; it does not advance one, and it must not read
  /// as though it did. The left swipe used to paint itself in lantern,
  /// exactly like the right one: same tint, same wave, same warmth, telling
  /// the two apart only by which icon had faded in. Ice is the obvious
  /// reading of "held, not earned", and cold against a warm accent is a
  /// distinction the eye makes before it reads anything.
  ///
  /// This is not a second accent. Nothing reaches for it except a freeze,
  /// the same way nothing reaches for [coral] except destruction.
  static const frost = Color(0xFFD3E9F4);

  // --- Fire -------------------------------------------------------------

  /// The two ends of the streak flame's ramp: [lantern] turned a few degrees
  /// either way round the wheel, never picked fresh.
  ///
  /// A flame filled in flat lantern read as a sticker — one amber with no
  /// heat moving through it. Fire runs from a pale, yellower hot face to a
  /// deeper orange where it cools, and deriving both ends from the one
  /// accent keeps the mark lit by the same light as everything else. Only
  /// the flame reaches for these. The ember stops at orange, well short of
  /// the red that [coral] reserves for destruction.
  static final Color flare = HSLColor.fromColor(
    lantern,
  ).withHue(44).withSaturation(0.95).withLightness(0.64).toColor();

  static final Color ember = HSLColor.fromColor(
    lantern,
  ).withHue(20).withSaturation(0.85).withLightness(0.52).toColor();

  // --- Derived ----------------------------------------------------------

  /// Hairline separator. Warm, like the ink it divides.
  static final Color hairline = bone.withValues(alpha: 0.09);

  /// The 1px lit top edge on a raised surface.
  static final Color innerHighlight = bone.withValues(alpha: 0.06);

  /// Backdrop behind modals and the long-press menu.
  static final Color scrim = const Color(0xFF02080A).withValues(alpha: 0.72);

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
  static Color intensity(double t, {Color hue = lantern}) {
    final level = t.clamp(0.0, 1.0);
    if (level <= 0) return bone.withValues(alpha: 0.07);
    return hue.withValues(alpha: 0.16 + 0.84 * Curves.easeIn.transform(level));
  }

  /// Desaturated [color], for the drain transition on a paused habit and
  /// for locked milestones.
  static Color drained(Color color, double amount) {
    final grey = Color.lerp(silt, deepWater, 0.45)!;
    return Color.lerp(color, grey, amount.clamp(0.0, 1.0))!;
  }
}
