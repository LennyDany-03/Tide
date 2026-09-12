import 'package:flutter/widgets.dart';

/// Fades in while rising the last few pixels into place.
///
/// Driven by a [progress] the caller owns, so a sequence of lines can rise
/// on one clock — the welcome's greeting, the farewell's words under the
/// tick — rather than each keeping a controller of its own.
class Rise extends StatelessWidget {
  const Rise({
    super.key,
    required this.progress,
    required this.lift,
    required this.child,
  });

  final double progress;
  final double lift;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: progress,
      child: Transform.translate(
        offset: Offset(0, lift * (1 - progress)),
        child: child,
      ),
    );
  }
}
