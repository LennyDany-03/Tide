import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../services/reminders/call_controller.dart';
import '../../services/reminders/reminder_plan.dart';
import '../../theme/tide_colors.dart';
import '../../theme/tide_gradients.dart';
import '../../theme/tide_motion.dart';
import '../../theme/tide_typography.dart';
import '../../widgets/press_scale.dart';
import '../../widgets/tide_tick.dart';
import 'widgets/call_chip.dart';
import 'widgets/call_clock.dart';
import 'widgets/dock_slider.dart';
import 'widgets/lighthouse_beam.dart';
import 'widgets/task_slip.dart';

/// "Lighthouse": a to-do's reminder, full screen, at its time.
///
/// A different picture from the Tide Call on purpose, so the two are told
/// apart before a word is read. A habit is a rhythm, and its call is water
/// rising; a to-do is one thing to bring in, and its call is a light finding
/// it. Night over a flat sea, a tower on the horizon, and a beam that sweeps
/// the sky every few seconds and catches the to-do's slip as it passes.
///
/// It is answered with the to-do's own gesture — carried to the right — as a
/// buoy slid along a channel to dock it. The beam swings onto the slip and
/// holds. A to-do with steps open will not dock, the rule the list keeps, so
/// the steps are tickable right here on the slip.
class LighthouseScreen extends StatefulWidget {
  const LighthouseScreen({
    super.key,
    required this.controller,
    required this.call,
  });

  final CallController controller;
  final PlannedReminder call;

  @override
  State<LighthouseScreen> createState() => _LighthouseScreenState();
}

enum _Answer { none, docked, snoozed, tomorrow, dismissed }

