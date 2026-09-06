import 'package:flutter/material.dart';

import '../../../services/models/milestone.dart';
import '../../../theme/tide_colors.dart';
import '../../../theme/tide_motion.dart';
import '../../../theme/tide_typography.dart';
import '../../../widgets/habit_glyph.dart';
import '../../../widgets/ripple_burst.dart';

/// The biggest moment in the app.
///
/// It is the same ripple that fires when a habit is logged — scaled up, run
/// longer, and given a particle flourish in kelp and foam. Deliberately the
/// same language rather than a new one: this is a *bigger version* of the
/// daily reward, which is exactly what a milestone is.
class UnlockCelebration extends StatefulWidget {
  const UnlockCelebration({
    super.key,
    required this.milestone,
    required this.onDismiss,
  });

  final Milestone milestone;
  final VoidCallback onDismiss;

  @override
  State<UnlockCelebration> createState() => _UnlockCelebrationState();
}

class _UnlockCelebrationState extends State<UnlockCelebration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: TideMotion.celebration,
  )..forward();

  int _tick = 0;

  @override
  void initState() {
    super.initState();
    // One frame later, so the burst plays into a laid-out tree rather than
    // firing before the badge has a position on screen.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _tick++);
    });
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) widget.onDismiss();
    });
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
          final presence = t < 0.18
              ? Curves.easeOut.transform(t / 0.18)
              : t < 0.76
              ? 1.0
              : 1 - Curves.easeIn.transform((t - 0.76) / 0.24);

          return Stack(
            children: [
              Positioned.fill(
                child: ColoredBox(
                  color: TideColors.deepWater.withValues(
                    alpha: 0.72 * presence,
                  ),
                ),
              ),
              Center(
                child: Opacity(
                  opacity: presence,
                  child: RippleBurst(
                    trigger: _tick,
                    particles: true,
                    intensity: 2.2,
                    // The one place the rings are meant to leave their
                    // bounds: this sits on a full-screen scrim, and the
                    // burst reaching past the badge is the celebration.
                    clip: false,
                    color: TideColors.lantern,
                    accent: TideColors.lantern,
                    child: Transform.scale(
                      scale:
                          0.86 +
                          0.14 *
                              Curves.easeOutBack.transform(
                                (t / 0.3).clamp(0.0, 1.0),
                              ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          HabitGlyph(
                            glyph: widget.milestone.glyph,
                            size: 60,
                            color: TideColors.lantern,
                            strokeWidth: 2.4,
                          ),
                          const SizedBox(height: 24),
                          Text(
                            widget.milestone.name,
                            style: TideType.hero.copyWith(
                              color: TideColors.lantern,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${widget.milestone.caption}, surfaced',
                            style: TideType.labelMuted,
                          ),
                        ],
                      ),
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
