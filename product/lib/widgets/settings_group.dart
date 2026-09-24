import 'package:flutter/material.dart';

import '../../../theme/tide_colors.dart';
import '../../../theme/tide_typography.dart';
import '../../../widgets/tide_surface.dart';

/// A titled group of settings rows on one raised surface.
///
/// The rows used to sit directly on the page, on the argument that habits
/// on Home were hairline rows on the ground and Settings should match. That
/// argument has expired: habits are cards now, History and Insights are
/// panels, and Settings on bare ground was the last screen still built the
/// old way — so the thing that was meant to make it look like the same
/// product was the one thing making it look like a different one.
///
/// The hairlines stay, inside the panel, separating rows. The panel is what
/// says the group is a group; the hairlines are what say where one row ends
/// and the next begins. Those are two different jobs and the spacing alone
/// was doing neither of them well.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({
    super.key,
    required this.title,
    required this.rows,
    this.destructive = false,
  });

  final String title;
  final List<Widget> rows;

  /// The heading wears coral — the danger zone, where every row in the
  /// panel is one that cannot be taken back.
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final accent = destructive ? TideColors.coral : TideColors.lantern;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Row(
            children: [
              Container(
                width: 3,
                height: 13,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 9),
              Text(
                title,
                style: TideType.label.copyWith(
                  color: destructive ? TideColors.coral : TideColors.bone,
                ),
              ),
            ],
          ),
        ),
        TideSurface(
          color: TideColors.shelf,
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0)
                  Padding(
                    // Inset from the left so the rule starts where the text
                    // does, not under the icons — a divider that cuts
                    // through a column of marks reads as a table.
                    padding: const EdgeInsets.only(left: 62),
                    child: Container(height: 1, color: TideColors.hairline),
                  ),
                rows[i],
              ],
            ],
          ),
        ),
      ],
    );
  }
}
