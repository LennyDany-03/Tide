/// What the app says when you finish something.
///
/// It used to say "Mission complete", every time, forever. Two things wrong
/// with that. It is borrowed language — a mission is a thing a game gives
/// you, and Tide does not give anybody anything to do; the habit was the
/// user's idea. And a line that never changes stops being read at all after
/// about a week, which is exactly the point at which a habit app most needs
/// to be saying something.
///
/// So: short lines, four to six words, picked at random per firing and held
/// steady for the length of the panel. They are written to be about the
/// person rather than about the app — "you kept the loop going", not
/// "objective achieved".
abstract final class CelebrationCopy {
  /// One habit finished, with more of the day still to go.
  static const List<String> completion = [
    'That is one more day',
    'You kept the loop going',
    'The water came in again',
    'Another day added to it',
    'You showed up for this',
    'That is the rhythm holding',
    'One more mark on the line',
    'Small thing, done again today',
    'The streak just got longer',
    'You did not skip today',
    'Quiet progress, banked for good',
    'Today belongs to you now',
    'The loop closed cleanly today',
    'Still going, and it shows',
  ];

  /// The log that finished every habit scheduled for today.
  static const List<String> dayComplete = [
    'Every habit is in today',
    'The whole day just surfaced',
    'You cleared the entire day',
    'Nothing left on the list',
    'A full day, start to finish',
    'That is the whole day done',
    'All of it, done today',
  ];

  /// A freeze spent. Encouraging, but never congratulatory — a held streak
  /// is not an advanced one, and the copy must not pretend otherwise.
  static const List<String> frozen = [
    'Your streak is safely held',
    'The loop survives this one',
    'Held, and nothing was lost',
    'Rest counts, the streak stands',
    'Paused, not broken, not lost',
  ];

  /// Picks a line and keeps picking the same one for the same [seed].
  ///
  /// The cue's nonce is the seed, which is what makes the headline stable
  /// across the rebuilds that happen while the panel is on screen — a line
  /// that reshuffled mid-animation would be unreadable.
  static String pick(List<String> lines, int seed) =>
      lines[seed.abs() % lines.length];
}
