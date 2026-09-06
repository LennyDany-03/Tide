import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/tide_colors.dart';
import '../theme/tide_elevation.dart';
import '../theme/tide_motion.dart';
import '../theme/tide_typography.dart';
import 'press_scale.dart';

/// A labelled text input.
///
/// The error language is the one the habit name field already established:
/// the border pulses coral and the field shakes briefly, and no banner
/// drops in — a banner would push the rest of the form down and make the
/// mistake feel bigger than it is.
///
/// What is added here is *which* mistake. A shake alone is enough on a
/// one-field sheet, where there is only one thing it could be about; on a
/// sign-up form with three fields it says something is wrong and leaves you
/// to guess what. So the message takes over the label's slot instead of
/// claiming a new line — the field says what it wants, and nothing below it
/// moves.
class TideField extends StatefulWidget {
  const TideField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.error,
    this.errorTick = 0,
    this.obscure = false,
    this.keyboardType,
    this.textInputAction = TextInputAction.next,
    this.textCapitalization = TextCapitalization.none,
    this.autofillHints,
    this.onSubmitted,
    this.onChanged,
    this.trailing,
  });

  final TextEditingController controller;

  /// Sits above the field, and is replaced by [error] while one is set.
  final String label;

  final String? hint;

  /// What is wrong, in a few words. Null clears back to the label.
  final String? error;

  /// Increment to replay the shake. Kept separate from [error] so the same
  /// message can be re-asserted — submitting twice with the same empty
  /// field has to shake twice.
  final int errorTick;

  final bool obscure;
  final TextInputType? keyboardType;
  final TextInputAction textInputAction;
  final TextCapitalization textCapitalization;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;

  /// A control inside the field's right edge — the password reveal.
  final Widget? trailing;

  @override
  State<TideField> createState() => _TideFieldState();
}

class _TideFieldState extends State<TideField>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: TideMotion.errorShake,
  );

  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(TideField old) {
    super.didUpdateWidget(old);
    if (old.errorTick != widget.errorTick && widget.errorTick > 0) {
      _shake
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _focus
      ..removeListener(_onFocusChanged)
      ..dispose();
    _shake.dispose();
    super.dispose();
  }

  void _onFocusChanged() => setState(() {});

  Color get _border {
    if (widget.error != null) return TideColors.coral.withValues(alpha: 0.65);
    if (_focus.hasFocus) return TideColors.lantern.withValues(alpha: 0.45);
    return Colors.transparent;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // One line, two possible contents. Swapping in place is what keeps
        // the field from jumping when a message arrives.
        AnimatedSwitcher(
          duration: TideMotion.tabSwitch,
          child: Text(
            widget.error ?? widget.label,
            key: ValueKey(widget.error ?? widget.label),
            style: TideType.labelMuted.copyWith(
              color: widget.error != null ? TideColors.coral : TideColors.silt,
            ),
          ),
        ),
        const SizedBox(height: 8),
        AnimatedBuilder(
          animation: _shake,
          builder: (context, child) {
            final t = _shake.value;
            // Three decaying swings — a nudge, not a tantrum.
            final offset = t == 0 ? 0.0 : math.sin(t * math.pi * 6) * 7 * (1 - t);
            return Transform.translate(offset: Offset(offset, 0), child: child);
          },
          child: AnimatedContainer(
            duration: TideMotion.tabSwitch,
            curve: TideMotion.tabCurve,
            decoration: BoxDecoration(
              color: TideColors.trench,
              borderRadius: TideElevation.radius12,
              border: Border.all(color: _border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: widget.controller,
                    focusNode: _focus,
                    style: TideType.body,
                    obscureText: widget.obscure,
                    cursorColor: TideColors.lantern,
                    keyboardType: widget.keyboardType,
                    textInputAction: widget.textInputAction,
                    textCapitalization: widget.textCapitalization,
                    autofillHints: widget.autofillHints,
                    onSubmitted: widget.onSubmitted,
                    onChanged: widget.onChanged,
                    decoration: InputDecoration(
                      hintText: widget.hint,
                      hintStyle: TideType.bodyMuted,
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 17,
                      ),
                    ),
                  ),
                ),
                if (widget.trailing != null) ...[
                  widget.trailing!,
                  const SizedBox(width: 6),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// The reveal control inside a password field.
class TideFieldToggle extends StatelessWidget {
  const TideFieldToggle({
    super.key,
    required this.on,
    required this.onTap,
    required this.onIcon,
    required this.offIcon,
  });

  final bool on;
  final VoidCallback onTap;
  final IconData onIcon;
  final IconData offIcon;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Icon(
          on ? onIcon : offIcon,
          size: 19,
          color: TideColors.silt,
        ),
      ),
    );
  }
}
