import 'package:flutter/material.dart';

/// The icon vocabulary, in two families.
///
/// The abstract marks — a crescent, a peak, a diamond — are painted by
/// `HabitGlyphPainter` and belong to the app's own furniture: milestone
/// badges, tab icons, the celebration marker. They read as one instrument
/// panel, which is right for chrome that repeats on every screen.
///
/// The pictographic set is everything a *habit* can wear. Abstract shapes
/// were the whole picker at first and they failed the one job a habit icon
/// has: you scan a list of five cards and know which row is water and
/// which is the evening walk without reading either name. A half-moon
/// beside "Morning water" tells you nothing. These are Material's rounded
/// glyphs — already bundled, already drawn by people who draw icons for a
/// living, and consistent with each other at 17px.
///
/// Both live in one enum so `Habit.glyph` did not have to become a sum
/// type: [icon] is null for a drawn mark and set for a pictographic one,
/// and [HabitGlyph] picks the renderer from that.
enum TideGlyph {
  // --- Abstract marks (painted) ---------------------------------------
  crescent,
  lines,
  peak,
  halfMoon,
  diamond,
  square,
  diamondOutline,
  dot,
  striped,
  hexagon,
  sparkle,
  ring,

  // --- Body -----------------------------------------------------------
  water(Icons.water_drop_rounded, 'Water'),
  meal(Icons.restaurant_rounded, 'Meal'),
  coffee(Icons.local_cafe_rounded, 'Coffee'),
  meds(Icons.medication_rounded, 'Meds'),
  sleep(Icons.bedtime_rounded, 'Sleep'),
  vitals(Icons.monitor_heart_rounded, 'Health'),
  shower(Icons.shower_rounded, 'Shower'),
  care(Icons.spa_rounded, 'Self care'),

  // --- Movement --------------------------------------------------------
  walk(Icons.directions_walk_rounded, 'Walk'),
  run(Icons.directions_run_rounded, 'Run'),
  gym(Icons.fitness_center_rounded, 'Gym'),
  cycle(Icons.directions_bike_rounded, 'Cycle'),
  swim(Icons.pool_rounded, 'Swim'),
  ballSport(Icons.sports_soccer_rounded, 'Sport'),
  hike(Icons.hiking_rounded, 'Hike'),
  martialArts(Icons.sports_martial_arts_rounded, 'Practice'),

  // --- Mind ------------------------------------------------------------
  read(Icons.menu_book_rounded, 'Read'),
  journal(Icons.edit_note_rounded, 'Journal'),
  study(Icons.school_rounded, 'Study'),
  language(Icons.translate_rounded, 'Language'),
  meditate(Icons.self_improvement_rounded, 'Meditate'),
  focus(Icons.psychology_rounded, 'Focus'),
  ideas(Icons.lightbulb_rounded, 'Ideas'),
  stories(Icons.auto_stories_rounded, 'Learn'),

  // --- Make ------------------------------------------------------------
  code(Icons.code_rounded, 'Code'),
  draw(Icons.brush_rounded, 'Draw'),
  music(Icons.music_note_rounded, 'Music'),
  photo(Icons.photo_camera_rounded, 'Photo'),
  piano(Icons.piano_rounded, 'Instrument'),
  voice(Icons.mic_rounded, 'Voice'),
  work(Icons.work_rounded, 'Work'),
  spark(Icons.bolt_rounded, 'Energy'),

  // --- Life ------------------------------------------------------------
  tidy(Icons.cleaning_services_rounded, 'Tidy'),
  save(Icons.savings_rounded, 'Save'),
  screenOff(Icons.phonelink_off_rounded, 'Screen off'),
  outdoors(Icons.park_rounded, 'Outdoors'),
  pets(Icons.pets_rounded, 'Pets'),
  kindness(Icons.volunteer_activism_rounded, 'Kindness'),
  connect(Icons.forum_rounded, 'Connect'),
  plants(Icons.local_florist_rounded, 'Plants'),
  sunlight(Icons.wb_sunny_rounded, 'Daylight'),
  windDown(Icons.dark_mode_rounded, 'Wind down'),
  laundry(Icons.checkroom_rounded, 'Laundry'),
  wake(Icons.alarm_rounded, 'Wake'),
  green(Icons.eco_rounded, 'Green'),
  love(Icons.favorite_rounded, 'Love');

