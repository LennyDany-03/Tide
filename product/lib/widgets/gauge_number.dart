import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/tide_motion.dart';
import '../theme/tide_typography.dart';

/// A numeric readout that moves to its value instead of appearing at it.
///
/// Every streak, count and percentage on screen goes through this widget or
/// [GaugeCountUp]. The motion is in the *value*: the number is tweened and
/// each frame draws the figure it has reached, so a rate settling on 87
/// visibly climbs there.
///
/// It is deliberately not a two-drum odometer. Stacking the outgoing digit
/// against the incoming one — sliding, crossfading, any blend of the two —
/// means that for the whole length of the change there are two glyphs in
/// one column, and at gauge sizes that does not read as a wheel turning
/// over. It reads as a smeared or doubled character sitting in the middle
/// of a card, which is worse than no animation at all. One glyph per column
/// per frame is the rule here, and the climb supplies the movement.
class GaugeNumber extends StatelessWidget {
  const GaugeNumber({
    super.key,
    required this.value,
    required this.style,
    this.minDigits = 1,
    this.duration = TideMotion.digitRoll,
  });

  final int value;
  final TextStyle style;

  /// Pads with leading zeros — used by the reminder time readout (08:00).
  final int minDigits;

  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: value.toDouble()),
      duration: duration,
      curve: TideMotion.digitRollCurve,
      builder: (context, animated, _) {
        return _Readout(
          value: animated,
          target: value,
          style: style,
          minDigits: minDigits,
        );
      },
    );
  }
}

/// The figure itself.
///
/// Two things keep this from disturbing anything around it:
///
/// * It is a single text run, so the glyphs are laid out by the font with
///   its own metrics and the run reports a real alphabetic baseline — which
///   is what lets a suffix beside it sit on the same line.
/// * The column count is taken from the *target*, and places the value has
///   not reached yet hold a space rather than a digit. The run therefore
///   keeps one width for the whole climb: nothing reflows, no parent
///   re-fits, and the caption underneath never moves. Blank rather than
///   zero because a rate climbing to 100 would otherwise read "084%" the
///   entire way up.
class _Readout extends StatelessWidget {
  const _Readout({
    required this.value,
    required this.target,
    required this.style,
    required this.minDigits,
  });

  /// The tweened value — somewhere between the previous figure and [target].
  final double value;

  final int target;
  final TextStyle style;
  final int minDigits;

  @override
  Widget build(BuildContext context) {
    final reached = value.abs().floor();

    // The widest the run will ever be on the way to [target]. Taking the
    // max with [reached] covers a value tweening *down*, where the figure
    // on screen is still wider than the one it is heading for.
    final columns = math.max(
      minDigits,
      math.max(target.abs(), reached).toString().length,
    );

    final digits = reached.toString().padLeft(minDigits, '0');
    final sign = target < 0 ? '-' : '';

    return Text(
      '$sign${digits.padLeft(columns)}',
      style: style,
      maxLines: 1,
      softWrap: false,
    );
  }
}

/// A number that counts up from zero when it first appears — the entrance
/// treatment for stat chips and the Insights hero, where the reveal *is*
/// the moment rather than an update to something already on screen.
class GaugeCountUp extends StatefulWidget {
  const GaugeCountUp({
    super.key,
    required this.value,
    required this.style,
    this.duration = TideMotion.countUp,
    this.delay = Duration.zero,
    this.suffix,
    this.suffixStyle,
  });

  final int value;
  final TextStyle style;
  final Duration duration;
  final Duration delay;

  /// Rendered immediately after the digits — the % on Insights, the "min"
  /// on a duration habit.
  final String? suffix;
  final TextStyle? suffixStyle;

  @override
  State<GaugeCountUp> createState() => _GaugeCountUpState();
}

class _GaugeCountUpState extends State<GaugeCountUp>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void didUpdateWidget(GaugeCountUp old) {
    super.didUpdateWidget(old);
    // A changed target re-runs the roll from where it is, rather than
    // restarting the count from zero.
    if (old.value != widget.value && _controller.isCompleted) {
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
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final eased = Curves.easeOutCubic.transform(_controller.value);
        final current = widget.value * eased;
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            _Readout(
              value: current,
              target: widget.value,
              style: widget.style,
              minDigits: 1,
            ),
            if (widget.suffix != null)
              Text(
                widget.suffix!,
                style:
                    widget.suffixStyle ??
                    TideType.gauge(
                      (widget.style.fontSize ?? 16) * 0.45,
                      color: widget.style.color ?? TideType.body.color!,
                    ),
              ),
          ],
        );
      },
    );
  }
}
