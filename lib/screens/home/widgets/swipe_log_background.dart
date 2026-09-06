import 'package:flutter/material.dart';

import '../../../theme/tide_colors.dart';
import '../../../theme/tide_elevation.dart';
import '../../../theme/tide_motion.dart';
import '../../../widgets/tide_wave.dart';

/// What sits behind a card as it is swiped.
///
/// Right is completion — a tide-blue wave trails the finger and a checkmark
/// scales in as the threshold approaches. Left is a streak freeze — a frozen
/// drop, in foam cyan, because it preserves the loop rather than advancing
/// it. The two directions never share an icon or a colour, so a half-started
/// swipe already tells you which one you are doing.
class SwipeLogBackground extends StatelessWidget {
  const SwipeLogBackground({
    super.key,
    required this.offset,
    required this.width,
    required this.phase,
    this.freezeAvailable = true,
  });

  /// Signed pixels the card has travelled.
  final double offset;

  final double width;

  /// Advances the wave crest while the finger is down.
  final double phase;

  /// With no freeze tokens left, the left swipe shows a coral refusal
  /// instead of promising something it cannot deliver.
  final bool freezeAvailable;

  bool get _completing => offset > 0;

  double get _fraction =>
      width == 0 ? 0 : (offset.abs() / width).clamp(0.0, 1.0);

  /// 0..1 toward the commit point, so the icon reaches full size exactly
  /// when the gesture would commit.
  double get _approach =>
      (_fraction / TideMotion.swipeThreshold).clamp(0.0, 1.0);

  Color get _color {
    if (_completing) return TideColors.lantern;
    return freezeAvailable ? TideColors.lantern : TideColors.coral;
  }

  IconData get _icon {
    if (_completing) return Icons.check_rounded;
    return freezeAvailable ? Icons.ac_unit_rounded : Icons.block_rounded;
  }

  @override
  Widget build(BuildContext context) {
    if (offset.abs() < 1) return const SizedBox.shrink();

    return ClipRRect(
      borderRadius: TideElevation.radius20,
      child: Stack(
        children: [
          Positioned.fill(
            child: ColoredBox(
              color: _color.withValues(alpha: 0.10 + 0.14 * _approach),
            ),
          ),

          // The wave trails the finger on the side the swipe came from.
          Positioned(
            left: _completing ? 0 : null,
            right: _completing ? null : 0,
            top: 0,
            bottom: 0,
            width: offset.abs().clamp(0.0, width),
            child: TideWave(
              amplitude: 0.4 + 0.6 * _approach,
              phase: phase,
              color: _color,
              fill: true,
              strokeWidth: 1.5,
            ),
          ),

          Align(
            alignment: _completing
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
