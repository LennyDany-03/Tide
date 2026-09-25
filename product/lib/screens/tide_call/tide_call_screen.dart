import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/semantics.dart';

import '../../services/habits/habit_rows.dart';
import '../../services/haptics.dart';
import '../../services/models/tide_glyph.dart';
import '../../services/reminders/call_controller.dart';
import '../../services/reminders/reminder_plan.dart';
import '../../theme/tide_colors.dart';
import '../../theme/tide_gradients.dart';
import '../../theme/tide_motion.dart';
import '../../theme/tide_typography.dart';
import '../../widgets/gauge_number.dart';
import '../../widgets/habit_glyph.dart';
import '../../widgets/hold_to_fill.dart';
import '../../widgets/press_scale.dart';
import '../../widgets/ripple_burst.dart';
import 'widgets/call_chip.dart';
import 'widgets/call_clock.dart';
import 'widgets/call_water.dart';
import 'widgets/habit_orb.dart';
import 'widgets/wave_marks.dart';

/// "Tide Call": a habit's reminder, full screen, at its time.
///
/// **The whole screen is the gesture.** The same hand the app already
/// taught: swipe up and the water rises under the finger — let go high
/// enough and the habit is ridden in, the water surges to the top, a ripple
/// runs out from the orb and the streak counts up. Swipe the orb away to the
/// left to snooze it, and the water drains out; hold the orb to spend a
/// freeze on the day. Every one of those has a chip under it, and a screen
/// reader gets them as actions, because a gesture is not an accessible
/// control.
///
/// **Several habits at the same minute ring as one call.** Their orbs sit in
/// a row under the clock; the one in the middle is the one answering, a tap
/// on another brings it forward, and "Done all" rides the lot in at once.
///
/// **Nothing is decided here.** An answer goes to the [controller] the moment
/// it is given — the ringing stops as the water reaches the top — and the
/// screen plays its farewell before retiring the call.
class TideCallScreen extends StatefulWidget {
  const TideCallScreen({
    super.key,
    required this.controller,
    required this.calls,
  });

  final CallController controller;

  /// The habit calls still on screen, in the order they rang.
  final List<PlannedReminder> calls;

  @override
  State<TideCallScreen> createState() => _TideCallScreenState();
}

enum _Answer { none, done, doneAll, snoozed, skipped, dismissed }

