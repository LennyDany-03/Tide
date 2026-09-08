import 'package:flutter_test/flutter_test.dart';
import 'package:tide/main.dart';

/// Morning water is the seeded quantity habit: 8 glasses a day, sitting at
/// 5 when the app opens. Its card on Today reads "5 of 8".
///
/// What these tests pin down is that the count only moves when someone asks
/// it to. The control they cover used to bank a unit on touch-down and then
/// another every 260ms for as long as it was held, so a thumb resting on the
/// button ran the target from 5 to 8 in under a second — and there was no
/// way to stop on 6, because 6 went past before you could react to it.
void main() {
  Future<void> openShell(WidgetTester tester) async {
    await tester.pumpWidget(const TideApp(startOnboarded: true));
    // Fixed pumps rather than pumpAndSettle: several screens carry
    // deliberate ambient loops that never settle by design.
    await tester.pump(const Duration(milliseconds: 900));
  }

  Future<void> openSheet(WidgetTester tester) async {
    await tester.tap(find.text('Morning water'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  /// Pumps frames until [finder] matches, or gives up.
  ///
  /// Used instead of jumping the exact length of a lap: what these tests are
  /// about is that a unit arrives once per hold, not which millisecond it
  /// lands on.
  Future<bool> pumpUntil(WidgetTester tester, Finder finder) async {
    for (var frame = 0; frame < 60; frame++) {
      if (finder.evaluate().isNotEmpty) return true;
      await tester.pump(const Duration(milliseconds: 40));
    }
    return finder.evaluate().isNotEmpty;
  }

  testWidgets('a counted habit opens its own surface rather than logging', (
    tester,
  ) async {
    await openShell(tester);
    expect(find.text('5 of 8'), findsOneWidget);

    await openSheet(tester);

    expect(find.text('of 8 glasses'), findsOneWidget);
    expect(find.text('Hold to log'), findsOneWidget);
    // Opening it logs nothing on its own.
    expect(find.text('5 of 8'), findsOneWidget);
  });

  testWidgets('touching down banks nothing, and releasing early keeps it that '
      'way', (tester) async {
    await openShell(tester);
    await openSheet(tester);

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Hold to log')),
    );

    // The press is the start of a commit now, not the commit itself.
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('5 of 8'), findsOneWidget);
    expect(find.text('Keep holding…'), findsOneWidget);

    await gesture.up();
    await tester.pump(const Duration(milliseconds: 500));
    expect(
      find.text('5 of 8'),
      findsOneWidget,
      reason: 'a part-finished lap must drain rather than round up',
    );
  });

  testWidgets('one hold banks one unit, and holding on banks no more', (
    tester,
  ) async {
    await openShell(tester);
    await openSheet(tester);

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Hold to log')),
    );

    expect(await pumpUntil(tester, find.text('6 of 8')), isTrue);

    // The finger has not moved. This is the spam the control was rebuilt to
    // stop: the lap does not restart, so the count stays on 6 however long
    // it is held.
    await tester.pump(const Duration(seconds: 4));
    expect(find.text('6 of 8'), findsOneWidget);
    expect(find.text('7 of 8'), findsNothing);
    expect(
      find.text('Lift to log another'),
      findsOneWidget,
      reason: 'a spent hold should say so rather than reading as stuck',
    );

    await gesture.up();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('6 of 8'), findsOneWidget);
  });

  testWidgets('the next unit costs another hold', (tester) async {
    await openShell(tester);
    await openSheet(tester);

    final button = tester.getCenter(find.text('Hold to log'));

    final first = await tester.startGesture(button);
    expect(await pumpUntil(tester, find.text('6 of 8')), isTrue);
    await first.up();
    await tester.pump(const Duration(milliseconds: 500));

    final second = await tester.startGesture(button);
    expect(
      await pumpUntil(tester, find.text('7 of 8')),
      isTrue,
      reason: 'a second hold should bank a second unit',
    );
    await second.up();
    await tester.pump(const Duration(milliseconds: 500));
  });

  testWidgets('the nudges move the count a unit either way', (tester) async {
    final semantics = tester.ensureSemantics();
    await openShell(tester);
    await openSheet(tester);

    await tester.tap(find.bySemanticsLabel('Log one more'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('6 of 8'), findsOneWidget);

    // Walking a count back down is the thing the hold alone cannot do, and
    // the reason an overshoot used to mean leaving the day wrong.
    await tester.tap(find.bySemanticsLabel('Log one less'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('5 of 8'), findsOneWidget);

    semantics.dispose();
  });

  testWidgets('the last unit finishes the habit and disarms the control', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await openShell(tester);
    await openSheet(tester);

    for (var i = 0; i < 3; i++) {
      await tester.tap(find.bySemanticsLabel('Log one more'));
      await tester.pump(const Duration(milliseconds: 300));
    }

    expect(find.text('All logged'), findsOneWidget);
    expect(find.text('Target reached for today.'), findsOneWidget);

    semantics.dispose();
  });

  testWidgets('a long press on a habit card raises the menu, with a route '
      'through to detail', (tester) async {
    await openShell(tester);

    // Anywhere on the card, not just the 34px ring it used to take.
    await tester.longPress(find.text('Morning water'));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Habit details'), findsOneWidget);
    expect(find.text('Edit habit'), findsOneWidget);
    expect(find.text('Pause habit'), findsOneWidget);
    expect(find.text('Hold to delete'), findsOneWidget);
  });

  testWidgets('the menu opens the habit detail screen', (tester) async {
    await openShell(tester);

    await tester.longPress(find.text('Morning water'));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.text('Habit details'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    // The menu has closed behind the push. Asserted on one of its own
    // labels rather than on an icon: the Insights tab wears the same
    // insights mark the menu's details row does, so an icon finder here
    // matches the navigation bar and never fails.
    expect(find.text('Hold to delete'), findsNothing);
    expect(find.text('Morning water'), findsWidgets);
  });
}
