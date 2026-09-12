import 'package:flutter/foundation.dart';

import '../models/habit.dart';
import 'habit_rows.dart';

/// Where the open account's habits stand with the server.
enum SyncStatus {
  /// Nothing leaves the device: there is no project behind the app.
  localOnly,

  /// Reading the account, or sending writes.
  syncing,

  /// The server holds every write this device has made.
  synced,

  /// The server could not be reached. Writes wait on the device and go out
  /// when it can be.
  offline,
}

/// A change to the open account's habits that did not start in this app — a
/// tap on another device, or the server's copy arriving.
@immutable
sealed class HabitChange {
  const HabitChange(this.accountId);

  /// Whose habits these are. The store drops a change for an account that
  /// has since signed out.
  final String accountId;
}

/// The server's whole copy of the account. Only sent while nothing is waiting
/// to be written, so it never steps back over a change made here.
final class HabitsReplaced extends HabitChange {
  const HabitsReplaced(super.accountId, this.habits);

  final List<Habit> habits;
}

/// A habit's settings, created or edited elsewhere. It carries no history:
/// the days the store already holds for the habit are kept.
final class HabitSaved extends HabitChange {
  const HabitSaved(super.accountId, this.habit);

  final Habit habit;
}

final class HabitRemoved extends HabitChange {
  const HabitRemoved(super.accountId, this.habitId);

  final String habitId;
}

/// One day of one habit, logged, frozen or undone elsewhere.
final class HabitEntrySaved extends HabitChange {
  const HabitEntrySaved(super.accountId, this.entry);

  final HabitEntry entry;
}

/// The seam between `TideStore` and wherever habits are kept.
///
/// Two implementations: `SupabaseHabitRepository` for a real build, and
/// `DemoHabitRepository` for tests and for a build with no project
/// configured.
///
/// The store stays the source of truth for what is on screen. It changes its
/// own list first — a log lands under the finger, not after a round trip —
/// and then tells the repository what changed. Everything after that belongs
/// here: getting the write to the server eventually, keeping a copy on the
/// device, and reporting what changed somewhere else as a [HabitChange].
///
/// Writes address the account passed to [open] and are ignored while none is
/// open, so the store never has to guard them.
abstract class HabitRepository {
  /// What this device already holds for [accountId], synchronously, so a
  /// restored session draws its habits on the first frame rather than an
  /// empty Today. [accountId] is null before anyone has signed in.
  List<Habit> cached(String? accountId);

  /// Every [HabitChange] for the open account.
  Stream<HabitChange> get changes;

  ValueListenable<SyncStatus> get status;

  /// When the server last confirmed this device's copy. Null until it has.
  DateTime? get lastSynced;

  /// Whether writes are still waiting to be sent.
  bool get hasPendingWrites;

  /// Starts following [accountId]: sends what it still owes, reads the
  /// account, and listens for changes. Closes whichever account was open.
  void open(String accountId);

  /// Keeps [habits] as this device's copy of the open account.
  void remember(List<Habit> habits);

  void saveHabit(Habit habit);

  /// Writes what [habit] holds on [day] — the amount logged and the freeze,
  /// together.
  void saveEntry(Habit habit, DateTime day);

  void removeHabit(String habitId);

  /// Sends what is owed, then reads the account back. Resolves once both are
  /// done or have failed; never throws.
  Future<void> refresh();

  /// Sends what is owed. Resolves once the queue is empty or cannot be emptied
  /// now; never throws.
  Future<void> flush();

  /// Stops following the open account. [forget] also drops this device's copy
  /// and anything still queued — for a log out, where the next person to pick
  /// up the phone should not find either.
  Future<void> close({bool forget = false});
}
