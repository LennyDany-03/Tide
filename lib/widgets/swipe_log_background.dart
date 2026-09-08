import 'package:flutter/material.dart';

import '../theme/tide_colors.dart';
import '../theme/tide_motion.dart';
import 'tide_wave.dart';

/// What sits behind a card as it is swiped.
///
/// Right is completion: a warm [TideColors.lantern] wave trails the finger
/// and a checkmark scales in as the threshold approaches. Left is a streak
/// freeze, and it is cold — [TideColors.frost] ice, a snowflake, and a wave
/// held almost flat, because a freeze preserves the loop rather than
/// advancing it.
///
/// The two directions must never share a colour, and for a while they did.
/// The freeze side was written for a `foamCyan` that the redesign deleted,
/// so it fell back to lantern and both swipes came out the same warm amber
/// with the same rolling wave — identical until an icon had faded far
/// enough in to read. Temperature is the fastest distinction available
/// here: warm is earned, cold is held, and you know which one you are doing
/// before the card has travelled a centimetre.
class SwipeLogBackground extends StatelessWidget {
  const SwipeLogBackground({
    super.key,
    required this.offset,
    required this.width,
    required this.phase,
    required this.radius,
    this.freezeAvailable = true,
    this.freezeOnRight = false,
    this.unfreezing = false,
  });

  /// Signed pixels the card has travelled.
  final double offset;

  final double width;

  /// Advances the wave crest while the finger is down.
  final double phase;

  /// Matched to the card's own radius. The backdrop is the shape the card
  /// slides out of, so the two corners have to agree.
  final BorderRadius radius;

  /// With no freeze tokens left, the left swipe shows a coral refusal
  /// instead of promising something it cannot deliver.
  final bool freezeAvailable;
  final bool freezeOnRight;
  final bool unfreezing;

  bool get _freezing => freezeOnRight ? offset > 0 : offset < 0;

  bool get _completing => !_freezing;

  double get _fraction =>
      width == 0 ? 0 : (offset.abs() / width).clamp(0.0, 1.0);

  /// 0..1 toward the commit point, so the icon reaches full size exactly
  /// when the gesture would commit.
  double get _approach =>
      (_fraction / TideMotion.swipeThreshold).clamp(0.0, 1.0);

  Color get _color {
    if (_completing) return TideColors.lantern;
    return freezeAvailable ? TideColors.frost : TideColors.coral;
  }

  /// Ice sits at a lower alpha than the accent does.
  ///
  /// [TideColors.frost] is a near-white, so it carries far more luminance
  /// per unit of alpha than lantern; matched numerically the freeze side
  /// blows out into a grey slab while the log side is still a tint. Lower
  /// again now that the tint sits on the trench rather than on the page:
  /// the recess is darker to begin with, so the same alpha lifted the ice
  /// further clear of the card than it should ever get. A socket must read
  /// as *under* the row, whatever colour is being washed into it.
  double get _tintAlpha {
    final base = _completing ? 0.10 : 0.045;
    final gain = _completing ? 0.14 : 0.075;
    return base + gain * _approach;
  }

  /// A frozen surface does not roll. The wave is flattened almost out on
  /// the freeze side so the ice reads as set rather than as water that
  /// happens to be a different colour.
  double get _amplitude =>
      _completing ? 0.4 + 0.6 * _approach : 0.06 + 0.1 * _approach;

  IconData get _icon {
    if (_completing) return Icons.check_rounded;
    if (unfreezing) return Icons.undo_rounded;
    return freezeAvailable ? Icons.ac_unit_rounded : Icons.block_rounded;
  }

  @override
  Widget build(BuildContext context) {
    if (offset.abs() < 1) return const SizedBox.shrink();

    // Rounded, and to the card's exact radius. This was square back when a
    // habit was a full-bleed row: a rounded panel behind a square row left a
    // curved sliver of tint hanging off each end. Now the card is the
    // rounded thing, so a square backdrop would be the one showing corners —
    // the tint has to be the socket the card lifts out of.
    return ClipRRect(
      borderRadius: radius,
      child: Stack(
        children: [
          // An opaque recess first, and only then the tint.
          //
          // The tint used to be painted straight onto whatever was behind
          // the row, which is the page. Frost is a near-white, so a freeze
          // swipe laid a pale wash over deep water and the exposed socket
          // came out *lighter* than the card that had just slid off it —
          // a card lifting away from a slab of grey rather than out of
          // anything. The trench is the app's own recess colour, darker
          // than the page for exactly this reason, and the tint reads as
          // light falling into the cut instead of a panel behind it.
          const Positioned.fill(
            child: ColoredBox(color: TideColors.trench),
          ),
          Positioned.fill(
            child: ColoredBox(color: _color.withValues(alpha: _tintAlpha)),
          ),

          // The wave trails the finger on the side the swipe came from.
          Positioned(
            left: offset > 0 ? 0 : null,
            right: offset > 0 ? null : 0,
            top: 0,
            bottom: 0,
            width: offset.abs().clamp(0.0, width),
            child: TideWave(
              amplitude: _amplitude,
              phase: phase,
              color: _color,
              fill: true,
              strokeWidth: 1.5,
              // Taper the outer end only. The end against the card is the
              // one the water was pulled from, and flattening it there
              // left a band of bare tint above the fill running the whole
              // height of the seam — which is the "shadow" the card looked
              // like it was casting onto its own backdrop.
              taperStart: offset > 0,
              taperEnd: offset < 0,
            ),
          ),

          Align(
            alignment: offset > 0
                ? Alignment.centerLeft
                : Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Transform.scale(
                scale: 0.4 + 0.6 * Curves.easeOutBack.transform(_approach),
                child: Icon(_icon, color: _color, size: 22),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
