import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../../services/models/milestone.dart';
import '../../../services/share/card_share.dart';
import '../../../theme/tide_colors.dart';
import '../../../theme/tide_elevation.dart';
import '../../../theme/tide_motion.dart';
import '../../../theme/tide_typography.dart';
import '../../../widgets/press_scale.dart';
import '../../../widgets/segmented_pill.dart';
import '../../../widgets/tide_button.dart';
import '../../../widgets/tide_sheet.dart';
import 'milestone_card.dart';

/// The shareable milestone card, and the ways out of the app with it.
///
/// The card "develops" into view — it starts washed out and low-contrast
/// and resolves over a beat, like a print coming up. That short wait is
/// what makes the image feel generated for this moment rather than fetched.
///
/// What is sent is the card exactly as previewed, rendered again at 1080
/// pixels across: the preview is the export, so nothing can look different
/// once it lands in a story.
Future<void> showShareCard(
  BuildContext context, {
  required Milestone milestone,
  required String accountName,
  int? bestRun,
  CardShare? share,
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
              accountName: accountName,
              bestRun: bestRun,
              share: share ?? CardShare.platform(),
            ),
          ),
        ],
      );
    },
  );
}

class _ShareSheet extends StatefulWidget {
  const _ShareSheet({
    required this.milestone,
    required this.accountName,
    required this.bestRun,
    required this.share,
  });

  final Milestone milestone;
  final String accountName;
  final int? bestRun;
  final CardShare share;

