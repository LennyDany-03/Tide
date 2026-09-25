import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../config/reminder_copy.dart';
import '../services/haptics.dart';
import '../theme/tide_colors.dart';
import '../theme/tide_elevation.dart';
import '../theme/tide_gradients.dart';
import '../theme/tide_motion.dart';
import '../theme/tide_typography.dart';
import 'press_scale.dart';
import 'tide_button.dart';

/// A time, set by turning a ring — the tide dial.
///
/// **One lap is one hour, and turning on winds the hours.** A ring with all
/// twenty-four hours round it puts five minutes two pixels apart, which no
/// thumb can hit; a ring of sixty minutes puts them a knuckle apart, and
/// carrying on past the top moves the hour, the way a watch is wound. The
/// hour buttons under it are for the long jumps.
///
/// **The water inside is the day.** Empty at midnight, half full at noon,
/// brimming just before the next midnight — so a glance says "early" or
/// "evening" before the digits are read.
class TideDial extends StatefulWidget {
  const TideDial({
    super.key,
    required this.value,
    required this.onChanged,
    this.size = 248,
  });

  final TimeOfDay value;
  final ValueChanged<TimeOfDay> onChanged;
  final double size;

  @override
  State<TideDial> createState() => _TideDialState();
}

class _TideDialState extends State<TideDial>
    with SingleTickerProviderStateMixin {
  /// The ring moves in five-minute detents.
  static const int _step = 5;

  late final AnimationController _drift = AnimationController(
    vsync: this,
    duration: TideMotion.swell,
  );

  double? _lastAngle;
  double _carry = 0;

  int get _minutes => widget.value.hour * 60 + widget.value.minute;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _drift.stop();
    } else if (!_drift.isAnimating) {
      _drift.repeat();
    }
  }

  @override
  void dispose() {
    _drift.dispose();
    super.dispose();
  }

  double _angleOf(Offset local) {
    final center = Offset(widget.size / 2, widget.size / 2);
    return math.atan2(local.dy - center.dy, local.dx - center.dx);
  }

  void _start(DragStartDetails details) {
    _lastAngle = _angleOf(details.localPosition);
    _carry = 0;
  }

  void _update(DragUpdateDetails details) {
    final last = _lastAngle;
    if (last == null) return;
    final angle = _angleOf(details.localPosition);
    var delta = angle - last;
    if (delta > math.pi) delta -= 2 * math.pi;
    if (delta < -math.pi) delta += 2 * math.pi;
    _lastAngle = angle;

    _carry += delta / (2 * math.pi) * 60;
    var moved = 0;
    while (_carry >= _step) {
      _carry -= _step;
      moved += _step;
    }
    while (_carry <= -_step) {
      _carry += _step;
      moved -= _step;
    }
    if (moved != 0) _shift(moved);
  }

  void _shift(int minutes) {
    final next = (_snapped(_minutes) + minutes) % (24 * 60);
    unawaited(TideHaptics.selectionClick());
    widget.onChanged(TimeOfDay(hour: next ~/ 60, minute: next % 60));
  }

  /// A time off the five-minute grid (07:32, from before this dial) is put
  /// on it by the first turn rather than carried along two minutes out.
  static int _snapped(int minutes) => minutes - minutes % _step;

  @override
  Widget build(BuildContext context) {
    final label = ReminderCopy.clock(widget.value);
    return Semantics(
      label: 'Reminder time',
      value: label,
      increasedValue: ReminderCopy.clock(_offset(_step)),
      decreasedValue: ReminderCopy.clock(_offset(-_step)),
      onIncrease: () => _shift(_step),
      onDecrease: () => _shift(-_step),
      child: ExcludeSemantics(
        child: GestureDetector(
          onPanStart: _start,
          onPanUpdate: _update,
          onPanEnd: (_) => _lastAngle = null,
          child: SizedBox.square(
            dimension: widget.size,
            child: AnimatedBuilder(
              animation: _drift,
              builder: (context, _) => CustomPaint(
                painter: _DialPainter(
                  minutes: _minutes,
                  phase: _drift.value * 2 * math.pi,
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(label, style: TideType.gauge(46, letterSpacing: 1)),
                      const SizedBox(height: 6),
                      Text('Turn the ring', style: TideType.labelMuted),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  TimeOfDay _offset(int minutes) {
    final next = (_snapped(_minutes) + minutes) % (24 * 60);
    return TimeOfDay(hour: next ~/ 60, minute: next % 60);
  }
}

class _DialPainter extends CustomPainter {
  const _DialPainter({required this.minutes, required this.phase});

  final int minutes;
  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final outer = size.shortestSide / 2;
    const track = 14.0;
    final ring = outer - track / 2 - 12;
    final inner = ring - track / 2 - 6;
    final face = Rect.fromCircle(center: center, radius: inner);

    // The day, as water in the face.
    canvas.save();
    canvas.clipPath(Path()..addOval(face));
    canvas.drawRect(face, Paint()..color = TideColors.trench);
    final level = minutes / (24 * 60);
    final surface = face.bottom - face.height * level;
    final water = Path()..moveTo(face.left, surface);
    const steps = 40;
    for (var i = 0; i <= steps; i++) {
      final u = i / steps;
      water.lineTo(
        face.left + face.width * u,
        surface + math.sin(u * math.pi * 2.4 + phase) * 3.5,
      );
    }
    water
      ..lineTo(face.right, face.bottom)
      ..lineTo(face.left, face.bottom)
      ..close();
    canvas.drawPath(
      water,
      Paint()
        ..shader = TideGradients.callWater(
          TideGradients.callWaterLayer(2),
        ).createShader(face),
    );
    canvas.restore();

    // The track, cut into the surface.
    canvas.drawCircle(
      center,
      ring,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = track
        ..color = TideColors.trench,
    );

    // A tick every five minutes, the quarters longer.
    final tick = Paint()
      ..strokeCap = StrokeCap.round
      ..color = TideColors.silt.withValues(alpha: 0.55);
    for (var i = 0; i < 12; i++) {
      final a = -math.pi / 2 + i * math.pi / 6;
      final long = i % 3 == 0;
      tick.strokeWidth = long ? 2 : 1.2;
      final from = ring + track / 2 + 4;
      final to = from + (long ? 8 : 5);
      canvas.drawLine(
        center + Offset(math.cos(a), math.sin(a)) * from,
        center + Offset(math.cos(a), math.sin(a)) * to,
        tick,
      );
    }

    // How far round the hour stands, from the top.
    final minute = minutes % 60;
    final sweep = 2 * math.pi * minute / 60;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: ring),
      -math.pi / 2,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = track
        ..strokeCap = StrokeCap.round
        ..color = TideColors.lantern.withValues(alpha: 0.35),
    );

    // The handle.
    final a = -math.pi / 2 + sweep;
    final knob = center + Offset(math.cos(a), math.sin(a)) * ring;
    canvas.drawCircle(knob, 13, Paint()..color = TideColors.lantern);
    canvas.drawCircle(knob, 4, Paint()..color = TideColors.onLantern);
  }

  @override
  bool shouldRepaint(_DialPainter old) =>
      old.minutes != minutes || old.phase != phase;
}

/// The dial in a sheet, with hour buttons and a Set button. Resolves to the
/// time chosen, or null if the sheet was dismissed.
Future<TimeOfDay?> showTideDial(
  BuildContext context, {
  required TimeOfDay initial,
  String title = 'Reminder time',
}) {
  return showGeneralDialog<TimeOfDay>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss',
    barrierColor: TideColors.scrim,
    transitionDuration: TideMotion.sheetIn,
    pageBuilder: (context, _, _) => Align(
      alignment: Alignment.bottomCenter,
      child: Material(
        type: MaterialType.transparency,
        child: _DialSheet(initial: initial, title: title),
      ),
    ),
    transitionBuilder: (context, animation, _, child) => SlideTransition(
      position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
          .animate(
            CurvedAnimation(
              parent: animation,
              curve: TideMotion.sheetCurve,
              reverseCurve: Curves.easeInCubic,
            ),
          ),
      child: child,
    ),
  );
}

class _DialSheet extends StatefulWidget {
  const _DialSheet({required this.initial, required this.title});

  final TimeOfDay initial;
  final String title;

  @override
  State<_DialSheet> createState() => _DialSheetState();
}

class _DialSheetState extends State<_DialSheet> {
  late TimeOfDay _time = widget.initial;

  void _hours(int by) {
    final minutes = (_time.hour * 60 + _time.minute + by * 60) % (24 * 60);
    unawaited(TideHaptics.selectionClick());
    setState(
      () => _time = TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 520),
      decoration: BoxDecoration(
        color: TideColors.shoal,
        borderRadius: TideElevation.sheetRadius,
        boxShadow: TideElevation.floating,
      ),
      padding: EdgeInsets.fromLTRB(
        22,
        10,
        22,
        16 + MediaQuery.paddingOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: TideColors.bone.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(widget.title, style: TideType.hero.copyWith(fontSize: 19)),
            const SizedBox(height: 14),
            Center(
              child: TideDial(
                value: _time,
                onChanged: (time) => setState(() => _time = time),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _HourButton(
                  label: '− 1 hr',
                  semantics: 'An hour earlier',
                  onTap: () => _hours(-1),
                ),
                const SizedBox(width: 12),
                _HourButton(
                  label: '+ 1 hr',
                  semantics: 'An hour later',
                  onTap: () => _hours(1),
                ),
              ],
            ),
            const SizedBox(height: 18),
            TideButton(
              label: 'Set ${ReminderCopy.clock(_time)}',
              onPressed: () => Navigator.of(context).pop(_time),
            ),
          ],
        ),
      ),
    );
  }
}

class _HourButton extends StatelessWidget {
  const _HourButton({
    required this.label,
    required this.semantics,
    required this.onTap,
  });

  final String label;
  final String semantics;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semantics,
      child: ExcludeSemantics(
        child: PressScale(
          onTap: onTap,
          child: Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: TideColors.shelf,
              borderRadius: TideElevation.radius12,
              border: Border.all(color: TideColors.hairline),
            ),
            child: Text(label, style: TideType.label),
          ),
        ),
      ),
    );
  }
}
