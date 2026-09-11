import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../services/models/habit.dart';
import '../../../services/models/tide_glyph.dart';
import '../../../theme/tide_colors.dart';
import '../../../theme/tide_elevation.dart';
import '../../../theme/tide_motion.dart';
import '../../../theme/tide_typography.dart';
import '../../../widgets/habit_glyph.dart';
import '../../../widgets/press_scale.dart';
import '../../../widgets/ripple_strip.dart';
import '../../../widgets/tide_ring.dart';
import '../../../widgets/tide_surface.dart';
import '../../../widgets/swipe_log_background.dart';

/// One habit on Home, and the gesture surface for logging it.
///
/// An enclosed card. The list spent a while as full-bleed rows separated by
/// a hairline, on the argument that a panel carried no information the
/// content inside it did not already carry. True, and beside the point: on
/// a near-black ground four hairlines do not read as four objects, they
/// read as ruling on a page, and the habit you are aiming a thumb at has no
/// edge to it. Giving each habit a fill one step off the page, a hairline
/// all the way round and a 20px radius is what makes it a thing you can
/// pick up rather than a line of text with a gesture attached.
///
/// The fill is [TideColors.shelf] rather than the page colour — one step of
/// luminance, no gradient — and it is opaque, which is what still lets the
/// card slide cleanly over the swipe backdrop when it is dragged.
///
/// **Read left to right: what it is, how it has gone, where today stands.**
/// The glyph sits in a tile of its own; the name carries the week and one
/// line of status beneath it; and a single mark at the far end says whether
/// today is open, filling, done or frozen. The card used to put a progress
/// ring *around* the glyph, which fused "which habit" and "how far" into one
/// 34px object, and then end the row on a bare streak figure nothing
/// labelled. Splitting identity from state, and naming the streak where it
/// is shown, is what lets a list of four be scanned rather than decoded.
///
/// The body logs the habit — binary habits are swiped, and a habit with a
/// count opens the log sheet, where its units are metered out one at a
/// time.
///
/// The trailing side of the body reads the day rather than offering one
/// fixed action: an open day is frozen, a frozen day gives its token back,
/// and a day already logged is undone. Undo lives here rather than in a
/// snackbar because it is the *same* gesture reversed — the thing you reach
/// for when a swipe logged a habit you did not mean to log is the swipe
/// back, and a card that has to be found again in a list of four is not
/// where that reach ends up.
///
/// **A long press anywhere on the card** raises the context menu. It used
/// to be reachable only from the ring, which is a 34px target for the one
/// gesture people go looking for when they want to edit or delete
/// something — so in practice the menu was not reachable at all. Long press
/// and horizontal drag settle in the gesture arena on their own (movement
/// picks the drag, stillness picks the press), so the whole card can carry
/// both without the two fighting.
class HabitCard extends StatefulWidget {
  const HabitCard({
    super.key,
    required this.habit,
    required this.streak,
    required this.weekLevels,
    required this.frozenDays,
    required this.onMenu,
    required this.onCount,
    required this.onComplete,
    required this.onFreeze,
    required this.onUnfreeze,
    required this.onUndo,
  });

  final Habit habit;
  final int streak;

  /// Seven completion levels, oldest first.
  final List<double> weekLevels;

  /// Which of those seven days were frozen rather than logged, so the strip
  /// can shade them cold. Same length and order as [weekLevels].
  final List<bool> frozenDays;

  final VoidCallback onMenu;

  /// Opens the count drawer when a measured habit is tapped.
  final VoidCallback onCount;

  final VoidCallback onComplete;

  final VoidCallback onFreeze;
  final VoidCallback onUnfreeze;

  /// Clears today's log. The freeze side turns into this once the habit is
  /// finished, so the gesture that logged it by accident is also the one
  /// that takes it back.
  final VoidCallback onUndo;

  /// Taller than the hairline rows it replaced: a card needs its content to
  /// sit off its own edges, not just off its neighbours.
  static const double height = 78;

  /// Vertical air between two cards. Enough that the gap reads as ground
  /// showing through rather than as a thick divider — and the same as the
  /// bento grid's gutter plus a little, so the list breathes slightly more
  /// than the summary above it.
  static const double gap = 12;

  static const BorderRadius radius = TideElevation.radius20;

  @override
  State<HabitCard> createState() => _HabitCardState();
}

/// Where today stands for one habit — the single state the trailing mark
/// draws.
enum _Mark { open, counting, done, frozen }

