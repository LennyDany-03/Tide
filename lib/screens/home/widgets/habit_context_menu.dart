import 'package:flutter/material.dart';

import '../../../services/models/habit.dart';
import '../../../theme/tide_colors.dart';
import '../../../theme/tide_elevation.dart';
import '../../../theme/tide_motion.dart';
import '../../../theme/tide_typography.dart';
import '../../../widgets/habit_glyph.dart';
import '../../../widgets/hold_to_fill.dart';
import '../../../widgets/press_scale.dart';
import '../../../widgets/tide_sheet.dart';

/// The long-press menu, raised from anywhere on a habit card.
///
/// Everything you can do to a habit that is not logging it, in the order you
/// reach for it: look at it, change it, park it, destroy it. **Habit
/// details** is the entry that was missing — long-pressing a habit and
/// finding no route through to its own screen sent people back to the card
/// to hunt for a second, different gesture that opened it.
///
/// Floating elevation over a blurred backdrop, so it reads as lifted off the
/// page rather than as another card. The shell carries a 20px radius and 8px
/// of padding; the rows inside carry 12 — 20 minus 8, so the two curves are
/// concentric rather than merely both rounded. Delete lives here behind the
/// same coral hold-to-fill used on Habit detail and in Settings — the
/// gesture that destroys things never changes shape.
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
    barrierColor: Colors.transparent,
    transitionDuration: TideMotion.sheetIn,
    pageBuilder: (context, animation, secondary) => const SizedBox.shrink(),
    transitionBuilder: (context, animation, secondary, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: TideMotion.overshoot,
        reverseCurve: Curves.easeInCubic,
      );

      return Stack(
        children: [
          TideBackdrop(
            animation: animation,
            onTap: () => Navigator.of(context).pop(),
          ),
          Center(
            child: FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.9, end: 1).animate(curved),
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
          ),
        ],
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

  /// Where the habit stands, said once, so the menu is not four verbs
  /// floating over a screen you can no longer see behind it.
  String get _subtitle {
    if (habit.paused) return 'Paused';
    if (streak > 0) return '$streak day streak';
    return 'No streak yet';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 36),
      child: Material(
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: TideColors.shoal,
            borderRadius: TideElevation.radius20,
            border: Border.all(color: TideColors.bone.withValues(alpha: 0.08)),
            boxShadow: TideElevation.floating,
          ),
          // 8, so the rows' 12 sits concentric inside the shell's 20.
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 14),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: const BoxDecoration(
                        color: TideColors.trench,
                        borderRadius: TideElevation.radius12,
                      ),
                      child: Center(
                        child: HabitGlyph(
                          glyph: habit.glyph,
                          size: 15,
                          color: TideColors.lantern,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
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
                          const SizedBox(height: 3),
                          Text(_subtitle, style: TideType.labelMuted),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (onComplete != null) ...[
                _MenuRow(
                  icon: Icons.check_rounded,
                  label: 'Mark complete',
                  primary: true,
                  onTap: () {
                    Navigator.of(context).pop();
                    onComplete!();
                  },
                ),
                const SizedBox(height: 6),
              ],
              if (onLogProgress != null) ...[
                _MenuRow(
                  icon: Icons.add_task_rounded,
                  label: 'Log progress',
                  primary: true,
                  onTap: () {
                    Navigator.of(context).pop();
                    onLogProgress!();
                  },
                ),
                const SizedBox(height: 6),
              ],
              _MenuRow(
                icon: Icons.insights_rounded,
                label: 'Habit details',
                onTap: () {
                  Navigator.of(context).pop();
                  onDetails();
                },
              ),
              const SizedBox(height: 6),
              _MenuRow(
                icon: Icons.tune_rounded,
                label: 'Edit habit',
                onTap: () {
                  Navigator.of(context).pop();
                  onEdit();
                },
              ),
              const SizedBox(height: 6),
              _MenuRow(
                icon: habit.paused
                    ? Icons.play_arrow_rounded
                    : Icons.pause_rounded,
                label: habit.paused ? 'Resume habit' : 'Pause habit',
                onTap: () {
                  Navigator.of(context).pop();
                  onPause();
                },
              ),
              const SizedBox(height: 12),
              HoldToConfirmButton(
                label: 'Hold to delete',
                holdingLabel: 'Keep holding…',
                onConfirm: () {
                  Navigator.of(context).pop();
                  onDelete();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: primary
              ? TideColors.lantern.withValues(alpha: 0.12)
              : TideColors.trench,
          borderRadius: TideElevation.radius12,
          border: Border.all(color: TideColors.bone.withValues(alpha: 0.06)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: primary ? TideColors.lantern : TideColors.silt),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: TideType.label)),
            if (primary)
              Icon(
                Icons.arrow_forward_rounded,
                size: 17,
                color: TideColors.lantern.withValues(alpha: 0.8),
              ),
          ],
        ),
      ),
    );
  }
}
