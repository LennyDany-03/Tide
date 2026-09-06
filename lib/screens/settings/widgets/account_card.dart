import 'package:flutter/material.dart';

import '../../../config/app_constants.dart';
import '../../../theme/tide_colors.dart';
import '../../../theme/tide_elevation.dart';
import '../../../theme/tide_typography.dart';
import '../../../widgets/press_scale.dart';

/// Who is signed in, which plan they are on, and the way to Pro.
class AccountCard extends StatelessWidget {
  const AccountCard({
    super.key,
    required this.name,
    required this.isPro,
    required this.habitCount,
    required this.onUpgrade,
  });

  final String name;
  final bool isPro;
  final int habitCount;
  final VoidCallback onUpgrade;

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }

  String get _plan => isPro
      ? 'Tide Pro, unlimited habits'
      : 'Free plan, $habitCount of ${AppConstants.freeHabitLimit} habits';

  @override
  Widget build(BuildContext context) {
    return Row(
        children: [
        Container(
          width: 46,
          height: 46,
          decoration: const BoxDecoration(
            color: TideColors.shelf,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              _initials,
              style: TideType.gauge(15, color: TideColors.bone),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                name,
                style: TideType.hero.copyWith(fontSize: 19),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(_plan, style: TideType.labelMuted),
            ],
          ),
        ),
        if (!isPro)
          PressScale(
            onTap: onUpgrade,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                // Outlined rather than filled: it is an invitation, not the
                // primary action on the screen.
                border: Border.all(
                  color: TideColors.lantern.withValues(alpha: 0.45),
                ),
                borderRadius: TideElevation.radius12,
              ),
              child: Text(
                'Go Pro',
                style: TideType.label.copyWith(color: TideColors.lantern),
              ),
            ),
          ),
      ],
    );
  }
}
