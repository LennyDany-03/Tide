import 'package:flutter/material.dart';

import '../../../theme/tide_colors.dart';
import '../../../theme/tide_elevation.dart';
import '../../../theme/tide_motion.dart';
import '../../../theme/tide_typography.dart';

/// A row in a settings group.
///
/// Each one leads with its own mark. A settings screen is the one place a
/// user arrives already looking for something specific, and a column of
/// left-aligned sentences is the worst possible shape to scan for a
/// specific thing — you have to read every line to rule it out. An icon per
/// row turns that into a glance, and it is the single change that separates
/// a settings screen that looks finished from one that looks like a list of
/// strings.
///
/// Note what this still does *not* do: no press scale, no ripple. Settings
/// is the screen that holds back, and its press state is a quiet background
/// fade and nothing else. Knowing where not to animate is part of the same
/// discipline as knowing where to.
class SettingsRow extends StatefulWidget {
  const SettingsRow({
    super.key,
    required this.label,
    this.icon,
    this.onTap,
    this.trailing,
    this.subtitle,
    this.destructive = false,
    this.showChevron = false,
  });

  final String label;

  /// The row's mark. Null on the rows that are not really rows — the inline
  /// cancel under a destructive confirmation.
  final IconData? icon;

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
    final tint = widget.destructive ? TideColors.coral : TideColors.bone;

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
        padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
        child: Row(
          children: [
            if (widget.icon != null) ...[
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: widget.destructive
                      ? TideColors.coral.withValues(alpha: 0.10)
                      : TideColors.bone.withValues(alpha: 0.05),
                  borderRadius: TideElevation.radius12,
                ),
                child: Icon(
                  widget.icon,
                  size: 18,
                  color: widget.destructive
                      ? TideColors.coral
                      : TideColors.silt,
                ),
              ),
              const SizedBox(width: 14),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.label,
                    style: TideType.heading.copyWith(color: tint),
                  ),
                  if (widget.subtitle != null) ...[
                    const SizedBox(height: 3),
                    Text(widget.subtitle!, style: TideType.labelMuted),
                  ],
                ],
              ),
            ),
            if (widget.trailing != null) ...[
              const SizedBox(width: 10),
              widget.trailing!,
            ],
            if (widget.showChevron) ...[
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: widget.destructive
                    ? TideColors.coral.withValues(alpha: 0.7)
                    : TideColors.silt,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
