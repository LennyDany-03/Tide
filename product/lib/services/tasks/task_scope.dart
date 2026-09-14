import 'package:flutter/widgets.dart';

import 'task_store.dart';

/// Hands the [TaskStore] down the tree, beside `TideScope` and above the
/// router, so the list tab, the editor and the archive read the same store.
///
/// A separate scope rather than a field on the habit store: a widget that
/// subscribes here rebuilds when a task changes, and no habit screen does.
class TaskScope extends InheritedNotifier<TaskStore> {
  const TaskScope({super.key, required TaskStore store, required super.child})
    : super(notifier: store);

  /// Reads and subscribes. Use in `build`.
  static TaskStore of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<TaskScope>()!.notifier!;

  /// Reads without subscribing. Use in callbacks.
  static TaskStore read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<TaskScope>()!.notifier!;
}