class _LighthouseScreenState extends State<LighthouseScreen>
    with TickerProviderStateMixin {
  /// Where the slip sits, for the beam to find it.
  static const Offset _slipAt = Offset(0.5, 0.46);

  final ValueNotifier<double> _time = ValueNotifier<double>(0);
  Ticker? _ticker;
  bool _still = false;

  late final AnimationController _entry = AnimationController(
    vsync: this,
    duration: TideMotion.callEntry,
  );
  late final AnimationController _lock = AnimationController(
    vsync: this,
    duration: TideMotion.beamLock,
  );
  late final AnimationController _dim = AnimationController(
    vsync: this,
    duration: TideMotion.callDrain,
  );

  /// The slip leaving: 0 in place, 1 gone — which way depends on the answer.
  late final AnimationController _leave = AnimationController(
    vsync: this,
    duration: TideMotion.callSurge,
  );
  late final AnimationController _farewell = AnimationController(
    vsync: this,
    duration: TideMotion.celebrateIn,
  );
  late final AnimationController _tick = AnimationController(
    vsync: this,
    duration: TideMotion.codeAccepted,
  );

  _Answer _answer = _Answer.none;
  String? _hint;
  Timer? _hintTimer;

  PlannedReminder get _call => widget.call;

  @override
  void initState() {
    super.initState();
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
  void dispose() {
    _hintTimer?.cancel();
    _ticker?.dispose();
    for (final controller in [_entry, _lock, _dim, _leave, _farewell, _tick]) {
      controller.dispose();
    }
    _time.dispose();
    super.dispose();
  }

  Duration _motion(Duration duration) => _still ? Duration.zero : duration;

  List<SlipStep> get _steps => SlipStep.parse(_call.details['steps']);

  int get _stepsLeft => _steps.where((s) => !s.done).length;

  void _flash(String hint) {
    _hintTimer?.cancel();
    setState(() => _hint = hint);
    _hintTimer = Timer(const Duration(milliseconds: 2400), () {
      if (mounted) setState(() => _hint = null);
    });
  }

  // --- Answers ----------------------------------------------------------------

  Future<void> _dock() async {
    if (_answer != _Answer.none) return;
    if (_stepsLeft > 0) {
      _blocked();
      return;
    }
    setState(() => _answer = _Answer.docked);
    unawaited(HapticFeedback.heavyImpact());
    unawaited(widget.controller.resolve(_call, CallOutcome.done));
    await _lock.animateTo(
      1,
      duration: _motion(TideMotion.beamLock),
      curve: TideMotion.beamLockCurve,
    );
    unawaited(_tick.animateTo(1, duration: _motion(TideMotion.codeAccepted)));
    await _finish();
  }

  void _blocked() {
    unawaited(HapticFeedback.lightImpact());
    _flash(
      _stepsLeft == 1
          ? 'One step left — tick it above to dock'
          : '$_stepsLeft steps left — tick them above to dock',
    );
  }

  Future<void> _snooze() async {
    if (_answer != _Answer.none) return;
    if (!widget.controller.canSnooze(_call)) {
      _flash('No snoozes left for this one');
      return;
    }
    setState(() => _answer = _Answer.snoozed);
    unawaited(HapticFeedback.mediumImpact());
    unawaited(widget.controller.resolve(_call, CallOutcome.snooze));
    await Future.wait([
      _dim.animateTo(1, duration: _motion(TideMotion.callDrain)),
      _leave.animateTo(
        1,
        duration: _motion(TideMotion.callDrain),
        curve: TideMotion.callDrainCurve,
      ),
    ]);
    await _finish();
  }

  Future<void> _tomorrow() async {
    if (_answer != _Answer.none) return;
    setState(() => _answer = _Answer.tomorrow);
    unawaited(HapticFeedback.mediumImpact());
    unawaited(widget.controller.resolve(_call, CallOutcome.tomorrow));
    await _leave.animateTo(
      1,
      duration: _motion(TideMotion.callSurge),
      curve: TideMotion.callDrainCurve,
    );
    await _finish();
  }

  Future<void> _dismiss() async {
    if (_answer != _Answer.none) return;
    setState(() => _answer = _Answer.dismissed);
    unawaited(widget.controller.resolve(_call, CallOutcome.dismiss));
    await _finish(hold: const Duration(milliseconds: 700));
  }

  Future<void> _finish({Duration hold = TideMotion.callFarewell}) async {
    if (!mounted) return;
    unawaited(_farewell.forward());
    await Future<void>.delayed(hold);
    if (mounted) widget.controller.retire(_call);
  }

  void _toggle(SlipStep step) {
    if (_answer != _Answer.none) return;
    unawaited(HapticFeedback.selectionClick());
    unawaited(widget.controller.toggleStep(_call, step.id, !step.done));
  }

  // --- Build ------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
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
                  gradient: TideGradients.lighthouseNight,
                ),
              ),
            ),
            Positioned.fill(
              child: LighthouseBeam(
                time: _time,
                lock: _lock,
                dim: _dim,
                target: _slipAt,
                still: _still,
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                ignoring: _answer != _Answer.none,
                child: SafeArea(child: _content()),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: FadeTransition(
                  opacity: _farewell,
                  child: SafeArea(child: _farewellCopy()),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _content() {
    return LayoutBuilder(
      builder: (context, box) {
        final compact = box.maxHeight < 700;
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
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 12),
                        _Signal(
                          time: _time,
                          still: _still,
                          test: _call.test,
                          onOpen: () => widget.controller.openApp(_call),
                        ),
                        SizedBox(height: compact ? 8 : 14),
                        AnimatedBuilder(
                          animation: _farewell,
                          builder: (context, child) => Opacity(
                            opacity: 1 - _farewell.value,
                            child: child,
                          ),
                          child: CallClock(
                            alignment: CrossAxisAlignment.start,
                            size: compact ? 48 : 60,
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _slip(box),
                          const SizedBox(height: 12),
                          AnimatedSwitcher(
                            duration: TideMotion.tabSwitch,
                            child: Text(
                              _hint ?? _call.copy['callBody'] ?? '',
                              key: ValueKey(_hint ?? 'body'),
                              textAlign: TextAlign.center,
                              style: _hint == null
                                  ? TideType.bodyMuted
                                  : TideType.label,
                            ),
                          ),
                        ],
                      ),
                    ),
                    AnimatedBuilder(
                      animation: _farewell,
                      builder: (context, child) =>
                          Opacity(opacity: 1 - _farewell.value, child: child),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          DockSlider(
                            label: 'Dock ${_call.title}',
                            stepsLeft: _stepsLeft,
                            enabled: _answer == _Answer.none,
                            onDocked: _dock,
                            onBlocked: _blocked,
                          ),
                          SizedBox(height: compact ? 10 : 14),
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              CallChip(
                                label: widget.controller.canSnooze(_call)
                                    ? 'Snooze ${_call.options.snoozeMinutes} min'
                                    : 'No snoozes left',
                                icon: Icons.snooze_rounded,
                                enabled: widget.controller.canSnooze(_call),
                                onTap: _snooze,
                              ),
                              CallChip(
                                label: 'Tomorrow',
                                icon: Icons.east_rounded,
                                onTap: _tomorrow,
                              ),
                            ],
                          ),
                          Center(child: CallDismiss(onTap: _dismiss)),
                          const SizedBox(height: 6),
                        ],
                      ),
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

  Widget _slip(BoxConstraints box) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: AnimatedBuilder(
          animation: Listenable.merge([_entry, _leave, _time, _lock]),
          builder: (context, child) {
            final rise =
                (1 - TideMotion.callEntryCurve.transform(_entry.value)) * 40;
            final leave = _leave.value;
            final offset = switch (_answer) {
              _Answer.snoozed => Offset(-box.maxWidth * leave, 0),
              _Answer.tomorrow => Offset(0, box.maxHeight * 0.45 * leave),
              _ => Offset.zero,
            };
            return Transform.translate(
              offset: Offset(offset.dx, offset.dy + rise),
              child: Opacity(
                opacity: (1 - leave).clamp(0.0, 1.0),
                child: TaskSlip(
                  title: _call.title,
                  note: '${_call.details['note'] ?? ''}',
                  due: '${_call.details['due'] ?? ''}',
                  repeats: _call.details['repeats'] == true,
                  steps: _steps,
                  onStep: _toggle,
                  glint: math.max(_glint(box), _lock.value),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// How squarely the beam is on the slip right now, 0..1.
  double _glint(BoxConstraints box) {
    if (_still) return 0.4;
    final angle = beamAngleAt(_time.value);
    if (angle == null) return 0;
    final aim = math.atan2(
      box.maxHeight * (_slipAt.dy - lighthouseLamp.dy),
      box.maxWidth * (_slipAt.dx - lighthouseLamp.dx),
    );
    return (1 - (angle - aim).abs() / 0.22).clamp(0.0, 1.0);
  }

  Widget _farewellCopy() {
    final text = switch (_answer) {
      _Answer.docked => _call.copy['done'] ?? 'Docked',
      _Answer.snoozed => _call.copy['snoozed'] ?? 'Snoozed',
      _Answer.tomorrow => _call.copy['tomorrow'] ?? 'Moved to tomorrow',
      _Answer.dismissed => 'Still on your list',
      _Answer.none => '',
    };
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (_answer == _Answer.docked) TideTickMark(progress: _tick, size: 64),
        const SizedBox(height: 14),
        Text(text, style: TideType.hero.copyWith(fontSize: 26)),
        const SizedBox(height: 120),
      ],
    );
  }
}

/// The top line: the lamp's signal blinking beside "To-do", a test badge
/// when it is one, and the way into the app.
class _Signal extends StatelessWidget {
  const _Signal({
    required this.time,
    required this.still,
    required this.test,
    required this.onOpen,
  });

  final ValueNotifier<double> time;
  final bool still;
  final bool test;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ValueListenableBuilder<double>(
          valueListenable: time,
          builder: (context, t, _) {
            final flare = still ? 0.6 : 0.3 + 0.7 * lampFlareAt(t);
            return Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: TideColors.lantern.withValues(alpha: flare),
              ),
            );
          },
        ),
        const SizedBox(width: 9),
        Text(
          'TO-DO',
          style: TideType.sectionHeader.copyWith(
            fontSize: 11.5,
            letterSpacing: 2.2,
          ),
        ),
        if (test) ...[
          const SizedBox(width: 10),
          const Flexible(child: CallTestBadge()),
          const SizedBox(width: 12),
        ] else
          const Spacer(),
        Semantics(
          button: true,
          label: 'Open Tide',
          child: ExcludeSemantics(
            child: PressScale(
              onTap: onOpen,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Open Tide', style: TideType.labelMuted),
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
