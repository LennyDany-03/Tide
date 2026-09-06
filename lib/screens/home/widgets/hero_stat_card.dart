import 'package:flutter/material.dart';

import '../../../theme/tide_colors.dart';
import '../../../theme/tide_typography.dart';
import '../../../widgets/gauge_number.dart';
import '../../../widgets/tide_level.dart';

/// The day's headline: how much of today is done, as water standing at a
/// level behind the figure.
///
/// There is no card. The figure and the water sit directly on the page,
/// full-bleed to both edges — a hero inside a rounded rectangle is one more
/// object on a screen already full of them, and the panel said nothing the
/// type and the water were not already saying.
///
/// The figure sits clear above the water rather than inside it. Running the
/// water behind the whole block gave the level somewhere to travel, but at
/// a half-finished day the lit waterline lands exactly across the caption
/// and cuts the letterforms in half — and where the line falls is decided by
/// the data, so there is no layout that survives every value. Text above,
/// water below, and the crest is free to be as bright as it needs to be.
///
/// The supporting figures sit below on clean ground: plain text, no
/// containers. They were recessed wells with accent bars and their own
/// radius, which made a footnote look like a control.
class HeroStatCard extends StatelessWidget {
  const HeroStatCard({
    super.key,
    required this.completed,
    required this.scheduled,
    required this.weeklyRate,
    required this.bestStreak,
    required this.dayComplete,
  });

  final int completed;
  final int scheduled;
  final double weeklyRate;
  final int bestStreak;
  final bool dayComplete;

  double get _level => scheduled == 0 ? 0 : completed / scheduled;

  /// Tall enough that the difference between a quarter done and half done
  /// is a distance you can see, not a two-pixel nudge.
  static const double _waterHeight = 96;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              GaugeNumber(value: completed, style: TideType.gaugeHero()),
              const SizedBox(width: 8),
              Text(
                'of $scheduled',
                style: TideType.gauge(18, color: TideColors.silt),
              ),
              const Spacer(),
              Text(
                dayComplete ? 'all logged' : 'logged today',
                style: TideType.labelMuted.copyWith(
                  color: dayComplete ? TideColors.lantern : TideColors.silt,
                ),
              ),
            ],
          ),
        ),

        // Full-bleed: the water runs off both edges of the screen, so it
        // reads as a body of water the page sits in rather than as a widget
        // with a left and a right end.
        SizedBox(
          height: _waterHeight,
          child: TideLevel(level: _level, amplitude: 9),
        ),
        const SizedBox(height: 20),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              _Figure(
                value: '${(weeklyRate * 100).round()}%',
                caption: 'this week',
              ),
              const SizedBox(width: 32),
              _Figure(value: '$bestStreak', caption: 'day best streak'),
            ],
          ),
        ),
      ],
    );
  }
}

/// A supporting figure: the number, and what it counts. No container, no
/// rule, no accent mark — the size difference against the hero is already
/// the whole hierarchy.
class _Figure extends StatelessWidget {
  const _Figure({required this.value, required this.caption});

  final String value;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(value, style: TideType.gauge(17)),
        const SizedBox(width: 7),
        Text(caption, style: TideType.labelMuted),
      ],
    );
  }
}
