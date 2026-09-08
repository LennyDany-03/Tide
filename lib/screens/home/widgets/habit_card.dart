import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../services/models/habit.dart';
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
/// The card divides into two handles, and the division is the same on every
/// card in the app:
///
/// * **The ring** opens the habit — a tap goes to detail.
/// * **The body** logs it — binary habits are swiped, and a habit with a
///   count opens the log sheet, where its units are metered out one at a
///   time.
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
///
/// The body used to hold-to-log a counted habit in place, sweeping the
/// whole target under one finger. Two problems: the only outcomes were
/// nothing and all ten, and a slow gesture sat on a card you scroll past.
/// The counting moved to a surface of its own.
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

  /// Called with the amount to log — the full target, from a swipe.
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
  /// showing through rather than as a thick divider.
  static const double gap = 10;

  static const BorderRadius radius = TideElevation.radius20;

  @override
  State<HabitCard> createState() => _HabitCardState();
}

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

  double get _progress => widget.habit.progressOn(DateTime.now());

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

  /// The second line, and only when there is something to say.
  ///
  /// This used to spell out the gesture on every row forever — "swipe right
  /// to log" under all four habits, every day. An affordance label that
  /// never retires stops being help and becomes noise, and the ring already
  /// shows where the habit stands.
  String? get _detail {
    if (_frozen) return 'frozen, streak held';
    if (_done) return null;
    if (widget.habit.type == HabitType.binary) return null;
    return '${_amount()} of ${widget.habit.target}';
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
  ///
  /// The seam is fine. The corner that genuinely was wrong is the row's,
  /// and that is fixed one level up in [build]: the stack used to clip with
  /// `Clip.hardEdge`, which is a rectangle, so the card left the row
  /// through a right angle while the socket kept its radius.

  Widget _body() {
    final detail = _detail;

    final row = TideSurface(
      height: HabitCard.height,
      radius: HabitCard.radius,
      color: _fill,
      border: Border.all(color: _edge),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          _ringHandle(),
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
                if (detail != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    detail,
                    style: _frozen
                        ? TideType.labelMuted.copyWith(
                            color: TideColors.frost.withValues(alpha: 0.75),
                          )
                        : TideType.labelMuted,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          RippleStrip(levels: widget.weekLevels, frozen: widget.frozenDays),
          const SizedBox(width: 14),
          SizedBox(
            width: 24,
            child: Text(
              '${widget.streak}',
              textAlign: TextAlign.right,
              style: TideType.gauge(
                17,
                color: _done ? _stateHue : TideColors.silt,
              ),
            ),
          ),
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

  /// The card fill. One step of luminance off the page, tinted very
  /// slightly once the day is settled — warm where it was earned, cold
  /// where it was frozen, at the lowest intensity either hue is used at
  /// anywhere.
  Color get _fill {
    if (_frozen) return Color.lerp(TideColors.shelf, TideColors.frost, 0.05)!;
    if (_done) return Color.lerp(TideColors.shelf, TideColors.lantern, 0.05)!;
    return TideColors.shelf;
  }

  /// Ice for a frozen day, the accent for an earned one.
  ///
  /// A frozen card used to be lantern throughout — the same ring, border and
  /// figure as a habit that was actually completed — so the only thing
  /// separating "I did this" from "I bought a day off" was a line of small
  /// grey text. Temperature carries it now.
  Color get _stateHue => _frozen ? TideColors.frost : TideColors.lantern;

  /// The hairline round the card, and the only place its state is spelled
  /// out on the edge rather than inside it.
  ///
  /// Kept low on purpose. A brighter warm edge on a finished habit made the
  /// two done cards the loudest things in a list whose whole job is to show
  /// what is still outstanding — done is already carried by a full ring, a
  /// silt name and a lantern streak figure, and it does not need a fourth
  /// signal competing for the eye.
  Color get _edge {
    if (_frozen) return TideColors.frost.withValues(alpha: 0.2);
    if (_done) return TideColors.lantern.withValues(alpha: 0.18);
    return TideColors.hairline;
  }

  /// The glyph is informational on Home. Pressing and holding it opens the
  /// same action menu as pressing and holding the row.
  Widget _ringHandle() {
    return TideRing(
      progress: _done ? 1 : _progress,
      size: 34,
      strokeWidth: 2,
      color: _stateHue,
      child: HabitGlyph(
        glyph: widget.habit.glyph,
        size: 14,
        color: _done ? _stateHue : TideColors.bone.withValues(alpha: 0.75),
      ),
    );
  }
}
