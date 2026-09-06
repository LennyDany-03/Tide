import 'package:flutter/material.dart';

import '../../../services/models/tide_glyph.dart';
import '../../../theme/tide_colors.dart';
import '../../../theme/tide_typography.dart';
import '../../../widgets/habit_glyph.dart';
import '../../../widgets/stagger_list.dart';
import '../../../widgets/tide_mark.dart';

/// The closing step, and the hand-off into sign-up.
///
/// It used to be a ring, a headline and a sentence about habits that had
/// just been picked — a page whose whole content was a receipt for a
/// configuration step that no longer exists. What replaces it does the two
/// jobs a last page can actually do: it recaps the three things the flow
/// just showed, in one line each with the glyph they were shown under, and
/// it hands the ring on.
///
/// [morph] is driven by the screen as it exits. The ring rises and
/// *shrinks* rather than swelling, because what it is travelling toward is
/// the small mark at the top of the auth screen — the last thing onboarding
/// shows and the first thing sign-up shows are one object moving, not two
/// screens that happen to both have a circle.
class ReadyStep extends StatelessWidget {
  const ReadyStep({super.key, required this.morph});

  /// 0..1 as the screen hands off.
  final double morph;

  /// What the three explainer steps said, in the order they said it.
  static const List<(TideGlyph, String)> _recap = [
    (TideGlyph.diamondOutline, 'Swipe a habit right to log it'),
    (TideGlyph.halfMoon, 'A freeze holds the run on a missed day'),
    (TideGlyph.striped, 'The grid shows the shape of the month'),
  ];

  @override
  Widget build(BuildContext context) {
    final travel = Curves.easeInCubic.transform(morph);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Spacer(),
        Transform.translate(
          // Up and toward where the auth mark sits.
          offset: Offset(0, -150 * travel),
          child: Transform.scale(
            scale: 1 - 0.58 * travel,
            child: Opacity(
              // Held opaque well into the move, then dropped fast. Fading
              // linearly from the first frame meant the ring was already
              // half gone before it had gone anywhere.
              opacity: (1 - travel * 1.35).clamp(0.0, 1.0),
              child: const TideMark(size: 124, strokeWidth: 3.5, coreSize: 11),
            ),
          ),
        ),
        const SizedBox(height: 38),
        Opacity(
          // Gone by the time the ring is halfway up. Text travelling with a
          // morph reads as the whole page sliding; text leaving first reads
          // as the ring being handed on.
          opacity: (1 - morph * 2.2).clamp(0.0, 1.0),
          child: Column(
            children: [
              Text('That is the whole app', style: TideType.hero),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Text(
                  'Make an account and Tide will keep the loop for you.',
                  style: TideType.bodyMuted,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 34),
              StaggerColumn(
                baseDelay: const Duration(milliseconds: 220),
                spacing: 14,
                children: [
                  for (final (glyph, line) in _recap)
                    _RecapLine(glyph: glyph, label: line),
                ],
              ),
            ],
          ),
        ),
        const Spacer(flex: 2),
      ],
    );
  }
}

/// One recap line. No card, no rule, no bullet — the glyph is the mark and
/// the indent is the list.
class _RecapLine extends StatelessWidget {
  const _RecapLine({required this.glyph, required this.label});

  final TideGlyph glyph;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 26,
          child: Center(
            child: HabitGlyph(glyph: glyph, size: 14, color: TideColors.silt),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: TideType.label)),
      ],
    );
  }
}
