import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../services/models/tide_glyph.dart';
import '../../theme/tide_colors.dart';
import '../../theme/tide_elevation.dart';
import '../../theme/tide_motion.dart';
import '../../theme/tide_typography.dart';
import '../gauge_number.dart';
import '../habit_glyph.dart';
import '../ripple_burst.dart';
import '../ripple_strip.dart';
import '../swipe_log_background.dart';
import '../tide_ring.dart';
import '../tide_surface.dart';

/// The three demos that explain what Tide does.
///
/// Onboarding no longer asks the user to configure anything, so these
/// carry the whole explanation: instead of describing the swipe, the
/// streak and the history, the app performs each one on a loop until it is
/// understood. The Home tour reuses the swipe demo verbatim, which is the
/// point of them living out here — the gesture a new user is shown on
/// their second screen and the one they are shown standing on an empty
/// Today are the same animation, not two drawings of it.
///
/// They are built from the real parts — [SwipeLogBackground], [RippleStrip],
/// [TideRing], [RippleBurst] — rather than from mock-ups of them. A demo
/// drawn separately drifts from the product the first time the product
/// changes, and then teaches the wrong thing.
///
/// These are the app's one sanctioned exception to "motion must be caused
/// by something the user did": a demonstration that waits to be poked is
/// not a demonstration.

/// Maps [t] onto 0..1 across the window [from]..[to], flat outside it.
double _window(double t, double from, double to) =>
    ((t - from) / (to - from)).clamp(0.0, 1.0);

/// A looping controller with the boilerplate in one place.
abstract class _LoopState<T extends StatefulWidget> extends State<T>
    with SingleTickerProviderStateMixin {
  late final AnimationController loop = AnimationController(
    vsync: this,
    duration: period,
  )..repeat();

  Duration get period;

  @override
  void dispose() {
    loop.dispose();
    super.dispose();
  }
}

// --- One: the gesture ------------------------------------------------------

/// A habit card logging itself, over and over.
///
/// A phantom fingertip carries the card right, the accent wave rises behind
/// it, and at the commit point the ring fills, the ripple fires, today's
/// cell lands in the week strip and the streak rolls up one. Then it all
/// quietly resets and does it again.
class SwipeLoopDemo extends StatefulWidget {
  const SwipeLoopDemo({
    super.key,
    this.name = 'Morning water',
    this.glyph = TideGlyph.crescent,
    this.streak = 11,
  });

  final String name;
  final TideGlyph glyph;

  /// Where the streak stands before the swipe lands.
  final int streak;

  @override
  State<SwipeLoopDemo> createState() => _SwipeLoopDemoState();
}

class _SwipeLoopDemoState extends _LoopState<SwipeLoopDemo> {
  /// Bumped when the swipe commits, so the ripple has an event to fire on.
  int _ripple = 0;

  /// Whether this pass has already fired. The listener runs every frame;
  /// without this the ripple would retrigger for the whole commit window.
  bool _fired = false;

  @override
  Duration get period => const Duration(milliseconds: 4400);

  @override
  void initState() {
    super.initState();
    loop.addListener(_watchCommit);
  }

  @override
  void dispose() {
    loop.removeListener(_watchCommit);
    super.dispose();
  }

  void _watchCommit() {
    final past = loop.value >= _commitAt;
    if (past == _fired) return;
    _fired = past;
    if (past) setState(() => _ripple++);
  }

  /// The instant the card is released and the log counts.
  static const double _commitAt = 0.46;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _DemoCard.height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;