  const TideGlyph([this.icon, this.label = '']);

  /// Null for the painted marks; a Material glyph otherwise.
  final IconData? icon;

  /// What the picker calls it. Empty for the abstract marks, which have no
  /// subject to name.
  final String label;

  /// Whether this one is drawn by hand rather than set from the icon font.
  bool get isDrawn => icon == null;
}

/// One tab of the icon picker.
@immutable
class GlyphGroup {
  const GlyphGroup(this.name, this.glyphs);

  final String name;
  final List<TideGlyph> glyphs;
}

/// What the add/edit screen offers, grouped so forty icons stay findable.
///
/// The abstract marks lead, because they are the app's native shapes and
/// the right answer for a habit that has no picture — "read ten pages" has
/// one, "be less online at night" does not.
abstract final class GlyphCatalog {
  static const List<GlyphGroup> groups = [
    GlyphGroup('Marks', [
      TideGlyph.crescent,
      TideGlyph.lines,
      TideGlyph.peak,
      TideGlyph.halfMoon,
      TideGlyph.diamond,
      TideGlyph.square,
      TideGlyph.diamondOutline,
      TideGlyph.dot,
      TideGlyph.hexagon,
      TideGlyph.sparkle,
      TideGlyph.ring,
      TideGlyph.striped,
    ]),
    GlyphGroup('Body', [
      TideGlyph.water,
      TideGlyph.meal,
      TideGlyph.coffee,
      TideGlyph.meds,
      TideGlyph.sleep,
      TideGlyph.vitals,
      TideGlyph.shower,
      TideGlyph.care,
    ]),
    GlyphGroup('Move', [
      TideGlyph.walk,
      TideGlyph.run,
      TideGlyph.gym,
      TideGlyph.cycle,
      TideGlyph.swim,
      TideGlyph.ballSport,
      TideGlyph.hike,
      TideGlyph.martialArts,
    ]),
    GlyphGroup('Mind', [
      TideGlyph.read,
      TideGlyph.journal,
      TideGlyph.study,
      TideGlyph.language,
      TideGlyph.meditate,
      TideGlyph.focus,
      TideGlyph.ideas,
      TideGlyph.stories,
    ]),
    GlyphGroup('Make', [
      TideGlyph.code,
      TideGlyph.draw,
      TideGlyph.music,
      TideGlyph.photo,
      TideGlyph.piano,
      TideGlyph.voice,
      TideGlyph.work,
      TideGlyph.spark,
    ]),
    GlyphGroup('Life', [
      TideGlyph.tidy,
      TideGlyph.save,
      TideGlyph.screenOff,
      TideGlyph.outdoors,
      TideGlyph.pets,
      TideGlyph.kindness,
      TideGlyph.connect,
      TideGlyph.plants,
      TideGlyph.sunlight,
      TideGlyph.windDown,
      TideGlyph.laundry,
      TideGlyph.wake,
      TideGlyph.green,
      TideGlyph.love,
    ]),
  ];

  /// Every offered glyph, flattened.
  static List<TideGlyph> get all => [
    for (final group in groups) ...group.glyphs,
  ];

  /// The group [glyph] belongs to, so opening the editor on an existing
  /// habit lands on the tab its icon is actually in.
  static int groupIndexOf(TideGlyph glyph) {
    for (var i = 0; i < groups.length; i++) {
      if (groups[i].glyphs.contains(glyph)) return i;
    }
    return 0;
  }
}
