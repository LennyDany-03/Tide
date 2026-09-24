import 'dart:async';

import 'task.dart';

/// Reminders for tasks, scheduled on the device.
///
/// Local rather than server pushes, so a reminder set on a plane still fires
/// on the plane. The store never schedules one reminder at a time: it hands
/// over the whole list after any change and [schedule] reconciles, so a
/// completed, deleted, re-dated or regenerated task cannot leave a stale
/// alarm behind.
///
/// In the app this is the reminder store's to-do channel
/// (`lib/services/reminders/`), which turns the list into Beacon heads-ups
/// and Lighthouse calls with the to-do defaults from Settings → Reminders.
/// Taps on a reminder are routed there too, for habits and to-dos alike.
abstract class TaskReminders {
  /// Makes the scheduled reminders match [tasks]: every future reminder on an
  /// open task, and nothing else.
  Future<void> schedule(List<Task> tasks);

  /// Removes every task reminder. For a log out.
  Future<void> clear();

  /// Asks the platform for permission to notify. True if granted.
  Future<bool> requestPermission();
}

/// Tests: reminders are kept on the task and never fire.
class NoTaskReminders implements TaskReminders {
  final List<List<Task>> scheduled = [];

  @override
  Future<void> schedule(List<Task> tasks) async => scheduled.add(tasks);

  @override
  Future<void> clear() async => scheduled.add(const []);

  @override
  Future<bool> requestPermission() async => true;
}
