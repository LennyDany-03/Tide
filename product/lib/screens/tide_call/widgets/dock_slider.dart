import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../config/reminder_copy.dart';
import '../../../theme/tide_colors.dart';
import '../../../theme/tide_elevation.dart';
import '../../../theme/tide_gradients.dart';
import '../../../theme/tide_motion.dart';
import '../../../theme/tide_typography.dart';
import '../../../widgets/gauge_number.dart';

/// "Slide to dock": the lit knob carried along the channel to the dock at
/// its far end — to the right, the way a to-do is finished everywhere else
/// in the app.
///
/// A gleam runs through the words toward the dock while it waits, the knob
/// leaves a wake of light behind it as it goes, and the dock lights up as
/// the knob nears it; past [TideMotion.dockThreshold] letting go docks the
/// to-do. While [stepsLeft] is above nought it gives a little and springs
/// back — the list refuses the same swipe for the same reason — says how
/// many steps are left, and shows no dock, because there is nothing to
/// reach yet.
class DockSlider extends StatefulWidget {
  const DockSlider({
    super.key,
    required this.label,
    required this.stepsLeft,
    required this.onDocked,
    this.onBlocked,
    this.enabled = true,
  });

  /// What a screen reader hears it as: "Dock Post the parcel".
  final String label;
  final int stepsLeft;
  final VoidCallback onDocked;
  final VoidCallback? onBlocked;
  final bool enabled;

  @override
  State<DockSlider> createState() => _DockSliderState();
}

class _DockSliderState extends State<DockSlider> with TickerProviderStateMixin {
  static const double _height = 66;
  static const double _knob = 54;
  static const double _inset = 6;
  static const double _dock = 42;

  /// Where the knob is, 0 at the start of the channel, 1 at the end.
  late final AnimationController _travel = AnimationController(
    vsync: this,
    duration: TideMotion.swipeCancel,
  );

  late final AnimationController _shimmer = AnimationController(
    vsync: this,
    duration: TideMotion.dockShimmer,
  );

  double _width = 1;
  bool _crossed = false;
  bool _still = false;

