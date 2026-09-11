import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show DateUtils;
import 'package:flutter_test/flutter_test.dart';
import 'package:tide/config/seed_data.dart';
import 'package:tide/services/auth/demo_auth_service.dart';
import 'package:tide/services/habits/habit_repository.dart';
import 'package:tide/services/habits/habit_rows.dart';
import 'package:tide/services/models/habit.dart';
import 'package:tide/services/models/tide_glyph.dart';
import 'package:tide/services/tide_store.dart';

/// Records what the store hands over, and lets a test play the server.
class _FakeRepository implements HabitRepository {
  _FakeRepository({List<Habit>? kept}) : kept = kept ?? SeedData.habits();

  List<Habit> kept;
  String? opened;
  bool? forgot;
  int refreshes = 0;
  final List<Habit> savedHabits = [];
  final List<(String, DateTime)> savedEntries = [];
  final List<String> removed = [];

  final StreamController<HabitChange> _changes =
      StreamController<HabitChange>.broadcast(sync: true);

  void announce(HabitChange change) => _changes.add(change);

  @override
  List<Habit> cached(String? accountId) => kept;

  @override
  Stream<HabitChange> get changes => _changes.stream;

  @override
  ValueListenable<SyncStatus> get status =>
      ValueNotifier<SyncStatus>(SyncStatus.synced);

  @override
  DateTime? get lastSynced => null;

  @override
  bool get hasPendingWrites => false;

  @override
  void open(String accountId) => opened = accountId;

  @override
  void remember(List<Habit> habits) => kept = habits;

  @override
  void saveHabit(Habit habit) => savedHabits.add(habit);

  @override
  void saveEntry(Habit habit, DateTime day) =>
      savedEntries.add((habit.id, day));

  @override
  void removeHabit(String habitId) => removed.add(habitId);

  @override
  Future<void> refresh() async => refreshes++;

  @override
  Future<void> flush() async {}

  @override
  Future<void> close({bool forget = false}) async {
    opened = null;
    forgot = forget;
  }
}

void main() {
  late _FakeRepository repository;
  late TideStore store;

  setUp(() {
    repository = _FakeRepository();
    store = TideStore(
      auth: DemoAuthService(signedIn: true),
      repository: repository,
    );
  });

  tearDown(() => store.dispose());

  group('what the store hands the server', () {
    test('a restored session opens on the device copy and follows it', () {
      expect(repository.opened, 'demo-jules');
      expect(store.habits, hasLength(4));
    });

    test('a log writes that whole day, and the device copy moves with it', () {
      final today = DateUtils.dateOnly(DateTime.now());

      store.log('no-screens');

      expect(repository.savedEntries, [('no-screens', today)]);
      expect(
        repository.kept
            .firstWhere((habit) => habit.id == 'no-screens')
            .isCompleteOn(today),
        isTrue,
      );
    });

    test('a freeze writes the spent token and the frozen day', () {
      expect(store.freeze('no-screens'), isTrue);

      expect(repository.savedHabits.single.freezesRemaining, 0);
      expect(repository.savedEntries.single.$1, 'no-screens');
    });

    test('a new habit, an edit and a delete each reach the server', () {
      final habit = Habit(
        id: store.newHabitId(),
        name: 'Stretch',
        glyph: TideGlyph.care,
        type: HabitType.binary,
        createdAt: DateTime.now(),
      );

      store
        ..addHabit(habit)
        ..updateHabit(habit.copyWith(name: 'Stretch well'))
        ..deleteHabit(habit.id);

      expect(repository.savedHabits.map((h) => h.name), [
        'Stretch',
        'Stretch well',
      ]);
      expect(repository.removed, [habit.id]);
    });

    test('pull to refresh asks the server', () async {
      await store.sync();
      expect(repository.refreshes, 1);
    });

    test('logging out lets the device copy go', () async {
      await store.logOut();

      expect(repository.opened, isNull);
      expect(repository.forgot, isTrue);
    });
  });

  group('changes from another device', () {
    test('a day logged elsewhere moves the figures here, uncelebrated', () {
      final today = DateUtils.dateOnly(DateTime.now());
      final before = store.today.completed;

      repository.announce(
        HabitEntrySaved(
          'demo-jules',
          HabitEntry(habitId: 'no-screens', day: today, amount: 1),
        ),
      );

      expect(store.today.completed, before + 1);
      expect(store.pendingHabitCue, isNull);
      expect(repository.savedEntries, isEmpty, reason: 'nothing written back');
    });

    test('an edit elsewhere keeps the history this device holds', () {
      final habit = store.habitById('morning-water')!;

      repository.announce(
        HabitSaved(
          'demo-jules',
          Habit(
            id: habit.id,
            name: 'Water',
            glyph: habit.glyph,
            type: habit.type,
            target: 10,
            unit: 'glasses',
            createdAt: habit.createdAt,
          ),
        ),
      );

      final after = store.habitById('morning-water')!;
      expect(after.name, 'Water');
      expect(after.target, 10);
      expect(after.logs, habit.logs);
    });

    test('a habit deleted elsewhere leaves', () {
      repository.announce(const HabitRemoved('demo-jules', 'read-pages'));

      expect(store.habitById('read-pages'), isNull);
      expect(store.habits, hasLength(3));
    });

    test('the server copy replaces the list and owes no celebrations', () {
      final empty = _FakeRepository(kept: const []);
      final fresh = TideStore(
        auth: DemoAuthService(signedIn: true),
        repository: empty,
      );
      addTearDown(fresh.dispose);
      expect(fresh.habits, isEmpty);

      empty.announce(HabitsReplaced('demo-jules', SeedData.habits()));

      expect(fresh.habits, hasLength(4));
      expect(fresh.unlockedMilestoneCount, greaterThan(0));
      expect(fresh.pendingCelebration, isNull);
    });

    test('a change for an account that has signed out is dropped', () async {
      await store.logOut();

      repository.announce(const HabitRemoved('demo-jules', 'read-pages'));

      expect(store.habitById('read-pages'), isNotNull);
    });
  });
}