  @override
  State<_ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends State<_ShareSheet> {
  CardFormat _format = CardFormat.story;

  /// One key per format: while the switcher crossfades the two, both cards
  /// are in the tree at once.
  final Map<CardFormat, GlobalKey> _cards = {
    for (final format in CardFormat.values) format: GlobalKey(),
  };

  Set<ShareTarget>? _targets;
  ShareTarget? _busy;
  bool _saved = false;
  String? _note;

  @override
  void initState() {
    super.initState();
    widget.share.targets().then((targets) {
      if (mounted) setState(() => _targets = targets);
    });
  }

  String get _caption {
    final m = widget.milestone;
    final days = m.threshold == 1 ? 'day' : 'days';
    return m.kind == MilestoneKind.cleanDays
        ? '${m.name}: ${m.threshold} $days without spending a freeze. '
              'Kept on Tide.'
        : '${m.name}: ${m.threshold} $days in a row. Kept on Tide.';
  }

  /// The card as a PNG in the directory the other app may read from.
  Future<File> _render() async {
    // A tap in the same frame as a format switch would otherwise capture a
    // card that has not painted yet.
    await WidgetsBinding.instance.endOfFrame;
    final boundary =
        _cards[_format]!.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
    final image = await boundary.toImage(
      pixelRatio: 1080 / _format.design.width,
    );
    try {
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      final directory = await widget.share.directory();
      final file = File(
        '${directory.path}/tide-${widget.milestone.id}-${_format.name}.png',
      );
      await file.writeAsBytes(png!.buffer.asUint8List(), flush: true);
      return file;
    } finally {
      image.dispose();
    }
  }

  Future<void> _send(ShareTarget target) async {
    if (_busy != null) return;
    setState(() {
      _busy = target;
      _note = null;
    });
    var sent = false;
    try {
      sent = await widget.share.send(
        target,
        await _render(),
        caption: _caption,
      );
    } on Exception catch (error) {
      debugPrint('Milestone card share failed: $error');
    }
    if (!mounted) return;
    setState(() {
      _busy = null;
      if (target == ShareTarget.save && sent) _saved = true;
      _note = !sent
          ? target == ShareTarget.save
                ? 'Could not save the card. Try More ways to share.'
                : 'Could not open that app. Try More ways to share.'
          : target == ShareTarget.save
          ? 'Saved to Pictures/Tide.'
          : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return TideSheet(
      title: widget.milestone.name,
      eyebrow: 'Milestone',
      onDismiss: () => Navigator.of(context).pop(),
      maxHeightFactor: 0.94,
      footer: _footer(),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 2, 20, 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SegmentedPill(
              labels: [for (final format in CardFormat.values) format.label],
              selectedIndex: _format.index,
              height: 38,
              onChanged: (i) => setState(() {
                _format = CardFormat.values[i];
                _saved = false;
                _note = null;
              }),
            ),
            const SizedBox(height: 14),
            Flexible(
              child: _DevelopingCard(
                child: AnimatedSwitcher(
                  duration: TideMotion.tabSwitch,
                  child: FittedBox(
                    key: ValueKey(_format),
                    child: DecoratedBox(
                      position: DecorationPosition.foreground,
                      decoration: BoxDecoration(
                        borderRadius: TideElevation.radius20,
                        border: Border.all(color: TideColors.hairline),
                      ),
                      // Rounded on screen only: the boundary inside the clip
                      // is what gets exported, square.
                      child: ClipRRect(
                        borderRadius: TideElevation.radius20,
                        child: RepaintBoundary(
                          key: _cards[_format],
                          child: MilestoneCard(
                            milestone: widget.milestone,
                            format: _format,
                            accountName: widget.accountName,
                            bestRun: widget.bestRun,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _footer() {
    final targets = _targets;
    if (targets != null && targets.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Text(
          'Sharing works in the Android app.',
          textAlign: TextAlign.center,
          style: TideType.labelMuted,
        ),
      );
    }

    final quick = [
      for (final target in const [
        ShareTarget.whatsapp,
        ShareTarget.instagram,
        ShareTarget.messages,
        ShareTarget.save,
      ])
        if (targets?.contains(target) ?? false) target,
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (quick.isNotEmpty)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (final target in quick)
                _TargetButton(
                  target: target,
                  busy: _busy == target,
                  done: target == ShareTarget.save && _saved,
                  onTap: () => _send(target),
                ),
            ],
          ),
        AnimatedSize(
          duration: TideMotion.tabSwitch,
          curve: TideMotion.tabCurve,
          child: _note == null
              ? const SizedBox(width: double.infinity, height: 16)
              : Padding(
                  padding: const EdgeInsets.fromLTRB(0, 12, 0, 12),
                  child: Text(
                    _note!,
                    textAlign: TextAlign.center,
                    style: TideType.labelMuted,
                  ),
                ),
        ),
        TideButton(
          label: 'More ways to share',
          phase: _busy == ShareTarget.more
              ? TideButtonPhase.busy
              : TideButtonPhase.idle,
          enabled: targets != null,
          icon: Icon(
            Icons.ios_share,
            size: 19,
            color: targets != null ? TideColors.onLantern : TideColors.silt,
          ),
          onPressed: () => _send(ShareTarget.more),
        ),
      ],
    );
  }
}

/// One app to send the card to: a round mark and its name.
class _TargetButton extends StatelessWidget {
  const _TargetButton({
    required this.target,
    required this.busy,
    required this.done,
    required this.onTap,
  });

  final ShareTarget target;
  final bool busy;
  final bool done;
  final VoidCallback onTap;

  /// Plain marks rather than the apps' logos: their colours are theirs, and
  /// a row of four brand colours would be the loudest thing on the sheet.
  (IconData, String) get _face => switch (target) {
    ShareTarget.whatsapp => (Icons.chat_bubble_outline_rounded, 'WhatsApp'),
    ShareTarget.instagram => (Icons.camera_alt_outlined, 'Instagram'),
    ShareTarget.messages => (Icons.sms_outlined, 'Messages'),
    ShareTarget.save => (Icons.download_rounded, 'Save'),
    ShareTarget.more => (Icons.ios_share, 'More'),
  };

  @override
  Widget build(BuildContext context) {
    final (icon, label) = _face;
    return Semantics(
      button: true,
      label: target == ShareTarget.save ? 'Save card' : 'Share to $label',
      excludeSemantics: true,
      child: PressScale(
        onTap: onTap,
        child: SizedBox(
          width: 72,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: done
                      ? TideColors.lantern.withValues(alpha: 0.14)
                      : TideColors.shoal,
                  border: Border.all(
                    color: done
                        ? TideColors.lantern.withValues(alpha: 0.6)
                        : TideColors.hairline,
                  ),
                ),
                child: busy
                    ? TideSpinner(size: 20, color: TideColors.lantern)
                    : Icon(
                        done ? Icons.check_rounded : icon,
                        size: 22,
                        color: done ? TideColors.lantern : TideColors.bone,
                      ),
              ),
              const SizedBox(height: 7),
              Text(
                done ? 'Saved' : label,
                maxLines: 1,
                style: TideType.labelMuted.copyWith(fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DevelopingCard extends StatefulWidget {
  const _DevelopingCard({required this.child});

  final Widget child;

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
      child: widget.child,
    );
  }
}
