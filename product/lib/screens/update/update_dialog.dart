import 'package:flutter/material.dart';

import '../../services/updates/update_store.dart';
import '../../theme/tide_colors.dart';
import '../../theme/tide_elevation.dart';
import '../../theme/tide_motion.dart';
import '../../theme/tide_typography.dart';
import '../../widgets/tide_dialog.dart';

/// "Tide 1.2.0 is ready": what changed, and one button that downloads,
/// verifies and installs it.
///
/// The whole update happens inside this one panel — the button becomes the
/// progress bar and the bar becomes Install — so an update reads as one
/// continuous action rather than a download notification somewhere else.
Future<void> showUpdateDialog(BuildContext context, UpdateStore store) {
  return showTideDialog<void>(
    context: context,
    // A required update cannot be waved away by tapping the scrim.
    dismissible: !store.updateRequired,
    builder: (context) => _UpdatePanel(store: store),
  );
}

class _UpdatePanel extends StatelessWidget {
  const _UpdatePanel({required this.store});

  final UpdateStore store;

  /// The first few changelog lines. A panel is not the place for all of
  /// them; the website's changelog has the rest.
  static const int _noteLimit = 5;

  String _body() {
    final notes = store.latest?.notes ?? const <String>[];
    if (notes.isEmpty) return 'A new version of Tide is ready to install.';
    final shown = notes.take(_noteLimit).map((note) => '•  $note');
    final more = notes.length - _noteLimit;
    return [...shown, if (more > 0) '…and $more more'].join('\n');
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final version = store.latest?.version;
        final busy = store.phase == UpdatePhase.downloading;

        return PopScope(
          canPop: !busy && !store.updateRequired,
          child: TideDialogPanel(
            title: version == null ? 'Update Tide' : 'Tide $version is ready',
            body: _body(),
            actions: [
              if (store.phase == UpdatePhase.failed && store.problem != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    store.problem!,
                    style: TideType.labelMuted.copyWith(
                      color: TideColors.coral,
                    ),
                  ),
                ),
              if (store.phase == UpdatePhase.needsPermission)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    'Allow Tide to install apps, then come back and tap '
                    'Install.',
                    style: TideType.labelMuted,
                  ),
                ),
              AnimatedSwitcher(
                duration: TideMotion.tabSwitch,
                child: switch (store.phase) {
                  UpdatePhase.downloading => _DownloadBar(
                    key: const ValueKey('downloading'),
                    progress: store.progress,
                  ),
                  UpdatePhase.readyToInstall ||
                  UpdatePhase.needsPermission => TideDialogAction(
                    key: const ValueKey('install'),
                    label: 'Install',
                    tone: TideDialogTone.primary,
                    onTap: store.install,
                  ),
                  UpdatePhase.failed => TideDialogAction(
                    key: const ValueKey('retry'),
                    label: 'Try again',
                    tone: TideDialogTone.primary,
                    onTap: store.downloadAndInstall,
                  ),
                  _ => TideDialogAction(
                    key: const ValueKey('update'),
                    label: 'Update now',
                    tone: TideDialogTone.primary,
                    onTap: store.downloadAndInstall,
                  ),
                },
              ),
              if (!store.updateRequired)
                AnimatedOpacity(
                  opacity: busy ? 0.4 : 1,
                  duration: TideMotion.tabSwitch,
                  child: TideDialogAction(
                    label: 'Later',
                    onTap: () {
                      if (!busy) Navigator.of(context).pop();
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// The primary action's shape, filling as the APK arrives.
class _DownloadBar extends StatelessWidget {
  const _DownloadBar({super.key, required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final percent = (progress * 100).floor();

    return Semantics(
      label: 'Downloading update',
      value: '$percent%',
      child: ClipRRect(
        borderRadius: TideElevation.radius12,
        child: Container(
          height: 50,
          color: TideColors.trench,
          child: Stack(
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(end: progress),
                duration: TideMotion.tabSwitch,
                curve: TideMotion.tabCurve,
                builder: (context, value, _) => FractionallySizedBox(
                  widthFactor: value,
                  heightFactor: 1,
                  child: ColoredBox(
                    color: TideColors.lantern.withValues(alpha: 0.28),
                  ),
                ),
              ),
              Center(
                child: Text(
                  'Downloading $percent%',
                  style: TideType.button.copyWith(color: TideColors.bone),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
