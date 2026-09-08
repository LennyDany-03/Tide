import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tide/main.dart';
import 'package:tide/services/tide_store.dart';
import 'package:tide/widgets/tide_button.dart';
import 'package:tide/widgets/tide_mark.dart';

/// Fixed pumps throughout rather than `pumpAndSettle`: onboarding runs a
/// drifting backdrop, an orbiting mark and three looping demos, and the
/// tour breathes a ring around its spotlight. None of them ever settle, by
/// design.
Future<void> settle(WidgetTester tester, [int ms = 700]) async {
  await tester.pump();
  await tester.pump(Duration(milliseconds: ms));
  // A timed pump advances the clock in one jump, so anything built during
  // that frame — a page arriving under the scroll, a step's staggered copy —
  // schedules its entrance timer relative to the clock *after* the jump. One
  // more pump flushes those, which is also what stops them being reported as
  // pending timers when the tree is torn down. Long enough to clear the
  // slowest of them: the welcome copy, which waits out the ring at 760ms.
  await tester.pump(const Duration(milliseconds: 1200));
}

/// Walks the explanation and lands on the auth form, which opens on log in.
Future<void> reachAuth(WidgetTester tester) async {
  await tester.pumpWidget(const TideApp());
  await settle(tester, 900);

  await tester.tap(find.text('Show me how'));
  await settle(tester);
  for (var i = 0; i < 3; i++) {
    await tester.tap(find.text('Next'));
    await settle(tester);
  }
  await tester.tap(find.text('Get started'));
  await settle(tester, 900);
}

/// Presses one of the account form's buttons, scrolling it into view first.
/// The form is longer than a short window, and the mode switch is pinned
/// across the bottom of it.
Future<void> pressAuthButton(WidgetTester tester, String label) async {
  final target = find.widgetWithText(TideButton, label);
  await tester.ensureVisible(target);
  await settle(tester, 200);
  await tester.tap(target);
  await settle(tester);
}

/// And crosses over to the sign-up half of it.
Future<void> reachSignUp(WidgetTester tester) async {
  await reachAuth(tester);
  await tester.tap(find.text('Create one'));
  await settle(tester);
}

/// Fills the sign-up form and waits out the button's fake round trip.
///
/// Assumes the form is already in sign-up mode — see [reachSignUp].
Future<void> signUp(
  WidgetTester tester, {
  String name = 'Sam Reyes',
  String email = 'sam@example.com',
  String password = 'seawater88',
}) async {
  final fields = find.byType(TextField);
  await tester.enterText(fields.at(0), name);
  await tester.enterText(fields.at(1), email);
  await tester.enterText(fields.at(2), password);
  await tester.pump();

  await pressAuthButton(tester, 'Create account');
  // Busy, then the checkmark, then the route change.
  await settle(tester, 700);
  await settle(tester, 500);
  await settle(tester, 600);
}

