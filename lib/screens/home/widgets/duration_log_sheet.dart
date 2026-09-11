import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../services/models/habit.dart';
import '../../../theme/tide_colors.dart';
import '../../../theme/tide_elevation.dart';
import '../../../theme/tide_motion.dart';
import '../../../theme/tide_typography.dart';
import '../../../widgets/press_scale.dart';
import '../../../widgets/tide_button.dart';
import '../../../widgets/tide_sheet.dart';

/// Logging a duration habit: a dial set to the time spent, then one tap.
///
/// Duration habits used to share the counted sheet, where one hold banks one
/// unit. A duration's unit is a minute, so a ninety-minute session cost
/// ninety holds. That sheet makes every unit deliberate on purpose, and on a
/// clock that is exactly the wrong property: nobody lives forty-five minutes
/// of reading as forty-five separate events. They finish, and they know
/// roughly how long it was.
///
/// So the question changes from "one more?" to "how long?", and the
/// instrument changes with it — a clock face is what people already read time
/// off. The dial shows the day's *total*, not an amount to add, so the same
/// drag that sets a session also corrects an overshoot. Nothing is written
/// until the button has said, in words, what will be written.
class DurationLogSheet extends StatefulWidget {
  const DurationLogSheet({
    super.key,
    required this.habit,
    required this.leading,
    required this.onLog,
    required this.onDismiss,
  });

  final Habit habit;

  /// The habit's mark, drawn by the counted sheet so both open the same way.
  final Widget leading;

  /// The total the day should now stand at. Routed out to Home, like the
  /// counted sheet, so finishing the day from here still lands its moment.
  final ValueChanged<num> onLog;

  final VoidCallback onDismiss;

  /// The spacing of the marks round the ring — and so of the detents a thumb
  /// feels, and of a screen reader's steps.
  ///
  /// The dial itself resolves to the minute on every target. It used to snap
  /// to these marks, which on a ninety-minute habit made the handle jump
  /// twenty degrees at a time; the marks are now a scale to read against, not
  /// the only places the handle may stop.
  static int tickEveryFor(num target) => target <= 20
      ? 1
      : target <= 120
      ? 5
      : 15;

  /// The quick amounts, scaled to the habit so "+30 min" is never offered on
  /// a ten-minute stretch.
  static List<int> quickAmountsFor(num target) => target <= 20
      ? const [1, 5, 10]
      : target <= 60
      ? const [5, 10, 15]
      : const [5, 15, 30];

  @override
  State<DurationLogSheet> createState() => _DurationLogSheetState();
}

class _DurationLogSheetState extends State<DurationLogSheet> {
  /// Where the dial is set: the day's total if this is written.
  late num _minutes = _logged;

  bool _dragging = false;

  num get _logged => widget.habit.amountOn(DateTime.now());
  num get _target => widget.habit.target;
  bool get _changed => _minutes != _logged;

  @override
  void didUpdateWidget(DurationLogSheet old) {
    super.didUpdateWidget(old);
    // Logged somewhere else while the sheet was open — another device. An
    // untouched dial follows it; one the person has already set keeps their
    // answer.
    final before = old.habit.amountOn(DateTime.now());
    if (!_dragging && _minutes == before) _minutes = _logged;
  }

  void _set(num minutes) {
    final next = minutes.clamp(0, _target);
    if (next == _minutes) return;
    setState(() => _minutes = next);
  }

  /// A quick amount or Full: one deliberate tap, one click.
  void _jump(num minutes) {
    if (minutes.clamp(0, _target) == _minutes) return;
    HapticFeedback.selectionClick();
    _set(minutes);
  }

  void _confirm() {
    final complete = widget.habit.isCompleteOn(DateTime.now());
    if (!_changed && complete) {
      widget.onDismiss();
      return;
    }
    // Untouched, the one-tap answer is the whole session: the common case is
    // "I did it", and it should not cost a drag.
    final total = _changed ? _minutes : _target;
    if (total >= _target && !complete) {
      HapticFeedback.heavyImpact();
    } else {
      HapticFeedback.mediumImpact();
    }
    widget.onLog(total);
    // Setting the time is the whole job. Once it is written there is nothing
    // left to do here, and Today — where the card and the day just moved — is
    // what should be in view.
    widget.onDismiss();
  }

  String _action(bool complete) {
    if (!_changed) {
      return complete ? 'Done' : 'Mark all ${Minutes.label(_target)}';
    }
    if (_minutes == 0) return 'Clear today';
    if (_minutes < _logged) return 'Change to ${Minutes.label(_minutes)}';
    return 'Mark ${Minutes.label(_minutes)}';
  }

