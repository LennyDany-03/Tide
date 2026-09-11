import 'package:flutter/material.dart';

import '../../../services/models/habit.dart';
import '../../../theme/tide_colors.dart';
import '../../../theme/tide_elevation.dart';
import '../../../theme/tide_motion.dart';
import '../../../theme/tide_typography.dart';
import '../../../widgets/habit_glyph.dart';
import '../../../widgets/hold_to_fill.dart';
import '../../../widgets/press_scale.dart';
import '../../../widgets/tide_button.dart';
import '../../../widgets/tide_surface.dart';

/// The long-press menu, raised from anywhere on a habit card.
///
/// Everything you can do to a habit, in the order you reach for it: log it,
/// look at it, change it, park it, destroy it. **Habit details** is the entry
/// that was missing — long-pressing a habit and finding no route through to
/// its own screen sent people back to the card to hunt for a second,
/// different gesture that opened it.
///
/// Three tiers, so the eye lands in the right place first. Logging is the
/// one solid lantern button — it is what a long-press is usually for. The
/// quiet verbs share one grouped list, divided by hairlines. Delete sits
/// apart behind the same coral hold-to-fill used on Habit detail and in
/// Settings — the gesture that destroys things never changes shape. The
/// menu used to give all four verbs identical trench blocks: darker than the
/// page, they read as holes punched in the panel, and the primary action
/// differed from "Pause" only by a faint tint.
///
/// Plain scrim, no blur, as with [showTideDialog]. The blur banded into
/// posterised colour blobs on some GPUs — hues the palette does not contain
/// — and it cost a `BackdropFilter` at the exact moment the menu opens.
///
/// The shell carries a 20px radius and 8px of padding; everything inside
/// carries 12 — 20 minus 8, so the curves are concentric rather than merely
/// both rounded.
Future<void> showHabitContextMenu(
  BuildContext context, {
  required Habit habit,
  required int streak,
  required VoidCallback onDetails,
  required VoidCallback onEdit,
  required VoidCallback onPause,
  required VoidCallback onDelete,
  VoidCallback? onComplete,
  VoidCallback? onLogProgress,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss',
    barrierColor: TideColors.scrim,
    transitionDuration: TideMotion.sheetIn,
    pageBuilder: (context, animation, secondary) => Center(
      child: Material(
        type: MaterialType.transparency,
        child: _Menu(
          habit: habit,
          streak: streak,
          onDetails: onDetails,
          onEdit: onEdit,
          onPause: onPause,
          onDelete: onDelete,
          onComplete: onComplete,
          onLogProgress: onLogProgress,
        ),
      ),
    ),
    transitionBuilder: (context, animation, secondary, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: TideMotion.overshoot,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.92, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class _Menu extends StatelessWidget {
  const _Menu({
    required this.habit,
    required this.streak,
    required this.onDetails,
    required this.onEdit,
    required this.onPause,
    required this.onDelete,
    this.onComplete,
    this.onLogProgress,
  });

  final Habit habit;
  final int streak;
  final VoidCallback onDetails;
  final VoidCallback onEdit;
  final VoidCallback onPause;
  final VoidCallback onDelete;
  final VoidCallback? onComplete;
  final VoidCallback? onLogProgress;

  /// Closes the menu before acting, so a pushed route or an opened sheet
  /// never arrives underneath it.
  void _run(BuildContext context, VoidCallback action) {
    Navigator.of(context).pop();
    action();
  }

  @override
  Widget build(BuildContext context) {
    final log = onComplete != null
        ? (label: 'Mark complete', icon: Icons.check_rounded, act: onComplete!)
        : onLogProgress != null
        ? (label: 'Mark progress', icon: Icons.add_rounded, act: onLogProgress!)
        : null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: TideSurface(
          color: TideColors.shoal,
          floating: true,
          border: Border.all(color: TideColors.bone.withValues(alpha: 0.08)),
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(habit: habit, streak: streak),
              if (log != null) ...[
                TideButton(
                  label: log.label,
                  icon: Icon(log.icon, size: 19, color: TideColors.deepWater),
                  onPressed: () => _run(context, log.act),
                ),
                const SizedBox(height: 8),
              ],
              _Group(
                children: [
                  _MenuRow(
                    icon: Icons.insights_rounded,
                    label: 'Habit details',
                    navigates: true,
                    onTap: () => _run(context, onDetails),
                  ),
                  _MenuRow(
                    icon: Icons.tune_rounded,
                    label: 'Edit habit',
                    navigates: true,
                    onTap: () => _run(context, onEdit),
                  ),
                  _MenuRow(
                    icon: habit.paused
                        ? Icons.play_arrow_rounded
                        : Icons.pause_rounded,
                    label: habit.paused ? 'Resume habit' : 'Pause habit',
                    onTap: () => _run(context, onPause),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              HoldToConfirmButton(
                label: 'Hold to delete',
                holdingLabel: 'Keep holding…',
                onConfirm: () => _run(context, onDelete),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Which habit this is and where it stands, said once, so the menu is not a
/// stack of verbs floating over a screen you can no longer read.
class _Header extends StatelessWidget {
  const _Header({required this.habit, required this.streak});

  final Habit habit;
  final int streak;

  bool get _live => !habit.paused && streak > 0;

  String get _status {
    if (habit.paused) return 'Paused';
    if (streak > 0) return '$streak day streak';
    return 'No streak yet';
  }

  @override
  Widget build(BuildContext context) {
    final glyphColor = habit.paused
        ? TideColors.drained(TideColors.lantern, 0.7)
        : TideColors.lantern;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: TideColors.lantern.withValues(
                alpha: habit.paused ? 0.05 : 0.12,
              ),
              borderRadius: TideElevation.radius12,
            ),
            child: HabitGlyph(glyph: habit.glyph, size: 18, color: glyphColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  habit.name,
                  style: TideType.heading,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    // Lit only while there is a streak to protect — the same
                    // intensity-of-one-hue state the cards use.
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _live
                            ? TideColors.lantern
                            : TideColors.silt.withValues(alpha: 0.5),
                      ),
                    ),
                    const SizedBox(width: 7),
                    Flexible(
                      child: Text(
                        _status,
                        style: TideType.labelMuted,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The quiet verbs as one grouped list. A step *below* the shell rather than
/// a trench, so it reads as a tray set into the panel, not a hole in it.
class _Group extends StatelessWidget {
  const _Group({required this.children});

  final List<Widget> children;

  /// Row padding + icon + gap, so the hairlines start under the labels and
  /// the icons stand in one unbroken column.
  static const double _dividerInset = 14 + 19 + 14;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: TideColors.shelf,
        borderRadius: TideElevation.radius12,
        border: Border.all(color: TideColors.hairline),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              Container(
                height: 1,
                margin: const EdgeInsets.only(left: _dividerInset),
                color: TideColors.hairline,
              ),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.navigates = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  /// Takes you to another screen — earns a chevron. Pause acts in place and
  /// does not, so the row tells you whether you are about to leave.
  final bool navigates;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onTap,
      // Shallower than the default: the row is full-width inside a group,
      // and a deep press pulls it visibly away from its own dividers.
      scale: 0.985,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
        child: Row(
          children: [
            Icon(icon, size: 19, color: TideColors.silt),
            const SizedBox(width: 14),
            Expanded(child: Text(label, style: TideType.label)),
            if (navigates)
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: TideColors.silt.withValues(alpha: 0.7),
              ),
          ],
        ),
      ),
    );
  }
}