void main() {
  group('onboarding explains the product', () {
    testWidgets('opens on the mark and offers no back on the first page', (
      tester,
    ) async {
      await tester.pumpWidget(const TideApp());
      await settle(tester, 900);

      expect(find.text('Tide'), findsOneWidget);
      expect(find.text('Show me how'), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);
      expect(
        find.byIcon(Icons.arrow_back_rounded),
        findsNothing,
        reason: 'nothing to go back to on page one',
      );
    });

    testWidgets('the middle pages demonstrate rather than configure', (
      tester,
    ) async {
      await tester.pumpWidget(const TideApp());
      await settle(tester, 900);

      await tester.tap(find.text('Show me how'));
      await settle(tester);
      expect(find.text('One swipe, and the day is done'), findsOneWidget);

      await tester.tap(find.text('Next'));
      await settle(tester);
      expect(find.text('A missed day does not undo you'), findsOneWidget);

      await tester.tap(find.text('Next'));
      await settle(tester);
      expect(find.text('The shape shows up over weeks'), findsOneWidget);

      // The wizard steps are gone, not merely reworded.
      expect(find.text('What should we track?'), findsNothing);
      expect(find.text('Set the rhythm'), findsNothing);
      expect(find.text('One nudge a day'), findsNothing);
    });

    testWidgets('nudging a page does not restart its entrance', (tester) async {
      await tester.pumpWidget(const TideApp());
      await settle(tester, 900);

      // The mark owns the welcome step's entrance. If its State survives, so
      // did the ring it had already finished drawing.
      final before = tester.state(find.byType(TideMark));

      // A drag too short to turn the page, which springs back to where it
      // started — the gesture that used to rebuild the whole step twice, once
      // on the way out and once on the way back.
      await tester.drag(find.byType(PageView), const Offset(-40, 0));
      await settle(tester);

      expect(
        find.text('Show me how'),
        findsOneWidget,
        reason: 'still page one',
      );
      expect(
        tester.state(find.byType(TideMark)),
        same(before),
        reason: 'the mark was rebuilt from scratch, so its draw-in replayed',
      );
    });

    testWidgets('back walks the flow instead of leaving it', (tester) async {
      await tester.pumpWidget(const TideApp());
      await settle(tester, 900);

      await tester.tap(find.text('Show me how'));
      await settle(tester);
      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await settle(tester);

      expect(find.text('Show me how'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back_rounded), findsNothing);
    });

    testWidgets('the last page hands off to the account form', (tester) async {
      await reachAuth(tester);

      // Log in first: most people reaching this screen have been here
      // before, and handing a returning user a sign-up form every time is
      // the wrong default.
      expect(find.text('Welcome back'), findsOneWidget);
      expect(find.widgetWithText(TideButton, 'Log in'), findsOneWidget);
    });

    testWidgets('skip goes to the form, not straight into the app', (
      tester,
    ) async {
      await tester.pumpWidget(const TideApp());
      await settle(tester, 900);

      await tester.tap(find.text('Skip'));
      await settle(tester, 900);

      expect(find.text('Welcome back'), findsOneWidget);
    });
  });

  group('the account form', () {
    testWidgets('refuses an incomplete sign-up and says which field', (
      tester,
    ) async {
      await reachSignUp(tester);

      await pressAuthButton(tester, 'Create account');

      expect(find.text('What should we call you?'), findsOneWidget);
      expect(find.text('Email is required'), findsOneWidget);
      expect(find.text('Password is required'), findsOneWidget);
      expect(
        find.text('Start your first loop'),
        findsOneWidget,
        reason: 'still on the form',
      );
    });

    testWidgets('catches a malformed email and a short password', (
      tester,
    ) async {
      await reachSignUp(tester);

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'Sam');
      await tester.enterText(fields.at(1), 'sam-at-example');
      await tester.enterText(fields.at(2), 'short');
      await tester.pump();

      await pressAuthButton(tester, 'Create account');

      expect(find.text('That does not look like an email'), findsOneWidget);
      expect(find.text('Use at least 8 characters'), findsOneWidget);
    });

    testWidgets('crossing to sign-up adds the name field, and back', (
      tester,
    ) async {
      await reachAuth(tester);
      expect(find.byType(TextField), findsNWidgets(2));

      await tester.tap(find.text('Create one'));
      await settle(tester);

      expect(find.byType(TextField), findsNWidgets(3));
      expect(find.text('Start your first loop'), findsOneWidget);

      await tester.tap(find.text('Log in'));
      await settle(tester);

      expect(find.byType(TextField), findsNWidgets(2));
      expect(find.text('Welcome back'), findsOneWidget);
    });
  });

  group('signing up opens an empty Today with a tour', () {
    testWidgets('the app arrives blank', (tester) async {
      await reachSignUp(tester);
      await signUp(tester);

      expect(find.text('Today'), findsWidgets);
      expect(
        find.text('No habits yet'),
        findsOneWidget,
        reason: 'a new account starts with nothing in it',
      );
      expect(
        find.text('Morning water'),
        findsNothing,
        reason: 'the demo history belongs to the returning account',
      );
    });

    testWidgets('the tour lights the first stop and can be walked', (
      tester,
    ) async {
      await reachSignUp(tester);
      await signUp(tester);

      // The overlay waits for Today to paint before closing in on it.
      await settle(tester, 900);
      expect(find.text('This is Today'), findsOneWidget);
      expect(find.text('1 of 5'), findsOneWidget);

      await tester.tap(find.widgetWithText(TideButton, 'Next'));
      await settle(tester, 900);
      expect(find.text('The day, as one figure'), findsOneWidget);
      expect(find.text('2 of 5'), findsOneWidget);
    });

    testWidgets('skipping the tour leaves Today usable', (tester) async {
      await reachSignUp(tester);
      await signUp(tester);
      await settle(tester, 900);

      await tester.tap(find.text('Skip tour'));
      await settle(tester);

      expect(find.text('This is Today'), findsNothing);
      expect(find.text('No habits yet'), findsOneWidget);
    });
  });

  group('the store behind the form', () {
    test('signing up clears the demo history and arms the tour', () {
      final store = TideStore();
      expect(store.habits, isNotEmpty);
      expect(store.tourPending, isFalse);

      store.signUp(name: '  Sam Reyes  ', email: 'sam@example.com');

      expect(store.habits, isEmpty);
      expect(store.today.scheduled, 0);
      expect(store.unlockedMilestoneCount, 0);
      expect(store.tourPending, isTrue);
      expect(store.signedIn, isTrue);
      expect(store.onboardingComplete, isTrue);
      expect(store.accountName, 'Sam Reyes', reason: 'trimmed for the avatar');
    });

    test('an unnamed sign-up still has something to call the account', () {
      final store = TideStore()..signUp(name: '   ', email: 'a@b.co');
      expect(store.accountName, 'You');
    });

    test('logging in keeps the history and raises no tour', () {
      final store = TideStore()..signIn(email: 'jules@tide.app');

      expect(store.habits, hasLength(4));
      expect(store.tourPending, isFalse);
      expect(store.signedIn, isTrue);
    });

    test('finishing the tour is idempotent', () {
      final store = TideStore()..signUp(name: 'Sam', email: 'a@b.co');

      var notifications = 0;
      store.addListener(() => notifications++);

      store.finishTour();
      store.finishTour();

      expect(store.tourPending, isFalse);
      expect(notifications, 1, reason: 'the second call is a no-op');
    });
  });
}
