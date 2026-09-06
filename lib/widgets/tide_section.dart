import 'package:flutter/material.dart';

import '../theme/tide_colors.dart';
import '../theme/tide_typography.dart';

/// The pieces every non-list screen is built from.
///
/// Insights, History and Habit detail were three separate stacks of rounded
/// panels, each inventing its own padding, radius and label sizes for what
/// was structurally the same thing: a fact, its name, and a rule between it
/// and the next one. Sharing these three widgets is what makes those screens
/// read as one instrument rather than three dashboards — and it is why none
/// of them needs a card.

/// The hairline between two sections.
class TideRule extends StatelessWidget {
  const TideRule({super.key});

  @override
  Widget build(BuildContext context) =>
      Container(height: 1, color: TideColors.hairline);
}

/// A section heading: quiet, sentence case, no tracking, no rule under it.
class TideSectionTitle extends StatelessWidget {
  const TideSectionTitle(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) =>
      Text(title, style: TideType.heading);
}

/// A named fact with its value set to the right.
///
/// The label leads because it is what you are scanning for; the value is
/// larger because it is what you came to read. [accent] lifts the value to
/// lantern, and should be true for at most one line in a group — the point
/// of a single accent is lost if every row claims it.
class TideStatLine extends StatelessWidget {
  const TideStatLine({
    super.key,
    required this.label,
    required this.value,
    this.detail,
    this.accent = false,
  });

  final String label;
  final String value;
  final String? detail;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: TideType.heading),
              if (detail != null) ...[
                const SizedBox(height: 4),
                Text(detail!, style: TideType.labelMuted),
              ],
            ],
          ),
        ),
        const SizedBox(width: 16),
        Text(
          value,
          style: TideType.hero.copyWith(
            fontSize: 19,
            color: accent ? TideColors.lantern : TideColors.bone,
          ),
        ),
      ],
    );
  }
}

/// A figure stacked over what it counts, for rows of two or three.
class TideFigure extends StatelessWidget {
  const TideFigure({
    super.key,
    required this.value,
    required this.caption,
    this.accent = false,
  });

  final String value;
  final String caption;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TideType.gaugeStat(
            color: accent ? TideColors.lantern : TideColors.bone,
          ),
        ),
        const SizedBox(height: 6),
        Text(caption, style: TideType.labelMuted),
      ],
    );
  }
}