class _HabitCardState extends State<HabitCard>
    with SingleTickerProviderStateMixin {
  // Built eagerly in initState rather than lazily: a row disposed without
  // ever being dragged would otherwise construct its controller inside
  // dispose(), which is too late to look up a TickerMode.
  late final AnimationController _settle;

  double _drag = 0;
  double _phase = 0;
  double _cardWidth = 0;

  /// Logged to target today — earned, as opposed to held.
  bool get _completed => widget.habit.isCompleteOn(DateTime.now());

  bool get _frozen => widget.habit.isFrozenOn(DateTime.now());

  /// The day is settled either way, which is what the card's colouring and
  /// its second line care about.
  bool get _done => _completed || _frozen;

  bool get _counted => widget.habit.type != HabitType.binary;

  double get _progress => widget.habit.progressOn(DateTime.now());

  _Mark get _mark {
    if (_frozen) return _Mark.frozen;
    if (_completed) return _Mark.done;
    return _counted ? _Mark.counting : _Mark.open;
  }

  @override
  void initState() {
    super.initState();
    _settle = AnimationController(
      vsync: this,
      duration: TideMotion.swipeCancel,
    );
  }

  @override
  void dispose() {
    _settle.dispose();
    super.dispose();
  }

  // --- Swipe ------------------------------------------------------------

  void _onDragUpdate(DragUpdateDetails details) {
    setState(() {
      _drag += details.delta.dx;
      // Resistance past the commit point, so the row never slides right off
      // the screen and the threshold stays findable by feel.
      final limit = _cardWidth * 0.62;
      // A measured habit is completed in its count drawer, not by a
      // binary check gesture. Do not even reveal the gold check side for
      // it: showing an action that will spring back is misleading.
      final max = widget.habit.type == HabitType.binary ? limit : 0.0;
      _drag = _drag.clamp(-limit, max);
      _phase += details.delta.dx * 0.03;
    });
  }

  void _onDragEnd(DragEndDetails details) {
    final fraction = _cardWidth == 0 ? 0.0 : _drag.abs() / _cardWidth;

    // Distance used to decide this on its own, and distance on its own
    // cannot tell a habit being logged from a page being thrown at the tab
    // bar. This card's recogniser sits below the shell's and wins the arena
    // by depth, so a flick meant as "next tab" that started on a card never
    // reached the shell — it crossed the threshold on the way past and
    // logged the habit. Speed is the tell, and the bar is the shell's own
    // fling speed: anything quick enough to have been a page swipe springs
    // back untouched rather than guessing.
    //
    // A flick back the other way is caught by the same check, which is
    // correct — a gesture the hand has already reversed is a cancel.
    final flung =
        details.velocity.pixelsPerSecond.dx.abs() >=
        TideMotion.swipeFlingVelocity;

    if (fraction >= TideMotion.swipeThreshold && !flung) {
      if (_drag > 0 && widget.habit.type == HabitType.binary) {
        _commitLog();
      } else if (_drag < 0) {
        // Three readings of one side, in order of what the day already is.
        // A frozen day gives its token back; a finished day is taken back;
        // an open day is protected.
        if (_frozen) {
          _commitUnfreeze();
        } else if (_completed) {
          _commitUndo();
        } else {
          _commitFreeze();
        }
      } else {
        _animateDragHome(TideMotion.swipeCancel, TideMotion.swipeCancelCurve);
      }
      return;
    }
    _animateDragHome(TideMotion.swipeCancel, TideMotion.swipeCancelCurve);
  }

  /// Binary habits deliberately keep their quick check-off gesture. Counted
  /// habits never call this path: their exact amount belongs in the drawer.
  void _commitLog() {
    HapticFeedback.mediumImpact();
    _animateDragHome(TideMotion.swipeSettle, Curves.easeOutCubic);
    widget.onComplete();
  }

  void _commitFreeze() {
    HapticFeedback.mediumImpact();
    _animateDragHome(TideMotion.swipeSettle, Curves.easeOutCubic);
    widget.onFreeze();
  }

  void _commitUnfreeze() {
    HapticFeedback.selectionClick();
    _animateDragHome(TideMotion.swipeSettle, Curves.easeOutCubic);
    widget.onUnfreeze();
  }

  /// The lighter selection tick rather than the medium impact the commits
  /// use: taking something back should not feel like landing it.
  void _commitUndo() {
    HapticFeedback.selectionClick();
    _animateDragHome(TideMotion.swipeSettle, Curves.easeOutCubic);
    widget.onUndo();
  }

  void _animateDragHome(Duration duration, Curve curve) {
    final from = _drag;
    _settle
      ..reset()
      ..duration = duration;

    final animation = _settle.drive(
      Tween<double>(begin: from, end: 0).chain(CurveTween(curve: curve)),
    );

    void tick() => setState(() => _drag = animation.value);
    animation.addListener(tick);
    _settle.forward().whenComplete(() {
      animation.removeListener(tick);
      if (mounted) setState(() => _drag = 0);
    });
  }

  // --- Copy -------------------------------------------------------------

  /// The line under the name: always something, and never the gesture.
  ///
  /// It used to spell out "swipe right to log" under every habit, every
  /// day — an affordance label that never retires stops being help and
  /// becomes noise. What it says now is the most useful fact about the
  /// habit at this moment: how far a count has got, that a day is being
  /// held, or how long the run is. The streak moved here from a bare figure
  /// at the end of the row, where nothing said what it was counting.
  String get _detail {
    if (_frozen) return 'frozen, streak held';
    if (!_done && _counted) return '${_amount()} of ${widget.habit.target}';
    if (widget.streak > 0) return '${widget.streak} day streak';
    return 'No streak yet';
  }

  TextStyle get _detailStyle {
    if (_frozen) {
      return TideType.labelMuted.copyWith(
        color: TideColors.frost.withValues(alpha: 0.75),
      );
    }
    // A count in progress is the one line here that is about *today*, so it
    // takes the accent, faintly.
    if (!_done && _counted && _progress > 0) {
      return TideType.labelMuted.copyWith(
        color: TideColors.lantern.withValues(alpha: 0.85),
      );
    }
    return TideType.labelMuted;
  }

  String _amount() {
    final amount = widget.habit.amountOn(DateTime.now());
    return '${amount == amount.roundToDouble() ? amount.round() : amount}';
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _cardWidth = constraints.maxWidth;

        // Rounded, not square. The stack used to clip with `Clip.hardEdge`,
        // which is a rectangle — so a card sliding out of the row was cut
        // off with a hard right angle at whichever end it was leaving,
        // while the socket behind it kept the 20px radius. The two corners
        // disagreed for the whole length of every swipe, which is exactly
        // the moment the card is the only thing anybody is looking at.
        //
        // One rounded clip round the whole row instead: the socket, the
        // card and the card's exit are all the same shape, and at rest the
        // clip sits exactly on the card's own border.
        return SizedBox(
          height: HabitCard.height,
          child: ClipRRect(
            borderRadius: HabitCard.radius,
            clipBehavior: Clip.antiAlias,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: SwipeLogBackground(
                    offset: _drag,
                    width: _cardWidth,
                    phase: _phase,
                    radius: HabitCard.radius,
                    freezeAvailable: widget.habit.freezesRemaining > 0,
                    freezeOnRight: false,
                    unfreezing: _frozen,
                    undoing: _completed,
                  ),
                ),
                Transform.translate(
                  offset: Offset(_drag, 0),
                  child: _body(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// The card keeps all four corners, the whole way through a swipe.
  ///
  /// The alternative was tried and looked worse. Straightening whichever
  /// edge had moved *into* the row is the tidier idea on paper — that side
  /// has stopped being the edge of anything — and it does remove the seam
  /// where the card's curve meets the socket's. But what it actually reads
  /// as is the card being sliced off flat against the backdrop, and the
  /// thing a swipe is supposed to say is that a card has *lifted away* and
  /// left a socket behind it. A card is a rounded object; it does not stop
  /// being one because part of it is over a tint.
  Widget _body() {
    final row = TideSurface(
      height: HabitCard.height,
      radius: HabitCard.radius,
      color: _fill,
      border: Border.all(color: _edge),
      padding: const EdgeInsets.fromLTRB(12, 0, 16, 0),
      child: Row(
        children: [
          _GlyphTile(glyph: widget.habit.glyph, hue: _glyphHue, wash: _wash),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  widget.habit.name,
                  style: TideType.heading.copyWith(
                    color: _done ? TideColors.silt : TideColors.bone,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    RippleStrip(
                      levels: widget.weekLevels,
                      frozen: widget.frozenDays,
                      height: 6,
                      spacing: 2.5,
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        _detail,
                        style: _detailStyle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _StatusMark(mark: _mark, progress: _progress),
        ],
      ),
    );

    // Tap and long press ride on the card itself. A shallower press than the
    // global default — 0.97 on a full-width card is a lurch, where the same
    // ratio on a chip is a nudge.
    final pressable = PressScale(
      scale: 0.985,
      // A measured habit opens its logging drawer on tap. Binary habits are
      // deliberately tap-silent: their complete action lives in More so a
      // fast scroll can never turn into an accidental check-off.
      onTap: widget.habit.type == HabitType.binary ? null : widget.onCount,
      onLongPress: widget.onMenu,
      child: row,
    );

    // Right reveals the warm check on the left for binary habits; left
    // reveals the trailing side for every habit — ice to freeze an open
    // day, neutral ink to take back a finished one. Counted habits still
    // use their drawer for progress, so their right swipe returns.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragUpdate: _onDragUpdate,
      onHorizontalDragEnd: _onDragEnd,
      child: pressable,
    );
  }

  /// The card fill. One step of luminance off the page while the habit is
  /// open; part of the way back down toward the page once the day is
  /// settled.
  ///
  /// A settled card used to be tinted *up* — lantern or frost lerped into
  /// the fill — and on this ground the warm lerp came out a lighter olive
  /// slab. That made the finished habits the brightest objects in a list
  /// whose job is to show what is still outstanding. Sinking them toward
  /// the page does the opposite: open work stands forward, finished work
  /// settles back, and the solid mark at the end still says which is which.
  Color get _fill {
    if (_done) return Color.lerp(TideColors.shelf, TideColors.deepWater, 0.4)!;
    return TideColors.shelf;
  }

  /// The hairline round the card. Ice stays on the edge of a frozen card,
  /// faintly, because a held day and an earned one should not be mistaken
  /// for each other at a glance; an earned day needs no edge of its own —
  /// the lantern disc already carries it.
  Color get _edge {
    if (_frozen) return TideColors.frost.withValues(alpha: 0.16);
    return TideColors.hairline;
  }

  /// The glyph lights with the habit: ice once frozen, lantern once earned
  /// or under way, and plain ink while nothing has happened yet.
  Color get _glyphHue {
    if (_frozen) return TideColors.frost;
    if (_completed || (_counted && _progress > 0)) return TideColors.lantern;
    return TideColors.bone.withValues(alpha: 0.8);
  }

  /// The tile behind the glyph. A wash of the same hue rather than the
  /// trench — a recess darker than the card reads as a hole punched in it.
  Color get _wash {
    if (_frozen) return TideColors.frost.withValues(alpha: 0.08);
    if (_completed) return TideColors.lantern.withValues(alpha: 0.09);
    return TideColors.bone.withValues(alpha: 0.05);
  }
}

/// Which habit this is, on a small tile of its own colour.
class _GlyphTile extends StatelessWidget {
  const _GlyphTile({
    required this.glyph,
    required this.hue,
    required this.wash,
  });

  final TideGlyph glyph;
  final Color hue;
  final Color wash;

  @override
  Widget build(BuildContext context) {
    // Tweened, so a habit being marked warms its tile in the same beat the
    // trailing mark fills — the card changes state as one object.
    return AnimatedContainer(
      duration: TideMotion.ringFill,
      curve: TideMotion.tabCurve,
      width: 42,
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: wash,
        borderRadius: TideElevation.radius12,
      ),
      child: HabitGlyph(glyph: glyph, size: 16, color: hue),
    );
  }
}

/// Where today stands, at the end of the row, as one mark.
///
/// * **Open** — an empty circle: the universal "not yet", with no words.
/// * **Counting** — a ring filling toward the target, with a plus in it,
///   because tapping this card adds to the count.
/// * **Done** — a solid lantern disc and a check. The one solid warm object
///   on the card, so a finished habit is legible from across the list.
/// * **Frozen** — ice: a frost ring and a flake, the same mark the freeze
///   swipe shows.
///
/// A change between them pops rather than cuts, on the signature overshoot,
/// so marking a habit lands as a small physical event.
class _StatusMark extends StatelessWidget {
  const _StatusMark({required this.mark, required this.progress});

  final _Mark mark;
  final double progress;

  static const double _size = 30;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: _size,
      child: AnimatedSwitcher(
        duration: TideMotion.tabSwitch,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.6, end: 1).animate(
              CurvedAnimation(parent: animation, curve: TideMotion.overshoot),
            ),
            child: child,
          ),
        ),
        child: SizedBox.square(
          key: ValueKey(mark),
          dimension: _size,
          child: _face(),
        ),
      ),
    );
  }

  Widget _face() {
    return switch (mark) {
      _Mark.done => const DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: TideColors.lantern,
        ),
        child: Icon(
          Icons.check_rounded,
          size: 18,
          color: TideColors.deepWater,
        ),
      ),
      _Mark.frozen => DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: TideColors.frost.withValues(alpha: 0.10),
          border: Border.all(color: TideColors.frost.withValues(alpha: 0.35)),
        ),
        child: const Icon(
          Icons.ac_unit_rounded,
          size: 14,
          color: TideColors.frost,
        ),
      ),
      _Mark.counting => TideRing(
        progress: progress,
        size: _size,
        strokeWidth: 2.5,
        child: Icon(
          Icons.add_rounded,
          size: 15,
          color: progress > 0 ? TideColors.lantern : TideColors.silt,
        ),
      ),
      _Mark.open => DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: TideColors.bone.withValues(alpha: 0.18),
            width: 1.5,
          ),
        ),
      ),
    };
  }
}
