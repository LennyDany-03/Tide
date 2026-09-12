import 'package:flutter/material.dart';

import '../theme/tide_colors.dart';
import '../theme/tide_elevation.dart';
import '../theme/tide_motion.dart';
import '../theme/tide_typography.dart';
import 'press_scale.dart';
import 'tide_ring.dart';

enum TideButtonVariant {
  /// Solid lantern — the one primary action on a screen.
  primary,

  /// A plain surface — everything alongside a primary.
  secondary,

  /// Text only, for dismissals and low-stakes navigation.
  ghost,
}

/// The progress a button is reporting about its own action.
enum TideButtonPhase { idle, busy, done }

/// The app's button.
///
/// The [phase] states matter: a saving button collapses into a tide-ring
/// spinner and then a checkmark rather than freezing or showing a separate
/// dialog, which is what lets a save read as one continuous motion.
class TideButton extends StatelessWidget {
  const TideButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = TideButtonVariant.primary,
    this.phase = TideButtonPhase.idle,
    this.expand = true,
    this.icon,
    this.shadows,
    this.enabled = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final TideButtonVariant variant;
  final TideButtonPhase phase;
  final bool expand;
  final Widget? icon;

  /// The paywall CTA passes its glow here.
  final List<BoxShadow>? shadows;

  final bool enabled;

  bool get _interactive => enabled && phase == TideButtonPhase.idle;

  /// Solid fills, no ramps. A warm accent block on near-black water is
  /// already the loudest thing on any screen it appears on; a gradient
  /// across it adds nothing except the look of a template.
  Color? get _fill => switch (variant) {
    TideButtonVariant.primary => TideColors.lantern,
    TideButtonVariant.secondary => TideColors.shelf,
    TideButtonVariant.ghost => null,
  };

  Color get _foreground => switch (variant) {
    TideButtonVariant.primary => TideColors.onLantern,
    TideButtonVariant.secondary => TideColors.bone,
    TideButtonVariant.ghost => TideColors.silt,
  };

  /// A disabled primary goes neutral rather than dim.
  ///
  /// Fading the fill to 40% turned the accent into a muddy olive that reads
  /// as a rendering fault rather than as an unavailable control. Dropping
  /// the colour entirely says "not yet" without inventing a shade that is
  /// not in the palette.
  Color? get _disabledFill =>
      variant == TideButtonVariant.ghost ? null : TideColors.shelf;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: _interactive ? onPressed : null,
      enabled: _interactive && onPressed != null,
      child: Opacity(
        opacity: 1,
        child: AnimatedContainer(
          duration: TideMotion.tabSwitch,
          curve: TideMotion.tabCurve,
          width: expand ? double.infinity : null,
          height: 52,
          // A full-width button gets its air from the screen margins. One
          // sized to its own label has none unless it is given some, and
          // without this the label sits hard against both ends and reads as
          // clipped rather than compact.
          padding: expand
              ? null
              : const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            color: enabled ? _fill : _disabledFill,
            borderRadius: TideElevation.radius12,
            // No glow. The primary button does not need to emit light to be
            // found — it is the only warm block on the screen.
            boxShadow: shadows,
            border: variant == TideButtonVariant.secondary
                ? Border.all(color: TideColors.hairline)
                : null,
          ),
          alignment: Alignment.center,
          child: AnimatedSwitcher(
            duration: TideMotion.tabSwitch,
            child: switch (phase) {
              TideButtonPhase.busy => TideSpinner(
                key: const ValueKey('busy'),
                color: _foreground,
              ),
              TideButtonPhase.done => Icon(
                Icons.check_rounded,
                key: const ValueKey('done'),
                size: 24,
                color: _foreground,
              ),
              TideButtonPhase.idle => Row(
                key: const ValueKey('idle'),
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[icon!, const SizedBox(width: 8)],
                  Text(
                    label,
                    style: TideType.button.copyWith(
                      color: enabled ? _foreground : TideColors.silt,
                    ),
                  ),
                ],
              ),
            },
          ),
        ),
      ),
    );
  }
}

/// The busy state spins, so the ring reads as working rather than stuck at
/// 28%. Kept separate from [TideButton] so a static button never pays for
/// an animation controller it does not use.
class TideSpinner extends StatefulWidget {
  const TideSpinner({
    super.key,
    this.size = 22,
    this.color,
    this.strokeWidth = 2.5,
  });

  final double size;
  final Color? color;
  final double strokeWidth;

  @override
  State<TideSpinner> createState() => _TideSpinnerState();
}

class _TideSpinnerState extends State<TideSpinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: TideRing(
        progress: 0.28,
        size: widget.size,
        strokeWidth: widget.strokeWidth,
        animate: false,
        showTrack: false,
        color: widget.color ?? TideColors.onLantern,
      ),
    );
  }
}