          return AnimatedBuilder(
            animation: loop,
            builder: (context, _) {
              final t = loop.value;

              // Out and back. The card is carried past the commit line, then
              // springs home under the same curve a real released card uses.
              final out = Curves.easeInOutCubic.transform(
                _window(t, 0.18, _commitAt),
              );
              final back = Curves.easeOutBack.transform(
                _window(t, _commitAt, 0.60),
              );
              final drag = width * 0.46 * out * (1 - back);

              // Logged, held, then cleared for the next pass.
              final done =
                  _window(t, _commitAt, 0.58) * (1 - _window(t, 0.88, 1.0));

              final finger =
                  _window(t, 0.06, 0.18) * (1 - _window(t, _commitAt, 0.54));

              // Clipped to its own box. The card genuinely travels off the
              // edge — that is what a real swipe does — but unclipped it
              // would paint outside the demo, and the tour runs this inside
              // a caption panel it must not spill out of.
              return ClipRect(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: SwipeLogBackground(
                        offset: drag,
                        width: width,
                        phase: t * 2 * math.pi * 3,
                        radius: TideElevation.radius20,
                      ),
                    ),
                    Transform.translate(
                      offset: Offset(drag, 0),
                      child: RippleBurst(
                        trigger: _ripple,
                        borderRadius: TideElevation.radius20,
                        child: _DemoCard(
                          name: widget.name,
                          glyph: widget.glyph,
                          progress: done,
                          streak: widget.streak + (done > 0.5 ? 1 : 0),
                          week: [
                            for (var i = 0; i < 6; i++) i == 2 ? 0.0 : 1.0,
                            done,
                          ],
                        ),
                      ),
                    ),
                    if (finger > 0.01)
                      Positioned(
                        left: width * 0.30 + drag - _Fingertip.size / 2,
                        // Centred on the card rather than resting on its
                        // bottom edge, where it read as a bubble falling
                        // off the row instead of a thumb on it.
                        top: (_DemoCard.height - _Fingertip.size) / 2,
                        child: Opacity(
                          opacity: finger,
                          child: const _Fingertip(),
                        ),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// The soft disc standing in for a fingertip.
///
/// Deliberately not a hand or a cursor: a warm circle is the same mark the
/// ripple leaves, so the pointer and the reward read as one material.
class _Fingertip extends StatelessWidget {
  const _Fingertip();

  static const double size = 30;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: TideColors.bone.withValues(alpha: 0.16),
        border: Border.all(color: TideColors.bone.withValues(alpha: 0.34)),
      ),
    );
  }
}

// --- Two: the loop holds ---------------------------------------------------

/// A week filling in, breaking, and being held.
///
/// Six days land one after another, the seventh is missed, and a freeze
/// token spends itself to keep the run alive — the whole argument for
/// freezes in about four seconds, without a paragraph explaining them.
class StreakLoopDemo extends StatefulWidget {
  const StreakLoopDemo({super.key});

  @override
  State<StreakLoopDemo> createState() => _StreakLoopDemoState();
}

class _StreakLoopDemoState extends _LoopState<StreakLoopDemo> {
  @override
  Duration get period => const Duration(milliseconds: 5200);

