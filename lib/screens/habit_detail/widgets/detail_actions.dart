import 'package:flutter/material.dart';

import '../../../theme/tide_colors.dart';
import '../../../theme/tide_typography.dart';
import '../../../widgets/hold_to_fill.dart';
import '../../../widgets/press_scale.dart';
import '../../../widgets/tide_section.dart';

/// Edit, pause and delete.
///
/// Three rows in the same shape as every other list in the app rather than a
/// block of two side-by-side buttons over a third full-width one, which put
/// the heaviest furniture on the screen underneath its quietest content.
/// Delete stays a coral hold-to-fill — identical to the one in the context
/// menu and in Settings — so the weight of the action is carried by the
/// gesture rather than by a confirmation dialog.
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
        _ActionRow(label: 'Edit habit', onTap: onEdit),
        const TideRule(),
        _ActionRow(
          label: paused ? 'Resume habit' : 'Pause habit',
          onTap: onPause,
        ),
        const TideRule(),
        const SizedBox(height: 26),
        HoldToConfirmButton(
          label: 'Hold to delete',
          holdingLabel: 'Keep holding…',
          onConfirm: onDelete,
        ),
        const SizedBox(height: 10),
        Text(
          'Deleting removes every mark for this habit.',
          style: TideType.labelMuted,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Row(
          children: [
            Expanded(child: Text(label, style: TideType.heading)),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: TideColors.silt,
            ),
          ],
        ),
      ),
    );
  }
}
