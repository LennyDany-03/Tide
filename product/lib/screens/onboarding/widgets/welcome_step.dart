import 'package:flutter/material.dart';

import '../../../services/tide_scope.dart';
import '../../../theme/tide_motion.dart';
import '../../../theme/tide_typography.dart';
import '../../../widgets/stagger_list.dart';
import '../../../widgets/tide_mark.dart';

/// Step one.
///
/// The mark draws itself in from empty as the screen loads, before any tap
/// happens — the app performing its central gesture once, unprompted, so
/// the ring is already familiar by the time it turns up on a habit card.
/// Then a lit point starts going round it and never stops, which is the
/// whole pitch before a word of the tagline has been read.
///
/// The name and the tagline arrive behind it on the standard stagger, so
/// the first screen resolves in the same order every list in the app does.
class WelcomeStep extends StatelessWidget {
  const WelcomeStep({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Spacer(flex: 2),
        // Whole on arrival when the splash has just drawn it — the same
        // mark handed on, not a second one starting over.
        TideMark(
          size: 164,
          strokeWidth: 4,
          drawIn: !TideScope.read(context).splashPlayed,
        ),
        const SizedBox(height: 46),
        StaggerColumn(
          // Behind the ring rather than with it: the mark takes a full
          // second to close, and copy that has already settled by then is
          // copy nobody read.
          baseDelay: const Duration(milliseconds: 760),
          crossAxisAlignment: CrossAxisAlignment.center,
          spacing: 14,
          children: [
            // One Text, not one per letter. The name is the steadiest thing
            // on the screen and everything else is moving around it.
            Text('Tide', style: TideType.screenTitle.copyWith(fontSize: 40)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 26),
              child: Text(
                'Habits move like water. Small, daily, repeating. Here is '
                'how it works — it takes about thirty seconds.',
                style: TideType.bodyMuted,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
        const Spacer(flex: 3),
      ],
    );
  }
}

/// The nudge under the primary button on the first step.
///
/// Onboarding is swipeable now, and a page that can be swiped has to say so
/// once — there is no other affordance for it on a full-bleed page. Fades
/// itself out rather than sitting there, because an instruction that stays
/// after it has been followed is clutter.
class SwipeHint extends StatefulWidget {
  const SwipeHint({super.key, required this.visible});

  final bool visible;

  @override
  State<SwipeHint> createState() => _SwipeHintState();
}

class _SwipeHintState extends State<SwipeHint>
    with SingleTickerProviderStateMixin {
  late final AnimationController _drift = AnimationController(
    vsync: this,
    duration: TideMotion.breathe,
  )..repeat();

  @override
  void dispose() {
    _drift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: widget.visible ? 1 : 0,
      duration: TideMotion.sheetIn,
      child: AnimatedBuilder(
        animation: _drift,
        builder: (context, child) {
          // One pass every three seconds, easing out and resting — a
          // continuous slide would read as a marquee.
          final t = Curves.easeInOut.transform(
            (_drift.value * 1.6).clamp(0.0, 1.0),
          );
          return Transform.translate(offset: Offset(6 * t, 0), child: child);
        },
        child: Text(
          'or swipe',
          style: TideType.labelMuted,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
