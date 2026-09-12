import 'package:flutter/foundation.dart';

import 'tide_glyph.dart';

/// How a milestone is earned.
enum MilestoneKind {
  /// Reached a streak of [Milestone.threshold] days on any habit.
  streak,

  /// Logged [Milestone.threshold] days without spending a single freeze.
  cleanDays,

  /// Held a Tide Pro plan. The only badge in the catalogue that is not
  /// earned by logging anything, which is exactly why it sits off the route
  /// rather than on it: the ladder measures the habit, and this does not.
  ///
  /// It is a real badge and not a receipt — it stays lit while the plan
  /// runs and goes dark when it lapses, so the wall never claims something
  /// about the account that is no longer true.
  pro,
}

@immutable
class Milestone {
  const Milestone({
    required this.id,
    required this.name,
    required this.glyph,
    required this.threshold,
    required this.caption,
    this.kind = MilestoneKind.streak,
  });

  final String id;
  final String name;
  final TideGlyph glyph;
  final int threshold;

  /// The small gauge line under the badge name — "7 days", "90 clean".
  final String caption;

  final MilestoneKind kind;
}

/// A milestone paired with the user's progress toward it.
@immutable
class MilestoneStatus {
  const MilestoneStatus({
    required this.milestone,
    required this.unlocked,
    required this.progress,
  });

  final Milestone milestone;
  final bool unlocked;

  /// 0..1 toward [Milestone.threshold]. Locked badges sit dim and
  /// desaturated regardless — the progress is used only for ordering which
  /// badge unlocks next.
  final double progress;
}
