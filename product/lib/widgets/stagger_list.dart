import 'package:flutter/material.dart';

import '../theme/tide_motion.dart';

/// List entrance: fade in and rise 8px, each item 60ms behind the one
/// above it.
///
/// Home's habit list, the paywall's feature rows and Insights' callouts all
/// use this, which is why arriving on any of those screens feels like the
/// same content settling rather than three different reveals.
class StaggerIn extends StatefulWidget {
  const StaggerIn({
    super.key,
    required this.index,
    required this.child,
    this.baseDelay = Duration.zero,
    this.rise = TideMotion.staggerRise,
    this.enabled = true,
  });

  final int index;
  final Widget child;

  /// Offsets the whole run — used where a list must wait for a chart to
  /// finish drawing before it appears.
  final Duration baseDelay;

  final double rise;
  final bool enabled;

  @override
  State<StaggerIn> createState() => _StaggerInState();
}

class _StaggerInState extends State<StaggerIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: TideMotion.staggerItem,
  );

  @override
  void initState() {
    super.initState();
    if (!widget.enabled) {
      _controller.value = 1;
      return;
    }
    Future<void>.delayed(
      widget.baseDelay + TideMotion.staggerStep * widget.index,
      () {
        if (mounted) _controller.forward();
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curve = CurvedAnimation(
      parent: _controller,
      curve: TideMotion.staggerCurve,
    );

    return AnimatedBuilder(
      animation: curve,
      child: widget.child,
      builder: (context, child) {
        return Opacity(
          opacity: curve.value,
          child: Transform.translate(
            offset: Offset(0, widget.rise * (1 - curve.value)),
            child: child,
          ),
        );
      },
    );
  }
}

/// Convenience for a whole column of staggered children.
class StaggerColumn extends StatelessWidget {
  const StaggerColumn({
    super.key,
    required this.children,
    this.spacing = 0,
    this.baseDelay = Duration.zero,
    this.crossAxisAlignment = CrossAxisAlignment.stretch,
  });

  final List<Widget> children;
  final double spacing;
  final Duration baseDelay;
  final CrossAxisAlignment crossAxisAlignment;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: crossAxisAlignment,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0 && spacing > 0) SizedBox(height: spacing),
          StaggerIn(index: i, baseDelay: baseDelay, child: children[i]),
        ],
      ],
    );
  }
}
