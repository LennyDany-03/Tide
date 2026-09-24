import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../config/reminder_copy.dart';
import '../../../theme/tide_colors.dart';
import '../../../theme/tide_motion.dart';
import '../../../theme/tide_typography.dart';
import '../../../widgets/gauge_number.dart';

/// "Slide to dock": a buoy carried along a channel to the right, the way a
/// to-do is finished everywhere else in the app.
///
/// It leaves a wake behind it as it goes, and past
/// [TideMotion.dockThreshold] letting go docks the to-do. While [stepsLeft]
/// is above nought it gives a little and springs back — the list refuses the
/// same swipe for the same reason — and says how many steps are left.
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

class _DockSliderState extends State<DockSlider>
    with SingleTickerProviderStateMixin {
  static const double _height = 64;
  static const double _knob = 52;

  /// Where the buoy is, 0 at the start of the channel, 1 at the end.
  late final AnimationController _travel = AnimationController(
    vsync: this,
    duration: TideMotion.swipeCancel,
  );

  double _width = 1;
  bool _crossed = false;

  bool get _blocked => widget.stepsLeft > 0;

  @override
  void dispose() {
    _travel.dispose();
    super.dispose();
  }

  void _update(DragUpdateDetails details) {
    if (!widget.enabled) return;
    final span = _width - _knob - 12;
    var next = _travel.value + details.delta.dx / span;
    // Blocked, it only gives a little: enough to feel that it is a slider,
    // not enough to look like it might go.
    if (_blocked) next = next.clamp(0.0, 0.18);
    _travel.value = next.clamp(0.0, 1.0);
    final crossed = _travel.value >= TideMotion.dockThreshold;
    if (crossed != _crossed) {
      _crossed = crossed;
      if (crossed) unawaited(HapticFeedback.selectionClick());
    }
  }

  void _end(DragEndDetails details) {
    if (!widget.enabled) return;
    final flung = (details.primaryVelocity ?? 0) > 1200 && _travel.value > 0.5;
    if (!_blocked && (_travel.value >= TideMotion.dockThreshold || flung)) {
      _travel.animateTo(
        1,
        duration: TideMotion.swipeSettle,
        curve: Curves.easeOut,
      );
      widget.onDocked();
      return;
    }
    if (_blocked && _travel.value > 0.08) widget.onBlocked?.call();
    _crossed = false;
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
                    final span = _width - _knob - 12;
                    final x = 6 + span * _travel.value;
                    return Stack(
                      children: [
                        // The channel.
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: TideColors.trench,
                              borderRadius: BorderRadius.circular(_height / 2),
                              border: Border.all(color: TideColors.hairline),
                            ),
                          ),
                        ),
                        // The wake behind the buoy.
                        Positioned(
                          left: 0,
                          top: 0,
                          bottom: 0,
                          width: x + _knob,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(_height / 2),
                              gradient: LinearGradient(
                                colors: [
                                  TideColors.lantern.withValues(alpha: 0.04),
                                  TideColors.lantern.withValues(alpha: 0.22),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Positioned.fill(
                          child: Center(
                            child: Opacity(
                              opacity: (1 - _travel.value * 2.2).clamp(
                                0.0,
                                1.0,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.only(
                                  left: _knob + 8,
                                  right: 12,
                                ),
                                child: Text(
                                  label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TideType.label.copyWith(
                                    color: _blocked
                                        ? TideColors.silt
                                        : TideColors.bone,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: x,
                          top: (_height - _knob) / 2,
                          child: _Buoy(
                            size: _knob,
                            stepsLeft: widget.stepsLeft,
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
}

/// The knob: a buoy, abstractly — a disc with a band across it. Blocked, it
/// carries the number of steps left instead.
class _Buoy extends StatelessWidget {
  const _Buoy({required this.size, required this.stepsLeft});

  final double size;
  final int stepsLeft;

  @override
  Widget build(BuildContext context) {
    final blocked = stepsLeft > 0;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: blocked ? TideColors.shelf : TideColors.lantern,
        border: blocked ? Border.all(color: TideColors.hairline) : null,
      ),
      child: blocked
          ? GaugeNumber(
              value: stepsLeft,
              style: TideType.gauge(18, color: TideColors.silt),
            )
          : Container(
              width: size * 0.5,
              height: size * 0.16,
              decoration: BoxDecoration(
                color: TideColors.onLantern,
                borderRadius: BorderRadius.circular(size * 0.08),
              ),
            ),
    );
  }
}
