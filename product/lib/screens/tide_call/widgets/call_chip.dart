import 'package:flutter/material.dart';

import '../../../theme/tide_colors.dart';
import '../../../theme/tide_typography.dart';
import '../../../widgets/press_scale.dart';

/// A small button under a call — the way to do what the gestures do, for a
/// screen reader, a gloved hand, or anybody who would rather tap.
///
/// Every gesture on a call has one of these. They are quiet on purpose: the
/// gesture is the main way in, and three bright buttons under it would make
/// the call a form.
class CallChip extends StatelessWidget {
  const CallChip({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.accent = false,
    this.enabled = true,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  /// The one chip that means "yes", tinted in the accent.
  final bool accent;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final ink = !enabled
        ? TideColors.silt.withValues(alpha: 0.5)
        : accent
        ? TideColors.lantern
        : TideColors.bone;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: ExcludeSemantics(
        child: PressScale(
          enabled: enabled,
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: TideColors.shelf.withValues(alpha: 0.82),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: accent && enabled
                    ? TideColors.lantern.withValues(alpha: 0.45)
                    : TideColors.hairline,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: ink),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TideType.label.copyWith(color: ink, fontSize: 13.5),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "Dismiss", under everything: heard, and nothing more.
class CallDismiss extends StatelessWidget {
  const CallDismiss({super.key, required this.onTap, this.label = 'Dismiss'});

  final VoidCallback onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: ExcludeSemantics(
        child: PressScale(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Text(label, style: TideType.labelMuted),
          ),
        ),
      ),
    );
  }
}

/// "Test · nothing changes", on a call fired from Settings.
class CallTestBadge extends StatelessWidget {
  const CallTestBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: TideColors.lantern.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        'Test · nothing will change',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TideType.labelMuted.copyWith(
          color: TideColors.lantern,
          fontSize: 12,
        ),
      ),
    );
  }
}
