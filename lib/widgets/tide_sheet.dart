import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/tide_colors.dart';
import '../theme/tide_elevation.dart';
import '../theme/tide_motion.dart';
import '../theme/tide_typography.dart';
import 'press_scale.dart';

/// Sheet chrome: rounded top corners, floating elevation, an optional
/// header with a dismiss control.
///
/// Both sheets in the app — add/edit habit and the paywall — use this, so
/// "this is contextual and you can leave" is communicated the same way in
/// both places.
class TideSheet extends StatelessWidget {
  const TideSheet({
    super.key,
    required this.child,
    this.title,
    this.leading,
    this.onDismiss,
    this.eyebrow,
    this.footer,
    this.maxHeightFactor = 0.94,
  });

  final Widget child;
  final String? title;

  /// The morph target the FAB flies into, where there is one.
  final Widget? leading;

  final VoidCallback? onDismiss;

  /// A short line above the title — "Tide Pro". Sentence case; it names
  /// the sheet, it is not a category stamp.
  final String? eyebrow;

  /// Pinned below the scrolling body: the primary action.
  final Widget? footer;

  final double maxHeightFactor;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);

    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: media.size.height * maxHeightFactor,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: TideColors.shelf,
            borderRadius: TideElevation.sheetRadius,
            boxShadow: TideElevation.floating,
          ),
          child: ClipRRect(
            borderRadius: TideElevation.sheetRadius,
            // Sheets are pushed as bare non-opaque routes with no Scaffold,
            // so this is the Material ancestor that text fields, selection
            // toolbars and snackbars inside a sheet need.
            child: Material(
              type: MaterialType.transparency,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: TideElevation.innerHighlightWidth,
                    decoration: BoxDecoration(
                      gradient: TideElevation.innerHighlightGradient,
                    ),
                  ),
                  if (title != null || onDismiss != null || eyebrow != null)
                    _Header(
                      title: title,
                      eyebrow: eyebrow,
                      leading: leading,
                      onDismiss: onDismiss,
                    ),
                  Flexible(child: child),
                  if (footer != null)
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        20,
                        12,
                        20,
                        20 + media.padding.bottom,
                      ),
                      child: footer,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.eyebrow,
    required this.leading,
    required this.onDismiss,
  });

  final String? title;
  final String? eyebrow;
  final Widget? leading;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 14)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (eyebrow != null) ...[
                  Text(
                    eyebrow!,
                    style: TideType.sectionHeader.copyWith(
                      color: TideColors.lantern,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                if (title != null) Text(title!, style: TideType.hero),
              ],
            ),
          ),
          if (onDismiss != null) SheetDismissButton(onTap: onDismiss!),
        ],
      ),
    );
  }
}

/// The × in a sheet corner.
///
/// Plain press feedback and nothing else — the way out of a paywall must
/// never carry extra friction.
class SheetDismissButton extends StatelessWidget {
  const SheetDismissButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: TideColors.trench,
          borderRadius: TideElevation.radius12,
        ),
        child: const Icon(
          Icons.close_rounded,
          size: 18,
          color: TideColors.silt,
        ),
      ),
    );
  }
}

/// The backdrop behind a sheet: a scrim plus a real blur, so the page
/// underneath stays legible as *context* without competing for attention.
class TideBackdrop extends StatelessWidget {
  const TideBackdrop({
    super.key,
    required this.animation,
    this.onTap,
    this.blur = 12,
  });

  final Animation<double> animation;
  final VoidCallback? onTap;
  final double blur;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final t = Curves.easeOut.transform(animation.value.clamp(0.0, 1.0));
        if (t == 0) return const SizedBox.shrink();

        return GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: blur * t, sigmaY: blur * t),
            child: ColoredBox(
              color: TideColors.scrim.withValues(alpha: 0.66 * t),
              child: const SizedBox.expand(),
            ),
          ),
        );
      },
    );
  }
}

/// Sheets slide up and fade their backdrop in — used by the go_router pages
/// for add/edit and upgrade.
Widget tideSheetTransition(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondary,
  Widget child,
) {
  final curved = CurvedAnimation(
    parent: animation,
    curve: TideMotion.sheetCurve,
    reverseCurve: Curves.easeInCubic,
  );

  return Stack(
    children: [
      TideBackdrop(
        animation: curved,
        onTap: () => Navigator.of(context).maybePop(),
      ),
      SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 1),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    ],
  );
}
