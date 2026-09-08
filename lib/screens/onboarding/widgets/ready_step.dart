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
/// [morph] is driven by the screen as it exits. The ring travels up and to
/// the left and *shrinks* rather than swelling, because what it is
/// travelling toward is the small mark above the title on the auth
/// screen — the last thing onboarding shows and the first thing the account
/// screen shows are one object moving, not two screens that happen to both
/// have a circle.
///
/// The two things that were wrong with it, both of them timing. The copy
/// left at 2.2× the morph and the chrome left at the same rate, but the
/// ring held its opacity almost to the end — so for the back half of the
/// hand-off the screen was a single small circle drifting on an empty page,
/// which is the frame that read as the animation breaking. And it drifted
/// straight up toward a mark that was in the top *right* corner, then
/// arrived to find that mark drawing itself in from an empty arc over a
/// full second. Nothing was continuous about it.
///
/// Now the ring leaves with everything else, aimed at where the mark
/// actually lands, and the mark on the other side is simply already there.
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

  /// Where the mark ends up on the account screen: the page margin plus
  /// half its own width, measured from the left edge.
  static const double _landingX = 24 + 30;

  /// And how far above the ring's resting place that is. Approximate on
  /// purpose — the ring dissolves before it lands, and the eye reads a
  /// hand-off from the direction and the shrink, not from the last pixel.
  static const double _landingRise = 130;

  /// 124 down to the 60 the account screen wears.
  static const double _landingScale = 60 / 124;

  @override
  Widget build(BuildContext context) {
    // Ease *out*, not in. Eased in, the ring spent the first half of the
    // hand-off barely moving and then vanished — it had covered nine per
    // cent of the distance by the time its opacity ran out, which is a
    // fade dressed up as a journey. Leaving fast and decelerating means
    // most of the travel happens while it is still bright.
    final travel = Curves.easeOutCubic.transform(morph);
    final width = MediaQuery.sizeOf(context).width;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Spacer(),
        Transform.translate(
          // Up and across, toward the corner the mark lands in — not
          // straight up toward nothing.
          offset: Offset(
            (_landingX - width / 2) * travel,
            -_landingRise * travel,
          ),
          child: Transform.scale(
            scale: 1 - (1 - _landingScale) * travel,
            child: Opacity(
              // Leaves at the same rate as the copy and the chrome. Holding
              // it opaque to the end is what left one small ring alone on a
              // blank page for the back half of the hand-off.
              opacity: (1 - morph * 2.2).clamp(0.0, 1.0),
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
                  'Sign in and Tide will keep the loop for you.',
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
