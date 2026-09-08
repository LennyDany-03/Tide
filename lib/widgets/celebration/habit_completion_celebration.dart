import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config/celebration_copy.dart';
import '../../services/models/celebration_cue.dart';
import '../../theme/tide_colors.dart';
import '../../theme/tide_motion.dart';
import '../../theme/tide_typography.dart';
import '../habit_glyph.dart';
import '../ripple_burst.dart';

/// The everyday version of the Milestones unlock moment.
///
/// Every completed habit uses this exact Tide ritual: the current screen
/// falls beneath dark water, a route of rings expands from the centre, and
/// the completed habit surfaces inside it.
class HabitCompletionCelebration extends StatefulWidget {
  const HabitCompletionCelebration({
    super.key,
    required this.cue,
    required this.onDismiss,
  });

  final CelebrationCue cue;
  final VoidCallback onDismiss;

  @override
  State<HabitCompletionCelebration> createState() =>
      _HabitCompletionCelebrationState();
}

class _HabitCompletionCelebrationState extends State<HabitCompletionCelebration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: TideMotion.celebrateIn +
        TideMotion.celebrateHold +
        TideMotion.celebrateOut,
  )..forward();
  Timer? _timer;
  bool _dismissed = false;
  int _rippleTick = 0;

  @override
  void initState() {
    super.initState();
    HapticFeedback.mediumImpact();
    // RippleBurst starts when its trigger changes, after its bounds exist.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _rippleTick++);
    });
    _timer = Timer(_controller.duration!, _dismiss);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _dismiss() {
    if (_dismissed || !mounted) return;
    _dismissed = true;
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    final frozen = widget.cue.type == CelebrationCueType.freeze;
    final accent = frozen ? TideColors.frost : TideColors.lantern;
    return Semantics(
      liveRegion: true,
      label: frozen
          ? 'Streak protected. ${widget.cue.habitName} frozen.'
          : '${widget.cue.habitName} completed.',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _dismiss,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final t = _controller.value;
            final inEnd = TideMotion.celebrateIn.inMilliseconds /
                _controller.duration!.inMilliseconds;
            final outStart = 1 -
                TideMotion.celebrateOut.inMilliseconds /
                    _controller.duration!.inMilliseconds;
            final entered = Curves.easeOutCubic.transform(
              (t / inEnd).clamp(0.0, 1.0),
            );
            final leaving = t < outStart
                ? 1.0
                : 1 - Curves.easeInCubic.transform((t - outStart) / (1 - outStart));
            final presence = entered * leaving;

            return Stack(
              children: [
                Positioned.fill(
                  child: ColoredBox(
                    color: TideColors.deepWater.withValues(
                      alpha: 0.84 * presence,
                    ),
                  ),
                ),
                Center(
                  child: Opacity(
                    opacity: presence,
                    child: RippleBurst(
                      trigger: _rippleTick,
                      particles: true,
                      intensity: 1.75,
                      clip: false,
                      color: accent,
                      accent: accent,
                      child: Transform.translate(
                        offset: Offset(0, (1 - entered) * 18),
                        child: Transform.scale(
                          scale: 0.9 + 0.1 * entered,
                          child: _MilestoneStyleMessage(
                            cue: widget.cue,
                            accent: accent,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MilestoneStyleMessage extends StatelessWidget {
  const _MilestoneStyleMessage({required this.cue, required this.accent});
  final CelebrationCue cue;
  final Color accent;

  /// The headline, drawn from the copy set that matches what just
  /// happened and seeded by the cue so it holds still while it is read.
  String get _headline {
    final lines = switch (cue.type) {
      CelebrationCueType.freeze => CelebrationCopy.frozen,
      CelebrationCueType.completion =>
        cue.dayComplete ? CelebrationCopy.dayComplete : CelebrationCopy.completion,
    };
    return CelebrationCopy.pick(lines, cue.nonce);
  }

  @override
  Widget build(BuildContext context) {
    final frozen = cue.type == CelebrationCueType.freeze;
    final closingLine = frozen
        ? 'Your streak is held for today'
        : cue.dayComplete
        ? 'The whole day is surfaced'
        : '${cue.streak} days, surfaced';
    return SizedBox(
      width: 290,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 112,
            height: 112,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withValues(alpha: 0.12),
              border: Border.all(
                color: accent.withValues(alpha: 0.78),
                width: 2,
              ),
            ),
            child: frozen
                ? Icon(Icons.ac_unit_rounded, size: 48, color: accent)
                : HabitGlyph(
                    glyph: cue.glyph,
                    size: 53,
                    color: accent,
                    strokeWidth: 2.25,
                  ),
          ),
          const SizedBox(height: 24),
          Text(
            _headline,
            style: TideType.hero.copyWith(
              color: accent,
              decoration: TextDecoration.none,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            cue.habitName,
            style: TideType.label.copyWith(decoration: TextDecoration.none),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 5),
          Text(
            closingLine,
            style: TideType.labelMuted.copyWith(decoration: TextDecoration.none),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
