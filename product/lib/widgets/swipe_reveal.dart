import 'package:flutter/material.dart';

import '../theme/tide_colors.dart';
import '../theme/tide_motion.dart';
import '../theme/tide_typography.dart';

/// What a swiped card uncovers: a tint, one round mark and the word for what
/// letting go will do.
///
/// One drawing for every swipeable card, so a habit on Today and a task on
/// the to-do list answer the same hand the same way. The mark sits at the
/// edge the card was pulled away from and grows as the threshold nears; the
/// word fades in beside it; and once the threshold is crossed the mark fills
/// solid — the same beat the card fires its one haptic tick on — so "let go
/// now and it happens" is something you can see as well as feel.
///
/// The habit card used to trail a rolling wave behind the finger instead,
/// with an icon and no word. It looked busier and said less: a freeze, an
/// undo and a refusal were told apart only by an 18px glyph.
class SwipeReveal extends StatelessWidget {
  const SwipeReveal({
    super.key,
    required this.right,
    required this.progress,
    required this.hue,
    required this.icon,
    required this.label,
    this.onHue,
  });

  /// The card is travelling right, so the mark sits at the left edge.
  final bool right;

  /// 0..1 toward the commit point.
  final double progress;

  final Color hue;
  final IconData icon;
  final String label;

  /// The icon's ink once the mark has filled. Defaults to the page, which
  /// reads on every hue but lantern — a lantern fill takes
  /// [TideColors.onLantern], which differs from the page on light palettes.
  final Color? onHue;

  @override
  Widget build(BuildContext context) {
    final armed = progress >= 1;

    final mark = AnimatedContainer(
      duration: TideMotion.press,
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: armed ? hue : hue.withValues(alpha: 0.18),
      ),
      child: Icon(
        icon,
        size: 18,
        color: armed ? (onHue ?? TideColors.shoal) : hue,
      ),
    );

    final word = Flexible(
      child: Opacity(
        opacity: progress,
        child: Text(
          label,
          style: TideType.label.copyWith(color: hue),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );

    return ColoredBox(
      color: hue.withValues(alpha: 0.06 + 0.10 * progress),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: Row(
          mainAxisAlignment: right
              ? MainAxisAlignment.start
              : MainAxisAlignment.end,
          children: [
            if (!right) ...[word, const SizedBox(width: 10)],
            Transform.scale(scale: 0.7 + 0.3 * progress, child: mark),
            if (right) ...[const SizedBox(width: 10), word],
          ],
        ),
      ),
    );
  }
}
