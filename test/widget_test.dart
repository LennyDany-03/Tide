import 'package:flutter_test/flutter_test.dart';
import 'package:tide/main.dart';
import 'package:tide/services/models/habit.dart';
import 'package:tide/services/models/tide_glyph.dart';
import 'package:tide/services/tide_store.dart';

void main() {
  testWidgets('Home opens on the seeded day with its hero stat', (
    tester,
  ) async {
    await tester.pumpWidget(const TideApp(startOnboarded: true));
    // Fixed pumps rather than pumpAndSettle: several screens carry
    // deliberate ambient loops that never settle by design.
    await tester.pump(const Duration(milliseconds: 900));

    expect(find.text('Today'), findsWidgets);
    expect(find.text('marked today'), findsOneWidget);
    expect(find.text('Morning water'), findsOneWidget);
    expect(find.text('No screens after 10'), findsOneWidget);
  });

  testWidgets('the tab bar carries all four destinations', (tester) async {
    await tester.pumpWidget(const TideApp(startOnboarded: true));
    await tester.pump(const Duration(milliseconds: 900));

    for (final label in ['Today', 'History', 'Insights', 'Settings']) {
      expect(find.text(label), findsWidgets, reason: '$label tab missing');
    }
  });

  testWidgets('onboarding is the first run entry point', (tester) async {
    await tester.pumpWidget(const TideApp());
    await tester.pump(const Duration(milliseconds: 900));

    expect(find.text('Tide'), findsOneWidget);
    expect(find.text('Show me how'), findsOneWidget);
    // Skip stays visible and equally weighted throughout the flow.
    expect(find.text('Skip'), findsOneWidget);
  });

  test('the seeded store matches the figures the design calls for', () {
    final store = TideStore();

    expect(store.habits, hasLength(4));
    expect(store.today.scheduled, 4);
    expect(store.today.completed, 2, reason: '2 of 4 marked today');
    expect(store.bestActiveStreak, 23);
    expect(
      store.allTimeBestStreak,
      greaterThanOrEqualTo(30),
      reason: 'Full moon must be surfaced',
    );
    expect(
      store.unlockedMilestoneCount,
      9,
      reason:
          'every streak rung up to and including Full moon, and no '
          'clean-day badge yet',
    );
  });

  /// The route draws the catalogue as one journey and puts its lantern at
  /// the first badge still locked, which is only the truth if the unlocked
  /// ones form an unbroken prefix. That holds because thresholds ascend and
  /// every clean-day badge sits after the whole streak ladder — an ordering
  /// rule with nothing in the type system to enforce it, so it is enforced
  /// here.
  test('the unlocked milestones are always a prefix of the catalogue', () {
    final statuses = TideStore().milestones;
    final firstLocked = statuses.indexWhere((status) => !status.unlocked);

    expect(firstLocked, greaterThan(0), reason: 'the seed surfaces some');
    expect(
      statuses.skip(firstLocked).every((status) => !status.unlocked),
      isTrue,
      reason: 'a badge unlocked past the first locked one would throw the '
          'route lantern to the end of the line',
    );
  });

  test('logging a habit moves the day summary and the streak', () {
    final store = TideStore();
    final habit = store.habits.firstWhere((h) => h.id == 'no-screens');
    final before = store.currentStreakOf(habit);

    store.log(habit.id);

    expect(store.today.completed, 3);
    expect(store.currentStreakOf(store.habitById('no-screens')!), before + 1);
  });

  test('a freeze holds the streak and spends a token', () {
    final store = TideStore();
    final habit = store.habitById('no-screens')!;
    final tokens = habit.freezesRemaining;

    expect(store.freeze(habit.id), isTrue);

    final after = store.habitById('no-screens')!;
    expect(after.freezesRemaining, tokens - 1);
    expect(after.isFrozenOn(DateTime.now()), isTrue);
  });

  test('the free habit limit gates the paywall', () {
    final store = TideStore();
    expect(store.canAddHabit, isTrue, reason: '4 of 5 used');

    store.addHabit(
      Habit(
        id: store.newHabitId(),
        name: 'Fifth',
        glyph: TideGlyph.dot,
        type: HabitType.binary,
        createdAt: DateTime.now(),
      ),
    );
    expect(store.canAddHabit, isFalse, reason: 'limit reached');

    store.setPreference(isPro: true);
    expect(store.canAddHabit, isTrue, reason: 'Pro lifts the ceiling');
  });
}
