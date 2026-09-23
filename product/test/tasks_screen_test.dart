import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tide/main.dart';
import 'package:tide/services/tasks/task.dart';
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

  testWidgets('the archive opens straight from the header', (tester) async {
    // This used to be the one gated control on the screen: tapping Archive
    // raised the paywall. Tide is free, so it opens the archive itself.
    await openTasks(tester);
    tester.view.physicalSize = const Size(1500, 2800);
    await settle(tester);

    await tester.tap(find.bySemanticsLabel('Archive'));
    await settle(tester, 600);

    expect(find.text('Archive'), findsWidgets);
    expect(find.text('Tide Pro'), findsNothing);
  });

  testWidgets('the Undo bar leaves by itself', (tester) async {
    // A snackbar with an action persists by default since Flutter 3.29, so
    // "Task deleted. Undo" used to sit over the tab bar until tapped.
    await openTasks(tester);
    await quickAdd(tester, 'Paint the shed');

    await swipe(tester, 'Paint the shed', -260);
    expect(find.text('Task deleted.'), findsOneWidget);

    await outlastSnackbar(tester);
    expect(find.text('Task deleted.'), findsNothing);
    expect(find.text('Paint the shed'), findsNothing, reason: 'still deleted');
  });

  testWidgets('a task with steps left will not swipe complete', (tester) async {
    await openTasks(tester);
    await quickAdd(tester, 'Move house');
    final store = TaskScope.read(tester.element(find.byType(TideTabBar)));
    final task = store.open.single;
    store.update(
      task.copyWith(
        subtasks: const [
          Subtask(id: 'a', title: 'Pack', isCompleted: true),
          Subtask(id: 'b', title: 'Book a van'),
        ],
      ),
    );
    await settle(tester);

    await swipe(tester, 'Move house', 260);

    expect(find.text('Move house'), findsOneWidget, reason: 'sprang back');
    expect(store.open.single.isCompleted, isFalse);
    expect(find.textContaining('1 step still open'), findsOneWidget);
    await outlastSnackbar(tester);
  });

  testWidgets('leaving the tab puts the keyboard away', (tester) async {
    await openTasks(tester);
    await tester.tap(find.widgetWithText(TextField, 'Add a task'));
    await settle(tester);
    expect(tester.testTextInput.isVisible, isTrue);

    await tester.tap(
      find.descendant(
        of: find.byType(TideTabBar),
        matching: find.text('Today'),
      ),
    );
    await settle(tester);

    expect(tester.testTextInput.isVisible, isFalse);
  });

  testWidgets('a long press lists what a task can do', (tester) async {
    await openTasks(tester);
    await quickAdd(tester, 'Paint the shed');

    await tester.longPress(find.text('Paint the shed'));
    await settle(tester);

    expect(find.text('Edit task'), findsOneWidget);
    expect(find.text('Mark as complete'), findsOneWidget);
    expect(find.text('Move to today'), findsOneWidget);
    expect(find.text('Delete task'), findsOneWidget);

    await tester.tap(find.text('Delete task'));
    await settle(tester);

    expect(find.text('Paint the shed'), findsNothing);
    expect(find.text('Task deleted.'), findsOneWidget);
    await outlastSnackbar(tester);
  });

  testWidgets('the menu on a task with steps left points at the steps', (
    tester,
  ) async {
    await openTasks(tester);
    await quickAdd(tester, 'Move house');
    final store = TaskScope.read(tester.element(find.byType(TideTabBar)));
    store.update(
      store.open.single.copyWith(
        subtasks: const [Subtask(id: 'a', title: 'Pack')],
      ),
    );
    await settle(tester);

    await tester.longPress(find.text('Move house'));
    await settle(tester);

    expect(find.text('Mark as complete'), findsNothing);
    expect(find.text('Finish the steps'), findsOneWidget);
    expect(find.text('1 step left'), findsOneWidget);
  });
}