  /// The day the run would have broken on, counting the strip from Monday
  /// as the calendar and the week strip both do. The caption names this day
  /// out loud, so the index and the word have to agree.
  static const int _missed = 3;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: loop,
      builder: (context, _) {
        final t = loop.value;
        // Seven days dealt across the first two-thirds, then a hold.
        final dealt = _window(t, 0.05, 0.62) * 7;
        final frozen = _window(t, 0.58, 0.74);
        final clear = _window(t, 0.90, 1.0);

        final levels = <double>[];
        final frost = <bool>[];
        for (var day = 0; day < 7; day++) {
          final arrived = (dealt - day).clamp(0.0, 1.0) * (1 - clear);
          final isFreeze = day == _missed;
          levels.add(isFreeze ? arrived * frozen : arrived);
          frost.add(isFreeze);
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                GaugeNumber(
                  value: (dealt.floor() * (1 - clear)).round(),
                  style: TideType.gaugeHero(color: TideColors.lantern),
                ),
                const SizedBox(width: 10),
                Text(
                  'day loop',
                  style: TideType.gauge(17, color: TideColors.silt),
                ),
              ],
            ),
            const SizedBox(height: 26),
            RippleStrip(
              levels: levels,
              frozen: frost,
              height: 26,
              spacing: 8,
              animate: false,
            ),
            const SizedBox(height: 18),
            // The caption names the one cell that is a different colour, at
            // the moment it changes, rather than sitting there as a legend.
            AnimatedOpacity(
              opacity: frozen > 0.4 && clear < 0.5 ? 1 : 0,
              duration: TideMotion.tabSwitch,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.ac_unit_rounded,
                    size: 14,
                    color: TideColors.frost.withValues(alpha: 0.8),
                  ),
                  const SizedBox(width: 7),
                  Text(
                    'Missed Thursday. A freeze held it.',
                    style: TideType.labelMuted.copyWith(
                      color: TideColors.frost.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

// --- Three: the shape of it ------------------------------------------------

/// Weeks of history washing in across a grid.
///
/// The same square mark the week strip and the calendar use, at the same
/// intensity ramp, filling on a diagonal so the wave reads as light moving
/// over water rather than as cells switching on.
class HistoryLoopDemo extends StatefulWidget {
  const HistoryLoopDemo({super.key});

  @override
  State<HistoryLoopDemo> createState() => _HistoryLoopDemoState();
}

class _HistoryLoopDemoState extends _LoopState<HistoryLoopDemo> {
  @override
  Duration get period => const Duration(milliseconds: 5600);

  static const int _columns = 9;
  static const int _rows = 5;

  /// A fixed pattern rather than random values: the grid has to look the
  /// same on every pass, or the demo reads as noise being generated.
  static const List<double> _pattern = [
    1, 1, 0.5, 1, 0, 1, 1, 1, 0.5, //
    1, 0, 1, 1, 1, 0.5, 1, 1, 1,
    0.5, 1, 1, 0, 1, 1, 1, 0.5, 1,
    1, 1, 1, 1, 0.5, 1, 0, 1, 1,
    0, 1, 0.5, 1, 1, 1, 1, 1, 1,
  ];

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: loop,
      builder: (context, _) {
        final t = loop.value;
        final sweep = _window(t, 0.04, 0.66);
        final clear = _window(t, 0.90, 1.0);
        // The wave front runs a little past the last cell so the bottom
        // right corner gets its full fill rather than being caught mid-ramp.
        final front = sweep * (_columns + _rows + 2);

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var row = 0; row < _rows; row++) ...[
              if (row > 0) const SizedBox(height: 7),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var column = 0; column < _columns; column++) ...[
                    if (column > 0) const SizedBox(width: 7),
                    _GridCell(
                      level:
                          _pattern[row * _columns + column] *
                          (front - row - column).clamp(0.0, 1.0) *
                          (1 - clear),
                    ),
                  ],
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}

class _GridCell extends StatelessWidget {
  const _GridCell({required this.level});

  final double level;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: TideColors.intensity(level),
        borderRadius: BorderRadius.circular(5),
      ),
    );
  }
}

// --- The card the swipe demo swipes ---------------------------------------

/// A habit card with its state handed in rather than read from a store.
class _DemoCard extends StatelessWidget {
  const _DemoCard({
    required this.name,
    required this.glyph,
    required this.progress,
    required this.streak,
    required this.week,
  });

  final String name;
  final TideGlyph glyph;

  /// 0..1 for today.
  final double progress;

  final int streak;
  final List<double> week;

  /// Matched to `HabitCard.height`, so the demo is the size of the thing it
  /// is demonstrating.
  static const double height = 78;

  bool get _done => progress > 0.5;

  @override
  Widget build(BuildContext context) {
    return TideSurface(
      height: height,
      radius: TideElevation.radius20,
      color: _done
          ? Color.lerp(TideColors.shelf, TideColors.lantern, 0.05)
          : TideColors.shelf,
      border: Border.all(
        color: _done
            ? TideColors.lantern.withValues(alpha: 0.28)
            : TideColors.hairline,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          TideRing(
            progress: progress,
            size: 34,
            animate: false,
            child: HabitGlyph(
              glyph: glyph,
              size: 15,
              color: _done ? TideColors.lantern : TideColors.silt,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              name,
              style: TideType.heading.copyWith(
                color: _done ? TideColors.silt : TideColors.bone,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          RippleStrip(levels: week, animate: false),
          const SizedBox(width: 14),
          SizedBox(
            width: 24,
            child: Align(
              alignment: Alignment.centerRight,
              child: GaugeNumber(
                value: streak,
                style: TideType.gauge(
                  17,
                  color: _done ? TideColors.lantern : TideColors.silt,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
