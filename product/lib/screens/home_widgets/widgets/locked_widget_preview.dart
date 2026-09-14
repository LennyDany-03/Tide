import 'package:flutter/material.dart';

import '../../../config/pro_features.dart';
import '../../../theme/tide_colors.dart';
import '../../../theme/tide_typography.dart';
import '../../../widgets/press_scale.dart';
import '../../../widgets/pro_lock.dart';
import '../../../widgets/tide_surface.dart';

/// The Pro widget on a free account: the same static-and-marked treatment
/// [ProBadge] already uses elsewhere, not an in-place unlock animation —
/// Android's RemoteViews has no such animation to mirror on the home screen
/// itself, so the real unlock moment is the paywall this opens into.
class LockedWidgetPreview extends StatelessWidget {
  const LockedWidgetPreview({
    super.key,
    required this.title,
    required this.feature,
  });

  final String title;
  final ProFeature feature;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: () => askForPro(context, feature),
      child: TideSurface(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(title, style: TideType.sectionHeader)),
                const ProBadge(),
              ],
            ),
            const SizedBox(height: 2),
            ProHint(feature: feature),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 28),
              decoration: BoxDecoration(
                color: TideColors.drained(TideColors.shoal, 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Icon(
                  Icons.lock_outline_rounded,
                  size: 22,
                  color: TideColors.lantern,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
