import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../services/models/habit.dart';
import '../../../theme/tide_colors.dart';
import '../../../theme/tide_elevation.dart';
import '../../../theme/tide_motion.dart';
import '../../../theme/tide_typography.dart';
import '../../../widgets/habit_glyph.dart';
import '../../../widgets/press_scale.dart';
import '../../../widgets/ripple_burst.dart';
import '../../../widgets/ripple_strip.dart';
import '../../../widgets/tide_ring.dart';
import '../../../widgets/tide_surface.dart';
import 'swipe_log_background.dart';

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
    required this.onOpen,
    required this.onMenu,
    required this.onLog,
    required this.onCount,
    required this.onFreeze,
  });

  final Habit habit;
  final int streak;

  /// Seven completion levels, oldest first.
  final List<double> weekLevels;

  final VoidCallback onOpen;
  final VoidCallback onMenu;

  /// Called with the amount to log — the full target, from a swipe.
  final ValueChanged<num> onLog;

  /// Opens the counting surface, for a habit whose target has parts.
  final VoidCallback onCount;

  final VoidCallback onFreeze;

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
  int _rippleTick = 0;

  bool get _done =>
      widget.habit.isCompleteOn(DateTime.now()) ||
      widget.habit.isFrozenOn(DateTime.now());

  bool get _frozen => widget.habit.isFrozenOn(DateTime.now());

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

  // --- Swipe (binary habits) -------------------------------------------

  void _onDragUpdate(DragUpdateDetails details) {
    setState(() {
      _drag += details.delta.dx;
      // Resistance past the commit point, so the row never slides right off
      // the screen and the threshold stays findable by feel.
      final limit = _cardWidth * 0.62;
      _drag = _drag.clamp(-limit, limit);
      _phase += details.delta.dx * 0.03;
    });
  }

  void _onDragEnd(DragEndDetails details) {
    final fraction = _cardWidth == 0 ? 0.0 : _drag.abs() / _cardWidth;

    if (fraction >= TideMotion.swipeThreshold) {
      if (_drag > 0) {
        _commitLog();
      } else {
        _commitFreeze();
      }
      return;
    }
    _animateDragHome(TideMotion.swipeCancel, TideMotion.swipeCancelCurve);
  }

  /// Snap into place, then hand off to the store. The ripple fires here so
  /// the reward starts before the list has finished reordering.
  void _commitLog() {
    HapticFeedback.mediumImpact();
    setState(() => _rippleTick++);
    _animateDragHome(TideMotion.swipeSettle, Curves.easeOutCubic);
    widget.onLog(widget.habit.target);
  }

  void _commitFreeze() {
    HapticFeedback.mediumImpact();
    _animateDragHome(TideMotion.swipeSettle, Curves.easeOutCubic);
    widget.onFreeze();
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

        return SizedBox(
          height: HabitCard.height,
          child: Stack(
            children: [
              Positioned.fill(
                child: SwipeLogBackground(
                  offset: _drag,
                  width: _cardWidth,
                  phase: _phase,
                  radius: HabitCard.radius,
                  freezeAvailable: widget.habit.freezesRemaining > 0,
                ),
              ),
              Transform.translate(
                offset: Offset(_drag, 0),
                child: RippleBurst(
                  trigger: _rippleTick,
                  color: TideColors.lantern,
                  borderRadius: HabitCard.radius,
                  child: _body(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

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
                    style: TideType.labelMuted,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          RippleStrip(levels: widget.weekLevels),
          const SizedBox(width: 14),
          SizedBox(
            width: 24,
            child: Text(
              '${widget.streak}',
              textAlign: TextAlign.right,
              style: TideType.gauge(
                17,
                color: _done ? TideColors.lantern : TideColors.silt,
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
      onTap: widget.habit.type == HabitType.binary
          ? widget.onOpen
          : widget.onCount,
      onLongPress: widget.onMenu,
      child: row,
    );

    if (widget.habit.type != HabitType.binary) return pressable;

    // The drag sits outside the press, so a horizontal move takes the
    // gesture off the tap recogniser instead of racing it.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragUpdate: _onDragUpdate,
      onHorizontalDragEnd: _onDragEnd,
      child: pressable,
    );
  }

  /// The card fill. One step of luminance off the page, warmed very
  /// slightly once the habit is done — the same accent as everything else,
  /// at the lowest intensity it is used at anywhere.
  Color get _fill => _done
      ? Color.lerp(TideColors.shelf, TideColors.lantern, 0.05)!
      : TideColors.shelf;

  /// The hairline round the card, and the only place its state is spelled
  /// out on the edge rather than inside it.
  ///
  /// Kept low on purpose. A brighter warm edge on a finished habit made the
  /// two done cards the loudest things in a list whose whole job is to show
  /// what is still outstanding — done is already carried by a full ring, a
  /// silt name and a lantern streak figure, and it does not need a fourth
  /// signal competing for the eye.
  Color get _edge {
    if (_frozen) return TideColors.lantern.withValues(alpha: 0.16);
    if (_done) return TideColors.lantern.withValues(alpha: 0.18);
    return TideColors.hairline;
  }

  /// The open handle. Its own hit target because for a counted habit the
  /// card's tap goes to the log sheet, and there still has to be one place
  /// on the card that goes to detail instead.
  Widget _ringHandle() {
    return PressScale(
      onTap: widget.onOpen,
      onLongPress: widget.onMenu,
      child: TideRing(
        progress: _done ? 1 : _progress,
        size: 34,
        strokeWidth: 2,
        color: _frozen
            ? TideColors.lantern.withValues(alpha: 0.55)
            : TideColors.lantern,
        child: HabitGlyph(
          glyph: widget.habit.glyph,
          size: 14,
          color: _done
              ? TideColors.lantern
              : TideColors.bone.withValues(alpha: 0.75),
        ),
      ),
    );
  }
}
