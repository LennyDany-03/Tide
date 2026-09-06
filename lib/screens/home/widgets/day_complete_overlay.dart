import 'package:flutter/material.dart';

import '../../../theme/tide_colors.dart';
import '../../../theme/tide_motion.dart';
import '../../../theme/tide_typography.dart';

/// The whole-day moment.
///
/// Finishing one habit gets a ripple on that card. Finishing the *day* gets
/// this: a soft kelp-and-foam glow rising from the bottom of the screen with
/// a single line of copy, then gone. Deliberately larger and slower than any
/// per-habit feedback, because it is a rarer and bigger event — the same
/// reason the milestone burst is bigger again.
class DayCompleteOverlay extends StatefulWidget {
  const DayCompleteOverlay({super.key, required this.trigger});

  /// Increment to play.
  final int trigger;

  @override
  State<DayCompleteOverlay> createState() => _DayCompleteOverlayState();
}

class _DayCompleteOverlayState extends State<DayCompleteOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: TideMotion.dayComplete,
  );

  @override
  void didUpdateWidget(DayCompleteOverlay old) {
    super.didUpdateWidget(old);
    if (old.trigger != widget.trigger && widget.trigger > 0) {
      _controller
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value;
          if (t == 0) return const SizedBox.shrink();

          // In over the first third, hold, then ebb.
          final presence = t < 0.3
              ? Curves.easeOut.transform(t / 0.3)
              : t < 0.68
              ? 1.0
              : 1 - Curves.easeIn.transform((t - 0.68) / 0.32);

          return Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        TideColors.lantern.withValues(alpha: 0.22 * presence),
                        TideColors.lantern.withValues(alpha: 0.05 * presence),
                        Colors.transparent,
                      ],
                      stops: const [0, 0.35, 0.75],
                    ),
                  ),
                ),
              ),
              // Clear of the FAB rather than level with it. At 118 the
              // message sat exactly behind the add button, so the one
              // sentence the app says on its best moment was half hidden
              // behind a control nobody is about to press.
              Positioned(
                left: 0,
                right: 0,
                bottom: 230,
                child: Opacity(
                  opacity: presence,
                  child: Transform.translate(
                    offset: Offset(0, 12 * (1 - presence)),
                    child: Column(
                      children: [
                        Text(
                          'Day complete',
                          style: TideType.hero.copyWith(
                            color: TideColors.lantern,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text('The loop holds.', style: TideType.labelMuted),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
