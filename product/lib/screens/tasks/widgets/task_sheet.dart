import 'package:flutter/material.dart';

import '../../../theme/tide_colors.dart';
import '../../../theme/tide_elevation.dart';
import '../../../theme/tide_motion.dart';
import '../../../theme/tide_typography.dart';
import '../../../widgets/press_scale.dart';

/// Every to-do picker — due date, repeat, reminder, sort — rises from the
/// bottom in the same frame: a grabber, a title, and a list of choices.
///
/// Plain scrim, no blur, as with the habit sheet: the blur banded on some GPUs
/// and cost a `BackdropFilter` at the moment the sheet opens.
Future<T?> showTaskSheet<T>(
  BuildContext context, {
  required String title,
  required WidgetBuilder builder,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss',
    barrierColor: TideColors.scrim,
    transitionDuration: TideMotion.sheetIn,
    pageBuilder: (context, _, _) => Align(
      alignment: Alignment.bottomCenter,
      child: Material(
        type: MaterialType.transparency,
        child: _SheetFrame(
          title: title,
          child: Builder(builder: builder),
        ),
      ),
    ),
    transitionBuilder: (context, animation, _, child) => SlideTransition(
      position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
          .animate(
            CurvedAnimation(
              parent: animation,
              curve: TideMotion.sheetCurve,
              reverseCurve: Curves.easeInCubic,
            ),
          ),
      child: child,
    ),
  );
}

class _SheetFrame extends StatelessWidget {
  const _SheetFrame({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return Container(
      constraints: BoxConstraints(
        maxWidth: 520,
        maxHeight: media.size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: TideColors.shoal,
        borderRadius: TideElevation.sheetRadius,
        boxShadow: TideElevation.floating,
      ),
      child: ClipRRect(
        borderRadius: TideElevation.sheetRadius,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: TideElevation.innerHighlightWidth,
              decoration: BoxDecoration(
                gradient: TideElevation.innerHighlightGradient,
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: TideColors.bone.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 16, 22, 8),
              child: Text(title, style: TideType.hero.copyWith(fontSize: 19)),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  12,
                  4,
                  12,
                  14 + media.padding.bottom,
                ),
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One choice in a task sheet: an icon, what it is, what it resolves to.
class TaskSheetOption extends StatelessWidget {
  const TaskSheetOption({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.detail,
    this.selected = false,
    this.destructive = false,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final String? detail;
  final bool selected;

  /// Coral words and mark, for the one choice that removes something.
  final bool destructive;

  final Widget? trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ink = destructive
        ? TideColors.coral
        : selected
        ? TideColors.lantern
        : TideColors.bone;
    return PressScale(
      onTap: onTap,
      scale: 0.985,
      child: AnimatedContainer(
        duration: TideMotion.tabSwitch,
        constraints: const BoxConstraints(minHeight: 54),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? TideColors.lantern.withValues(alpha: 0.10)
              : Colors.transparent,
          borderRadius: TideElevation.radius12,
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected || destructive
                    ? ink.withValues(alpha: 0.14)
                    : TideColors.bone.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: ink),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(label, style: TideType.label.copyWith(color: ink)),
            ),
            if (detail != null) Text(detail!, style: TideType.labelMuted),
            if (trailing != null) ...[const SizedBox(width: 8), trailing!],
            if (selected && trailing == null) ...[
              const SizedBox(width: 8),
              Icon(Icons.check_rounded, size: 18, color: TideColors.lantern),
            ],
          ],
        ),
      ),
    );
  }
}
