import '../services/models/milestone.dart';
import '../services/models/tide_glyph.dart';

/// The twenty-eight badges, ordered by how hard they are to reach.
///
/// Names stay inside the tidal metaphor — a spring tide, a full moon, deep
/// water — so the reward vocabulary matches the rest of the product rather
/// than reading as generic gamification.
///
/// **The order is load-bearing.** Everything that reads this list assumes
/// two things: thresholds ascend, and every streak badge comes before every
/// clean-day one. The route draws the list as a single journey and puts its
/// lantern at the first badge still locked, which is only the truth if the
/// unlocked badges form a prefix — a clean-day badge sitting mid-ladder
/// would unlock out of turn on a value the ladder is not measuring, and the
/// lantern would jump past streak badges nobody has reached.
///
/// The rungs are close together early and spread out later. The first week
/// is where a habit is actually won or lost, so days one, two, three and
/// five each get a marker; past a hundred days the gaps widen, because by
/// then the run is its own reward and a badge every fortnight would be
/// noise.
///
/// Glyphs repeat — there are twelve abstract marks and twenty-eight badges,
/// so they have to. The rotation is arranged so no two adjacent markers
/// wear the same one, which is the only place a repeat would read as an
/// error rather than as a set.
abstract final class MilestoneCatalog {
  static const List<Milestone> all = [
    // --- The first week ---------------------------------------------------
    Milestone(
      id: 'first-tide',
      name: 'First tide',
      glyph: TideGlyph.dot,
      threshold: 1,
      caption: '1 day',
    ),
    Milestone(
      id: 'ripple',
      name: 'Ripple',
      glyph: TideGlyph.lines,
      threshold: 2,
      caption: '2 days',
    ),
    Milestone(
      id: 'swell',
      name: 'Swell',
      glyph: TideGlyph.peak,
      threshold: 3,
      caption: '3 days',
    ),
    Milestone(
      id: 'slack-water',
      name: 'Slack water',
      glyph: TideGlyph.lines,
      threshold: 5,
      caption: '5 days',
    ),
    Milestone(
      id: 'one-week',
      name: 'One week',
      glyph: TideGlyph.crescent,
      threshold: 7,
      caption: '7 days',
    ),

    // --- The first month --------------------------------------------------
    Milestone(
      id: 'ebb-and-flow',
      name: 'Ebb and flow',
      glyph: TideGlyph.square,
      threshold: 10,
      caption: '10 days',
    ),
    Milestone(
      id: 'fortnight',
      name: 'Fortnight',
      glyph: TideGlyph.diamond,
      threshold: 14,
      caption: '14 days',
    ),
    Milestone(
      id: 'third-quarter',
      name: 'Third quarter',
      glyph: TideGlyph.halfMoon,
      threshold: 21,
      caption: '21 days',
    ),
    Milestone(
      id: 'full-moon',
      name: 'Full moon',
      glyph: TideGlyph.striped,
      threshold: 30,
      caption: '30 days',
    ),

    // --- The long middle --------------------------------------------------
    Milestone(
      id: 'undertow',
      name: 'Undertow',
      glyph: TideGlyph.hexagon,
      threshold: 40,
      caption: '40 days',
    ),
    Milestone(
      id: 'half-hundred',
      name: 'Half hundred',
      glyph: TideGlyph.square,
      threshold: 50,
      caption: '50 days',
    ),
    Milestone(
      id: 'spring-tide',
      name: 'Spring tide',
      glyph: TideGlyph.diamondOutline,
      threshold: 60,
      caption: '60 days',
    ),
    Milestone(
      id: 'headland',
      name: 'Headland',
      glyph: TideGlyph.peak,
      threshold: 75,
      caption: '75 days',
    ),
    Milestone(
      id: 'open-water',
      name: 'Open water',
      glyph: TideGlyph.ring,
      threshold: 90,
      caption: '90 days',
    ),
    Milestone(
      id: 'hundred',
      name: 'Hundred',
      glyph: TideGlyph.sparkle,
      threshold: 100,
      caption: '100 days',
    ),

    // --- Past the hundred -------------------------------------------------
    Milestone(
      id: 'trade-wind',
      name: 'Trade wind',
      glyph: TideGlyph.lines,
      threshold: 125,
      caption: '125 days',
    ),
    Milestone(
      id: 'meridian',
      name: 'Meridian',
      glyph: TideGlyph.crescent,
      threshold: 150,
      caption: '150 days',
    ),
    Milestone(
      id: 'solstice',
      name: 'Solstice',
      glyph: TideGlyph.ring,
      threshold: 180,
      caption: '180 days',
    ),
    Milestone(
      id: 'gulf-stream',
      name: 'Gulf stream',
      glyph: TideGlyph.lines,
      threshold: 210,
      caption: '210 days',
    ),
    Milestone(
      id: 'blue-water',
      name: 'Blue water',
      glyph: TideGlyph.hexagon,
      threshold: 250,
      caption: '250 days',
    ),
    Milestone(
      id: 'storm-glass',
      name: 'Storm glass',
      glyph: TideGlyph.square,
      threshold: 300,
      caption: '300 days',
    ),

    // --- The far water ----------------------------------------------------
    Milestone(
      id: 'deep-water',
      name: 'Deep water',
      glyph: TideGlyph.diamond,
      threshold: 365,
      caption: '365 days',
    ),
    Milestone(
      id: 'abyssal',
      name: 'Abyssal',
      glyph: TideGlyph.diamondOutline,
      threshold: 500,
      caption: '500 days',
    ),
    Milestone(
      id: 'two-years',
      name: 'Two years',
      glyph: TideGlyph.sparkle,
      threshold: 730,
      caption: '730 days',
    ),

    // --- Clean days -------------------------------------------------------
    //
    // Measured on a different number — days carried without spending a
    // freeze — so they sit after the whole streak ladder rather than being
    // slotted in among it by threshold. See the ordering note above.
    Milestone(
      id: 'clean-fortnight',
      name: 'Clean fortnight',
      glyph: TideGlyph.diamond,
      threshold: 14,
      caption: '14 clean',
      kind: MilestoneKind.cleanDays,
    ),
    Milestone(
      id: 'unbroken',
      name: 'Unbroken',
      glyph: TideGlyph.peak,
      threshold: 45,
      caption: '45 clean',
      kind: MilestoneKind.cleanDays,
    ),
    Milestone(
      id: 'no-freezes',
      name: 'No freezes',
      glyph: TideGlyph.halfMoon,
      threshold: 90,
      caption: '90 clean',
      kind: MilestoneKind.cleanDays,
    ),
    Milestone(
      id: 'glass-water',
      name: 'Glass water',
      glyph: TideGlyph.square,
      threshold: 200,
      caption: '200 clean',
      kind: MilestoneKind.cleanDays,
    ),
  ];
}
