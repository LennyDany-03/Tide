import 'package:flutter_test/flutter_test.dart';
import 'package:tide/main.dart';

/// Morning water is the seeded quantity habit: 8 glasses a day, sitting at
/// 5 when the app opens. Its row on Today reads "5 of 8".
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
  /// about is that units arrive one at a time, not which millisecond each
  /// one lands on.
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

  testWidgets('holding counts the units out one at a time', (tester) async {
    await openShell(tester);
    await openSheet(tester);

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Hold to log')),
    );

    // Touching down is worth exactly one — which is what makes a plain tap a
    // single glass, and what the old single sweep could not do: it banked
    // all three remaining glasses or none of them.
    expect(await pumpUntil(tester, find.text('6 of 8')), isTrue);
    expect(find.text('8 of 8'), findsNothing);

    // Then one more per lap, with the day never skipping a number.
    expect(
      await pumpUntil(tester, find.text('7 of 8')),
      isTrue,
      reason: 'the count should climb one glass at a time',
    );
    expect(
      await pumpUntil(tester, find.text('All logged')),
      isTrue,
      reason: 'the eighth glass should finish the habit',
    );

    // And it stops there. Holding on past the target must not keep counting
    // into a day that is already done.
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('All logged'), findsOneWidget);

    await gesture.up();
    await tester.pump(const Duration(milliseconds: 400));
  });

  testWidgets('lifting keeps what was counted and nothing more', (
    tester,
  ) async {
    await openShell(tester);
    await openSheet(tester);

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Hold to log')),
    );
    expect(await pumpUntil(tester, find.text('7 of 8')), isTrue);
    await gesture.up();

    // The part-finished lap drains away rather than rounding up into a
    // glass that was never held for.
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('7 of 8'), findsOneWidget);
  });
}
