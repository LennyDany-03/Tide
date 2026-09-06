import 'package:flutter/material.dart';

import '../../../theme/tide_colors.dart';
import '../../../theme/tide_typography.dart';

/// A titled group of settings rows, hairline-separated.
///
/// The rows sit on the page rather than inside a rounded panel. Three panels
/// down a settings screen is the grouped-list convention, but this app has
/// already made its choice on the main screen — habits are hairline rows on
/// the ground — and running the same structure here means Settings reads as
/// the same product rather than as a screen borrowed from the OS. The
/// hairlines carry the grouping; the panel was drawing a box around what the
/// spacing had already separated.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({super.key, required this.title, required this.rows});

  final String title;
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(title, style: TideType.sectionHeader),
        ),
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) Container(height: 1, color: TideColors.hairline),
          rows[i],
        ],
      ],
    );
  }
}
