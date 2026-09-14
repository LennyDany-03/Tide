import 'package:flutter/material.dart';

import '../../../theme/tide_colors.dart';
import '../../../theme/tide_typography.dart';
import '../../../widgets/press_scale.dart';
import '../../../widgets/tide_surface.dart';

/// One widget in the gallery: a title, a static preview of the native
/// RemoteViews layout, and the "Add to home screen" action.
class WidgetGalleryCard extends StatelessWidget {
  const WidgetGalleryCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.preview,
    required this.onAdd,
  });

  final String title;
  final String subtitle;
  final Widget preview;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return TideSurface(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TideType.sectionHeader),
          const SizedBox(height: 2),
          Text(subtitle, style: TideType.labelMuted),
          const SizedBox(height: 14),
          preview,
          const SizedBox(height: 14),
          PressScale(
            onTap: onAdd,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: TideColors.lantern,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  'Add to home screen',
                  style: TideType.gauge(13, color: TideColors.onLantern),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
