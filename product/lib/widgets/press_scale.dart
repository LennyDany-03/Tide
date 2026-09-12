import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/tide_motion.dart';

/// The global press-feedback rule, in one widget.
///
/// Every tappable element in Tide is wrapped in this — scale to 0.97 on
/// press, spring back on release. It is deliberately the *only* press
/// affordance in the app: Material ink is switched off in the theme, so if
/// something is tappable and not wrapped here, it will feel dead.
class PressScale extends StatefulWidget {
  const PressScale({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.enabled = true,
    this.scale = TideMotion.pressScale,
    this.haptic = true,
    this.behavior = HitTestBehavior.opaque,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool enabled;

  /// Override only where the default reads wrong — a very large surface
  /// wants a shallower press than a small chip.
  final double scale;

  final bool haptic;
  final HitTestBehavior behavior;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: TideMotion.press,
    reverseDuration: TideMotion.press * 1.6,
  );

  late final Animation<double> _scale =
      Tween<double>(begin: 1, end: widget.scale).animate(
        CurvedAnimation(
          parent: _controller,
          curve: TideMotion.pressCurve,
          reverseCurve: TideMotion.pressReleaseCurve,
        ),
      );

  bool get _interactive =>
      widget.enabled && (widget.onTap != null || widget.onLongPress != null);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _press() {
    if (!_interactive) return;
    _controller.forward();
  }

  void _release() {
    if (!_controller.isDismissed) _controller.reverse();
  }

  void _handleTap() {
    if (widget.haptic) HapticFeedback.selectionClick();
    widget.onTap?.call();
  }

  void _handleLongPress() {
    if (widget.haptic) HapticFeedback.mediumImpact();
    widget.onLongPress?.call();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: widget.behavior,
      onTapDown: (_) => _press(),
      onTapUp: (_) => _release(),
      onTapCancel: _release,
      onTap: widget.onTap == null || !widget.enabled ? null : _handleTap,
      onLongPress: widget.onLongPress == null || !widget.enabled
          ? null
          : _handleLongPress,
      child: ScaleTransition(scale: _scale, child: widget.child),
    );
  }
}
