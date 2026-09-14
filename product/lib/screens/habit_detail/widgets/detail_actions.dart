import 'package:flutter/material.dart';

import '../../../config/habit_copy.dart';
import '../../../theme/tide_colors.dart';
import '../../../theme/tide_elevation.dart';
import '../../../theme/tide_typography.dart';
import '../../../widgets/hold_to_fill.dart';
import '../../../widgets/press_scale.dart';

/// Pause, edit and delete, at the foot of the screen.
///
/// Two rows used to say only "Edit habit" and "Pause habit" in heading type
/// with a chevron each — the same chevron on a row that leaves the screen
/// and on one that acts in place, and nothing anywhere saying what pausing
/// would do to the streak. Each row now carries its consequence under its
/// name, in one grouped surface, and only the row that navigates has a
/// chevron.
///
/// Delete stays the coral hold-to-fill used in Settings and on the long-press
/// sheet, in its quiet form: words until it is held.
class DetailActions extends StatelessWidget {
  const DetailActions({
    super.key,
    required this.paused,
    required this.onEdit,
    required this.onPause,
    required this.onDelete,
  });

  final bool paused;
  final VoidCallback onEdit;
  final VoidCallback onPause;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: TideColors.shelf,
            borderRadius: TideElevation.radius20,
            border: Border.all(color: TideColors.hairline),
          ),
          child: Column(
            children: [
              _ActionRow(
                icon: paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                label: paused ? 'Resume habit' : 'Pause habit',
                detail: paused
                    ? 'Due again from today, on the streak it left.'
                    : HabitCopy.pauseExplainer,
                onTap: onPause,
              ),
              Container(
                height: 1,
                margin: const EdgeInsets.only(left: 56),
                color: TideColors.hairline,
              ),
              _ActionRow(
                icon: Icons.tune_rounded,
                label: 'Edit habit',
                detail: 'Name, schedule, target and reminder.',
                navigates: true,
                onTap: onEdit,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        HoldToConfirmButton(
          label: 'Hold to delete',
          holdingLabel: 'Keep holding…',
          quiet: true,
          onConfirm: onDelete,
        ),
        const SizedBox(height: 4),
        Text(
          'Deleting removes every mark for this habit.',
          style: TideType.labelMuted.copyWith(fontSize: 12),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.label,
    required this.detail,
    required this.onTap,
    this.navigates = false,
  });

  final IconData icon;
  final String label;
  final String detail;
  final VoidCallback onTap;

  /// Leaves the screen — earns a chevron. Pause acts in place and does not.
  final bool navigates;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onTap,
      scale: 0.985,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
        child: Row(
          children: [
            Icon(icon, size: 20, color: TideColors.silt),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label, style: TideType.heading),
                  const SizedBox(height: 3),
                  Text(detail, style: TideType.labelMuted),
                ],
              ),
            ),
            if (navigates) ...[
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: TideColors.silt.withValues(alpha: 0.7),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
