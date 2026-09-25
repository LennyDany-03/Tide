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

  /// The fast path through the new-task drawer: open, type, Return.
  Future<void> quickAdd(WidgetTester tester, String title) async {
    await tester.tap(find.bySemanticsLabel('New task'));
    await settle(tester);
    await tester.enterText(
      find.widgetWithText(TextField, 'What needs doing?'),
      title,
    );
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
      find.text('Nothing on your list. Tap New task to add one.'),
      findsOneWidget,
    );
  });

  // It once sat on the bar on any phone with a gesture bar: the bar's
  // reserved height was rebuilt from a view padding the Scaffold strips out
  // of its body, so it came up one gesture bar short.
  testWidgets('the New task button floats clear of the tab bar', (
    tester,
  ) async {
    // A 24pt gesture bar at 3x.
    tester.view.padding = const FakeViewPadding(bottom: 72);
    tester.view.viewPadding = const FakeViewPadding(bottom: 72);
    await openTasks(tester);

    final button = tester.getRect(find.bySemanticsLabel('New task'));
    final bar = tester.getRect(find.byType(TideTabBar));
    expect(bar.top - button.bottom, greaterThanOrEqualTo(16));
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

  testWidgets('steps tick on the card, and the last one completes the task', (
    tester,
  ) async {
    await openTasks(tester);
    await quickAdd(tester, 'Move house');
    await outlastSnackbar(tester);
    final store = TaskScope.read(tester.element(find.byType(TideTabBar)));
    store.update(
      store.open.single.copyWith(
        subtasks: const [
          Subtask(id: 'a', title: 'Pack'),
          Subtask(id: 'b', title: 'Book a van'),
        ],
      ),
    );
    await settle(tester);

    await tester.tap(find.text('Pack'));
    await settle(tester);
    expect(store.open.single.subtasksDone, 1);
    expect(store.open.single.isCompleted, isFalse, reason: 'a step is open');
    expect(find.text('Move house'), findsOneWidget);

    await tester.tap(find.text('Book a van'));
    await settle(tester, 900);
    await settle(tester);
    expect(store.open, isEmpty);
    expect(store.completed.single.title, 'Move house');
    expect(find.text('Last step done. Task complete.'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await settle(tester);
    final back = store.open.single;
    expect(back.isCompleted, isFalse);
    expect(back.subtasksLeft, 1, reason: 'Undo takes the last tick back too');
    expect(find.text('Move house'), findsOneWidget);
    await outlastSnackbar(tester);
  });

  testWidgets('the new-task drawer takes a whole task in one go', (
    tester,
  ) async {
    await openTasks(tester);
    await tester.tap(find.bySemanticsLabel('New task'));
    await settle(tester);

    expect(
      tester.testTextInput.isVisible,
      isTrue,
      reason: 'the title is focused as the drawer rises',
    );

    await tester.enterText(
      find.widgetWithText(TextField, 'What needs doing?'),
      'Move house',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Add details'),
      'The flat on Harbour Street',
    );
    await tester.tap(find.text('Tomorrow'));
    await tester.enterText(
      find.widgetWithText(TextField, 'Add a step'),
      'Pack',
    );
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await settle(tester);
    await tester.enterText(
      find.widgetWithText(TextField, 'Add a step'),
      'Book a van',
    );
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await settle(tester);

    await tester.tap(find.text('Add task'));
    await settle(tester);

    final store = TaskScope.read(tester.element(find.byType(TideTabBar)));
    final task = store.open.single;
    final today = DateUtils.dateOnly(DateTime.now());
    expect(task.title, 'Move house');
    expect(task.description, 'The flat on Harbour Street');
    expect(task.dueDate, DateTime(today.year, today.month, today.day + 1));
    expect(task.subtasks.map((s) => s.title), ['Pack', 'Book a van']);
    expect(find.text('Move house'), findsOneWidget);
    expect(tester.testTextInput.isVisible, isFalse);
    await outlastSnackbar(tester);
  });

  testWidgets('the drawer will not add a task with no title', (tester) async {
    await openTasks(tester);
    await tester.tap(find.bySemanticsLabel('New task'));
    await settle(tester);

    await tester.tap(find.text('Add task'));
    await settle(tester);

    final store = TaskScope.read(tester.element(find.byType(TideTabBar)));
    expect(store.open, isEmpty);
    expect(
      find.text('What needs doing?'),
      findsOneWidget,
      reason: 'still open',
    );
  });

  testWidgets('a section folds away when its heading is tapped', (
    tester,
  ) async {
    await openTasks(tester);
    await quickAdd(tester, 'Paint the shed');
    await outlastSnackbar(tester);

    await tester.tap(find.text('Someday'));
    await settle(tester);
    expect(find.text('Paint the shed'), findsNothing);

    await tester.tap(find.text('Someday'));
    await settle(tester);
    expect(find.text('Paint the shed'), findsOneWidget);
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
