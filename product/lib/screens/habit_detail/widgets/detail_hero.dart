import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../services/models/habit.dart';
import '../../../theme/tide_colors.dart';
import '../../../theme/tide_elevation.dart';
import '../../../theme/tide_typography.dart';
import '../../../widgets/gauge_number.dart';
import '../../../widgets/press_scale.dart';
import '../../../widgets/tide_flame.dart';
import '../../../widgets/tide_surface.dart';

/// The one card on Habit detail: the streak, and the three figures that
/// qualify it.
///
/// The screen used to open on a bare "2 days" floating over open ground,
/// with best streak and the 30-day rate as two loose captions under a rule —
/// correct, and with nothing holding it together, so the most important
/// number on the screen had the same visual footing as the chart captions.
/// A single surface gives the headline somewhere to stand. Everything below
/// it stays flat, so the card is unmistakably the answer to "how is this
/// going" and the rest is the evidence.
///
/// The flame is the same emblem as Today's streak tile, sized by the run.
/// It goes out while the habit is paused, and the card says so in words: a
/// held streak is not a burning one.
class DetailHero extends StatelessWidget {
  const DetailHero({
    super.key,
    required this.habit,
    required this.current,
    required this.best,
    required this.rate,
    required this.kept,
    required this.onResume,
  });

  final Habit habit;
  final int current;
  final int best;
  final double rate;
  final int kept;
  final VoidCallback onResume;

  /// Same curve as Today's tile: the flame grows fast early and slowly
  /// later, so a week is visibly alight and a season is not a bonfire.
  double get _heat => math.sqrt((current / 90).clamp(0.0, 1.0));

  @override
  Widget build(BuildContext context) {
    final lit = current > 0 && !habit.paused;

    return TideSurface(
      border: Border.all(color: TideColors.hairline),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Current streak', style: TideType.sectionHeader),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        GaugeCountUp(
                          value: current,
                          style: TideType.gaugeHero(
                            color: lit ? TideColors.bone : TideColors.silt,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          current == 1 ? 'day' : 'days',
                          style: TideType.gauge(18, color: TideColors.silt),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (lit)
                SizedBox(
                  width: 48,
                  height: 66,
                  child: TideFlame(intensity: math.max(0.25, _heat)),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Container(height: 1, color: TideColors.hairline),
          const SizedBox(height: 16),
          IntrinsicHeight(
            child: Row(
              children: [
                Expanded(
                  child: _Figure(value: '$best', caption: 'best streak'),
                ),
                _divider(),
                Expanded(
                  child: _Figure(
                    value: '${(rate * 100).round()}%',
                    caption: 'last 30 days',
                  ),
                ),
                _divider(),
                Expanded(
                  child: _Figure(value: '$kept', caption: 'days kept'),
                ),
              ],
            ),
          ),
          if (habit.paused) ...[
            const SizedBox(height: 18),
            _PausedNote(streak: current, onResume: onResume),
          ],
        ],
      ),
    );
  }

  Widget _divider() => Container(
    width: 1,
    margin: const EdgeInsets.symmetric(horizontal: 14),
    color: TideColors.hairline,
  );
}

class _Figure extends StatelessWidget {
  const _Figure({required this.value, required this.caption});

  final String value;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, style: TideType.gaugeStat(), maxLines: 1),
        const SizedBox(height: 6),
        Text(
          caption,
          style: TideType.labelMuted,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

/// What a pause is doing to this habit, and the way out of it, in the card
/// rather than at the bottom of the page.
class _PausedNote extends StatelessWidget {
  const _PausedNote({required this.streak, required this.onResume});

  final int streak;
  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: BoxDecoration(
        color: TideColors.bone.withValues(alpha: 0.04),
        borderRadius: TideElevation.radius12,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  streak > 0
                      ? 'Your $streak day streak is held'
                      : 'Nothing is being counted',
                  style: TideType.label,
                ),
                const SizedBox(height: 3),
                Text('Paused days are not misses.', style: TideType.labelMuted),
              ],
            ),
          ),
          const SizedBox(width: 12),
          PressScale(
            onTap: onResume,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: TideColors.lantern,
                borderRadius: TideElevation.radius12,
              ),
              child: Text(
                'Resume',
                style: TideType.label.copyWith(
                  color: TideColors.onLantern,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
