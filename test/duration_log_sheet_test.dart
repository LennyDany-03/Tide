import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tide/main.dart';
import 'package:tide/screens/home/widgets/duration_log_sheet.dart';
import 'package:tide/services/tide_scope.dart';
import 'package:tide/services/tide_store.dart';

/// "Move 30 min" is the seeded duration habit. It opens the day already
/// finished, so each test clears or sets today first and then works from a
/// known starting point.
void main() {
  Future<TideStore> openShell(WidgetTester tester, {num? logged}) async {
    tester.view.physicalSize = const Size(1100, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const TideApp(startOnboarded: true));
    // Fixed pumps rather than pumpAndSettle: several screens carry
    // deliberate ambient loops that never settle by design.
    await tester.pump(const Duration(milliseconds: 900));

    final store = TideScope.read(tester.element(find.text('Move 30 min')));
    if (logged == null) {
      store.unlog('move-30');
    } else {
      store.log('move-30', amount: logged);
    }
    await tester.pump(const Duration(milliseconds: 700));
    return store;
  }

  Future<void> openSheet(WidgetTester tester) async {
    await tester.tap(find.text('Move 30 min'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  num minutesToday(TideStore store) =>
      store.habitById('move-30')!.amountOn(DateTime.now());

  /// Lets the sheet close and any completion moment play out.
  Future<void> afterMarking(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
  }

  testWidgets('a duration habit opens a dial, not the one-unit hold', (
    tester,
  ) async {
    await openShell(tester);
    await openSheet(tester);

    expect(find.byType(DurationLogSheet), findsOneWidget);
    expect(find.text('Hold to mark'), findsNothing);
    expect(find.text('Mark all 30 min'), findsOneWidget);
    expect(find.text('30 min to go'), findsOneWidget);
  });

  testWidgets('one tap marks the whole session', (tester) async {
    final store = await openShell(tester);
    await openSheet(tester);

    await tester.tap(find.text('Mark all 30 min'));
    await afterMarking(tester);

    expect(minutesToday(store), 30);
    expect(find.byType(DurationLogSheet), findsNothing);
  });

  testWidgets('a quick amount says what it will write before writing it', (
    tester,
  ) async {
    final store = await openShell(tester);
    await openSheet(tester);

    await tester.tap(find.text('+15 min'));
    await tester.pump(const Duration(milliseconds: 400));

    expect(minutesToday(store), 0, reason: 'a chip moves the dial only');
    expect(find.text('Adds 15 min'), findsOneWidget);

    await tester.tap(find.text('Mark 15 min'));
    await afterMarking(tester);

    expect(minutesToday(store), 15);
  });

  testWidgets('dragging round the dial sets the time', (tester) async {
    final semantics = tester.ensureSemantics();
    final store = await openShell(tester);
    await openSheet(tester);

    final dial = tester.getRect(find.bySemanticsLabel('Time spent today'));
    final radius = dial.width / 2 - 16;

    // Three o'clock is a quarter of 30 minutes; six o'clock is half.
    final gesture = await tester.startGesture(
      dial.center + Offset(radius, 0),
    );
    await tester.pump();
    await gesture.moveTo(dial.center + Offset(0, radius));
    await tester.pump();
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Mark 15 min'), findsOneWidget);

    await tester.tap(find.text('Mark 15 min'));
    await afterMarking(tester);
    expect(minutesToday(store), 15);

    semantics.dispose();
  });

  testWidgets('winding a finished day back says so, and writes the change', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final store = await openShell(tester, logged: 30);
    await openSheet(tester);

    expect(find.text('Done'), findsOneWidget);
    expect(find.text('Target reached for today.'), findsOneWidget);

    final dial = tester.getRect(find.bySemanticsLabel('Time spent today'));
    final radius = dial.width / 2 - 16;
    final gesture = await tester.startGesture(
      dial.center + Offset(0, radius),
    );
    await tester.pump();
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Change to 15 min'), findsOneWidget);
    expect(find.text('Takes off 15 min'), findsOneWidget);

    await tester.tap(find.text('Change to 15 min'));
    await afterMarking(tester);
    expect(minutesToday(store), 15);

    semantics.dispose();
  });

  testWidgets('the dial stops on any minute, not only on its marks', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final store = await openShell(tester);
    await openSheet(tester);

    final dial = tester.getRect(find.bySemanticsLabel('Time spent today'));
    final radius = dial.width / 2 - 16;
    // 84° round from twelve is 7 of 30 minutes — between the 5 and 10 marks,
    // where the dial used to refuse to stop.
    final angle = 84 * math.pi / 180;
    final gesture = await tester.startGesture(
      dial.center + Offset(math.sin(angle), -math.cos(angle)) * radius,
    );
    await tester.pump();
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Mark 7 min'), findsOneWidget);

    await tester.tap(find.text('Mark 7 min'));
    await afterMarking(tester);
    expect(minutesToday(store), 7);

    semantics.dispose();
  });

  group('the keypad', () {
    Future<void> press(WidgetTester tester, String key) async {
      await tester.tap(find.byKey(ValueKey('keypad-$key')));
      await tester.pump(const Duration(milliseconds: 120));
    }

    Future<void> openKeypad(WidgetTester tester) async {
      await tester.tap(find.bySemanticsLabel('Type a time'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    }

    testWidgets('tapping the figure opens it, and typed minutes are exact', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final store = await openShell(tester);
      await openSheet(tester);

      expect(find.byKey(const ValueKey('keypad-4')), findsNothing);
      await openKeypad(tester);
      expect(find.byKey(const ValueKey('keypad-4')), findsOneWidget);
      expect(find.text('+5 min'), findsNothing, reason: 'the pad replaces them');

      await press(tester, '2');
      await press(tester, '7');

      expect(find.text('Mark 27 min'), findsOneWidget);
      expect(find.text('Adds 27 min'), findsOneWidget);

      await tester.tap(find.text('Mark 27 min'));
      await afterMarking(tester);
      expect(minutesToday(store), 27);

      semantics.dispose();
    });

    testWidgets('an entry past the target is capped, and deleting it all '
        'puts the dial back', (tester) async {
      final semantics = tester.ensureSemantics();
      await openShell(tester, logged: 10);
      await openSheet(tester);
      await openKeypad(tester);

      // 1, 3, 0 is an hour and a half — well past a 30-minute habit.
      await press(tester, '1');
      await press(tester, '3');
      await press(tester, '0');

      expect(find.text('Capped at 30 min'), findsOneWidget);
      expect(find.text('Mark 30 min'), findsOneWidget);

      for (var i = 0; i < 3; i++) {
        await press(tester, 'delete');
      }
      expect(
        find.text('Mark all 30 min'),
        findsOneWidget,
        reason: 'back to the untouched 10 minutes, not forced to zero',
      );

      semantics.dispose();
    });

    testWidgets('Done closes it and keeps what was typed', (tester) async {
      final semantics = tester.ensureSemantics();
      await openShell(tester);
      await openSheet(tester);
      await openKeypad(tester);

      await press(tester, '8');
      await press(tester, 'done');
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byKey(const ValueKey('keypad-8')), findsNothing);
      expect(find.text('+5 min'), findsOneWidget);
      expect(find.text('Mark 8 min'), findsOneWidget);

      semantics.dispose();
    });

    test('reads digits the way a kitchen timer does', () {
      expect(DurationLogSheet.minutesOf(''), 0);
      expect(DurationLogSheet.minutesOf('7'), 7);
      expect(DurationLogSheet.minutesOf('45'), 45);
      expect(DurationLogSheet.minutesOf('90'), 90);
      expect(DurationLogSheet.minutesOf('130'), 90);
      expect(DurationLogSheet.minutesOf('1000'), 600);
    });
  });

  test('the marks and quick amounts scale with the target', () {
    expect(DurationLogSheet.tickEveryFor(10), 1);
    expect(DurationLogSheet.tickEveryFor(90), 5);
    expect(DurationLogSheet.tickEveryFor(240), 15);
    expect(DurationLogSheet.quickAmountsFor(10), [1, 5, 10]);
    expect(DurationLogSheet.quickAmountsFor(90), [5, 15, 30]);
  });
}
