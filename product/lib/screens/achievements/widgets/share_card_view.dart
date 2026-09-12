import 'package:flutter/material.dart';

import '../../../services/models/milestone.dart';
import '../../../theme/tide_colors.dart';
import '../../../theme/tide_elevation.dart';
import '../../../theme/tide_motion.dart';
import '../../../theme/tide_typography.dart';
import '../../../widgets/habit_glyph.dart';
import '../../../widgets/tide_button.dart';
import '../../../widgets/tide_sheet.dart';

/// The shareable streak card.
///
/// The card "develops" into view — it starts washed out and low-contrast
/// and resolves over a beat, like a print coming up. That short wait is
/// what makes the image feel generated for this moment rather than fetched.
Future<void> showShareCard(
  BuildContext context, {
  required Milestone milestone,
  required int streak,
  required String accountName,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss',
    barrierColor: Colors.transparent,
    transitionDuration: TideMotion.sheetIn,
    pageBuilder: (context, animation, secondary) => const SizedBox.shrink(),
    transitionBuilder: (context, animation, secondary, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: TideMotion.sheetCurve,
        reverseCurve: Curves.easeInCubic,
      );

      return Stack(
        children: [
          TideBackdrop(
            animation: curved,
            onTap: () => Navigator.of(context).pop(),
          ),
          SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).animate(curved),
            child: _ShareSheet(
              milestone: milestone,
              streak: streak,
              accountName: accountName,
            ),
          ),
        ],
      );
    },
  );
}

class _ShareSheet extends StatelessWidget {
  const _ShareSheet({
    required this.milestone,
    required this.streak,
    required this.accountName,
  });

  final Milestone milestone;
  final int streak;
  final String accountName;

  @override
  Widget build(BuildContext context) {
    return TideSheet(
      title: milestone.name,
      eyebrow: 'Milestone',
      onDismiss: () => Navigator.of(context).pop(),
      maxHeightFactor: 0.82,
      footer: TideButton(
        label: 'Share card',
        onPressed: () {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Card ready to share.', style: TideType.label),
            ),
          );
        },
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
        child: _DevelopingCard(
          milestone: milestone,
          streak: streak,
          accountName: accountName,
        ),
      ),
    );
  }
}

class _DevelopingCard extends StatefulWidget {
  const _DevelopingCard({
    required this.milestone,
    required this.streak,
    required this.accountName,
  });

  final Milestone milestone;
  final int streak;
  final String accountName;

  @override
  State<_DevelopingCard> createState() => _DevelopingCardState();
}

class _DevelopingCardState extends State<_DevelopingCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _develop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 160), () {
      if (mounted) _develop.forward();
    });
  }

  @override
  void dispose() {
    _develop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _develop,
      builder: (context, child) {
        final t = Curves.easeOutCubic.transform(_develop.value);
        return Opacity(
          opacity: 0.25 + 0.75 * t,
          child: ColorFiltered(
            colorFilter: ColorFilter.mode(
              TideColors.deepWater.withValues(alpha: 0.55 * (1 - t)),
              BlendMode.srcATop,
            ),
            child: Transform.scale(scale: 0.97 + 0.03 * t, child: child),
          ),
        );
      },
      child: AspectRatio(
        aspectRatio: 4 / 5,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: TideElevation.radius20,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [TideColors.shelf, TideColors.deepWater],
            ),
            border: Border.all(
              color: TideColors.lantern.withValues(alpha: 0.22),
            ),
          ),
          padding: const EdgeInsets.all(26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tide', style: TideType.sectionHeader),
              const Spacer(),
              HabitGlyph(
                glyph: widget.milestone.glyph,
                size: 46,
                color: TideColors.lantern,
                strokeWidth: 2.2,
              ),
              const SizedBox(height: 22),
              Text(
                widget.milestone.name,
                style: TideType.hero.copyWith(fontSize: 30),
              ),
              const SizedBox(height: 8),
              Text(
                '${widget.streak} days, unbroken',
                style: TideType.gauge(15, color: TideColors.lantern),
              ),
              const Spacer(),
              Text(widget.accountName, style: TideType.labelMuted),
            ],
          ),
        ),
      ),
    );
  }
}
