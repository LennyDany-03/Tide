import 'package:flutter/material.dart';

import '../theme/tide_colors.dart';
import '../theme/tide_motion.dart';
import 'swipe_reveal.dart';

/// What sits behind a habit card as it is swiped.
///
/// The same drawing as a task card's — a tint, a round mark that fills once
/// the threshold is crossed, and the word for what letting go will do — so
/// the app's two swipe lists answer the hand the same way. See
/// [SwipeReveal].
///
/// Right is completion: warm [TideColors.lantern] and a tick. Left is a
/// streak freeze, and it is cold — [TideColors.frost] ice and a snowflake,
/// because a freeze preserves the loop rather than advancing it.
///
/// Left on a habit that already has something logged today is [undoing]
/// instead, and it is neither warm nor cold: plain [TideColors.bone].
/// Taking a log back is not an advance and not a freeze, and the palette
/// reserves frost for a frozen day and coral for destruction — neither of
/// which this is. Neutral ink is the honest third reading: the card is going
/// back to nothing.
///
/// The two directions must never share a colour. Temperature is the fastest
/// distinction available here: warm is earned, cold is held, and you know
/// which one you are doing before the card has travelled a centimetre.
class SwipeLogBackground extends StatelessWidget {
  const SwipeLogBackground({
    super.key,
    required this.offset,
    required this.width,
    required this.radius,
    this.freezeAvailable = true,
    this.unfreezing = false,
    this.undoing = false,
    this.partial = false,
  });

  /// Signed pixels the card has travelled.
  final double offset;

  final double width;

  /// Matched to the card's own radius. The backdrop is the shape the card
  /// slides out of, so the two corners have to agree.
  final BorderRadius radius;

  /// With no freeze tokens left, the left swipe shows a coral refusal
  /// instead of promising something it cannot deliver.
  final bool freezeAvailable;
  final bool unfreezing;

  /// Something is logged today, so the freeze side is showing an undo.
  /// Takes precedence over the freeze reading: a day you have started is
  /// not a day you would spend a token to protect.
  final bool undoing;

  /// The undo is clearing a count part way to its target, not a finished
  /// day — which only changes the word.
  final bool partial;

  bool get _completing => offset > 0;

  double get _fraction =>
      width == 0 ? 0 : (offset.abs() / width).clamp(0.0, 1.0);

  /// 0..1 toward the commit point, so the mark fills exactly when the
  /// gesture would commit.
  double get _approach =>
      (_fraction / TideMotion.swipeThreshold).clamp(0.0, 1.0);

  Color get _color {
    if (_completing) return TideColors.lantern;
    if (unfreezing || undoing) return TideColors.bone;
    return freezeAvailable ? TideColors.frost : TideColors.coral;
  }

  IconData get _icon {
    if (_completing) return Icons.check_rounded;
    if (unfreezing || undoing) return Icons.undo_rounded;
    return freezeAvailable ? Icons.ac_unit_rounded : Icons.block_rounded;
  }

  String get _label {
    if (_completing) return 'Complete';
    if (unfreezing) return 'Unfreeze';
    if (undoing) return partial ? 'Clear today' : 'Undo';
    return freezeAvailable ? 'Freeze' : 'No freezes left';
  }

  @override
  Widget build(BuildContext context) {
    if (offset.abs() < 1) return const SizedBox.shrink();

    return ClipRRect(
      borderRadius: radius,
      child: Stack(
        children: [
          // An opaque recess first, and only then the tint.
          //
          // The tint used to be painted straight onto whatever was behind
          // the row, which is the page. Frost is a near-white, so a freeze
          // swipe laid a pale wash over deep water and the exposed socket
          // came out *lighter* than the card that had just slid off it. The
          // trench is the app's own recess colour, darker than the page for
          // exactly this reason.
          Positioned.fill(child: ColoredBox(color: TideColors.trench)),
          Positioned.fill(
            child: SwipeReveal(
              right: _completing,
              progress: _approach,
              hue: _color,
              onHue: _completing ? TideColors.onLantern : TideColors.trench,
              icon: _icon,
              label: _label,
            ),
          ),
        ],
      ),
    );
  }
}
