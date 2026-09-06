import 'package:flutter/foundation.dart';

enum CelebrationCueType { completion, freeze }


/// One completion worth celebrating, handed from the store to the overlay.
///
/// The store raises a cue rather than a screen calling a celebration
/// directly, because a habit can be completed from four places — a swipe on
/// Home, the counting sheet, habit detail, a tap in the day breakdown — and
/// wiring the reward into each of them would guarantee that one of them
/// eventually forgets. `TideStore.log` is the single choke point every one
/// of those paths already runs through, so the cue is raised there and the
/// overlay above the router plays it wherever you happen to be standing.
@immutable
class CelebrationCue {
  const CelebrationCue({
    required this.habitId,
    required this.habitName,
    required this.type,
    required this.streak,
    required this.dayComplete,
    required this.nonce,
  });

  final String habitId;
  final String habitName;
  final CelebrationCueType type;
  /// The streak *including* the day just logged — the figure the panel
  /// reports.
  final int streak;

  /// This log also finished every habit scheduled for today.
  ///
  /// Folded into the cue rather than left to Home's separate day-complete
  /// wash, so the two do not fire over the top of each other. One event
  /// gets one moment; the panel simply says a bigger thing when the day is
  /// the thing that closed.
  final bool dayComplete;

  /// Changes on every firing. The panel seeds its copy picker with this, so
  /// the encouragement is different each time but stable across the
  /// rebuilds that happen while it is on screen — a headline that reshuffled
  /// mid-animation would be unreadable.
  /// Changes on every firing so each overlay gets a fresh widget identity.
  final int nonce;

}