  String _status(bool complete) {
    if (_changed) {
      final delta = _minutes - _logged;
      return delta > 0
          ? 'Adds ${Minutes.label(delta)}'
          : 'Takes off ${Minutes.label(-delta)}';
    }
    if (complete) return 'Target reached for today.';
    return '${Minutes.label(_target - _logged)} to go';
  }

  @override
  Widget build(BuildContext context) {
    final habit = widget.habit;
    final complete = habit.isCompleteOn(DateTime.now());
    final canAdd = _minutes < _target;

    return TideSheet(
      eyebrow: '${habit.targetLabel} a day',
      title: habit.name,
      leading: widget.leading,
      onDismiss: widget.onDismiss,
      maxHeightFactor: 0.8,
      footer: TideButton(label: _action(complete), onPressed: _confirm),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: SizedBox.square(
                dimension: 228,
                child: _TimeDial(
                  minutes: _minutes,
                  logged: _logged,
                  target: _target,
                  onChanged: _set,
                  onDragging: (value) => setState(() => _dragging = value),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _Status(text: _status(complete), lit: _minutes >= _target),
            const SizedBox(height: 14),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final amount in DurationLogSheet.quickAmountsFor(_target))
                  _QuickChip(
                    label: '+${Minutes.label(amount)}',
                    enabled: canAdd,
                    onTap: () => _jump(_minutes + amount),
                  ),
                _QuickChip(
                  label: 'Full',
                  enabled: canAdd,
                  onTap: () => _jump(_target),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The dial: a ring that is the day's target, turned clockwise from twelve.
class _TimeDial extends StatefulWidget {
  const _TimeDial({
    required this.minutes,
    required this.logged,
    required this.target,
    required this.onChanged,
    required this.onDragging,
  });

  final num minutes;
  final num logged;
  final num target;
  final ValueChanged<num> onChanged;
  final ValueChanged<bool> onDragging;

  @override
  State<_TimeDial> createState() => _TimeDialState();
}

class _TimeDialState extends State<_TimeDial> {
  /// Where the thumb is, in 0..1 of a turn, while it is down.
  ///
  /// The arc and the handle follow this, not the minute it rounds to, so the
  /// dial turns continuously under the finger rather than stepping from
  /// minute to minute. The figure in the middle and the value written are
  /// the rounded minute; on release the arc eases the last fraction of a
  /// minute onto it.
  double? _thumb;

  bool get _dragging => _thumb != null;

  double _fractionOf(num minutes) => widget.target <= 0
      ? 0
      : (minutes / widget.target).clamp(0.0, 1.0).toDouble();

  /// Claims the pointer on touch-down. A pan would have to travel past its
  /// slop first, and inside a scrolling sheet the vertical scroll gets there
  /// sooner — so a drag down the right side of the dial scrolled the sheet
  /// instead of turning the dial.
  Drag? _start(Offset position) {
    if (_dragging) return null;
    final box = context.findRenderObject();
    if (box is! RenderBox) return null;
    final offset = box.globalToLocal(position) - box.size.center(Offset.zero);
    // The figure in the middle is for reading. A touch on it should not throw
    // the dial to wherever the thumb happened to land.
    if (offset.distance < box.size.shortestSide * 0.24) return null;
    widget.onDragging(true);
    _seek(position);
    return _DialDrag(onUpdate: _seek, onEnd: _release);
  }

  void _release() {
    if (!mounted || _thumb == null) return;
    setState(() => _thumb = null);
    widget.onDragging(false);
  }

  void _seek(Offset position) {
    if (!mounted) return;
    final box = context.findRenderObject()! as RenderBox;
    final offset = box.globalToLocal(position) - box.size.center(Offset.zero);
    if (offset.distance < 1) return;

    // Clockwise from twelve, in 0..1 of a turn.
    var fraction = math.atan2(offset.dx, -offset.dy) / (math.pi * 2);
    if (fraction < 0) fraction += 1;

    // Twelve o'clock is both empty and full. Crossing it must not flip from
    // one to the other: a dial driven up to full stays full as the thumb
    // passes the top, and one wound back past empty stays empty. Measured
    // against the thumb, not the rounded minute, which can lag a pointer
    // event behind it.
    final current = _thumb ?? _fractionOf(widget.minutes);
    if (current > 0.75 && fraction < 0.25) fraction = 1;
    if (current < 0.25 && fraction > 0.75) fraction = 0;

    final target = widget.target;
    final raw = fraction * target;
    // To the minute — and full is always reachable, whatever the target.
    final minutes = raw >= target - 0.5 ? target : raw.round();

    // A click at every mark on the ring, not at every minute: sixty clicks
    // through an hour is a buzz, not a scale.
    final every = DurationLogSheet.tickEveryFor(target);
    final before = widget.minutes;
    if (minutes != before &&
        (minutes ~/ every != before ~/ every ||
            minutes == 0 ||
            minutes == target)) {
      HapticFeedback.selectionClick();
    }

    setState(() => _thumb = fraction);
    widget.onChanged(minutes);
  }

  /// Marks inside the ring, [DurationLogSheet.tickEveryFor] apart — quarter
  /// hours once that would crowd the ring. The longer marks fall every five
  /// minutes on a short habit, every quarter hour on a normal one, and on the
  /// hour on a long one.
  List<(double, bool)> _ticks() {
    final target = widget.target;
    var every = DurationLogSheet.tickEveryFor(target);
    if (target / every > 48) every = 15;
    final major = every == 1
        ? 5
        : every < 15
        ? 15
        : 60;
    return [
      for (var minute = 0; minute < target; minute += every)
        (minute / target, minute % major == 0),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final full = widget.minutes >= widget.target;
    final ticks = _ticks();
    final every = DurationLogSheet.tickEveryFor(widget.target);
    final up = math.min(widget.target, widget.minutes + every);
    final down = math.max(0, widget.minutes - every);

    return Semantics(
      slider: true,
      label: 'Time spent today',
      value: Minutes.label(widget.minutes),
      increasedValue: Minutes.label(up),
      decreasedValue: Minutes.label(down),
      onIncrease: () => widget.onChanged(up),
      onDecrease: () => widget.onChanged(down),
      child: RawGestureDetector(
        behavior: HitTestBehavior.opaque,
        gestures: {
          ImmediateMultiDragGestureRecognizer:
              GestureRecognizerFactoryWithHandlers<
                ImmediateMultiDragGestureRecognizer
              >(
                ImmediateMultiDragGestureRecognizer.new,
                (recognizer) => recognizer.onStart = _start,
              ),
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            // One animation for every way the dial moves, so it never jumps
            // between them. Under the thumb it trails by a frame or two —
            // enough to smooth a jittery touch, too little to feel like drag.
            // Released, or set by a chip, it eases the rest of the way.
            TweenAnimationBuilder<double>(
              tween: Tween<double>(end: _dragging ? 1 : 0),
              duration: TideMotion.press,
              curve: TideMotion.pressCurve,
              builder: (context, grip, _) => TweenAnimationBuilder<double>(
                tween: Tween<double>(
                  end: _thumb ?? _fractionOf(widget.minutes),
                ),
                duration: _dragging
                    ? TideMotion.dialFollow
                    : TideMotion.dialSettle,
                curve: _dragging
                    ? TideMotion.dialFollowCurve
                    : TideMotion.dialSettleCurve,
                builder: (context, shown, _) => CustomPaint(
                  painter: _DialPainter(
                    fraction: shown,
                    logged: _fractionOf(widget.logged),
                    ticks: ticks,
                    full: full,
                    grip: grip,
                  ),
                ),
              ),
            ),
            // The slider's own value already says the time. Left in, the
            // figure merges into the slider's label and a screen reader says
            // it twice, as "0, min, of 30 min" tacked onto the name.
            Center(
              child: ExcludeSemantics(
                child: _DialReadout(
                  minutes: widget.minutes,
                  target: widget.target,
                  full: full,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DialDrag implements Drag {
  _DialDrag({required this.onUpdate, required this.onEnd});

  final ValueChanged<Offset> onUpdate;
  final VoidCallback onEnd;

  @override
  void update(DragUpdateDetails details) => onUpdate(details.globalPosition);

  @override
  void end(DragEndDetails details) => onEnd();

  @override
  void cancel() => onEnd();
}

/// The figure in the middle of the dial.
class _DialReadout extends StatelessWidget {
  const _DialReadout({
    required this.minutes,
    required this.target,
    required this.full,
  });

  final num minutes;
  final num target;
  final bool full;

  @override
  Widget build(BuildContext context) {
    final whole = minutes.round();
    final hours = whole ~/ 60;
    // Minutes under the hour; past it, a clock's own form — "1:30", never
    // "90", which is a number of minutes nobody reads a day in.
    final figure = hours == 0
        ? '$whole'
        : '$hours:${(whole % 60).toString().padLeft(2, '0')}';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              figure,
              style: TideType.gauge(
                50,
                letterSpacing: -2.6,
                color: full ? TideColors.lantern : TideColors.bone,
              ),
            ),
            const SizedBox(width: 4),
            Text(hours == 0 ? 'min' : 'hr', style: TideType.labelMuted),
          ],
        ),
        const SizedBox(height: 2),
        Text('of ${Minutes.label(target)}', style: TideType.labelMuted),
      ],
    );
  }
}

class _DialPainter extends CustomPainter {
  const _DialPainter({
    required this.fraction,
    required this.logged,
    required this.ticks,
    required this.full,
    required this.grip,
  });

  /// 0..1 of the target, where the dial is drawn — continuous under a thumb.
  final double fraction;

  /// 0..1 of the target, what is already written for today.
  final double logged;

  /// Each mark's place round the ring, and whether it is a long one.
  final List<(double, bool)> ticks;

  final bool full;

  /// 0..1, how far the handle has grown under a thumb that holds it.
  final double grip;

  static const double _stroke = 16;
  static const double _knob = 12;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - _knob - 4;
    final ring = Rect.fromCircle(center: center, radius: radius);
    const top = -math.pi / 2;
    const turn = math.pi * 2;

    Paint band(Color color) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke
      ..color = color;

    // The well: recessed, like every track in the app.
    canvas.drawCircle(center, radius, band(TideColors.trench));

    final mark = Paint()..strokeCap = StrokeCap.round;
    for (final (at, major) in ticks) {
      final angle = top + turn * at;
      final direction = Offset(math.cos(angle), math.sin(angle));
      final outer = radius - _stroke / 2 - 6;
      final inner = outer - (major ? 9 : 4);
      mark
        ..strokeWidth = major ? 1.6 : 1
        ..color = TideColors.bone.withValues(alpha: major ? 0.30 : 0.14);
      canvas.drawLine(
        center + direction * inner,
        center + direction * outer,
        mark,
      );
    }

    // Already written and staying: solid, the way a logged day is.
    final kept = math.min(fraction, logged);
    if (kept > 0) {
      canvas.drawArc(ring, top, turn * kept, false, band(TideColors.lantern));
    }
    // About to be added: the same light, not yet at full strength.
    if (fraction > logged) {
      canvas.drawArc(
        ring,
        top + turn * logged,
        turn * (fraction - logged),
        false,
        band(TideColors.lantern.withValues(alpha: 0.4)),
      );
    }
    // About to be taken off: left as a ghost, so the loss is visible before
    // it is written rather than after.
    if (fraction < logged) {
      canvas.drawArc(
        ring,
        top + turn * fraction,
        turn * (logged - fraction),
        false,
        band(TideColors.bone.withValues(alpha: 0.12)),
      );
    }

    if (full) {
      canvas.drawCircle(
        center,
        radius + _stroke / 2 + 3,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = TideColors.lantern.withValues(alpha: 0.35),
      );
    }

    // The handle. It grows under a thumb that has it, so the thing being
    // moved is never hidden by the thing moving it.
    final angle = top + turn * fraction;
    final knob = center + Offset(math.cos(angle), math.sin(angle)) * radius;
    final knobRadius = _knob + 3 * grip;
    canvas
      ..drawCircle(knob, knobRadius, Paint()..color = TideColors.bone)
      ..drawCircle(
        knob,
        knobRadius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = TideColors.lantern,
      );
  }

  @override
  bool shouldRepaint(_DialPainter old) =>
      old.fraction != fraction ||
      old.logged != logged ||
      old.full != full ||
      old.grip != grip ||
      old.ticks.length != ticks.length;
}

/// What the dial's setting means for today, in words.
class _Status extends StatelessWidget {
  const _Status({required this.text, required this.lit});

  final String text;
  final bool lit;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: TideMotion.tabSwitch,
      curve: TideMotion.tabCurve,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: lit
            ? TideColors.lantern.withValues(alpha: 0.12)
            : TideColors.trench,
        borderRadius: TideElevation.radius12,
      ),
      child: Text(
        text,
        style: TideType.label.copyWith(
          color: lit ? TideColors.lantern : TideColors.silt,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

/// A quick amount. Moves the dial; writes nothing.
class _QuickChip extends StatelessWidget {
  const _QuickChip({
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      enabled: enabled,
      onTap: onTap,
      child: AnimatedOpacity(
        opacity: enabled ? 1 : 0.4,
        duration: TideMotion.tabSwitch,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: TideColors.trench,
            borderRadius: TideElevation.radius12,
            border: Border.all(color: TideColors.hairline),
          ),
          child: Text(
            label,
            style: TideType.label.copyWith(color: TideColors.bone),
          ),
        ),
      ),
    );
  }
}
