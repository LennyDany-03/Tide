import 'package:flutter/material.dart';

import '../../../theme/tide_colors.dart';
import '../../../theme/tide_typography.dart';
import '../../../widgets/stagger_list.dart';

/// One page of the explanation: a claim, a sentence, and the thing itself
/// running underneath.
///
/// Every explainer step is this shape. Three pages that each invent their
/// own layout read as three screens; three pages on one grid read as one
/// argument being made in three parts, which is what the flow is.
///
/// The demo gets the whole lower half and no container. Framing it in a
/// card would say "here is a picture of the app" — the point is that it is
/// not a picture, it is the same widgets doing the same thing they will do
/// on Today.
class ExplainerStep extends StatelessWidget {
  const ExplainerStep({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.body,
    required this.demo,
  });

  /// The one-word claim above the headline — "log", "hold", "read". Small,
  /// warm, and the only place in the flow where the accent touches type.
  final String eyebrow;

  final String title;
  final String body;
  final Widget demo;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StaggerColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 10,
          children: [
            Text(
              eyebrow,
              style: TideType.labelMuted.copyWith(color: TideColors.lantern),
            ),
            Text(title, style: TideType.hero),
            Text(body, style: TideType.bodyMuted),
          ],
        ),
        Expanded(child: Center(child: demo)),
      ],
    );
  }
}
