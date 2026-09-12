import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../config/seed_data.dart';
import '../models/habit.dart';
import 'habit_repository.dart';

/// Habits held in memory, for tests and for a build with no Supabase project.
///
/// Nothing is sent anywhere, so nothing ever changes from elsewhere and every
/// write is a no-op: the store's own list is already the whole truth. What it
/// does keep is each account's list for as long as the process lives, so
/// logging in again behaves the way it does against a server — until log out
/// forgets it, which the real repository does too.
///
/// An account it holds nothing for opens on the demo history. That is what
/// the demo owner signs in to, and what every test measuring the design's
/// figures reads.
class DemoHabitRepository implements HabitRepository {
  final Map<String, List<Habit>> _kept = {};

  final StreamController<HabitChange> _changes =
      StreamController<HabitChange>.broadcast();

  final ValueNotifier<SyncStatus> _status = ValueNotifier<SyncStatus>(
    SyncStatus.localOnly,
  );

  String? _open;

  @override
  List<Habit> cached(String? accountId) =>
      _kept[accountId] ?? SeedData.habits();

  @override
  Stream<HabitChange> get changes => _changes.stream;

  @override
  ValueListenable<SyncStatus> get status => _status;

  @override
  DateTime? get lastSynced => null;

  @override
  bool get hasPendingWrites => false;

  @override
  void open(String accountId) {
    _open = accountId;
  }

  @override
  void remember(List<Habit> habits) {
    final accountId = _open;
    if (accountId != null) _kept[accountId] = List.unmodifiable(habits);
  }

  @override
  void saveHabit(Habit habit) {}

  @override
  void saveEntry(Habit habit, DateTime day) {}

  @override
  void removeHabit(String habitId) {}

  @override
  Future<void> refresh() async {}

  @override
  Future<void> flush() async {}

  @override
  Future<void> close({bool forget = false}) async {
    final accountId = _open;
    _open = null;
    if (forget && accountId != null) _kept.remove(accountId);
  }
}
