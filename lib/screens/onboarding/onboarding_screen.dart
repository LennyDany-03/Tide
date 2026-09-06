import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../config/app_routes.dart';
import '../../config/habit_templates.dart';
import '../../services/models/habit.dart';
import '../../services/models/tide_glyph.dart';
import '../../services/tide_scope.dart';
import '../../theme/tide_colors.dart';
import '../../theme/tide_motion.dart';
import '../../theme/tide_typography.dart';
import '../../widgets/tide_backdrop.dart';
import '../../widgets/press_scale.dart';
import '../../widgets/tide_button.dart';
import 'widgets/notification_step.dart';
import 'widgets/ready_step.dart';
import 'widgets/rhythm_step.dart';
import 'widgets/template_grid.dart';
import 'widgets/tide_line_gauge.dart';
import 'widgets/welcome_step.dart';

/// First run.
///
/// The only screen whose job is conversion, so everything on it is in
/// service of getting to a populated Home fast: templates instead of a
/// blank form, smart defaults instead of a settings pass, and a skip that
/// stays visible and equally weighted the whole way through. A skip that
/// hides is a dark pattern, and it would also be a lie about how much this
/// flow matters.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  static const int _stepCount = 5;

  final PageController _pages = PageController();

  /// Drives the closing morph into Home.
  late final AnimationController _morph = AnimationController(
    vsync: this,
    duration: TideMotion.morph,
  );

  int _step = 0;
  Set<int> _selected = {};
  final Map<int, Set<int>> _days = {};
  final Map<int, TimeOfDay> _times = {};

  List<HabitTemplate> get _chosen => [
    for (final index in _selected) HabitTemplate.all[index],
  ];

  bool get _canContinue => switch (_step) {
    1 => _selected.isNotEmpty,
    _ => true,
  };

  String get _primaryLabel => switch (_step) {
    0 => 'Get started',
    1 => 'Continue',
    2 => 'Looks right',
    3 => 'Allow reminders',
    _ => 'Open Tide',
  };

  @override
  void dispose() {
    _pages.dispose();
    _morph.dispose();
    super.dispose();
  }

  void _next() {
    if (_step == _stepCount - 1) {
      _finish();
      return;
    }
    setState(() => _step++);
    _pages.animateToPage(
      _step,
      duration: TideMotion.sheetIn,
      curve: TideMotion.sheetCurve,
    );
  }

  /// Turns the chosen templates into real habits with today as day zero.
  List<Habit> _buildHabits() {
    final store = TideScope.read(context);
    final now = DateTime.now();
    final selected = _selected.toList()..sort();

    return [
      for (final index in selected)
        Habit(
          id: store.newHabitId() + index.toString(),
          name: HabitTemplate.all[index].name,
          glyph: HabitTemplate.all[index].glyph,
          type: HabitTemplate.all[index].type,
          target: HabitTemplate.all[index].target,
          unit: HabitTemplate.all[index].unit,
          days: _days[index] ?? HabitTemplate.all[index].days,
          reminderEnabled: true,
          reminderTime: _times[index] ?? HabitTemplate.all[index].reminderTime,
          createdAt: now,
        ),
    ];
  }

  Future<void> _finish() async {
    final store = TideScope.read(context);

    // The morph starts first so the ring is already travelling when the
    // route changes, but the route change does *not* wait for it to land.
    // Awaiting the whole sweep left a real gap: onboarding finished fading
    // to nothing and then held an empty page until the navigation ran, and
    // that dead frame is what read as the animation breaking. Handing over
    // partway through means Home is arriving while the ring is still on its
    // way out, which is the overlap the morph was for.
    _morph.forward();
    await Future<void>.delayed(_handOff);
    if (!mounted) return;

    store.completeOnboarding(_buildHabits());
    context.go(Routes.today);
  }

  /// How far into the morph Home takes over. Late enough that the ring has
  /// visibly moved, early enough that nothing is ever fully gone first.
  static const Duration _handOff = Duration(milliseconds: 300);

  void _skip() {
    TideScope.read(context).skipOnboarding();
    context.go(Routes.today);
  }

  @override
  Widget build(BuildContext context) {
    final firstChosen = _chosen.isEmpty ? null : _chosen.first;

    return Scaffold(
      backgroundColor: TideColors.deepWater,
      body: Stack(
        children: [
          // The one screen allowed a looping background: first run has no
          // history to show yet, so a still page would read as unloaded.
          const Positioned.fill(child: TideBackdrop(drift: true)),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
              child: Column(
                children: [
                  // The chrome leaves with everything else. It used to sit
                  // outside the exit fade, so the last thing onboarding did
                  // was dissolve the ring, the copy and the button and then
                  // hold a blank screen carrying a full progress bar and a
                  // Skip link — the two least important things on the page
                  // were the only two that survived it.
                  _ExitFade(
                    morph: _morph,
                    child: Row(
                      children: [
                        Expanded(
                          child: TideLineGauge(
                            progress: (_step + 1) / _stepCount,
                          ),
                        ),
                        const SizedBox(width: 18),
                        // Always visible while the flow is running, never
                        // de-emphasised.
                        PressScale(
                          onTap: _skip,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 8,
                            ),
                            child: Text('Skip', style: TideType.labelMuted),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  Expanded(
                    child: PageView(
                      controller: _pages,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        const WelcomeStep(),
                        TemplateGrid(
                          selected: _selected,
                          onChanged: (next) => setState(() => _selected = next),
                          onCustom: () => context.push(Routes.newHabit),
                        ),
                        RhythmStep(
                          templates: _chosen,
                          days: _days,
                          times: _times,
                          onDaysChanged: (i, days) =>
                              setState(() => _days[_indexOf(i)] = days),
                          onTimeChanged: (i, time) =>
                              setState(() => _times[_indexOf(i)] = time),
                        ),
                        NotificationStep(
                          habitName: firstChosen?.name ?? 'Morning water',
                          glyph: firstChosen?.glyph ?? TideGlyph.crescent,
                          time:
                              firstChosen?.reminderTime ??
                              const TimeOfDay(hour: 7, minute: 30),
                        ),
                        AnimatedBuilder(
                          animation: _morph,
                          builder: (context, _) => ReadyStep(
                            habitCount: _selected.length,
                            morph: _morph.value,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _ExitFade(
                    morph: _morph,
                    child: Column(
                      children: [
                        TideButton(
                          label: _primaryLabel,
                          enabled: _canContinue,
                          onPressed: _next,
                        ),
                        if (_step == 3) ...[
                          const SizedBox(height: 10),
                          TideButton(
                            label: 'Not now',
                            variant: TideButtonVariant.ghost,
                            onPressed: _next,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The rhythm step works in positions within the chosen list; the maps
  /// are keyed by template index, so translate between them.
  int _indexOf(int chosenPosition) {
    final sorted = _selected.toList()..sort();
    return sorted[chosenPosition];
  }
}

/// Everything that is not the ring, leaving as the screen hands off.
///
/// Faster than the morph it rides on, so the page has cleared before the
/// ring finishes travelling and the ring is unambiguously the thing being
/// carried across rather than one more element in a crossfade.
class _ExitFade extends StatelessWidget {
  const _ExitFade({required this.morph, required this.child});

  final Animation<double> morph;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: morph,
      builder: (context, child) => IgnorePointer(
        ignoring: morph.value > 0,
        child: Opacity(
          opacity: (1 - morph.value * 2.2).clamp(0.0, 1.0),
          child: child,
        ),
      ),
      child: child,
    );
  }
}
