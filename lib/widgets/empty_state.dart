import 'package:flutter/material.dart';

import '../theme/tide_colors.dart';
import '../theme/tide_typography.dart';
import 'tide_ring.dart';

/// A genuine empty state rather than a blank page.
///
/// The breathing outline of the tide ring keeps the screen alive while
/// there is nothing in it, and it is the same ring the first habit will fill
/// — so the empty state is a preview of the thing you are about to make,
/// not an apology for its absence.
class TideEmptyState extends StatelessWidget {
  const TideEmptyState({
    super.key,
    required this.title,
    required this.body,
    this.action,
    this.ringSize = 108,
  });

  final String title;
  final String body;
  final Widget? action;
  final double ringSize;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TideRingBreathing(size: ringSize, strokeWidth: 3),
            const SizedBox(height: 28),
            Text(title, style: TideType.hero, textAlign: TextAlign.center),
            const SizedBox(height: 10),
            Text(body, style: TideType.bodyMuted, textAlign: TextAlign.center),
            if (action != null) ...[const SizedBox(height: 22), action!],
          ],
        ),
      ),
    );
  }
}

/// A quieter variant for empty regions inside a populated screen — an
/// unscheduled day in the calendar sheet, a week with no data on Insights.
class TideEmptyNote extends StatelessWidget {
  const TideEmptyNote({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 26),
      child: Center(
        child: Text(
          message,
          style: TideType.labelMuted.copyWith(color: TideColors.silt),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
