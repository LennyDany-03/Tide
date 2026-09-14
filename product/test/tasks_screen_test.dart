import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tide/main.dart';
import 'package:tide/services/tasks/task_scope.dart';
import 'package:tide/widgets/tide_tab_bar.dart';

import 'support/flow.dart';

/// A phone-shaped surface, so the list is not laid out on the 800x600 default.
void usePhone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1100, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

/// The To-do tab, driven the way a person uses it.
void main() {
  Future<void> openTasks(WidgetTester tester) async {
    usePhone(tester);
    await tester.pumpWidget(const TideApp(startOnboarded: true));
    await settle(tester, 900);
    await tester.tap(
      find.descendant(
        of: find.byType(TideTabBar),
        matching: find.text('To-do'),
      ),
    );
    await settle(tester);
  }

  Future<void> quickAdd(WidgetTester tester, String title) async {
    await tester.enterText(find.widgetWithText(TextField, 'Add a task'), title);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester);
  }

  /// A considered swipe: far enough to arm, slow enough not to read as a
  /// page thrown at the tab bar.
  Future<void> swipe(WidgetTester tester, String title, double dx) async {
    await tester.timedDrag(
      find.text(title),
      Offset(dx, 0),
      const Duration(milliseconds: 900),
    );
    // The card leaves, then collapses, then acts — and what it acts on (the
    // list, the snackbar) needs frames of its own after that.
    await settle(tester, 900);
    await settle(tester);
  }

  /// Lets the snackbar run out, so no timer outlives the test.
  Future<void> outlastSnackbar(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 5));
    await settle(tester);
  }

  testWidgets('sits beside Today and opens on an empty, unpressured list', (
    tester,
  ) async {
    await openTasks(tester);

    expect(tester.widget<TideTabBar>(find.byType(TideTabBar)).currentIndex, 1);
    expect(
      find.text('Nothing on your list — add something above.'),
      findsOneWidget,
    );
  });

  testWidgets('a task goes in with one field and is completed by a swipe '
      'right', (tester) async {
    await openTasks(tester);
    await quickAdd(tester, 'Buy rope');

    expect(find.text('Buy rope'), findsOneWidget);
    expect(find.textContaining('Swipe right'), findsOneWidget);

    await swipe(tester, 'Buy rope', 260);

    expect(find.text('Buy rope'), findsNothing, reason: 'folded away');
    expect(find.text('Completed'), findsOneWidget);
    expect(
      find.textContaining('Swipe right'),
      findsNothing,
      reason: 'the tip retires once the gesture has been used',
    );
    await outlastSnackbar(tester);
  });

  testWidgets('a short swipe springs back and changes nothing', (tester) async {
    await openTasks(tester);
    await quickAdd(tester, 'Buy rope');

    await swipe(tester, 'Buy rope', 50);

    expect(find.text('Buy rope'), findsOneWidget);
    expect(find.text('Completed'), findsNothing);
  });

  testWidgets('a swipe left deletes, and Undo brings it back', (tester) async {
    await openTasks(tester);
    await quickAdd(tester, 'Paint the shed');

    await swipe(tester, 'Paint the shed', -260);
    expect(find.text('Paint the shed'), findsNothing);

    await tester.tap(find.text('Undo'));
    await settle(tester);
    expect(find.text('Paint the shed'), findsOneWidget);
    await outlastSnackbar(tester);
  });

  testWidgets('the editor keeps edits without a save button', (tester) async {
    await openTasks(tester);
    await quickAdd(tester, 'Call Marco');

    await tester.tap(find.text('Call Marco'));
    await settle(tester);
    expect(find.text('Mark as complete'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, 'Call Marco'),
      'Call Marco about the mooring',
    );
    await tester.tap(find.bySemanticsLabel('Back'));
    await settle(tester);

    expect(find.text('Call Marco about the mooring'), findsOneWidget);
    final store = TaskScope.read(tester.element(find.byType(TideTabBar)));
    expect(store.open.single.title, 'Call Marco about the mooring');
  });

  testWidgets('a locked Pro control opens the paywall, not a dead end', (
    tester,
  ) async {
    await openTasks(tester);
    // The paywall's buttons are sized for real type; the test font's square
    // glyphs are wider, so the sheet gets a wider phone.
    tester.view.physicalSize = const Size(1500, 2800);
    await settle(tester);

    await tester.tap(find.bySemanticsLabel('Archive'));
    await settle(tester, 600);

    expect(find.text('Tide Pro'), findsWidgets);
  });
}
