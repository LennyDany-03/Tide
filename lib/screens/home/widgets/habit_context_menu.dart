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

/// The long-press menu.
///
/// Floating elevation over a blurred backdrop, so it reads as lifted off the
/// page rather than as another card. Delete lives here behind the same
/// coral hold-to-fill used on Habit detail and in Settings — the gesture
/// that destroys things never changes shape.
Future<void> showHabitContextMenu(
  BuildContext context, {
  required Habit habit,
  required VoidCallback onEdit,
  required VoidCallback onPause,
  required VoidCallback onDelete,
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
                  onEdit: onEdit,
                  onPause: onPause,
                  onDelete: onDelete,
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
    required this.onEdit,
    required this.onPause,
    required this.onDelete,
  });

  final Habit habit;
  final VoidCallback onEdit;
  final VoidCallback onPause;
  final VoidCallback onDelete;

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
            boxShadow: TideElevation.floating,
          ),
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  HabitGlyph(glyph: habit.glyph, size: 16),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      habit.name,
                      style: TideType.heading,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _MenuRow(
                icon: Icons.tune_rounded,
                label: 'Edit habit',
                onTap: () {
                  Navigator.of(context).pop();
                  onEdit();
                },
              ),
              const SizedBox(height: 8),
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
              const SizedBox(height: 14),
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
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: TideColors.trench,
          borderRadius: TideElevation.radius12,
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: TideColors.silt),
            const SizedBox(width: 12),
            Text(label, style: TideType.label),
          ],
        ),
      ),
    );
  }
}
