import 'package:flutter/widgets.dart';

import 'reminder_store.dart';

/// Hands the [ReminderStore] down the tree, beside `TideScope` and
/// `TaskScope` and above the router, so onboarding, the habit editor,
/// Settings → Reminders and Today's banner all read the same one.
class ReminderScope extends InheritedNotifier<ReminderStore> {
  const ReminderScope({
    super.key,
    required ReminderStore store,
    required super.child,
  }) : super(notifier: store);

  /// Reads and subscribes. Use in `build`.
  static ReminderStore of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ReminderScope>()!.notifier!;

  /// Reads without subscribing. Use in callbacks.
  static ReminderStore read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<ReminderScope>()!.notifier!;

  /// Null where no store is mounted — a screen pumped on its own in a test.
  static ReminderStore? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ReminderScope>()?.notifier;

  /// [read], or null where no store is mounted.
  static ReminderStore? maybeRead(BuildContext context) =>
      context.getInheritedWidgetOfExactType<ReminderScope>()?.notifier;
}
