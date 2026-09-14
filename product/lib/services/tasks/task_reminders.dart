import 'dart:async';

import 'task.dart';

/// Reminders for tasks, scheduled on the device.
///
/// Local notifications rather than server pushes, so a reminder set on a
/// plane still fires on the plane. The store never schedules one reminder at
/// a time: it hands over the whole list after any change and [schedule]
/// reconciles, so a completed, deleted, re-dated or regenerated task cannot
/// leave a stale alarm behind.
abstract class TaskReminders {
  /// Makes the scheduled reminders match [tasks]: every future reminder on an
  /// open task, and nothing else. [snooze] adds the snooze action (Pro).
  Future<void> schedule(List<Task> tasks, {required bool snooze});

  /// Removes every task reminder. For a log out.
  Future<void> clear();

  /// Asks the platform for permission to notify. True if granted.
  Future<bool> requestPermission();

  /// The id of a task whose reminder was tapped.
  Stream<String> get opened;
}

/// Tests, web and desktop: reminders are kept on the task and never fire.
class NoTaskReminders implements TaskReminders {
  final List<List<Task>> scheduled = [];

  @override
  Future<void> schedule(List<Task> tasks, {required bool snooze}) async =>
      scheduled.add(tasks);

  @override
  Future<void> clear() async => scheduled.add(const []);

  @override
  Future<bool> requestPermission() async => true;

  @override
  Stream<String> get opened => const Stream.empty();
}
