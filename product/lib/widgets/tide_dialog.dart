import 'package:flutter/material.dart';

import '../theme/tide_colors.dart';
import '../theme/tide_elevation.dart';
import '../theme/tide_motion.dart';
import '../theme/tide_typography.dart';
import 'press_scale.dart';
import 'tide_surface.dart';

/// The app's one dialog shape.
///
/// A centred panel over a plain scrim — no blur. A `BackdropFilter` is the
/// single most expensive thing this app could put on screen, and it would
/// be paying for it at the exact moment the user is trying to leave.
///
/// It arrives by scaling up a few percent and fading, over the same
/// [TideMotion.tabSwitch] every other small transition uses, so a dialog
/// reads as part of the same object rather than as a system alert borrowed
/// from somewhere else.
class TideDialogPanel extends StatelessWidget {
  const TideDialogPanel({
    super.key,
    required this.title,
    required this.body,
    required this.actions,
  });

  final String title;
  final String body;

  /// Laid out in a column, primary first. Two is the sensible maximum.
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: TideSurface(
            color: TideColors.shoal,
            floating: true,
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TideType.hero),
                const SizedBox(height: 10),
                Text(body, style: TideType.bodyMuted),
                const SizedBox(height: 22),
                for (var i = 0; i < actions.length; i++) ...[
                  if (i > 0) const SizedBox(height: 8),
                  actions[i],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A full-width row in a [TideDialogPanel].
class TideDialogAction extends StatelessWidget {
  const TideDialogAction({
    super.key,
    required this.label,
    required this.onTap,
    this.tone = TideDialogTone.neutral,
  });

  final String label;
  final VoidCallback onTap;
  final TideDialogTone tone;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch (tone) {
      TideDialogTone.primary => (TideColors.lantern, TideColors.onLantern),
      TideDialogTone.neutral => (TideColors.shelf, TideColors.bone),
      TideDialogTone.destructive => (
        TideColors.coral.withValues(alpha: 0.12),
        TideColors.coral,
      ),
    };

    return PressScale(
      onTap: onTap,
      child: Container(
        height: 50,
        width: double.infinity,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: background,
          borderRadius: TideElevation.radius12,
          border: tone == TideDialogTone.destructive
              ? Border.all(color: TideColors.coral.withValues(alpha: 0.32))
              : null,
        ),
        child: Text(label, style: TideType.button.copyWith(color: foreground)),
      ),
    );
  }
}

enum TideDialogTone { primary, neutral, destructive }

/// Shows [builder] as a Tide dialog and resolves to whatever it pops.
Future<T?> showTideDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool dismissible = true,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: dismissible,
    barrierLabel: dismissible ? MaterialLocalizations.of(context).modalBarrierDismissLabel : null,
    barrierColor: TideColors.scrim,
    transitionDuration: TideMotion.tabSwitch,
    // A dialog route is mounted straight onto the navigator, above every
    // Scaffold in the app, so there is no Material and therefore no
    // DefaultTextStyle in scope. Without one, every Text inside falls back
    // to WidgetsApp's error style and comes out with a yellow rule under
    // it — which is exactly what the discard panel was wearing. The
    // Material also gives text selection and the field overlays something
    // to attach to, should a dialog ever carry an input.
    pageBuilder: (context, animation, secondary) => Material(
      type: MaterialType.transparency,
      child: DefaultTextStyle(style: TideType.body, child: builder(context)),
    ),
    transitionBuilder: (context, animation, secondary, child) {
      final eased = CurvedAnimation(
        parent: animation,
        curve: TideMotion.tabCurve,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: eased,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.94, end: 1).animate(eased),
          child: child,
        ),
      );
    },
  );
}

/// "You have unsaved changes" — as a decision, not a footnote.
///
/// This used to be an inline strip that slid into the footer of the editor
/// and waited. Two things were wrong with it. It sat below the fold on a
/// long form, so the answer to "why will the back gesture not work" was off
/// screen; and a strip that appears in place is easy to keep ignoring,
/// which left people pressing back three or four times and concluding the
/// app was stuck.
///
/// Resolves true when the user chooses to leave.
Future<bool> confirmDiscardChanges(BuildContext context) async {
  final discard = await showTideDialog<bool>(
    context: context,
    builder: (context) => TideDialogPanel(
      title: 'Discard changes?',
      body:
          'This habit has edits that have not been saved. Leaving now '
          'loses them.',
      actions: [
        TideDialogAction(
          label: 'Keep editing',
          tone: TideDialogTone.primary,
          onTap: () => Navigator.of(context).pop(false),
        ),
        TideDialogAction(
          label: 'Discard',
          tone: TideDialogTone.destructive,
          onTap: () => Navigator.of(context).pop(true),
        ),
      ],
    ),
  );
  return discard ?? false;
}
