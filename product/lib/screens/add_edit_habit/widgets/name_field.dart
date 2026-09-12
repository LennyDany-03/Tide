import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../theme/tide_colors.dart';
import '../../../theme/tide_elevation.dart';
import '../../../theme/tide_motion.dart';
import '../../../theme/tide_typography.dart';

/// The habit name input.
///
/// Validation is expressed on the field itself — the border pulses coral
/// and the field shakes briefly. No error banner drops in, because a banner
/// would push the rest of the form down and make the mistake feel bigger
/// than it is.
class NameField extends StatefulWidget {
  const NameField({
    super.key,
    required this.controller,
    required this.errorTick,
    this.hint = 'e.g. Evening walk',
    this.onSubmitted,
  });

  final TextEditingController controller;

  /// Increment to play the error pulse.
  final int errorTick;

  final String hint;
  final ValueChanged<String>? onSubmitted;

  @override
  State<NameField> createState() => _NameFieldState();
}

class _NameFieldState extends State<NameField>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: TideMotion.errorShake,
  );

  @override
  void didUpdateWidget(NameField old) {
    super.didUpdateWidget(old);
    if (old.errorTick != widget.errorTick && widget.errorTick > 0) {
      _shake
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shake,
      builder: (context, child) {
        final t = _shake.value;
        // Three decaying swings — a nudge, not a tantrum.
        final offset = math.sin(t * math.pi * 6) * 7 * (1 - t);

        return Transform.translate(
          offset: Offset(offset, 0),
          child: Container(
            decoration: BoxDecoration(
              color: TideColors.trench,
              borderRadius: TideElevation.radius12,
              border: Border.all(
                color: Color.lerp(
                  Colors.transparent,
                  TideColors.coral,
                  (1 - t) * (t > 0 ? 1 : 0),
                )!,
              ),
            ),
            child: child,
          ),
        );
      },
      child: TextField(
        controller: widget.controller,
        style: TideType.body,
        cursorColor: TideColors.lantern,
        textCapitalization: TextCapitalization.sentences,
        textInputAction: TextInputAction.done,
        onSubmitted: widget.onSubmitted,
        decoration: InputDecoration(
          hintText: widget.hint,
          hintStyle: TideType.bodyMuted,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
      ),
    );
  }
}
