import 'package:flutter/material.dart';

import '../../../theme/tide_colors.dart';
import '../../../theme/tide_motion.dart';
import '../../../theme/tide_typography.dart';

/// A row in a settings group.
///
/// Note what this does *not* do: no press scale, no ripple, no stagger.
/// Settings is the screen that holds back, and its press state is a quiet
/// background fade and nothing else. Knowing where not to animate is part
/// of the same discipline as knowing where to.
class SettingsRow extends StatefulWidget {
  const SettingsRow({
    super.key,
    required this.label,
    this.onTap,
    this.trailing,
    this.subtitle,
    this.destructive = false,
    this.showChevron = false,
  });

  final String label;
  final VoidCallback? onTap;
  final Widget? trailing;
  final String? subtitle;
  final bool destructive;
  final bool showChevron;

  @override
  State<SettingsRow> createState() => _SettingsRowState();
}

class _SettingsRowState extends State<SettingsRow> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.destructive
        ? TideColors.coral
        : TideColors.bone;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.onTap == null
          ? null
          : (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: TideMotion.tabSwitch,
        color: _pressed
            ? TideColors.bone.withValues(alpha: 0.04)
            : Colors.transparent,
        padding: const EdgeInsets.symmetric(vertical: 17),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.label,
                    style: TideType.heading.copyWith(color: color),
                  ),
                  if (widget.subtitle != null) ...[
                    const SizedBox(height: 3),
                    Text(widget.subtitle!, style: TideType.labelMuted),
                  ],
                ],
              ),
            ),
            if (widget.trailing != null) widget.trailing!,
            if (widget.showChevron) ...[
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: TideColors.silt,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