  bool get _blocked => widget.stepsLeft > 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _still = MediaQuery.disableAnimationsOf(context);
    if (_still) {
      _shimmer.stop();
    } else if (!_shimmer.isAnimating) {
      unawaited(_shimmer.repeat());
    }
  }

  @override
  void dispose() {
    _travel.dispose();
    _shimmer.dispose();
    super.dispose();
  }

  double get _span => _width - _knob - _inset * 2;

  void _update(DragUpdateDetails details) {
    if (!widget.enabled) return;
    var next = _travel.value + details.delta.dx / _span;
    // Blocked, it only gives a little: enough to feel that it is a slider,
    // not enough to look like it might go.
    if (_blocked) next = next.clamp(0.0, 0.18);
    _travel.value = next.clamp(0.0, 1.0);
    final crossed = _travel.value >= TideMotion.dockThreshold;
    if (crossed != _crossed) {
      setState(() => _crossed = crossed);
      if (crossed) unawaited(HapticFeedback.selectionClick());
    }
  }

  void _end(DragEndDetails details) {
    if (!widget.enabled) return;
    final flung = (details.primaryVelocity ?? 0) > 1200 && _travel.value > 0.5;
    if (!_blocked && (_travel.value >= TideMotion.dockThreshold || flung)) {
      setState(() => _crossed = true);
      _travel.animateTo(
        1,
        duration: TideMotion.swipeSettle,
        curve: TideMotion.tabCurve,
      );
      widget.onDocked();
      return;
    }
    if (_blocked && _travel.value > 0.08) widget.onBlocked?.call();
    setState(() => _crossed = false);
    _travel.animateTo(
      0,
      duration: TideMotion.swipeCancel,
      curve: TideMotion.swipeCancelCurve,
    );
  }

  @override
  Widget build(BuildContext context) {
    final label = _blocked
        ? ReminderCopy.stepsLeftLine(widget.stepsLeft)
        : 'Slide to dock';
    return Semantics(
      button: true,
      enabled: widget.enabled && !_blocked,
      label: _blocked ? label : widget.label,
      onTap: widget.enabled
          ? (_blocked ? widget.onBlocked : widget.onDocked)
          : null,
      child: ExcludeSemantics(
        child: LayoutBuilder(
          builder: (context, box) {
            _width = box.maxWidth;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragUpdate: _update,
              onHorizontalDragEnd: _end,
              child: SizedBox(
                height: _height,
                child: AnimatedBuilder(
                  animation: _travel,
                  builder: (context, _) {
                    final travel = _travel.value;
                    final x = _inset + _span * travel;
                    final near = _blocked
                        ? 0.0
                        : (travel / TideMotion.dockThreshold).clamp(0.0, 1.0);
                    return Stack(
                      children: [
                        _channel(),
                        // The wake behind the knob.
                        Positioned(
                          left: 0,
                          top: 0,
                          bottom: 0,
                          width: x + _knob + _inset,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(_height / 2),
                              gradient: LinearGradient(
                                colors: [
                                  TideColors.lantern.withValues(alpha: 0.02),
                                  TideColors.lantern.withValues(
                                    alpha: 0.12 + 0.14 * near,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        if (!_blocked)
                          Positioned(
                            right: (_height - _dock) / 2,
                            top: (_height - _dock) / 2,
                            child: _Dock(
                              size: _dock,
                              near: near,
                              crossed: _crossed,
                            ),
                          ),
                        Positioned.fill(
                          child: Center(
                            child: Opacity(
                              opacity: (1 - travel * 2.2).clamp(0.0, 1.0),
                              child: Padding(
                                padding: EdgeInsets.only(
                                  left: _knob + _inset + 10,
                                  right: _blocked ? 16 : _dock + 16,
                                ),
                                child: _label(label),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: x,
                          top: (_height - _knob) / 2,
                          child: _Knob(
                            size: _knob,
                            stepsLeft: widget.stepsLeft,
                            crossed: _crossed,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// The channel: cut into the night rather than raised off it, with the
  /// lit top edge every raised thing in the app has.
  Widget _channel() {
    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: TideColors.shelf.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(_height / 2),
          border: Border.all(color: TideColors.hairline),
        ),
        child: Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: _height / 2),
            child: SizedBox(
              height: TideElevation.innerHighlightWidth,
              width: double.infinity,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: TideElevation.innerHighlightGradient,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String label) {
    final text = Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      style: TideType.label.copyWith(
        fontSize: 15,
        color: _blocked ? TideColors.silt : TideColors.bone,
      ),
    );
    if (_blocked || _still) return text;
    return AnimatedBuilder(
      animation: _shimmer,
      builder: (context, child) => ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: (bounds) => TideGradients.dockShimmer(
          TideMotion.tabCurve.transform(_shimmer.value),
        ).createShader(bounds),
        child: child,
      ),
      child: text,
    );
  }
}

/// Where the knob is going: a ring at the end of the channel that lights
/// as the knob comes near it and fills once it is close enough to let go.
class _Dock extends StatelessWidget {
  const _Dock({required this.size, required this.near, required this.crossed});

  final double size;
  final double near;
  final bool crossed;

  @override
  Widget build(BuildContext context) {
    final ring = Color.lerp(
      TideColors.bone.withValues(alpha: 0.16),
      TideColors.lantern.withValues(alpha: 0.8),
      near * near,
    )!;
    return AnimatedContainer(
      duration: TideMotion.tabSwitch,
      curve: TideMotion.tabCurve,
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: TideColors.lantern.withValues(alpha: crossed ? 0.2 : 0),
        border: Border.all(color: ring, width: 1.5),
      ),
      child: Icon(
        Icons.check_rounded,
        size: 20,
        color: Color.lerp(
          TideColors.silt,
          TideColors.lantern,
          near,
        )!.withValues(alpha: 0.5 + 0.5 * near),
      ),
    );
  }
}

/// The knob: the one lit thing in the channel, with an arrow saying which
/// way it goes, turning to a tick once it is past the line. Blocked, it
/// goes dark and carries the number of steps left instead.
class _Knob extends StatelessWidget {
  const _Knob({
    required this.size,
    required this.stepsLeft,
    required this.crossed,
  });

  final double size;
  final int stepsLeft;
  final bool crossed;

  @override
  Widget build(BuildContext context) {
    final blocked = stepsLeft > 0;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: blocked ? TideColors.shoal : TideColors.lantern,
        border: blocked ? Border.all(color: TideColors.hairline) : null,
        boxShadow: blocked
            ? TideElevation.floating
            : TideElevation.lanternGlow(intensity: 0.8),
      ),
      child: blocked
          ? GaugeNumber(
              value: stepsLeft,
              style: TideType.gauge(19, color: TideColors.silt),
            )
          : AnimatedSwitcher(
              duration: TideMotion.tabSwitch,
              child: Icon(
                crossed ? Icons.check_rounded : Icons.arrow_forward_rounded,
                key: ValueKey(crossed),
                size: 24,
                color: TideColors.onLantern,
              ),
            ),
    );
  }
}