class _TideCallScreenState extends State<TideCallScreen>
    with TickerProviderStateMixin {
  /// Where the water rests while the call rings: the lower two fifths.
  static const double _rest = 0.4;

  final ValueNotifier<double> _time = ValueNotifier<double>(0);
  final ValueNotifier<double> _level = ValueNotifier<double>(0);
  Ticker? _ticker;

  late final AnimationController _entry = AnimationController(
    vsync: this,
    duration: TideMotion.callEntry,
  );

  /// The water above or below its resting level: the finger's pull, the
  /// surge, the drain.
  late final AnimationController _water = AnimationController.unbounded(
    vsync: this,
  );

  /// The orb's sideways travel, in pixels. Negative is toward a snooze.
  late final AnimationController _slide = AnimationController.unbounded(
    vsync: this,
  );

  late final AnimationController _farewell = AnimationController(
    vsync: this,
    duration: TideMotion.celebrateIn,
  );

  String? _currentKey;
  _Answer _answer = _Answer.none;
  int _ripple = 0;
  bool _still = false;
  double _rideOrigin = 0;
  int _answeredCount = 0;

  String? _hint;
  Timer? _hintTimer;

  PlannedReminder get _call => widget.calls.firstWhere(
    (c) => c.key == _currentKey,
    orElse: () => widget.calls.first,
  );

  @override
  void initState() {
    super.initState();
    _currentKey = widget.calls.first.key;
    _entry.addListener(_syncLevel);
    _water.addListener(_syncLevel);
    _entry.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _still = MediaQuery.disableAnimationsOf(context);
    if (_still) {
      _ticker?.stop();
      _entry.value = 1;
    } else {
      _ticker ??= createTicker((elapsed) {
        _time.value = elapsed.inMicroseconds / 1e6;
      });
      if (!_ticker!.isActive) _ticker!.start();
    }
  }

  @override
  void didUpdateWidget(TideCallScreen old) {
    super.didUpdateWidget(old);
    if (widget.calls.isEmpty) return;
    if (widget.calls.any((c) => c.key == _currentKey)) return;
    // The call on screen has been retired and another is still ringing: it
    // comes up the way the first one did.
    _currentKey = widget.calls.first.key;
    _answer = _Answer.none;
    _water.value = 0;
    _slide.value = 0;
    _farewell.value = 0;
    if (_still) {
      _entry.value = 1;
    } else {
      _entry.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    _ticker?.dispose();
    _entry.dispose();
    _water.dispose();
    _slide.dispose();
    _farewell.dispose();
    _time.dispose();
    _level.dispose();
    super.dispose();
  }

  void _syncLevel() {
    _level.value =
        _rest * TideMotion.callEntryCurve.transform(_entry.value) +
        _water.value;
  }

  Duration _motion(Duration duration) => _still ? Duration.zero : duration;

  void _flash(String hint) {
    _hintTimer?.cancel();
    setState(() => _hint = hint);
    _hintTimer = Timer(const Duration(milliseconds: 2200), () {
      if (mounted) setState(() => _hint = null);
    });
  }

  int get _freezes => (_call.details['freezes'] as num?)?.toInt() ?? 0;

  // --- Answers ----------------------------------------------------------------

  Future<void> _done() async {
    if (_answer != _Answer.none) return;
    final call = _call;
    setState(() => _answer = _Answer.done);
    unawaited(TideHaptics.heavyImpact());
    unawaited(widget.controller.resolve(call, CallOutcome.done));
    await _water.animateTo(
      1.12 - _rest,
      duration: _motion(TideMotion.callSurge),
      curve: TideMotion.callSurgeCurve,
    );
    await _farewellThen(() => widget.controller.retire(call), ripple: true);
  }

  Future<void> _doneAll() async {
    if (_answer != _Answer.none) return;
    final calls = List.of(widget.calls);
    setState(() {
      _answer = _Answer.doneAll;
      _answeredCount = calls.length;
    });
    unawaited(TideHaptics.heavyImpact());
    for (final call in calls) {
      unawaited(widget.controller.resolve(call, CallOutcome.done));
    }
    await _water.animateTo(
      1.12 - _rest,
      duration: _motion(TideMotion.callSurge),
      curve: TideMotion.callSurgeCurve,
    );
    await _farewellThen(() {
      for (final call in calls) {
        widget.controller.retire(call);
      }
    }, ripple: true);
  }

  Future<void> _snooze() async {
    if (_answer != _Answer.none) return;
    final call = _call;
    if (!widget.controller.canSnooze(call)) {
      _flash('No snoozes left for this one');
      await _springBack();
      return;
    }
    setState(() => _answer = _Answer.snoozed);
    unawaited(TideHaptics.mediumImpact());
    unawaited(widget.controller.resolve(call, CallOutcome.snooze));
    final width = MediaQuery.sizeOf(context).width;
    await Future.wait([
      _water.animateTo(
        -_rest,
        duration: _motion(TideMotion.callDrain),
        curve: TideMotion.callDrainCurve,
      ),
      _slide.animateTo(
        -width,
        duration: _motion(TideMotion.callDrain),
        curve: TideMotion.callDrainCurve,
      ),
    ]);
    await _farewellThen(() => widget.controller.retire(call));
  }

  Future<void> _skip() async {
    if (_answer != _Answer.none) return;
    if (_freezes <= 0) {
      _flash('No freezes left for this habit');
      return;
    }
    final call = _call;
    setState(() => _answer = _Answer.skipped);
    unawaited(widget.controller.resolve(call, CallOutcome.skip));
    await _farewellThen(() => widget.controller.retire(call), ripple: true);
  }

  Future<void> _dismiss() async {
    if (_answer != _Answer.none) return;
    final call = _call;
    setState(() => _answer = _Answer.dismissed);
    unawaited(widget.controller.resolve(call, CallOutcome.dismiss));
    await _farewellThen(
      () => widget.controller.retire(call),
      hold: const Duration(milliseconds: 700),
    );
  }

  Future<void> _farewellThen(
    VoidCallback retire, {
    bool ripple = false,
    Duration hold = TideMotion.callFarewell,
  }) async {
    if (!mounted) return;
    if (ripple) setState(() => _ripple++);
    unawaited(_farewell.forward());
    await Future<void>.delayed(hold);
    if (mounted) retire();
  }

  Future<void> _springBack() => _slide.animateTo(
    0,
    duration: _motion(TideMotion.swipeCancel),
    curve: TideMotion.swipeCancelCurve,
  );

  // --- Gestures ---------------------------------------------------------------

  void _rideStart(DragStartDetails details) {
    if (_answer != _Answer.none) return;
    _water.stop();
    _rideOrigin = details.globalPosition.dy + _water.value * _rideSpan;
  }

  double get _rideSpan => MediaQuery.sizeOf(context).height * 0.5;

  void _rideUpdate(DragUpdateDetails details) {
    if (_answer != _Answer.none) return;
    final travel = _rideOrigin - details.globalPosition.dy;
    final fraction = (travel / _rideSpan).clamp(0.0, 1.0);
    _water.value = (1 - _rest) * fraction;
  }

  void _rideEnd(DragEndDetails details) {
    if (_answer != _Answer.none) return;
    final fraction = _water.value / (1 - _rest);
    final flung = (details.primaryVelocity ?? 0) < -900 && fraction > 0.2;
    if (fraction >= TideMotion.rideThreshold || flung) {
      unawaited(_done());
      return;
    }
    _water.animateTo(
      0,
      duration: _motion(TideMotion.swipeCancel),
      curve: TideMotion.swipeCancelCurve,
    );
  }

  void _slideUpdate(DragUpdateDetails details) {
    if (_answer != _Answer.none) return;
    _slide.value = math.min(0, _slide.value + details.delta.dx);
  }

  void _slideEnd(DragEndDetails details) {
    if (_answer != _Answer.none) return;
    final width = MediaQuery.sizeOf(context).width;
    if (_slide.value < -width * 0.26 || (details.primaryVelocity ?? 0) < -800) {
      unawaited(_snooze());
    } else {
      unawaited(_springBack());
    }
  }

  // --- Build ------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final call = _call;
    final answering = _answer != _Answer.none;

    return RippleBurst(
      trigger: _ripple,
      color: _answer == _Answer.skipped ? TideColors.frost : TideColors.lantern,
      accent: _answer == _Answer.skipped
          ? TideColors.frost
          : TideColors.palette.flare,
      particles: _answer != _Answer.skipped,
      intensity: 2.2,
      clip: false,
      origin: const Alignment(0, -0.08),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragStart: _rideStart,
        onVerticalDragUpdate: _rideUpdate,
        onVerticalDragEnd: _rideEnd,
        child: ColoredBox(
          color: TideColors.trench,
          child: FadeTransition(
            opacity: CurvedAnimation(
              parent: _entry,
              curve: TideMotion.callEntryCurve,
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: TideGradients.callDepth,
                    ),
                  ),
                ),
                Positioned.fill(
                  child: CallWater(level: _level, time: _time, still: _still),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    ignoring: answering,
                    child: AnimatedBuilder(
                      animation: _farewell,
                      builder: (context, child) =>
                          Opacity(opacity: 1 - _farewell.value, child: child),
                      child: SafeArea(child: _content(call)),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: FadeTransition(
                      opacity: _farewell,
                      child: SafeArea(
                        child: Center(child: _farewellCopy(call)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _content(PlannedReminder call) {
    return LayoutBuilder(
      builder: (context, box) {
        final compact = box.maxHeight < 720;
        final orb = math
            .min(box.maxWidth * 0.5, box.maxHeight * 0.25)
            .clamp(120.0, 210.0);
        final day =
            HabitRows.parseDay(call.details['day']) ??
            DateUtils.dateOnly(call.dueAt);

        // Three groups spread down the screen. When large text will not fit,
        // the whole face is scaled down rather than scrolled: a scroll view
        // would take the upward swipe for itself, and the swipe is the call.
        // `spaceBetween` inside a minimum height rather than spacers inside
        // an intrinsic height, which cannot measure a layout builder.
        return FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: box.maxWidth,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: box.maxHeight),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      children: [
                        const SizedBox(height: 12),
                        _TopBar(
                          test: call.test,
                          onOpen: () => widget.controller.openApp(call),
                        ),
                        SizedBox(height: compact ? 8 : 16),
                        CallClock(size: compact ? 58 : 76),
                        if (widget.calls.length > 1) ...[
                          const SizedBox(height: 18),
                          _OrbStack(
                            calls: widget.calls,
                            current: call.key,
                            onSelect: (key) =>
                                setState(() => _currentKey = key),
                            onDoneAll: _doneAll,
                          ),
                        ],
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Column(
                        children: [
                          _orb(call, orb),
                          SizedBox(height: compact ? 16 : 26),
                          Text(
                            call.title,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TideType.hero.copyWith(fontSize: 30),
                          ),
                          const SizedBox(height: 8),
                          AnimatedSwitcher(
                            duration: TideMotion.tabSwitch,
                            child: Text(
                              _hint ?? call.copy['subtitle'] ?? '',
                              key: ValueKey(_hint ?? 'subtitle'),
                              textAlign: TextAlign.center,
                              style: TideType.bodyMuted.copyWith(
                                color: _hint == null ? null : TideColors.bone,
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          WaveMarks(
                            marks: WaveMarks.parse(call.details['week']),
                            lastDay: day,
                          ),
                        ],
                      ),
                    ),
                    Column(
                      children: [
                        _RideHint(level: _level, rest: _rest, still: _still),
                        SizedBox(height: compact ? 10 : 16),
                        _chips(call),
                        CallDismiss(onTap: _dismiss),
                        const SizedBox(height: 6),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _orb(PlannedReminder call, double size) {
    final glyph =
        TideGlyph.values.asNameMap()[call.details['glyph']] ?? TideGlyph.dot;
    final canSnooze = widget.controller.canSnooze(call);
    final snooze = call.options.snoozeMinutes;

    return Semantics(
      container: true,
      button: true,
      label: '${call.title} reminder. Double-tap to mark done.',
      onTap: _done,
      customSemanticsActions: {
        if (canSnooze)
          CustomSemanticsAction(label: 'Snooze $snooze minutes'): _snooze,
        if (_freezes > 0)
          const CustomSemanticsAction(label: 'Skip today'): _skip,
        const CustomSemanticsAction(label: 'Dismiss'): _dismiss,
      },
      child: ExcludeSemantics(
        child: GestureDetector(
          onHorizontalDragUpdate: _slideUpdate,
          onHorizontalDragEnd: _slideEnd,
          child: HoldToFill(
            enabled: _answer == _Answer.none && _freezes > 0,
            onCommit: (_) => _skip(),
            onTap: () => _flash(
              _freezes > 0
                  ? 'Swipe up to ride it in · hold to skip today'
                  : 'Swipe up to ride it in',
            ),
            builder: (context, hold, _) => AnimatedBuilder(
              animation: Listenable.merge([_slide, _time]),
              builder: (context, child) {
                final period = TideMotion.callBob.inMilliseconds / 1000;
                final bob = _still
                    ? 0.0
                    : math.sin(_time.value * 2 * math.pi / period) * 4;
                final away = (-_slide.value / (size * 1.2)).clamp(0.0, 1.0);
                return Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    // "Snooze" surfacing behind the orb as it is pushed away.
                    Opacity(
                      opacity:
                          (away * 2.4).clamp(0.0, 1.0) *
                          (_answer == _Answer.none ? 1 : 0),
                      child: Text(
                        canSnooze ? 'Snooze · $snooze min' : 'No snoozes left',
                        style: TideType.label.copyWith(color: TideColors.silt),
                      ),
                    ),
                    Transform.translate(
                      offset: Offset(_slide.value, bob),
                      child: Opacity(opacity: 1 - away * 0.85, child: child),
                    ),
                  ],
                );
              },
              child: HabitOrb(
                glyph: glyph,
                size: size,
                time: _time,
                hold: hold,
                still: _still,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _chips(PlannedReminder call) {
    final canSnooze = widget.controller.canSnooze(call);
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 10,
      runSpacing: 10,
      children: [
        CallChip(
          label: canSnooze
              ? 'Snooze ${call.options.snoozeMinutes} min'
              : 'No snoozes left',
          icon: Icons.snooze_rounded,
          enabled: canSnooze,
          onTap: _snooze,
        ),
        CallChip(
          label: 'Done',
          icon: Icons.check_rounded,
          accent: true,
          onTap: _done,
        ),
        CallChip(
          label: _freezes > 0 ? 'Skip today' : 'No freezes left',
          icon: Icons.ac_unit_rounded,
          enabled: _freezes > 0,
          onTap: _skip,
        ),
      ],
    );
  }

  Widget _farewellCopy(PlannedReminder call) {
    final streak = ((call.details['streak'] as num?)?.toInt() ?? 0) + 1;
    return switch (_answer) {
      _Answer.done => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GaugeCountUp(
            value: streak,
            style: TideType.gaugeHero(
              color: TideColors.bone,
            ).copyWith(fontSize: 88),
          ),
          const SizedBox(height: 10),
          Text(
            streak == 1 ? 'day streak' : 'day streak · ${call.title}',
            style: TideType.heading,
          ),
          const SizedBox(height: 6),
          Text(call.copy['done'] ?? '', style: TideType.bodyMuted),
        ],
      ),
      _Answer.doneAll => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'All $_answeredCount in',
            style: TideType.hero.copyWith(fontSize: 34),
          ),
          const SizedBox(height: 8),
          Text('The tide is full', style: TideType.bodyMuted),
        ],
      ),
      _Answer.snoozed => _Line(call.copy['snoozed'] ?? 'Snoozed'),
      _Answer.skipped => _Line(
        call.copy['skipped'] ?? 'Frozen for today',
        color: TideColors.frost,
      ),
      _Answer.dismissed => const _Line('Still open for today'),
      _Answer.none => const SizedBox.shrink(),
    };
  }
}

class _Line extends StatelessWidget {
  const _Line(this.text, {this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TideType.hero.copyWith(fontSize: 26, color: color),
      ),
    );
  }
}

/// The test badge, when there is one, and the way into the app.
class _TopBar extends StatelessWidget {
  const _TopBar({required this.test, required this.onOpen});

  final bool test;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (test) const Flexible(child: CallTestBadge()) else const Spacer(),
        if (test) const SizedBox(width: 12),
        Semantics(
          button: true,
          label: 'Open Tide',
          child: ExcludeSemantics(
            child: PressScale(
              onTap: onOpen,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Open Tide', maxLines: 1, style: TideType.labelMuted),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.north_east_rounded,
                      size: 14,
                      color: TideColors.silt,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Several habits at the same minute: their orbs in a row, the one being
/// answered ringed, and "Done all".
class _OrbStack extends StatelessWidget {
  const _OrbStack({
    required this.calls,
    required this.current,
    required this.onSelect,
    required this.onDoneAll,
  });

  final List<PlannedReminder> calls;
  final String current;
  final ValueChanged<String> onSelect;
  final VoidCallback onDoneAll;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final call in calls.take(5))
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Semantics(
              button: true,
              selected: call.key == current,
              label: call.title,
              child: ExcludeSemantics(
                child: PressScale(
                  onTap: () => onSelect(call.key),
                  child: AnimatedContainer(
                    duration: TideMotion.tabSwitch,
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: TideColors.shelf,
                      border: Border.all(
                        width: call.key == current ? 2 : 1,
                        color: call.key == current
                            ? TideColors.lantern
                            : TideColors.hairline,
                      ),
                    ),
                    child: HabitGlyph(
                      glyph:
                          TideGlyph.values.asNameMap()[call.details['glyph']] ??
                          TideGlyph.dot,
                      size: 17,
                    ),
                  ),
                ),
              ),
            ),
          ),
        const SizedBox(width: 10),
        CallChip(
          label: 'Done all',
          icon: Icons.done_all_rounded,
          accent: true,
          onTap: onDoneAll,
        ),
      ],
    );
  }
}

/// "Swipe up to ride the wave", and what the water is doing under the
/// finger once a swipe has started.
class _RideHint extends StatelessWidget {
  const _RideHint({
    required this.level,
    required this.rest,
    required this.still,
  });

  final ValueNotifier<double> level;
  final double rest;
  final bool still;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: level,
      builder: (context, value, _) {
        final fraction = ((value - rest) / (1 - rest)).clamp(0.0, 1.0);
        final text = fraction >= TideMotion.rideThreshold
            ? 'Let go to ride it in'
            : fraction > 0.08
            ? 'Keep going…'
            : 'Swipe up to ride the wave';
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Transform.translate(
              offset: Offset(0, still ? 0 : -8 * fraction),
              child: Icon(
                Icons.keyboard_double_arrow_up_rounded,
                size: 22,
                color: TideColors.lantern.withValues(
                  alpha: 0.55 + 0.45 * fraction,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              text,
              style: TideType.label.copyWith(
                color: fraction >= TideMotion.rideThreshold
                    ? TideColors.lantern
                    : TideColors.bone,
              ),
            ),
          ],
        );
      },
    );
  }
}
