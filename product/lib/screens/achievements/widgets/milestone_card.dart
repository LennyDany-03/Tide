import 'package:flutter/material.dart';

import '../../../config/milestone_art.dart';
import '../../../config/milestone_catalog.dart';
import '../../../services/models/milestone.dart';
import '../../../theme/tide_colors.dart';
import '../../../theme/tide_gradients.dart';
import '../../../theme/tide_typography.dart';
import '../../../widgets/gauge_number.dart';
import '../../../widgets/tide_logo.dart';
import 'milestone_art.dart';

/// The two shapes a card is exported in.
enum CardFormat {
  /// 9:16 — WhatsApp Status, Instagram and Facebook Stories, full screen on
  /// any phone it is sent to.
  story,

  /// 4:5 — a feed post, or a picture dropped into a chat.
  post;

  /// Laid out at this size and exported at three times it, so the image is
  /// 1080 pixels across — the width every one of those surfaces shows.
  Size get design => switch (this) {
    story => const Size(360, 640),
    post => const Size(360, 450),
  };

  double get _sceneHeight => switch (this) {
    story => 400,
    post => 250,
  };

  String get label => switch (this) {
    story => 'Story',
    post => 'Post',
  };
}

/// A milestone as a picture to post.
///
/// The scene at the top is the badge's own (see [MilestoneArtCatalog]); the
/// type underneath is the same on every card, so a run of them shared over
/// months reads as one series — a collector's number in the corner says
/// which of the twenty-eight this is.
///
/// Square-cornered on purpose. Stories and chats crop and round images
/// themselves, and corners rounded here would be exported as black wedges.
class MilestoneCard extends StatelessWidget {
  const MilestoneCard({
    super.key,
    required this.milestone,
    required this.format,
    required this.accountName,
    this.bestRun,
  });

  final Milestone milestone;
  final CardFormat format;
  final String accountName;

  /// The longest streak behind a streak badge, when there is one to show.
  final int? bestRun;

  @override
  Widget build(BuildContext context) {
    final art = MilestoneArtCatalog.of(milestone);
    final accent = MilestoneScenery.inkOf(art.primary);
    final story = format == CardFormat.story;
    final number =
        MilestoneCatalog.all.indexWhere((m) => m.id == milestone.id) + 1;

    // A fixed picture, not a screen: the reader's text size must not reflow
    // it, or the same badge would export differently from two phones.
    return MediaQuery.withNoTextScaling(
      child: SizedBox.fromSize(
        size: format.design,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: TideColors.deepWater,
            gradient: TideGradients.cardGround,
          ),
          child: Stack(
            children: [
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: format._sceneHeight,
                child: ShaderMask(
                  blendMode: BlendMode.dstIn,
                  shaderCallback: TideGradients.cardSceneFade.createShader,
                  child: MilestoneScenery(milestone: milestone),
                ),
              ),
              Positioned(
                top: 22,
                left: 24,
                right: 24,
                child: _Masthead(number: number),
              ),
              Positioned(
                left: 26,
                right: 26,
                bottom: story ? 30 : 22,
                child: _Inscription(
                  milestone: milestone,
                  accent: accent,
                  story: story,
                  accountName: accountName,
                  bestRun: bestRun,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The mark, the name, and which badge of the set this is.
class _Masthead extends StatelessWidget {
  const _Masthead({required this.number});

  final int number;

  @override
  Widget build(BuildContext context) {
    final small = TideType.gauge(12, color: TideColors.silt);
    return Row(
      children: [
        SizedBox.square(
          dimension: 22,
          child: CustomPaint(
            painter: TideLogoPainter(
              palette: TideColors.palette,
              frame: TideLogoFrame.complete,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'Tide',
          style: TideType.heading.copyWith(
            fontFamily: TideType.displayFamily,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
        const Spacer(),
        Text('No. ', style: small),
        GaugeNumber(value: number, minDigits: 2, style: small),
        Text(' / ', style: small),
        GaugeNumber(value: MilestoneCatalog.all.length, style: small),
      ],
    );
  }
}

class _Inscription extends StatelessWidget {
  const _Inscription({
    required this.milestone,
    required this.accent,
    required this.story,
    required this.accountName,
    required this.bestRun,
  });

  final Milestone milestone;
  final Color accent;
  final bool story;
  final String accountName;
  final int? bestRun;

  bool get _clean => milestone.kind == MilestoneKind.cleanDays;

  @override
  Widget build(BuildContext context) {
    final name = accountName.trim();
    final run = bestRun;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _clean ? 'Clean run surfaced' : 'Milestone surfaced',
          style: TideType.label.copyWith(fontSize: 12.5, color: accent),
        ),
        const SizedBox(height: 6),
        Text(
          milestone.name,
          maxLines: 2,
          style: TideType.screenTitle.copyWith(
            fontSize: story ? 40 : 32,
            fontWeight: FontWeight.w700,
            letterSpacing: -1.4,
          ),
        ),
        SizedBox(height: story ? 16 : 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Shrinks rather than overflows: three digits of a wide face
            // beside the unit is close to the card's width.
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.bottomLeft,
                child: GaugeNumber(
                  value: milestone.threshold,
                  style: TideType.gauge(
                    story ? 78 : 58,
                    color: accent,
                    weight: FontWeight.w700,
                    letterSpacing: -3.5,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Padding(
              padding: EdgeInsets.only(bottom: story ? 10 : 6),
              child: Text(
                _clean
                    ? 'clean days,\nno freezes'
                    : milestone.threshold == 1
                    ? 'day,\nunbroken'
                    : 'days,\nunbroken',
                style: TideType.label.copyWith(
                  color: TideColors.silt,
                  height: 1.25,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: story ? 22 : 14),
        Container(
          height: 1,
          decoration: BoxDecoration(gradient: TideGradients.hairline),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Text(
                name.isEmpty ? 'Kept on Tide' : name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TideType.label,
              ),
            ),
            if (run != null && !_clean) ...[
              Text('best run ', style: TideType.labelMuted),
              GaugeNumber(
                value: run,
                style: TideType.gauge(13, color: TideColors.bone),
              ),
              Text(' days', style: TideType.labelMuted),
            ],
          ],
        ),
      ],
    );
  }
}
