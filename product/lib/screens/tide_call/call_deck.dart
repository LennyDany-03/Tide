import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../config/app_constants.dart';
import '../../services/device_flags.dart';
import '../../services/haptics.dart';
import '../../services/reminders/call_controller.dart';
import '../../services/reminders/reminder_plan.dart';
import '../../services/reminders/reminder_scope.dart';
import '../../theme/tide_colors.dart';
import '../../theme/tide_motion.dart';
import '../../theme/tide_palette.dart';
import '../../theme/tide_theme.dart';
import 'lighthouse_screen.dart';
import 'tide_call_screen.dart';

/// Everything ringing, one screen at a time: the habits together as one
/// Tide Call, then each to-do as its own Lighthouse.
///
/// Habits first because they share a screen and are answered together; a
/// to-do is one thing and gets the whole night to itself.
class CallDeck extends StatefulWidget {
  const CallDeck({super.key, required this.controller});

  final CallController controller;

  @override
  State<CallDeck> createState() => _CallDeckState();
}

class _CallDeckState extends State<CallDeck> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_closeIfEmpty);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_closeIfEmpty);
    super.dispose();
  }

  /// A call opened after it had already been answered elsewhere — a tap on
  /// a notification the other half of the screen dealt with — has nothing to
  /// show, and closes rather than sitting on an empty night.
  void _closeIfEmpty() {
    final controller = widget.controller;
    if (controller.loaded && controller.calls.isEmpty) {
      unawaited(controller.close());
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return PopScope(
      // Back does not answer a call. Over the lock screen it does nothing at
      // all — an alarm is not closed by a stray thumb — and inside the app it
      // puts the call away unanswered.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !controller.overLockScreen) {
          unawaited(controller.close());
        }
      },
      child: Scaffold(
        backgroundColor: TideColors.trench,
        body: ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            final calls = controller.calls;
            final habits = [
              for (final call in calls)
                if (call.kind.isHabit) call,
            ];
            final tasks = [
              for (final call in calls)
                if (!call.kind.isHabit) call,
            ];
            final Widget screen = !controller.loaded
                ? const SizedBox.expand()
                : habits.isNotEmpty
                ? TideCallScreen(
                    key: const ValueKey('habits'),
                    controller: controller,
                    calls: habits,
                  )
                : tasks.isNotEmpty
                ? LighthouseScreen(
                    key: ValueKey(tasks.first.key),
                    controller: controller,
                    call: tasks.first,
                  )
                : const SizedBox.expand();
            return AnimatedSwitcher(
              duration: TideMotion.sheetIn,
              child: screen,
            );
          },
        ),
      ),
    );
  }
}

/// The app `TideCallActivity` runs over the lock screen: the call and
/// nothing else. It has no router, no store and no account — only what the
/// phone says is ringing — so there is nothing behind it to reach without
/// unlocking.
class TideCallApp extends StatelessWidget {
  const TideCallApp({super.key, required this.controller});

  final CallController controller;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: TideTheme.current,
      builder: (context, child) => MediaQuery.withClampedTextScaling(
        minScaleFactor: 0.9,
        maxScaleFactor: 1.2,
        child: child ?? const SizedBox.shrink(),
      ),
      home: CallDeck(controller: controller),
    );
  }
}

/// The lock screen's entry point, called from `tideCallMain` in `main.dart`.
Future<void> runTideCall() async {
  WidgetsFlutterBinding.ensureInitialized();
  // The palette this device chose, so the call is drawn in the light the
  // app is. Nothing else of the app is loaded.
  final flags = await DeviceFlags.load();
  TideColors.use(TidePalettes.byId(flags.paletteId ?? ''));
  // This engine has no store to mirror the setting from, so the gate reads
  // the flag directly — haptics off in Settings stays off over the lock.
  TideHaptics.enabled = flags.haptics;
  SystemChrome.setSystemUIOverlayStyle(TideTheme.overlayStyle);
  final controller = NativeCallController();
  runApp(TideCallApp(controller: controller));
  await controller.load();
}

/// What the in-app call route is opened with.
@immutable
class CallRequest {
  const CallRequest(this.calls, {this.preview = false});

  final List<PlannedReminder> calls;

  /// A look at the design from Settings: answering it changes nothing.
  final bool preview;
}

/// A call answered inside the app — a notification tapped on iOS, or a
/// preview from Settings → Reminders.
class InAppCallPage extends StatefulWidget {
  const InAppCallPage({super.key, required this.request});

  final CallRequest request;

  @override
  State<InAppCallPage> createState() => _InAppCallPageState();
}

class _InAppCallPageState extends State<InAppCallPage> {
  late final InAppCallController _controller = InAppCallController(
    reminders: ReminderScope.read(context),
    calls: widget.request.calls,
    preview: widget.request.preview,
    onClose: () {
      if (mounted && context.canPop()) context.pop();
    },
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CallDeck(controller: _controller);
}
