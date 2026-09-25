import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../services/haptics.dart';
import '../../services/reminders/call_controller.dart';
import '../../services/reminders/reminder_plan.dart';
import '../../theme/tide_colors.dart';
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
/// it. Stars over a still sea, a lighthouse on a headland at the horizon,
/// and a beam that sweeps the sky every few seconds and crosses the to-do's
/// card as it passes.
///
/// The scene is composed round the laid-out screen rather than fixed to it:
/// each frame measures where the card and the controls are, so the horizon
/// sits just above the controls, the tower is as tall as the gap under the
/// card allows, and the beam finds the card wherever its title and steps
/// have put it.
///
/// It is answered with the to-do's own gesture — carried to the right — by
/// sliding the lit knob along the channel to the dock. The beam swings onto
/// the card and holds. A to-do with steps open will not dock, the rule the
/// list keeps, so the steps are tickable right here on the card.
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
  final ValueNotifier<double> _time = ValueNotifier<double>(0);
  final ValueNotifier<LighthouseStage?> _stage =
      ValueNotifier<LighthouseStage?>(null);
  Ticker? _ticker;
  bool _still = false;

  final GlobalKey _stageKey = GlobalKey();
  final GlobalKey _slipKey = GlobalKey();
  final GlobalKey _controlsKey = GlobalKey();

  late final AnimationController _entry = AnimationController(
    vsync: this,
    duration: TideMotion.callEntry,
  );
  late final Animation<double> _nightIn = CurvedAnimation(
    parent: _entry,
    curve: TideMotion.callEntryCurve,
  );
  late final Animation<double> _clockIn = CurvedAnimation(
    parent: _entry,
    curve: TideMotion.lighthouseClockIn,
  );
  late final Animation<double> _slipIn = CurvedAnimation(
    parent: _entry,
    curve: TideMotion.lighthouseSlipIn,
  );
  late final Animation<double> _controlsIn = CurvedAnimation(
    parent: _entry,
    curve: TideMotion.lighthouseControlsIn,
  );

  late final AnimationController _lock = AnimationController(
    vsync: this,
    duration: TideMotion.beamLock,
  );
  late final AnimationController _dim = AnimationController(
    vsync: this,
    duration: TideMotion.callDrain,
  );

  /// The card leaving: 0 in place, 1 gone — which way depends on the answer.
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
        _measure();
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
    _stage.dispose();
    super.dispose();
  }

  /// Where the card and the controls were laid out last frame, for the
  /// scene to compose round. Measured outside their entrance and exit
  /// transforms, so the beam aims at where the card rests, not where it is
  /// sliding in from.
  void _measure() {
    final stage = _stageKey.currentContext?.findRenderObject();
    final slip = _slipKey.currentContext?.findRenderObject();
    final controls = _controlsKey.currentContext?.findRenderObject();
    if (stage is! RenderBox || slip is! RenderBox || controls is! RenderBox) {
      return;
    }
    if (!stage.hasSize || !slip.hasSize || !controls.hasSize) return;
    if (!stage.attached || !slip.attached || !controls.attached) return;
    final next = LighthouseStage(
      size: stage.size,
      slip: MatrixUtils.transformRect(
        slip.getTransformTo(stage),
        Offset.zero & slip.size,
      ),
      shore: controls.localToGlobal(Offset.zero, ancestor: stage).dy,
    );
    if (next != _stage.value) _stage.value = next;
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
    unawaited(TideHaptics.heavyImpact());
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
    unawaited(TideHaptics.lightImpact());
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
    unawaited(TideHaptics.mediumImpact());
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
    unawaited(TideHaptics.mediumImpact());
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
    unawaited(TideHaptics.selectionClick());
    unawaited(widget.controller.toggleStep(_call, step.id, !step.done));
  }

  // --- Build ------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    // Reduced motion has no ticker to measure on, and the first frame
    // should not wait for one either.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) _measure();
    });
    return ColoredBox(
      color: TideColors.trench,
      child: FadeTransition(
        opacity: _nightIn,
        child: Stack(
          key: _stageKey,
          children: [
            Positioned.fill(
              child: LighthouseBeam(
                time: _time,
                lock: _lock,
                dim: _dim,
                stage: _stage,
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
        // Three groups spread down the screen. When large text will not fit,
        // the whole face is scaled down rather than scrolled, the same as
        // the Tide Call.
        return FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: box.maxWidth,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: box.maxHeight),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 10),
                        _TopBar(
                          time: _time,
                          still: _still,
                          onOpen: () => widget.controller.openApp(_call),
                        ),
                        SizedBox(height: compact ? 14 : 30),
                        _arrive(
                          _clockIn,
                          rise: -12,
                          child: Column(
                            children: [
                              CallClock(size: compact ? 60 : 76),
                              if (_call.test) ...[
                                const SizedBox(height: 14),
                                const CallTestBadge(),
                              ],
                            ],
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
                          const SizedBox(height: 10),
                          SizedBox(
                            height: 34,
                            child: Center(
                              child: AnimatedSwitcher(
                                duration: TideMotion.tabSwitch,
                                child: _hint == null
                                    ? const SizedBox.shrink()
                                    : _Hint(key: ValueKey(_hint), text: _hint!),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    KeyedSubtree(
                      key: _controlsKey,
                      child: _arrive(
                        _controlsIn,
                        rise: 24,
                        child: _controls(compact),
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

  /// [child] coming up with its share of the entrance, and going with the
  /// farewell.
  Widget _arrive(
    Animation<double> entrance, {
    required double rise,
    required Widget child,
  }) {
    return AnimatedBuilder(
      animation: Listenable.merge([entrance, _farewell]),
      builder: (context, child) => Opacity(
        opacity: (entrance.value * (1 - _farewell.value)).clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, (1 - entrance.value) * rise),
          child: child,
        ),
      ),
      child: child,
    );
  }

  Widget _controls(bool compact) {
    final canSnooze = widget.controller.canSnooze(_call);
    return Column(
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
        Row(
          children: [
            Expanded(
              child: _Choice(
                label: canSnooze
                    ? 'Snooze ${_call.options.snoozeMinutes} min'
                    : 'No snoozes left',
                icon: Icons.snooze_rounded,
                enabled: canSnooze,
                onTap: _snooze,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _Choice(
                label: 'Tomorrow',
                icon: Icons.wb_twilight_rounded,
                onTap: _tomorrow,
              ),
            ),
          ],
        ),
        SizedBox(height: compact ? 0 : 4),
        Center(child: CallDismiss(onTap: _dismiss)),
        const SizedBox(height: 4),
      ],
    );
  }

  Widget _slip(BoxConstraints box) {
    return Center(
      child: ConstrainedBox(
        key: _slipKey,
        constraints: const BoxConstraints(maxWidth: 440),
        child: SizedBox(
          width: double.infinity,
          child: AnimatedBuilder(
            animation: Listenable.merge([
              _slipIn,
              _leave,
              _time,
              _lock,
              _dim,
              _stage,
            ]),
            builder: (context, child) {
              final rise = (1 - _slipIn.value) * 36;
              final leave = _leave.value;
              final offset = switch (_answer) {
                _Answer.snoozed => Offset(-box.maxWidth * leave, 0),
                _Answer.tomorrow => Offset(0, box.maxHeight * 0.45 * leave),
                _ => Offset.zero,
              };
              final (glint, sheen) = _light();
              return Transform.translate(
                offset: Offset(offset.dx, offset.dy + rise),
                child: Opacity(
                  opacity: (_slipIn.value * (1 - leave)).clamp(0.0, 1.0),
                  child: TaskSlip(
                    title: _call.title,
                    note: '${_call.details['note'] ?? ''}',
                    due: '${_call.details['due'] ?? ''}',
                    repeats: _call.details['repeats'] == true,
                    steps: _steps,
                    onStep: _toggle,
                    glint: glint,
                    sheen: sheen,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  /// How squarely the beam is on the card right now, 0..1, and where across
  /// it the light falls. Rises as the beam reaches the card's first corner,
  /// is full across its middle and falls away as it leaves the last; once
  /// docked it holds, full, across the middle.
  (double, double) _light() {
    final stage = _stage.value;
    final locked = _lock.value;
    if (stage == null) return (locked, 0.5);
    if (_still) return (math.max(0.35, locked), 0.5);
    final angle = beamAngleAt(_time.value);
    var glint = 0.0;
    var sheen = 0.5;
    if (angle != null) {
      final at = LighthouseGeometry.of(stage.size, stage).crossing(angle);
      glint = math.sin(((at + 0.2) / 1.4).clamp(0.0, 1.0) * math.pi);
      sheen = at;
    }
    glint *= 1 - _dim.value;
    return (glint + (1 - glint) * locked, sheen + (0.5 - sheen) * locked);
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
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TideType.hero.copyWith(fontSize: 26),
          ),
        ),
        const SizedBox(height: 110),
      ],
    );
  }
}

/// The top line: what kind of call this is, its signal blinking with the
/// lamp, and the way into the app.
class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.time,
    required this.still,
    required this.onOpen,
  });

  final ValueNotifier<double> time;
  final bool still;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(10, 6, 12, 6),
          decoration: BoxDecoration(
            color: TideColors.shelf.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: TideColors.hairline),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ValueListenableBuilder<double>(
                valueListenable: time,
                builder: (context, t, _) {
                  final flare = still ? 0.8 : 0.35 + 0.65 * lampFlareAt(t);
                  return Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: TideColors.lantern.withValues(alpha: flare),
                    ),
                  );
                },
              ),
              const SizedBox(width: 8),
              Text('To-do', style: TideType.label.copyWith(fontSize: 13)),
            ],
          ),
        ),
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

/// A word for a moment under the card — why it will not dock, why it will
/// not snooze — in a pill, so it reads over the night whatever is behind it.
class _Hint extends StatelessWidget {
  const _Hint({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: TideColors.shoal,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: TideColors.hairline),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TideType.label.copyWith(fontSize: 13),
      ),
    );
  }
}

/// One of the two other answers under the slider, side by side and the
/// same size, so neither reads as the one the call would rather you chose.
class _Choice extends StatelessWidget {
  const _Choice({
    required this.label,
    required this.icon,
    required this.onTap,
    this.enabled = true,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final ink = enabled
        ? TideColors.bone
        : TideColors.silt.withValues(alpha: 0.5);
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: ExcludeSemantics(
        child: PressScale(
          enabled: enabled,
          onTap: onTap,
          child: Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: TideColors.shelf.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: TideColors.hairline),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 18, color: ink),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TideType.label.copyWith(color: ink),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
