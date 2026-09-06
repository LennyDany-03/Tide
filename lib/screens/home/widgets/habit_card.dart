import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../services/models/habit.dart';
import '../../../theme/tide_colors.dart';
import '../../../theme/tide_motion.dart';
import '../../../theme/tide_typography.dart';
import '../../../widgets/habit_glyph.dart';
import '../../../widgets/press_scale.dart';
import '../../../widgets/ripple_burst.dart';
import '../../../widgets/ripple_strip.dart';
import '../../../widgets/tide_ring.dart';
import 'swipe_log_background.dart';

/// One habit on Home, and the gesture surface for logging it.
///
/// A row, not a card. Four rounded panels stacked down the main screen, each
/// with its own fill, border, shadow and inner pills, made the list read as
/// four separate widgets rather than one list of four habits — and the
/// panels carried no information the content inside them did not already
/// carry. What separates one habit from the next is a hairline.
///
/// The fill is the *page* colour rather than a surface colour: invisible at
/// rest, and opaque enough to slide cleanly over the swipe backdrop when the
/// row is dragged.
///
/// The row divides into two handles, and the division is the same on every
/// row in the app:
///
/// * **The ring** manages the habit — tap opens detail, long-press raises
///   the context menu.
/// * **The body** logs it — binary habits are swiped, and a habit with a
///   count opens the log sheet, where its units are metered out one at a
///   time.
///
/// That split is what lets a row keep a long-press menu without the two
/// gestures fighting each other for the same pixels.
///
/// The body used to hold-to-log a counted habit in place, sweeping the
/// whole target under one finger. Two problems: the only outcomes were
/// nothing and all ten, and a slow gesture sat on a row you scroll past.
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

  static const double height = 72;

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
                  freezeAvailable: widget.habit.freezesRemaining > 0,
                ),
              ),
              Transform.translate(
                offset: Offset(_drag, 0),
                child: RippleBurst(
                  trigger: _rippleTick,
                  color: TideColors.lantern,
                  borderRadius: BorderRadius.zero,
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

    final row = Container(
      height: HabitCard.height,
      // Page-coloured and opaque: nothing to see at rest, but solid enough
      // to slide over the swipe backdrop without it bleeding through.
      color: TideColors.deepWater,
      child: Row(
        children: [
          _ringHandle(),
          const SizedBox(width: 16),
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
          const SizedBox(width: 14),
          RippleStrip(levels: widget.weekLevels),
          const SizedBox(width: 16),
          SizedBox(
            width: 26,
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

    // One gesture per row body: binary habits swipe, counted habits open
    // the sheet that counts them.
    if (widget.habit.type == HabitType.binary) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragUpdate: _onDragUpdate,
        onHorizontalDragEnd: _onDragEnd,
        onTap: widget.onOpen,
        child: row,
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onCount,
      child: row,
    );
  }

  /// The management handle. Deliberately its own hit target so a long-press
  /// here never competes with the hold-to-log gesture on the body.
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

/// The hairline between two habit rows.
///
/// Inset past the ring so the rule starts at the text column — a divider
/// that runs the full width cuts the list into equal slabs, where one that
/// starts under the content reads as a list that continues.
class HabitRowDivider extends StatelessWidget {
  const HabitRowDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 50),
      child: Container(height: 1, color: TideColors.hairline),
    );
  }
}
